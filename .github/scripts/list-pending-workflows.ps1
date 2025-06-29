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

# Function to get PR information for a workflow run
function Get-PRInfo {
    param($run)
    
    $prNumber = $null
    
    # For pull_request events, the number field contains the PR number
    if ($run.event -eq "pull_request" -and $run.number) {
        $prNumber = $run.number
    } else {
        # For other events, try to find PR by matching head SHA
        if ($run.headSha) {
            try {
                $prs = gh pr list --repo $Repository --head $run.headBranch --json number,headRefOid | ConvertFrom-Json
                $matchingPR = $prs | Where-Object { $_.headRefOid -eq $run.headSha }
                if ($matchingPR) {
                    $prNumber = $matchingPR.number
                }
            } catch {
                # Ignore errors when trying to find PR
            }
        }
    }
    
    # If we found a PR number, get additional details including author
    if ($prNumber) {
        try {
            $prDetails = gh pr view $prNumber --repo $Repository --json number,author | ConvertFrom-Json
            return @{
                Number = $prDetails.number
                Author = $prDetails.author.login
            }
        } catch {
            # If we can't get details, just return the number
            return @{
                Number = $prNumber
                Author = $null
            }
        }
    }
    
    return $null
}

Write-Host "🔄 Checking for workflows needing approval..." -ForegroundColor Cyan
Write-Host "Repository: $Repository" -ForegroundColor Green

# Get workflows that need action (awaiting approval)
Write-Host "`nChecking for workflows awaiting approval..." -ForegroundColor Yellow
$actionRequiredRuns = gh run list --repo $Repository --status action_required --json name,status,conclusion,event,headBranch,headSha,url,workflowName,createdAt,number | ConvertFrom-Json

# Get other pending workflows  
Write-Host "Checking for other pending workflows..." -ForegroundColor Yellow
$pendingRuns = gh run list --repo $Repository --status pending --json name,status,conclusion,event,headBranch,headSha,url,workflowName,createdAt,number | ConvertFrom-Json
$queuedRuns = gh run list --repo $Repository --status queued --json name,status,conclusion,event,headBranch,headSha,url,workflowName,createdAt,number | ConvertFrom-Json
$requestedRuns = gh run list --repo $Repository --status requested --json name,status,conclusion,event,headBranch,headSha,url,workflowName,createdAt,number | ConvertFrom-Json
$waitingRuns = gh run list --repo $Repository --status waiting --json name,status,conclusion,event,headBranch,headSha,url,workflowName,createdAt,number | ConvertFrom-Json

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
    
    # Show PR information if available
    $prInfo = Get-PRInfo $run
    if ($prInfo) {
        if ($prInfo.Author) {
            Write-Host "   Related: PR #$($prInfo.Number) (by @$($prInfo.Author))" -ForegroundColor Cyan
        } else {
            Write-Host "   Related: PR #$($prInfo.Number)" -ForegroundColor Cyan
        }
    }
    
    if ($run.headBranch) {
        Write-Host "   Branch: $($run.headBranch)" -ForegroundColor Gray
    }
    Write-Host "   Created: $($run.createdAt)" -ForegroundColor Gray
    Write-Host "   URL: $($run.url)" -ForegroundColor Blue
}