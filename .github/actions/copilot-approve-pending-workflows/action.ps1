#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Approve workflow runs that need approval.

.DESCRIPTION
    This script uses gh CLI to find workflow runs that require manual approval
    (action_required status) and other pending workflows.

.PARAMETER Repository
    The GitHub repository in the format "owner/repo". Required.

.PARAMETER WorkflowName
    The name of the workflow to approve runs for. Required.

.PARAMETER DryRun
    If specified, the script will simulate the approval process without actually approving workflows.

.EXAMPLE
    ./copilot-approve-pending-workflows.ps1 -Repository "owner/repo" -WorkflowName "name of comment workflow"

.EXAMPLE
    ./copilot-approve-pending-workflows.ps1 -Repository "owner/repo" -WorkflowName "name of comment workflow" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$WorkflowName,

    [switch]$DryRun
)

$actionRequiredRuns = gh run list `
  --repo $Repository `
  --workflow $WorkflowName `
  --status action_required `
  --json databaseId,url | ConvertFrom-Json

if ($actionRequiredRuns.Count -eq 0) {
    Write-Host "No workflows needing approval or pending."
    exit 0
}

Write-Host "Found $($actionRequiredRuns.Count) workflow run(s) needing attention:"

foreach ($run in $actionRequiredRuns) {
    try {
        if ($DryRun) {
            Write-Host "[DryRun] Would approve workflow run: $($run.url)"
        } else {
            Write-Host "Approving workflow run: $($run.url)"
            gh run rerun $($run.databaseId)
        }
    } catch {
        Write-Error "Failed to approve workflow run: $($run.url)"
    }
}
