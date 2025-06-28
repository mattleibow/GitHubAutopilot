#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Example usage demonstrations for list-pending-approvals.ps1

.DESCRIPTION
    This script demonstrates various ways to use the list-pending-approvals.ps1 script
    with different parameters and in different environments.
#>

Write-Host "📚 List Pending Checks - Usage Examples" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "`n1. Basic Usage (current repository, detailed output):" -ForegroundColor Yellow
Write-Host "   ./.github/scripts/list-pending-approvals.ps1" -ForegroundColor Green

Write-Host "`n2. Specific repository:" -ForegroundColor Yellow
Write-Host "   ./.github/scripts/list-pending-approvals.ps1 -Repository 'mattleibow/GitHubAutopilot'" -ForegroundColor Green

Write-Host "`n3. Table format output:" -ForegroundColor Yellow
Write-Host "   ./.github/scripts/list-pending-approvals.ps1 -OutputFormat 'table'" -ForegroundColor Green

Write-Host "`n4. JSON format output (for automation):" -ForegroundColor Yellow
Write-Host "   ./.github/scripts/list-pending-approvals.ps1 -OutputFormat 'json'" -ForegroundColor Green

Write-Host "`n5. In GitHub Actions workflow:" -ForegroundColor Yellow
Write-Host @"
   - name: Check for PRs with pending checks
     shell: pwsh
     env:
       GH_TOKEN: `${{ secrets.GITHUB_TOKEN }}
     run: |
       ./.github/scripts/list-pending-approvals.ps1 -OutputFormat "table"
"@ -ForegroundColor Green

Write-Host "`n6. Save output to file:" -ForegroundColor Yellow
Write-Host "   ./.github/scripts/list-pending-approvals.ps1 -OutputFormat 'json' > pending-checks.json" -ForegroundColor Green

Write-Host "`n7. Use with other tools (parse JSON):" -ForegroundColor Yellow
Write-Host @"
   `$pendingPRs = ./.github/scripts/list-pending-approvals.ps1 -OutputFormat 'json' | ConvertFrom-Json
   `$pendingPRs | ForEach-Object { Write-Host "PR #`$(`$_.PR.number) has pending checks" }
"@ -ForegroundColor Green

Write-Host "`n📋 Script Features:" -ForegroundColor Cyan
Write-Host "• Identifies PRs with checks that haven't started running" -ForegroundColor White
Write-Host "• Detects pending, queued, and waiting check runs" -ForegroundColor White
Write-Host "• Finds missing required status checks" -ForegroundColor White
Write-Host "• Shows commit status checks in pending state" -ForegroundColor White
Write-Host "• Works in both local and GitHub Actions environments" -ForegroundColor White
Write-Host "• Supports multiple output formats" -ForegroundColor White
Write-Host "• Helps identify workflow bottlenecks where checks haven't started" -ForegroundColor White

Write-Host "`n🔧 Prerequisites:" -ForegroundColor Cyan
Write-Host "• GitHub CLI (gh) installed and authenticated" -ForegroundColor White
Write-Host "• PowerShell 5.1+ or PowerShell Core 6+" -ForegroundColor White
Write-Host "• Read access to repository and actions" -ForegroundColor White

Write-Host "`n📖 For detailed documentation, see:" -ForegroundColor Cyan
Write-Host "   ./.github/scripts/README.md" -ForegroundColor Blue

Write-Host "`n🧪 Run tests with:" -ForegroundColor Cyan
Write-Host "   ./.github/scripts/test-list-pending-approvals.ps1" -ForegroundColor Blue