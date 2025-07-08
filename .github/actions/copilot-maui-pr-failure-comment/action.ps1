#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Polls a repository for Copilot PRs with completed check suites and posts build failure comments.

.DESCRIPTION
    This script uses the GitHub CLI to:
    - List open PRs in a repository created by Copilot
    - For each PR, find completed check suites
    - For each failed check suite, post a build failure comment (if not already posted too many times)
    - Avoids comment loops by limiting the number of comments per PR

.PARAMETER Repository
    The GitHub repository to post comments on.

.PARAMETER MaxCommentCount
    The maximum number of comments allowed before skipping to avoid comment loops. Default is 5.

.PARAMETER DryRun
    If specified, the script will simulate posting a comment without actually making the API call.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $false)]
    [int]$MaxCommentCount = 5,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

try {
    $prsResponse = gh pr list `
        --author "@copilot" `
        --json number,state,baseRefName,baseRefOid,headRefName,headRefOid
    $prs = $prsResponse | ConvertFrom-Json
} catch {
    Write-Error "Failed to fetch Copilot PRs: $($_.Exception.Message)"
    exit 1
}

foreach ($pr in $prs) {
    $prNumber = $pr.number
    Write-Host "Processing PR #$prNumber by Copilot"

    try {
        $suitesResponse = gh api `
            "repos/$Repository/commits/$($pr.headRefOid)/check-suites" `
            -H "Accept: application/vnd.github+json"
        $suites = ($suitesResponse | ConvertFrom-Json).check_suites
    } catch {
        Write-Warning "Failed to fetch check suites for PR #$prNumber : $(${_.Exception.Message})"
        continue
    }

    foreach ($suite in $suites) {
        if ($suite.status -ne "completed" -or $suite.conclusion -eq "success") { continue }

        $suiteId = $suite.id
        Write-Host "  Found failed check suite $suiteId"

        # Check for comment loop
        try {
            $commentsResponse = gh api `
                "repos/$Repository/issues/$prNumber/comments" `
                -H "Accept: application/vnd.github+json"
            $comments = $commentsResponse | ConvertFrom-Json
            $commentCount = ($comments | Where-Object { $_.body -like '*Build Failed - AI Assistance Needed*' }).Count
            if ($commentCount -ge $MaxCommentCount) {
                Write-Warning "  Comment loop detected for PR #$prNumber. Skipping."
                continue
            }
        } catch {
            Write-Warning "  Failed to fetch comments for PR #$prNumber : $(${_.Exception.Message})"
        }

        # Fetch check runs for the suite
        try {
            $checkRunsResponse = gh api `
                "repos/$Repository/check-suites/$suiteId/check-runs" `
                -H "Accept: application/vnd.github+json"
            Write-Host $checkRunsResponse
            $checkRuns = ($checkRunsResponse | ConvertFrom-Json).check_runs
        } catch {
            Write-Warning "  Failed to fetch check runs for suite $suiteId : $(${_.Exception.Message})"
            continue
        }

        $failedJobs = @()
        $errorFiles = @()
        $errorMessages = @()
        $errorDetails = @()

        foreach ($checkRun in $checkRuns) {
            if ($checkRun.conclusion -eq "success" -or $null -eq $checkRun.conclusion) { continue }
            $jobDescription = "- [$($checkRun.name)]($($checkRun.details_url))"
            if ($checkRun.output.summary) { $jobDescription += " - $($checkRun.output.summary)" }
            $failedJobs += $jobDescription
            $errorMessages += "### $($checkRun.name) - $($checkRun.conclusion)"
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
                    Write-Warning "    Failed to fetch annotations for $($checkRun.name): $(${_.Exception.Message})"
                }
            }
            if ($checkRun.output.text -and $checkRun.output.text.Trim()) {
                $errorDetails += $checkRun.output.text
            }
        }

        $errorFiles = $errorFiles | Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique | ForEach-Object { $_.Trim() }
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

@copilot Please analyze these build failures and suggest fixes. Focus on:
1. Understanding the root cause of each failure
2. Providing specific code changes to resolve the issues  
3. Ensuring the fixes maintain code quality and don't break existing functionality
4. Avoiding unnecessary changes or comments unrelated to the failures

---
*This comment was automatically generated when the build failed.*
"@

        Write-Host "  Comment body prepared."
        if ($DryRun) {
            Write-Host "  [DryRun] Would post comment to PR #$prNumber."
            Write-Host $commentBody
        } else {
            try {
                $commentResponse = gh api repos/$Repository/issues/$prNumber/comments -f body="$commentBody"
                Write-Host "  Comment posted successfully to PR #$prNumber"
                Write-Host "  Comment URL: $(($commentResponse | ConvertFrom-Json).html_url)"
            } catch {
                Write-Warning "  Failed to post comment to PR #$prNumber : $(${_.Exception.Message})"
            }
        }
    }
}
