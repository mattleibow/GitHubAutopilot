#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists workflow runs that need approval.

.DESCRIPTION
    This script uses GitHub API to find workflow runs that require manual approval
    (action_required status only).

.PARAMETER Repository
    The GitHub repository in the format "owner/repo". Required.

.EXAMPLE
    ./list-pending-workflows.ps1 -Repository "mattleibow/GitHubAutopilot"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Repository
)

Write-Host "🔄 Checking for workflows needing approval..." -ForegroundColor Cyan
Write-Host "Repository: $Repository" -ForegroundColor Green

# Get workflow runs that need action (awaiting approval) using GitHub API
Write-Host "`nFetching workflows awaiting approval..." -ForegroundColor Yellow
$workflowRuns = gh api "repos/$Repository/actions/runs?status=action_required&per_page=100" --jq '.workflow_runs[] | {
    id: .id,
    name: .name,
    status: .status,
    conclusion: .conclusion,
    event: .event,
    head_branch: .head_branch,
    head_sha: .head_sha,
    url: .html_url,
    workflow_name: .name,
    created_at: .created_at,
    run_number: .run_number,
    pull_requests: .pull_requests
}' | ConvertFrom-Json

if (-not $workflowRuns -or $workflowRuns.Count -eq 0) {
    Write-Host "`n✅ No workflows needing approval." -ForegroundColor Green
    exit 0
}

# Ensure workflowRuns is always an array
if ($workflowRuns -isnot [array]) {
    $workflowRuns = @($workflowRuns)
}

# Display results
Write-Host "`n🚨 Found $($workflowRuns.Count) workflow run(s) needing approval:" -ForegroundColor Red

foreach ($run in $workflowRuns) {
    Write-Host "`n🔴 $($run.workflow_name)" -ForegroundColor Red
    Write-Host "   Status: awaiting approval" -ForegroundColor Red
    Write-Host "   Event: $($run.event)" -ForegroundColor Gray
    
    # Show PR information if available from the workflow run
    if ($run.pull_requests -and $run.pull_requests.Count -gt 0) {
        $prNumber = $run.pull_requests[0].number
        # Get PR details using API
        $prDetails = gh api "repos/$Repository/pulls/$prNumber" --jq '{number: .number, author: .user.login}' | ConvertFrom-Json
        Write-Host "   Related: PR #$($prDetails.number) (by @$($prDetails.author))" -ForegroundColor Cyan
    } elseif ($run.head_branch -and $run.head_branch -ne "main" -and $run.head_branch -ne "master") {
        # Try to find PR by branch name using API
        $prSearch = gh api "repos/$Repository/pulls?head=$($Repository.Split('/')[0]):$($run.head_branch)&state=open" --jq '.[0] | select(. != null) | {number: .number, author: .user.login}' | ConvertFrom-Json
        if ($prSearch) {
            Write-Host "   Related: PR #$($prSearch.number) (by @$($prSearch.author))" -ForegroundColor Cyan
        }
    }
    
    if ($run.head_branch) {
        Write-Host "   Branch: $($run.head_branch)" -ForegroundColor Gray
    }
    Write-Host "   Created: $($run.created_at)" -ForegroundColor Gray
    Write-Host "   URL: $($run.url)" -ForegroundColor Blue
}