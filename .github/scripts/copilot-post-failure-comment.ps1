#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Posts a comment on a PR when Azure pipeline builds fail.

.DESCRIPTION
    This script analyzes failed check runs from a GitHub check suite and posts
    a formatted comment on the associated PR, specifically targeting AI-created PRs.
    It includes detection for comment loops to avoid infinite commenting.

.PARAMETER Repository
    The GitHub repository in the format "owner/repo"

.PARAMETER CheckSuiteId
    The ID of the check suite that failed

.PARAMETER PullRequestNumber
    The PR number to comment on

.PARAMETER MaxCommentCount
    The maximum number of comments allowed before skipping to avoid comment loops. Default is 5.

.PARAMETER DryRun
    If specified, the script will simulate posting a comment without actually making the API call.

.EXAMPLE
    ./copilot-post-failure-comment.ps1 -Repository "owner/repo" -CheckSuiteId 123456 -PullRequestNumber 42

.EXAMPLE
    ./copilot-post-failure-comment.ps1 -Repository "owner/repo" -CheckSuiteId 123456 -PullRequestNumber 42 -MaxCommentCount 3 -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,
    
    [Parameter(Mandatory = $true)]
    [string]$CheckSuiteId,
    
    [Parameter(Mandatory = $true)]
    [int]$PullRequestNumber,

    [Parameter(Mandatory = $false)]
    [int]$MaxCommentCount = 5,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Fetch PR information to get the author dynamically
try {
    $prInfoResponse = gh api `
        "repos/$Repository/pulls/$PullRequestNumber" `
        -H "Accept: application/vnd.github+json"
    $prInfoJson = $prInfoResponse | ConvertFrom-Json

    $PullRequestAuthor = $prInfoJson.user.login
    Write-Host "Fetched PR author: $PullRequestAuthor"
} catch {
    Write-Error "Failed to fetch PR information: $($_.Exception.Message)"
    exit 1
}

# Check if this is a bot/AI-created PR
$botUsers = @("Copilot")
$isBotPR = $PullRequestAuthor -in $botUsers

if (-not $isBotPR) {
    Write-Host "PR #$PullRequestNumber not created by a bot or Copilot user ($PullRequestAuthor). Skipping comment."
    exit 0
}

Write-Host "Processing failed check suite $CheckSuiteId for PR #$PullRequestNumber created by $PullRequestAuthor"

# Fetch existing comments to detect loops
try {
    $existingCommentsResponse = gh api `
        "repos/$Repository/issues/$PullRequestNumber/comments" `
        -H "Accept: application/vnd.github+json"
    $existingComments = $existingCommentsResponse | ConvertFrom-Json
    $commentCount = ($existingComments | Where-Object { $_.body -like '*Build Failed - AI Assistance Needed*' }).Count

    if ($commentCount -ge $MaxCommentCount) {
        Write-Warning "Comment loop detected. Skipping comment to avoid infinite loop."
        exit 0
    }
} catch {
    Write-Warning "Failed to fetch existing comments: $($_.Exception.Message)"
}

try {
    # Fetch Check Runs
    $checkRunsResponse = gh api `
        "repos/$Repository/check-suites/$CheckSuiteId/check-runs" `
        -H "Accept: application/vnd.github+json"
    $checkRunsJson = $checkRunsResponse | ConvertFrom-Json

    # Initialize lists to store failed jobs and error messages
    $failedJobs = @()
    $errorFiles = @()
    $errorMessages = @()
    $errorDetails = @()

    # Loop through Failed Runs
    foreach ($checkRun in $checkRunsJson.check_runs) {
        if ($checkRun.conclusion -eq "success" -or $checkRun.conclusion -eq $null) {
            continue
        }

        # Build job description
        $jobDescription = "- [$($checkRun.name)]($($checkRun.details_url))"
        if ($checkRun.output.summary) {
            $jobDescription += " - $($checkRun.output.summary)"
        }
        $failedJobs += $jobDescription

        $errorMessages += "### $($checkRun.name) - $($checkRun.conclusion)"

        # Get Annotations (if any)
        if ($checkRun.output.annotations_url) {
            try {
                $annotationsResponse = gh api `
                    $checkRun.output.annotations_url `
                    -H "Accept: application/vnd.github+json"
                $annotations = $annotationsResponse | ConvertFrom-Json

                if ($annotations -and $annotations.Count -gt 0) {
                    foreach ($annotation in $annotations) {
                        if ($annotation.path -and $annotation.message) {
                            $normalizedPath = $annotation.path -replace "\\", "/"
                            if ($annotation.message.StartsWith($annotation.path)) {
                                $messageWithoutPath = $annotation.message.Substring($annotation.path.Length).TrimStart(':', ' ')
                                $errorFiles += "$normalizedPath`: $messageWithoutPath"
                                $errorMessages += "$normalizedPath`: $messageWithoutPath"
                            } else {
                                $errorMessages += "$normalizedPath`: $($annotation.message)"
                            }
                        } elseif ($annotation.message) {
                            $errorMessages += $annotation.message
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to fetch annotations for $($checkRun.name): $($_.Exception.Message)"
            }
        }

        # Also check for output text/summary as error details
        if ($checkRun.output.text -and $checkRun.output.text.Trim()) {
            $errorDetails += $checkRun.output.text
        }
    }

    # Remove duplicate error messages and clean them up
    $errorFiles = $errorFiles | 
        Where-Object { $_ -and $_.Trim() } |
        Sort-Object -Unique |
        ForEach-Object { $_.Trim() }

    # Create the comment body
    $failedJobsText = if ($failedJobs.Count -gt 0) { $failedJobs -join "`n" } else { "No specific job failures detected." }
    $errorFilesText = if ($errorFiles.Count -gt 0) { $errorFiles -join "`n" } else { "No specific error files found." }
    $errorMessagesText = if ($errorMessages.Count -gt 0) { $errorMessages -join "`n" } else { "No specific error messages found." }
    $errorDetailsText = if ($errorDetails.Count -gt 0) { $errorDetails -join "`n" } else { "No specific error details found." }

    $commentBody = @"
### 🚨 Build Failed - AI Assistance Needed

The Azure pipeline has failed for this PR. Here are the details:

#### Failed Jobs:
$failedJobsText

#### Errors:
``````
$errorFilesText
``````

<details>
<summary>See More</summary>

``````
$errorMessagesText
``````

$errorDetailsText

</details>

@$PullRequestAuthor Please analyze these build failures and suggest fixes. Focus on:
1. Understanding the root cause of each failure
2. Providing specific code changes to resolve the issues  
3. Ensuring the fixes maintain code quality and don't break existing functionality
4. Avoiding unnecessary changes or comments unrelated to the failures

---
*This comment was automatically generated when the build failed.*
"@

    Write-Host "Comment body prepared:"
    Write-Host $commentBody
    Write-Host ""

    # Add a comment to the PR
    if ($PullRequestNumber -and ($failedJobs.Count -gt 0 -or $errorMessages.Count -gt 0)) {
        if ($DryRun) {
            Write-Host "DryRun enabled. Comment not posted."
            Write-Host "Comment body that would have been posted:"
            Write-Host $commentBody
        } else {
            $commentResponse = gh api repos/$Repository/issues/$PullRequestNumber/comments -f body="$commentBody"
            Write-Host "Comment posted successfully to PR #$PullRequestNumber"
            Write-Host "Comment URL: $(($commentResponse | ConvertFrom-Json).html_url)"
        }
    } else {
        Write-Host "No failures found or PR number missing. No comment posted."
    }

} catch {
    Write-Error "Failed to process check suite and post comment: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
