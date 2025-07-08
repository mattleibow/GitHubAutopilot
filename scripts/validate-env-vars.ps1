#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that required environment variables are set during builds.

.DESCRIPTION
    This script checks for the presence of required environment variables, 
    specifically COPILOT_BUILD_RUN, to ensure the build environment is properly configured.

.EXAMPLE
    ./validate-env-vars.ps1
#>

$ErrorActionPreference = 'Stop'

Write-Host "Validating required environment variables..."

# Check for COPILOT_BUILD_RUN
if (-not $env:COPILOT_BUILD_RUN) {
    Write-Error "COPILOT_BUILD_RUN environment variable is not set. This should be set to 'true' during builds."
    exit 1
}

Write-Host "✓ COPILOT_BUILD_RUN is set to: $env:COPILOT_BUILD_RUN"

# Display all environment variables with 'set' command equivalent for verification
Write-Host ""
Write-Host "All environment variables:"
Get-ChildItem env: | Sort-Object Name | ForEach-Object {
    Write-Host "$($_.Name)=$($_.Value)"
}

Write-Host ""
Write-Host "Environment variable validation completed successfully."