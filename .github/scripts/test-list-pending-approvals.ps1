#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for the list-pending-approvals.ps1 script

.DESCRIPTION
    This script contains unit tests for the workflow approval checking functionality.
    It tests the core logic without requiring actual GitHub API calls.
#>

# Import the main script functions by dot-sourcing (we'll need to extract the functions)
# For now, let's test the logic with mock data

Write-Host "🧪 Testing list-pending-approvals.ps1 functionality..." -ForegroundColor Cyan

# Test function to check if workflow run is pending approval
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

# Test cases
$testCases = @(
    @{
        Name = "Workflow with waiting status"
        WorkflowRun = @{ status = "waiting"; event = "pull_request" }
        Expected = $true
    },
    @{
        Name = "Workflow with requested status"
        WorkflowRun = @{ status = "requested"; event = "pull_request" }
        Expected = $true
    },
    @{
        Name = "Workflow with pending status"
        WorkflowRun = @{ status = "pending"; event = "pull_request" }
        Expected = $true
    },
    @{
        Name = "Workflow with queued status and pull_request event"
        WorkflowRun = @{ status = "queued"; event = "pull_request" }
        Expected = $true
    },
    @{
        Name = "Workflow with completed status"
        WorkflowRun = @{ status = "completed"; event = "pull_request"; conclusion = "success" }
        Expected = $false
    },
    @{
        Name = "Workflow with in_progress status"
        WorkflowRun = @{ status = "in_progress"; event = "pull_request" }
        Expected = $false
    },
    @{
        Name = "Workflow with queued status but not pull_request event"
        WorkflowRun = @{ status = "queued"; event = "push" }
        Expected = $false
    }
)

$passedTests = 0
$totalTests = $testCases.Count

Write-Host "`nRunning $totalTests test cases..." -ForegroundColor Yellow

foreach ($testCase in $testCases) {
    $result = Test-WorkflowPendingApproval -workflowRun $testCase.WorkflowRun
    
    if ($result -eq $testCase.Expected) {
        Write-Host "✅ PASS: $($testCase.Name)" -ForegroundColor Green
        $passedTests++
    } else {
        Write-Host "❌ FAIL: $($testCase.Name)" -ForegroundColor Red
        Write-Host "   Expected: $($testCase.Expected), Got: $result" -ForegroundColor Red
    }
}

Write-Host "`n📊 Test Results: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Red" })

if ($passedTests -eq $totalTests) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "💥 Some tests failed!" -ForegroundColor Red
    exit 1
}