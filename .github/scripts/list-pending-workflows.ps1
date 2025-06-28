#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Lists all workflow runs and highlights pending ones.

.DESCRIPTION
    This script queries GitHub API to get all workflow runs in the repository
    and highlights the ones that are pending, queued, waiting, or in other
    non-final states. It shows workflows triggered by any event (PRs, pushes,
    manual triggers, scheduled events, etc.).

.PARAMETER Repository
    The GitHub repository in the format "owner/repo". If not provided, uses the current repository.

.PARAMETER OutputFormat
    The output format: "table", "json", or "detailed". Default is "detailed".

.PARAMETER PerPage
    Number of workflow runs to fetch per page. Default is 50, max is 100.

.PARAMETER MaxPages
    Maximum number of pages to fetch. Default is 5 (250 runs total).

.EXAMPLE
    ./list-pending-workflows.ps1
    Lists all workflow runs with pending ones highlighted

.EXAMPLE
    ./list-pending-workflows.ps1 -Repository "mattleibow/GitHubAutopilot" -OutputFormat "table"
    Lists workflow runs in table format for the specified repository
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Repository = "",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("table", "json", "detailed")]
    [string]$OutputFormat = "detailed",
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$PerPage = 50,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 20)]
    [int]$MaxPages = 5,
    
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

# Function to check if GitHub CLI is authenticated
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

# Function to get workflow runs
function Get-WorkflowRuns {
    param($repository, $perPage, $maxPages)
    
    $allRuns = @()
    $page = 1
    
    do {
        try {
            Write-Host "  Fetching page $page of workflow runs..." -ForegroundColor Gray
            $response = gh api "repos/$repository/actions/runs?per_page=$perPage&page=$page" | ConvertFrom-Json
            
            if ($response.workflow_runs -and $response.workflow_runs.Count -gt 0) {
                $allRuns += $response.workflow_runs
                $page++
            } else {
                break
            }
        } catch {
            Write-Warning "Failed to fetch workflow runs page ${page}: $($_.Exception.Message)"
            break
        }
    } while ($page -le $maxPages -and $response.workflow_runs.Count -eq $perPage)
    
    return $allRuns
}

# Function to categorize workflow runs
function Get-WorkflowCategories {
    param($workflowRuns)
    
    $pending = @()
    $running = @()
    $completed = @()
    
    foreach ($run in $workflowRuns) {
        switch ($run.status) {
            "queued" { $pending += $run }
            "pending" { $pending += $run }
            "waiting" { $pending += $run }
            "requested" { $pending += $run }
            "in_progress" { $running += $run }
            "completed" { $completed += $run }
            default { $completed += $run }
        }
    }
    
    return @{
        Pending = $pending
        Running = $running
        Completed = $completed
    }
}

# Function to format duration
function Format-Duration {
    param($startTime, $endTime = $null)
    
    if (-not $startTime) {
        return "Not started"
    }
    
    $start = [DateTime]::Parse($startTime)
    $end = if ($endTime) { [DateTime]::Parse($endTime) } else { [DateTime]::UtcNow }
    
    $duration = $end - $start
    
    if ($duration.TotalDays -ge 1) {
        return "$([math]::Floor($duration.TotalDays))d $($duration.Hours)h $($duration.Minutes)m"
    } elseif ($duration.TotalHours -ge 1) {
        return "$($duration.Hours)h $($duration.Minutes)m"
    } elseif ($duration.TotalMinutes -ge 1) {
        return "$($duration.Minutes)m $($duration.Seconds)s"
    } else {
        return "$($duration.Seconds)s"
    }
}

# Main execution starts here
Write-Host "🔄 Listing all workflow runs and highlighting pending ones..." -ForegroundColor Cyan

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
Write-Host "Fetching up to $($MaxPages * $PerPage) workflow runs..." -ForegroundColor Yellow

try {
    # Get all workflow runs
    $workflowRuns = Get-WorkflowRuns -repository $Repository -perPage $PerPage -maxPages $MaxPages
    
    if ($workflowRuns.Count -eq 0) {
        Write-Host "✅ No workflow runs found." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "Found $($workflowRuns.Count) workflow run(s). Categorizing by status..." -ForegroundColor Yellow
    
    # Categorize workflow runs
    $categories = Get-WorkflowCategories -workflowRuns $workflowRuns
    
    # Output results
    switch ($OutputFormat) {
        "json" {
            $result = @{
                Repository = $Repository
                TotalRuns = $workflowRuns.Count
                Pending = $categories.Pending
                Running = $categories.Running
                Completed = $categories.Completed
            }
            $result | ConvertTo-Json -Depth 10
        }
        "table" {
            Write-Host "`n📊 Workflow Runs Summary:" -ForegroundColor Cyan
            Write-Host "Pending: $($categories.Pending.Count)" -ForegroundColor Red
            Write-Host "Running: $($categories.Running.Count)" -ForegroundColor Yellow
            Write-Host "Completed: $($categories.Completed.Count)" -ForegroundColor Green
            Write-Host "Total: $($workflowRuns.Count)" -ForegroundColor White
            
            if ($categories.Pending.Count -gt 0) {
                Write-Host "`n⏳ PENDING WORKFLOW RUNS:" -ForegroundColor Red
                Write-Host "ID | Workflow | Status | Event | Branch | Created" -ForegroundColor Yellow
                Write-Host "---|----------|--------|-------|--------|--------" -ForegroundColor Yellow
                foreach ($run in $categories.Pending) {
                    $branch = if ($run.head_branch) { $run.head_branch } else { "N/A" }
                    $created = ([DateTime]::Parse($run.created_at)).ToString("yyyy-MM-dd HH:mm")
                    Write-Host "$($run.id) | $($run.name) | $($run.status) | $($run.event) | $branch | $created" -ForegroundColor Red
                }
            }
            
            if ($categories.Running.Count -gt 0) {
                Write-Host "`n🏃 RUNNING WORKFLOW RUNS:" -ForegroundColor Yellow
                Write-Host "ID | Workflow | Status | Event | Branch | Duration" -ForegroundColor Yellow
                Write-Host "---|----------|--------|-------|--------|--------" -ForegroundColor Yellow
                foreach ($run in $categories.Running) {
                    $branch = if ($run.head_branch) { $run.head_branch } else { "N/A" }
                    $duration = Format-Duration -startTime $run.run_started_at
                    Write-Host "$($run.id) | $($run.name) | $($run.status) | $($run.event) | $branch | $duration" -ForegroundColor Yellow
                }
            }
        }
        "detailed" {
            Write-Host "`n📊 Workflow Runs Summary:" -ForegroundColor Cyan
            Write-Host "Pending: $($categories.Pending.Count)" -ForegroundColor Red
            Write-Host "Running: $($categories.Running.Count)" -ForegroundColor Yellow
            Write-Host "Completed: $($categories.Completed.Count)" -ForegroundColor Green
            Write-Host "Total: $($workflowRuns.Count)" -ForegroundColor White
            
            if ($categories.Pending.Count -gt 0) {
                Write-Host "`n⏳ PENDING WORKFLOW RUNS:" -ForegroundColor Red
                foreach ($run in $categories.Pending) {
                    Write-Host "`n🔴 Workflow: $($run.name)" -ForegroundColor Red
                    Write-Host "   ID: $($run.id)" -ForegroundColor Gray
                    Write-Host "   Status: $($run.status)" -ForegroundColor Red
                    Write-Host "   Event: $($run.event)" -ForegroundColor Gray
                    if ($run.head_branch) {
                        Write-Host "   Branch: $($run.head_branch)" -ForegroundColor Gray
                    }
                    if ($run.triggering_actor) {
                        Write-Host "   Triggered by: $($run.triggering_actor.login)" -ForegroundColor Gray
                    }
                    Write-Host "   Created: $($run.created_at)" -ForegroundColor Gray
                    if ($run.run_started_at) {
                        Write-Host "   Started: $($run.run_started_at)" -ForegroundColor Gray
                    }
                    Write-Host "   URL: $($run.html_url)" -ForegroundColor Blue
                }
            }
            
            if ($categories.Running.Count -gt 0) {
                Write-Host "`n🏃 RUNNING WORKFLOW RUNS:" -ForegroundColor Yellow
                foreach ($run in $categories.Running) {
                    $duration = Format-Duration -startTime $run.run_started_at
                    Write-Host "`n🟡 Workflow: $($run.name)" -ForegroundColor Yellow
                    Write-Host "   ID: $($run.id)" -ForegroundColor Gray
                    Write-Host "   Status: $($run.status)" -ForegroundColor Yellow
                    Write-Host "   Event: $($run.event)" -ForegroundColor Gray
                    if ($run.head_branch) {
                        Write-Host "   Branch: $($run.head_branch)" -ForegroundColor Gray
                    }
                    if ($run.triggering_actor) {
                        Write-Host "   Triggered by: $($run.triggering_actor.login)" -ForegroundColor Gray
                    }
                    Write-Host "   Started: $($run.run_started_at)" -ForegroundColor Gray
                    Write-Host "   Duration: $duration" -ForegroundColor Gray
                    Write-Host "   URL: $($run.html_url)" -ForegroundColor Blue
                }
            }
            
            if ($categories.Completed.Count -gt 0 -and ($categories.Pending.Count -gt 0 -or $categories.Running.Count -gt 0)) {
                Write-Host "`n✅ Recent completed workflow runs: $($categories.Completed.Count)" -ForegroundColor Green
                $recentCompleted = $categories.Completed | Sort-Object { [DateTime]::Parse($_.updated_at) } -Descending | Select-Object -First 5
                foreach ($run in $recentCompleted) {
                    $duration = Format-Duration -startTime $run.run_started_at -endTime $run.updated_at
                    $statusIcon = if ($run.conclusion -eq "success") { "✅" } elseif ($run.conclusion -eq "failure") { "❌" } else { "⚠️" }
                    Write-Host "   $statusIcon $($run.name) ($($run.conclusion)) - $duration ago" -ForegroundColor Green
                }
            }
        }
    }
    
    if ($categories.Pending.Count -gt 0) {
        Write-Host "`n🚨 $($categories.Pending.Count) workflow run(s) are pending and need attention!" -ForegroundColor Red
    } elseif ($categories.Running.Count -gt 0) {
        Write-Host "`n⚡ $($categories.Running.Count) workflow run(s) are currently running." -ForegroundColor Yellow
    } else {
        Write-Host "`n✅ No pending or running workflow runs." -ForegroundColor Green
    }
    
} catch {
    Write-Error "Failed to fetch workflow information: $($_.Exception.Message)"
    Write-Error "Make sure you have the GitHub CLI installed and authenticated."
    exit 1
}