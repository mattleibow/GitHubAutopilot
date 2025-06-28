#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists all PRs with checks that are waiting to run.

.DESCRIPTION
    This script queries GitHub API to find all open PRs and checks which required
    status checks or workflows haven't started running yet. It identifies PRs where
    builds or other checks are waiting to begin, helping identify workflow bottlenecks.

.PARAMETER Repository
    The GitHub repository in the format "owner/repo". If not provided, uses the current repository.

.PARAMETER OutputFormat
    The output format: "table", "json", or "detailed". Default is "detailed".

.EXAMPLE
    ./list-pending-approvals.ps1
    Lists PRs with pending checks for the current repository

.EXAMPLE
    ./list-pending-approvals.ps1 -Repository "mattleibow/GitHubAutopilot" -OutputFormat "table"
    Lists PRs with pending checks in table format for the specified repository
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Repository = "",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("table", "json", "detailed")]
    [string]$OutputFormat = "detailed",
    
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Show help if requested
if ($Help) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

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

# Function to check if PR has pending/waiting checks
function Get-PendingChecks {
    param($repository, $pr)
    
    $pendingChecks = @()
    $commitSha = $pr.head.sha
    
    try {
        # Get check runs for the head commit
        $checkRuns = gh api "repos/$repository/commits/$commitSha/check-runs?per_page=100" | ConvertFrom-Json
        
        # Get commit statuses (legacy status API)
        $commitStatuses = gh api "repos/$repository/commits/$commitSha/status" | ConvertFrom-Json
        
        # Get required status checks from branch protection
        $requiredChecks = @()
        try {
            $branchProtection = gh api "repos/$repository/branches/$($pr.base.ref)/protection" | ConvertFrom-Json
            if ($branchProtection.required_status_checks -and $branchProtection.required_status_checks.contexts) {
                $requiredChecks = $branchProtection.required_status_checks.contexts
            }
        } catch {
            # Branch protection might not be set up
        }
        
        # Check for pending/queued/waiting check runs
        foreach ($checkRun in $checkRuns.check_runs) {
            if ($checkRun.status -eq "queued" -or $checkRun.status -eq "pending" -or $checkRun.status -eq "waiting" -or $checkRun.status -eq "requested") {
                $pendingChecks += [PSCustomObject]@{
                    Name = $checkRun.name
                    Status = $checkRun.status
                    Type = "check_run"
                    HtmlUrl = $checkRun.html_url
                    Conclusion = $checkRun.conclusion
                    StartedAt = $checkRun.started_at
                    CreatedAt = $checkRun.created_at
                }
            }
        }
        
        # Check for pending commit statuses
        foreach ($status in $commitStatuses.statuses) {
            if ($status.state -eq "pending") {
                $pendingChecks += [PSCustomObject]@{
                    Name = $status.context
                    Status = $status.state
                    Type = "status"
                    HtmlUrl = $status.target_url
                    Description = $status.description
                    CreatedAt = $status.created_at
                }
            }
        }
        
        # Check if any required checks are missing entirely
        $allCheckNames = @()
        $allCheckNames += $checkRuns.check_runs | ForEach-Object { $_.name }
        $allCheckNames += $commitStatuses.statuses | ForEach-Object { $_.context }
        
        foreach ($requiredCheck in $requiredChecks) {
            if ($requiredCheck -notin $allCheckNames) {
                $pendingChecks += [PSCustomObject]@{
                    Name = $requiredCheck
                    Status = "missing"
                    Type = "required_check"
                    HtmlUrl = $null
                    Description = "Required check has not started"
                    CreatedAt = $null
                }
            }
        }
        
    } catch {
        Write-Warning "Failed to get check information for PR #$($pr.number): $($_.Exception.Message)"
    }
    
    return $pendingChecks
}

# Check GitHub CLI authentication
function Test-GitHubAuthentication {
    # Check if running in GitHub Actions
    if ($env:GITHUB_ACTIONS -eq "true") {
        # Try to get token from environment
        $token = $env:GH_TOKEN
        if (-not $token) {
            $token = $env:GITHUB_TOKEN
        }
        
        if ($token -and $token.Length -gt 0) {
            # Set GH_TOKEN for gh CLI
            $env:GH_TOKEN = $token
            return $true
        } else {
            Write-Host "❌ Running in GitHub Actions but no GitHub token found." -ForegroundColor Red
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
Write-Host "🔍 Checking for PRs with pending checks..." -ForegroundColor Cyan

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
    
    Write-Host "Found $($prs.Count) open PR(s). Checking for pending checks..." -ForegroundColor Yellow
    
    $prsWithPendingChecks = @()
    
    # Check each PR for pending checks
    foreach ($pr in $prs) {
        Write-Host "  Checking PR #$($pr.number): $($pr.title)" -ForegroundColor Gray
        
        $pendingChecks = Get-PendingChecks -repository $Repository -pr $pr
        
        if ($pendingChecks.Count -gt 0) {
            $prsWithPendingChecks += [PSCustomObject]@{
                PR = $pr
                PendingChecks = $pendingChecks
            }
        }
    }
    
    # Output results
    if ($prsWithPendingChecks.Count -eq 0) {
        Write-Host "✅ No PRs found with pending checks." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "`n⏳ Found $($prsWithPendingChecks.Count) PR(s) with pending checks:" -ForegroundColor Yellow
    
    switch ($OutputFormat) {
        "json" {
            $prsWithPendingChecks | ConvertTo-Json -Depth 10
        }
        "table" {
            Write-Host "`nPR | Title | Pending Checks" -ForegroundColor Yellow
            Write-Host "---|-------|---------------" -ForegroundColor Yellow
            foreach ($item in $prsWithPendingChecks) {
                $checkNames = ($item.PendingChecks | ForEach-Object { "$($_.Name) ($($_.Status))" }) -join ", "
                Write-Host "#$($item.PR.number) | $($item.PR.title) | $checkNames"
            }
        }
        "detailed" {
            foreach ($item in $prsWithPendingChecks) {
                Write-Host "`n📋 PR #$($item.PR.number): $($item.PR.title)" -ForegroundColor Cyan
                Write-Host "   Author: $($item.PR.user.login)" -ForegroundColor Gray
                Write-Host "   URL: $($item.PR.html_url)" -ForegroundColor Gray
                Write-Host "   Branch: $($item.PR.head.ref) → $($item.PR.base.ref)" -ForegroundColor Gray
                Write-Host "   Created: $($item.PR.created_at)" -ForegroundColor Gray
                
                Write-Host "`n   ⏳ Pending Checks:" -ForegroundColor Yellow
                foreach ($check in $item.PendingChecks) {
                    Write-Host "   • $($check.Name)" -ForegroundColor White
                    Write-Host "     Status: $($check.Status)" -ForegroundColor Gray
                    Write-Host "     Type: $($check.Type)" -ForegroundColor Gray
                    if ($check.Description) {
                        Write-Host "     Description: $($check.Description)" -ForegroundColor Gray
                    }
                    if ($check.HtmlUrl) {
                        Write-Host "     URL: $($check.HtmlUrl)" -ForegroundColor Blue
                    }
                    if ($check.CreatedAt) {
                        Write-Host "     Created: $($check.CreatedAt)" -ForegroundColor Gray
                    }
                    Write-Host ""
                }
            }
        }
    }
    
    Write-Host "`n📊 Summary: $($prsWithPendingChecks.Count) PR(s) have pending checks" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to fetch PR and workflow information: $($_.Exception.Message)"
    Write-Error "Make sure you have the GitHub CLI installed and authenticated."
    exit 1
}