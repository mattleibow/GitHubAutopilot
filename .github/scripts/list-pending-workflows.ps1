#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists workflow runs that need approval.

.DESCRIPTION
    This script uses gh CLI to find workflow runs that require manual approval
    (action_required status) and other pending workflows.

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

# Get workflows that need action (awaiting approval)
Write-Host "`nChecking for workflows awaiting approval..." -ForegroundColor Yellow
$actionRequiredRuns = gh run list --repo $Repository --status action_required --json name,status,conclusion,event,headBranch,url,workflowName,createdAt | ConvertFrom-Json

# Get other pending workflows  
Write-Host "Checking for other pending workflows..." -ForegroundColor Yellow
$pendingRuns = gh run list --repo $Repository --status pending --json name,status,conclusion,event,headBranch,url,workflowName,createdAt | ConvertFrom-Json
$queuedRuns = gh run list --repo $Repository --status queued --json name,status,conclusion,event,headBranch,url,workflowName,createdAt | ConvertFrom-Json
$requestedRuns = gh run list --repo $Repository --status requested --json name,status,conclusion,event,headBranch,url,workflowName,createdAt | ConvertFrom-Json
$waitingRuns = gh run list --repo $Repository --status waiting --json name,status,conclusion,event,headBranch,url,workflowName,createdAt | ConvertFrom-Json

# Combine all pending runs
$allPendingRuns = @()
$allPendingRuns += $actionRequiredRuns
$allPendingRuns += $pendingRuns  
$allPendingRuns += $queuedRuns
$allPendingRuns += $requestedRuns
$allPendingRuns += $waitingRuns

# Remove duplicates by run ID
$uniqueRuns = $allPendingRuns | Sort-Object name -Unique

if ($uniqueRuns.Count -eq 0) {
    Write-Host "`n✅ No workflows needing approval or pending." -ForegroundColor Green
    exit 0
}

# Display results
Write-Host "`n🚨 Found $($uniqueRuns.Count) workflow run(s) needing attention:" -ForegroundColor Red

foreach ($run in $uniqueRuns) {
    Write-Host "`n🔴 $($run.workflowName)" -ForegroundColor Red
    Write-Host "   Name: $($run.name)" -ForegroundColor Gray
    
    if ($run.status -eq "completed" -and $run.conclusion -eq "action_required") {
        Write-Host "   Status: awaiting approval" -ForegroundColor Red
    } else {
        Write-Host "   Status: $($run.status)" -ForegroundColor Yellow
    }
    
    Write-Host "   Event: $($run.event)" -ForegroundColor Gray
    if ($run.headBranch) {
        Write-Host "   Branch: $($run.headBranch)" -ForegroundColor Gray
    }
    Write-Host "   Created: $($run.createdAt)" -ForegroundColor Gray
    Write-Host "   URL: $($run.url)" -ForegroundColor Blue
}