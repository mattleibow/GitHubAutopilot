#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for the list-pending-approvals.ps1 script

.DESCRIPTION
    This script contains unit tests for the pending check detection functionality.
    It tests the core logic without requiring actual GitHub API calls.
#>

Write-Host "🧪 Testing list-pending-approvals.ps1 functionality..." -ForegroundColor Cyan

# Mock function to simulate Get-PendingChecks logic
function Test-GetPendingChecks {
    param($workflowRuns, $checkRuns, $commitStatuses)
    
    $pendingChecks = @()
    
    # Check for pending/queued/waiting workflow runs
    foreach ($run in $workflowRuns) {
        if ($run.status -eq "queued" -or $run.status -eq "pending" -or $run.status -eq "waiting" -or $run.status -eq "requested") {
            $pendingChecks += [PSCustomObject]@{
                Name = $run.name
                Status = $run.status
                Type = "workflow_run"
            }
        }
    }
    
    # Check for pending/queued/waiting check runs
    foreach ($checkRun in $checkRuns) {
        if ($checkRun.status -eq "queued" -or $checkRun.status -eq "pending" -or $checkRun.status -eq "waiting" -or $checkRun.status -eq "requested") {
            $pendingChecks += [PSCustomObject]@{
                Name = $checkRun.name
                Status = $checkRun.status
                Type = "check_run"
            }
        }
    }
    
    # Check for pending commit statuses (external CI)
    foreach ($status in $commitStatuses) {
        if ($status.state -eq "pending") {
            $pendingChecks += [PSCustomObject]@{
                Name = $status.context
                Status = $status.state
                Type = "external_status"
            }
        }
    }
    
    # If no checks at all, indicate nothing has started
    if ($workflowRuns.Count -eq 0 -and $checkRuns.Count -eq 0 -and $commitStatuses.Count -eq 0) {
        $pendingChecks += [PSCustomObject]@{
            Name = "No checks detected"
            Status = "waiting"
            Type = "no_checks"
        }
    }
    
    return $pendingChecks
}

# Test cases
$testCases = @(
    @{
        Name = "Workflow run with queued status"
        WorkflowRuns = @(@{ name = "CI Pipeline"; status = "queued" })
        CheckRuns = @()
        CommitStatuses = @()
        ExpectedCount = 1
        ExpectedNames = @("CI Pipeline")
    },
    @{
        Name = "Check run with pending status"
        WorkflowRuns = @()
        CheckRuns = @(@{ name = "Test Suite"; status = "pending" })
        CommitStatuses = @()
        ExpectedCount = 1
        ExpectedNames = @("Test Suite")
    },
    @{
        Name = "External CI with pending status"
        WorkflowRuns = @()
        CheckRuns = @()
        CommitStatuses = @(@{ context = "Azure Pipelines"; state = "pending" })
        ExpectedCount = 1
        ExpectedNames = @("Azure Pipelines")
    },
    @{
        Name = "Multiple pending checks from different sources"
        WorkflowRuns = @(@{ name = "GitHub Actions CI"; status = "waiting" })
        CheckRuns = @(@{ name = "Security Scan"; status = "queued" })
        CommitStatuses = @(@{ context = "Azure Pipelines"; state = "pending" })
        ExpectedCount = 3
        ExpectedNames = @("GitHub Actions CI", "Security Scan", "Azure Pipelines")
    },
    @{
        Name = "No checks at all (waiting for CI to start)"
        WorkflowRuns = @()
        CheckRuns = @()
        CommitStatuses = @()
        ExpectedCount = 1
        ExpectedNames = @("No checks detected")
    },
    @{
        Name = "Completed checks (no pending)"
        WorkflowRuns = @(@{ name = "CI Pipeline"; status = "completed" })
        CheckRuns = @(@{ name = "Test Suite"; status = "completed" })
        CommitStatuses = @(@{ context = "Azure Pipelines"; state = "success" })
        ExpectedCount = 0
        ExpectedNames = @()
    },
    @{
        Name = "Mix of completed and pending checks"
        WorkflowRuns = @(
            @{ name = "CI Pipeline"; status = "completed" },
            @{ name = "Deploy Preview"; status = "waiting" }
        )
        CheckRuns = @(@{ name = "Test Suite"; status = "completed" })
        CommitStatuses = @()
        ExpectedCount = 1
        ExpectedNames = @("Deploy Preview")
    }
)

$passedTests = 0
$totalTests = $testCases.Count

Write-Host "Running $totalTests test cases..." -ForegroundColor Yellow

foreach ($testCase in $testCases) {
    Write-Host "  Testing: $($testCase.Name)" -ForegroundColor Gray
    
    $result = Test-GetPendingChecks -workflowRuns $testCase.WorkflowRuns -checkRuns $testCase.CheckRuns -commitStatuses $testCase.CommitStatuses
    
    # Check count
    if ($result.Count -eq $testCase.ExpectedCount) {
        # Check names if expected
        if ($testCase.ExpectedCount -eq 0) {
            Write-Host "    ✅ PASS: No pending checks found as expected" -ForegroundColor Green
            $passedTests++
        } else {
            $resultNames = $result | ForEach-Object { $_.Name }
            $allNamesMatch = $true
            foreach ($expectedName in $testCase.ExpectedNames) {
                if ($expectedName -notin $resultNames) {
                    $allNamesMatch = $false
                    break
                }
            }
            
            if ($allNamesMatch) {
                Write-Host "    ✅ PASS: Found expected pending checks: $($resultNames -join ', ')" -ForegroundColor Green
                $passedTests++
            } else {
                Write-Host "    ❌ FAIL: Expected checks [$($testCase.ExpectedNames -join ', ')] but got [$($resultNames -join ', ')]" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "    ❌ FAIL: Expected $($testCase.ExpectedCount) pending checks but got $($result.Count)" -ForegroundColor Red
    }
}

Write-Host "`n📊 Test Results: $passedTests/$totalTests tests passed" -ForegroundColor Yellow

if ($passedTests -eq $totalTests) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some tests failed!" -ForegroundColor Red
    exit 1
}