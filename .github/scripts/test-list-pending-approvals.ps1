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
    param($checkRuns, $commitStatuses, $requiredChecks)
    
    $pendingChecks = @()
    
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
    
    # Check for pending commit statuses
    foreach ($status in $commitStatuses) {
        if ($status.state -eq "pending") {
            $pendingChecks += [PSCustomObject]@{
                Name = $status.context
                Status = $status.state
                Type = "status"
            }
        }
    }
    
    # Check if any required checks are missing entirely
    $allCheckNames = @()
    $allCheckNames += $checkRuns | ForEach-Object { $_.name }
    $allCheckNames += $commitStatuses | ForEach-Object { $_.context }
    
    foreach ($requiredCheck in $requiredChecks) {
        if ($requiredCheck -notin $allCheckNames) {
            $pendingChecks += [PSCustomObject]@{
                Name = $requiredCheck
                Status = "missing"
                Type = "required_check"
            }
        }
    }
    
    return $pendingChecks
}

# Test cases
$testCases = @(
    @{
        Name = "Check run with queued status"
        CheckRuns = @(@{ name = "CI Build"; status = "queued" })
        CommitStatuses = @()
        RequiredChecks = @()
        ExpectedCount = 1
        ExpectedNames = @("CI Build")
    },
    @{
        Name = "Check run with pending status"
        CheckRuns = @(@{ name = "Test Suite"; status = "pending" })
        CommitStatuses = @()
        RequiredChecks = @()
        ExpectedCount = 1
        ExpectedNames = @("Test Suite")
    },
    @{
        Name = "Commit status with pending state"
        CheckRuns = @()
        CommitStatuses = @(@{ context = "continuous-integration"; state = "pending" })
        RequiredChecks = @()
        ExpectedCount = 1
        ExpectedNames = @("continuous-integration")
    },
    @{
        Name = "Missing required check"
        CheckRuns = @(@{ name = "CI Build"; status = "completed" })
        CommitStatuses = @()
        RequiredChecks = @("Required Check", "CI Build")
        ExpectedCount = 1
        ExpectedNames = @("Required Check")
    },
    @{
        Name = "Multiple pending checks"
        CheckRuns = @(
            @{ name = "CI Build"; status = "queued" },
            @{ name = "Security Scan"; status = "waiting" }
        )
        CommitStatuses = @(@{ context = "code-quality"; state = "pending" })
        RequiredChecks = @()
        ExpectedCount = 3
        ExpectedNames = @("CI Build", "Security Scan", "code-quality")
    },
    @{
        Name = "No pending checks"
        CheckRuns = @(@{ name = "CI Build"; status = "completed" })
        CommitStatuses = @(@{ context = "continuous-integration"; state = "success" })
        RequiredChecks = @("CI Build")
        ExpectedCount = 0
        ExpectedNames = @()
    },
    @{
        Name = "Check run with completed status (should not be pending)"
        CheckRuns = @(@{ name = "CI Build"; status = "completed" })
        CommitStatuses = @()
        RequiredChecks = @()
        ExpectedCount = 0
        ExpectedNames = @()
    }
)

$passedTests = 0
$totalTests = $testCases.Count

Write-Host "Running $totalTests test cases..." -ForegroundColor Yellow

foreach ($testCase in $testCases) {
    Write-Host "  Testing: $($testCase.Name)" -ForegroundColor Gray
    
    $result = Test-GetPendingChecks -checkRuns $testCase.CheckRuns -commitStatuses $testCase.CommitStatuses -requiredChecks $testCase.RequiredChecks
    
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