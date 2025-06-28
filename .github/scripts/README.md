# GitHub Scripts

This directory contains PowerShell scripts for GitHub automation and monitoring.

## Scripts

### list-pending-approvals.ps1

Lists all pull requests with checks that are waiting to run.

#### Prerequisites
- PowerShell 5.1 or later (or PowerShell Core 6+)
- [GitHub CLI](https://cli.github.com/) installed and authenticated

#### Usage

```powershell
# List PRs with pending checks for current repository (detailed format)
./list-pending-approvals.ps1

# List PRs with pending checks for specific repository
./list-pending-approvals.ps1 -Repository "owner/repo"

# List PRs with pending checks in table format
./list-pending-approvals.ps1 -OutputFormat "table"

# List PRs with pending checks in JSON format
./list-pending-approvals.ps1 -OutputFormat "json"
```

#### Parameters

- **Repository** (optional): The GitHub repository in format "owner/repo". If not provided, uses current repository.
- **OutputFormat** (optional): Output format - "detailed" (default), "table", or "json".

#### Output

The script identifies PRs with checks that are:
- In "queued", "pending", "waiting", or "requested" status (haven't started running)
- Required by branch protection but missing entirely
- Status checks showing "pending" state

This helps identify workflow bottlenecks where builds or other checks haven't started yet.

#### Examples

**Detailed Output:**
```
📋 PR #123: Add new feature
   Author: developer
   URL: https://github.com/owner/repo/pull/123
   Branch: feature-branch → main
   Created: 2025-01-01T10:00:00Z

   ⏳ Pending Checks:
   • CI Build
     Status: queued
     Type: check_run
     URL: https://github.com/owner/repo/actions/runs/456789
     Created: 2025-01-01T10:05:00Z
   
   • Code Quality
     Status: pending
     Type: status
     Description: Waiting for checks to complete
```

**Table Output:**
```
PR | Title | Pending Checks
---|-------|---------------
#123 | Add new feature | CI Build (queued), Code Quality (pending)
#124 | Fix bug | Unit Tests (missing), Deploy (queued)
```

### test-list-pending-approvals.ps1

Unit tests for the `list-pending-approvals.ps1` script functionality.

```powershell
# Run tests
./test-list-pending-approvals.ps1
```

### post-failure-comment.ps1

Posts comments on PRs when Azure pipeline builds fail (existing script).

## Setup

1. Install GitHub CLI:
   ```bash
   # On macOS
   brew install gh
   
   # On Windows
   winget install GitHub.cli
   
   # On Linux
   # See https://github.com/cli/cli/blob/trunk/docs/install_linux.md
   ```

2. Authenticate with GitHub:
   ```bash
   gh auth login
   ```

3. Run the scripts from the repository root:
   ```powershell
   ./.github/scripts/list-pending-approvals.ps1
   ```

## Troubleshooting

**Error: "GitHub CLI is not authenticated"**
- Run `gh auth login` and follow the prompts
- Ensure you have appropriate permissions to access the repository

**Error: "Could not determine current repository"**
- Make sure you're running the script from within a git repository
- Or specify the repository explicitly with `-Repository "owner/repo"`

**Error: "Failed to fetch PR and workflow information"**
- Check your internet connection
- Verify repository exists and you have access
- Ensure GitHub CLI is properly configured