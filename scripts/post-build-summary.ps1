<#
.SYNOPSIS
    Posts a summary comment on a PR or build with all build failures after an Azure Pipeline run.

.DESCRIPTION
    This script fetches job and task results from Azure DevOps using the REST API, extracts all errors and details for failed jobs,
    and generates a detailed markdown comment suitable for posting to GitHub or Azure DevOps.

.PARAMETER CollectionUri
    The Azure DevOps collection URI (e.g., https://dev.azure.com/your-org/). Defaults to the environment variable `SYSTEM_COLLECTIONURI`.

.PARAMETER TeamProject
    The Azure DevOps project name. Defaults to the environment variable `SYSTEM_TEAMPROJECT`.

.PARAMETER BuildId
    The Azure DevOps build ID to fetch results for. Defaults to the environment variable `BUILD_BUILDID`.

.PARAMETER Repository
    The name of the repository where the build was run. Defaults to the environment variable `BUILD_REPOSITORY_NAME`.

.PARAMETER PRNumber
    The pull request number to comment on. Defaults to the environment variable `SYSTEM_PULLREQUEST_PULLREQUESTNUMBER`.
    If not provided, the script will skip posting to GitHub.

.PARAMETER AccessToken
    The Azure DevOps System.AccessToken (OAuth token) for REST API authentication. Defaults to the environment variable `SYSTEM_ACCESSTOKEN`.

.EXAMPLE
    .\post-build-summary.ps1

.EXAMPLE
    .\post-build-summary.ps1 -CollectionUri "https://dev.azure.com/your-org/" -TeamProject "YourProject" -BuildId "12345" -AccessToken $env:SYSTEM_ACCESSTOKEN
#>
param(
    [string]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
    [string]$TeamProject = $env:SYSTEM_TEAMPROJECT,
    [string]$BuildId = $env:BUILD_BUILDID,
    [string]$Repository = $env:BUILD_REPOSITORY_NAME,
    [string]$PRNumber = $env:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER,
    [string]$AccessToken = $env:SYSTEM_ACCESSTOKEN
)

$ErrorActionPreference = 'Stop'

if (-not $CollectionUri -or -not $TeamProject) {
# if (-not $CollectionUri -or -not $TeamProject -or -not $AccessToken) {
    Write-Error "Missing required parameters. Please provide -AccessToken, -CollectionUri, and -TeamProject."
    exit 1
}

# Clean up parameters
$CollectionUri = $CollectionUri.TrimEnd('/')

# Initialize variables
$failedJobs = @()
$errorFiles = @()
$errorMessages = @()
$errorDetails = @()

# Prepare auth header
if ($AccessToken) {
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AccessToken"))
    $headers = @{ Authorization = "Basic $base64AuthInfo" }
} else {
    $headers = @{ Accepts = "application/json" }
}
# Get timeline (contains jobs and tasks)
$timelineUrl = "$CollectionUri/$TeamProject/_apis/build/Builds/$BuildId/Timeline?api-version=7.1"
Write-Host "Fetching timeline from: $timelineUrl"

$timeline = Invoke-RestMethod -Uri $timelineUrl -Headers $headers

# Group records by job
$jobRecords = $timeline.records | Where-Object { $_.type -eq 'Job' }
$taskRecords = $timeline.records | Where-Object { $_.type -eq 'Task' }

foreach ($job in $jobRecords) {
    Write-Host "Processing job: $($job.name) with result: $($job.result)"

    if ($job.result -eq 'succeeded') {
        continue
    }

    $failedJobs += "- $($job.name): $($job.result)"

    # Find all tasks under this job
    $tasks = $taskRecords | Where-Object { $_.parentId -eq $job.id }
    foreach ($task in $tasks) {
        if ($task.issues) {
            $errorMessages += "**Task: $($job.name) - $($task.name)**"
            if ($task.log && $task.log.url) {
                $logUrl = $task.log.url
                $errorMessages += "* [See Logs]($CollectionUri/$TeamProject/_build/results?buildId=$BuildId&view=logs&j=$($job.id)&t=$($task.id))"
                $errorMessages += "* [See Raw Logs]($logUrl)"
            }
            $errorMessages += "``````"
            foreach ($issue in $task.issues) {
                $type = $issue.type
                if ($type -ne 'error') {
                    continue
                }

                $msg = $issue.message
                $sourceFile = $issue.data.sourcepath
                
                $errorMessages += $msg

                if ($sourceFile) {
                    $normalizedPath = $sourceFile -replace "\\", "/"
                    if ($msg.StartsWith($sourceFile)) {
                        $msg = $normalizedPath + $msg.Substring($sourceFile.Length)
                    }
                    $errorFiles += $msg
                }
            }
            $errorMessages += "``````"
            $errorMessages += ""
        }
    }
}

# Remove duplicate error messages
$errorFiles = $errorFiles | Select-Object -Unique

# Create the comment body
$commentBody = @"
### 🚨 Build Summary

**Build Status**: Failed

#### Failed Jobs:
$($failedJobs -join "`n")

#### File Errors:
``````
$($errorFiles -join "`n")
``````

@Copilot Please analyze these build failures and suggest fixes. Focus on:
1. Understanding the root cause of each failure
2. Providing specific code changes to resolve the issues  
3. Ensuring the fixes maintain code quality and don't break existing functionality
4. Avoiding unnecessary changes or comments unrelated to the failures

<br>

<details>
<summary>See All Errors</summary>

<br>

All errors and details from the build:

$($errorMessages -join "`n")

$($errorDetails -join "`n")

</details>

---
*This comment was automatically generated when the build failed.*
"@

# Output the comment body and post to PR if PR number is available
Write-Output "Comment as Markdown:"
Write-Output $commentBody

$markdownInfo = $commentBody | ConvertFrom-Markdown

Write-Output "Comment as HTML:"
Write-Output $markdownInfo.Html

# Post to PR using GitHub CLI if PR number is available
if ($PRNumber) {
    Write-Host "Posting comment to PR #$PRNumber in $Repository..."
    
    # $tempFile = New-TemporaryFile
    # $commentBody | Out-File -FilePath $tempFile -Encoding utf8
    # gh pr comment $PRNumber --repo $Repository --body-file $tempFile
    # Remove-Item $tempFile

    $singleLine = $markdownInfo.Html -replace "`n", " "
    Write-Host "##vso[task.setvariable variable=GITHUB_COMMENT]$singleLine"
} else {
    Write-Warning "No PR number detected. Skipping GitHub comment post."
}
