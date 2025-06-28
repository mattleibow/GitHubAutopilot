#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists all PRs that have workflows pending manual approval.

.DESCRIPTION
    This script queries GitHub API to find all open PRs and checks their associated
    workflow runs to identify which ones are pending manual approval. It provides
    detailed information about each PR and the specific workflows awaiting approval.

.PARAMETER Repository
    The GitHub repository in the format "owner/repo". If not provided, uses the current repository.

.PARAMETER OutputFormat
    The output format: "table", "json", or "detailed". Default is "detailed".

.EXAMPLE
    ./list-pending-approvals.ps1
    Lists pending approvals for the current repository

.EXAMPLE
    ./list-pending-approvals.ps1 -Repository "mattleibow/GitHubAutopilot" -OutputFormat "table"
    Lists pending approvals in table format for the specified repository
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Repository = "",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("table", "json", "detailed")]
    [string]$OutputFormat = "detailed"
)

# Function to get repository info if not provided
function Get-CurrentRepository {
    # Try GitHub Actions environment first
    if ($env:GITHUB_REPOSITORY) {
        return $env:GITHUB_REPOSITORY
    }
    
    # Try git remote
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if ($remoteUrl) {
            # Parse GitHub URL
            if ($remoteUrl -match "github\.com[:/]([^/]+)/([^/.]+)") {
                return "$($matches[1])/$($matches[2])"
            }
        }
    } catch {
        # Ignore git errors
    }
    
    # Try gh CLI
    try {
        $repoInfo = gh repo view --json owner,name 2>$null | ConvertFrom-Json
        if ($repoInfo) {
            return "$($repoInfo.owner.login)/$($repoInfo.name)"
        }
    } catch {
        # Ignore gh errors
    }
    
    Write-Error "Could not determine current repository. Please specify -Repository parameter."
    exit 1
}

# Function to check if workflow run is pending approval
function Test-WorkflowPendingApproval {
    param($workflowRun)
    
    # Check for pending approval states
    $pendingStates = @("waiting", "requested", "pending")
    
    # Check the main status
    if ($workflowRun.status -in $pendingStates) {
        return $true
    }
    
    # Check if conclusion indicates manual approval needed
    if ($workflowRun.status -eq "queued" -and $workflowRun.event -eq "pull_request") {
        return $true
    }
    
    # Check if workflow is waiting for deployment approval
    if ($workflowRun.status -eq "waiting") {
        return $true
    }
    
    return $false
}

# Function to get pending deployments for a workflow run
function Get-PendingDeployments {
    param($repository, $workflowRunId)
    
    try {
        $deployments = gh api "repos/$repository/actions/runs/$workflowRunId/pending_deployments" | ConvertFrom-Json
        return $deployments
    } catch {
        return @()
    }
}

# Check GitHub CLI authentication
function Test-GitHubAuthentication {
    # Check if running in GitHub Actions
    if ($env:GITHUB_ACTIONS -eq "true") {
        if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) {
            return $true
        } else {
            Write-Host "❌ Running in GitHub Actions but GH_TOKEN is not set." -ForegroundColor Red
            Write-Host "Please set the GH_TOKEN environment variable in your workflow:" -ForegroundColor Yellow
            Write-Host "env:" -ForegroundColor Gray
            Write-Host "  GH_TOKEN: `${{ github.token }}" -ForegroundColor Gray
            return $false
        }
    }
    
    # Check regular authentication
    try {
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

# Main execution starts here
Write-Host "🔍 Checking for PRs with pending workflow approvals..." -ForegroundColor Cyan

# Check if GitHub CLI is authenticated
if (-not (Test-GitHubAuthentication)) {
    if ($env:GITHUB_ACTIONS -eq "true") {
        # Already handled in the function above
        exit 1
    } else {
        Write-Host "❌ GitHub CLI is not authenticated." -ForegroundColor Red
        Write-Host "Please run 'gh auth login' to authenticate before using this script." -ForegroundColor Yellow
        Write-Host "For more information, visit: https://cli.github.com/manual/gh_auth_login" -ForegroundColor Blue
        exit 1
    }
}

# Determine repository
if (-not $Repository) {
    $Repository = Get-CurrentRepository
}

Write-Host "Repository: $Repository" -ForegroundColor Green

try {
    # Get all open PRs
    Write-Host "Fetching open pull requests..." -ForegroundColor Yellow
    $prs = gh api "repos/$Repository/pulls?state=open&per_page=100" | ConvertFrom-Json
    
    if ($prs.Count -eq 0) {
        Write-Host "✅ No open pull requests found." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "Found $($prs.Count) open PR(s). Checking workflow statuses..." -ForegroundColor Yellow
    
    $prsWithPendingApprovals = @()
    
    # Check each PR for pending workflow approvals
    foreach ($pr in $prs) {
        Write-Host "  Checking PR #$($pr.number): $($pr.title)" -ForegroundColor Gray
        
        try {
            # Get workflow runs for this PR
            $workflowRuns = gh api "repos/$Repository/actions/runs?event=pull_request&branch=$($pr.head.ref)&per_page=100" | ConvertFrom-Json
            
            $pendingWorkflows = @()
            
            foreach ($run in $workflowRuns.workflow_runs) {
                # Only check runs that are associated with this PR
                if ($run.pull_requests -and ($run.pull_requests | Where-Object { $_.number -eq $pr.number })) {
                    if (Test-WorkflowPendingApproval -workflowRun $run) {
                        # Get additional details about pending deployments
                        $pendingDeployments = Get-PendingDeployments -repository $Repository -workflowRunId $run.id
                        
                        $pendingWorkflows += [PSCustomObject]@{
                            WorkflowName = $run.name
                            WorkflowId = $run.id
                            Status = $run.status
                            Conclusion = $run.conclusion
                            CreatedAt = $run.created_at
                            HtmlUrl = $run.html_url
                            PendingDeployments = $pendingDeployments
                        }
                    }
                }
            }
            
            if ($pendingWorkflows.Count -gt 0) {
                $prsWithPendingApprovals += [PSCustomObject]@{
                    PR = $pr
                    PendingWorkflows = $pendingWorkflows
                }
            }
        } catch {
            Write-Warning "Failed to get workflow runs for PR #$($pr.number): $($_.Exception.Message)"
        }
    }
    
    # Output results
    if ($prsWithPendingApprovals.Count -eq 0) {
        Write-Host "✅ No PRs found with pending workflow approvals." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "`n🚨 Found $($prsWithPendingApprovals.Count) PR(s) with pending workflow approvals:" -ForegroundColor Red
    
    switch ($OutputFormat) {
        "json" {
            $prsWithPendingApprovals | ConvertTo-Json -Depth 10
        }
        "table" {
            Write-Host "`nPR | Title | Pending Workflows" -ForegroundColor Yellow
            Write-Host "---|-------|------------------" -ForegroundColor Yellow
            foreach ($item in $prsWithPendingApprovals) {
                $workflowNames = ($item.PendingWorkflows | ForEach-Object { $_.WorkflowName }) -join ", "
                Write-Host "#$($item.PR.number) | $($item.PR.title) | $workflowNames"
            }
        }
        "detailed" {
            foreach ($item in $prsWithPendingApprovals) {
                Write-Host "`n📋 PR #$($item.PR.number): $($item.PR.title)" -ForegroundColor Cyan
                Write-Host "   Author: $($item.PR.user.login)" -ForegroundColor Gray
                Write-Host "   URL: $($item.PR.html_url)" -ForegroundColor Gray
                Write-Host "   Branch: $($item.PR.head.ref) → $($item.PR.base.ref)" -ForegroundColor Gray
                Write-Host "   Created: $($item.PR.created_at)" -ForegroundColor Gray
                
                Write-Host "`n   🔄 Pending Workflows:" -ForegroundColor Yellow
                foreach ($workflow in $item.PendingWorkflows) {
                    Write-Host "   • $($workflow.WorkflowName)" -ForegroundColor White
                    Write-Host "     Status: $($workflow.Status)" -ForegroundColor Magenta
                    if ($workflow.Conclusion) {
                        Write-Host "     Conclusion: $($workflow.Conclusion)" -ForegroundColor Magenta
                    }
                    Write-Host "     Created: $($workflow.CreatedAt)" -ForegroundColor Gray
                    Write-Host "     URL: $($workflow.HtmlUrl)" -ForegroundColor Gray
                    
                    if ($workflow.PendingDeployments -and $workflow.PendingDeployments.Count -gt 0) {
                        Write-Host "     🚀 Pending Deployments:" -ForegroundColor Yellow
                        foreach ($deployment in $workflow.PendingDeployments) {
                            Write-Host "       - Environment: $($deployment.environment.name)" -ForegroundColor Cyan
                            if ($deployment.reviewers) {
                                $reviewers = ($deployment.reviewers | ForEach-Object { 
                                    if ($_.type -eq "User") { $_.reviewer.login } else { $_.reviewer.name } 
                                }) -join ", "
                                Write-Host "       - Reviewers: $reviewers" -ForegroundColor Cyan
                            }
                        }
                    }
                    Write-Host ""
                }
            }
        }
    }
    
    Write-Host "`n📊 Summary: $($prsWithPendingApprovals.Count) PR(s) require workflow approval" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to fetch PR and workflow information: $($_.Exception.Message)"
    Write-Error "Make sure you have the GitHub CLI installed and authenticated."
    exit 1
}