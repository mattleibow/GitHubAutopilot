# GitHub Scripts

This directory contains PowerShell scripts for GitHub automation and monitoring.

## Scripts

### list-pending-approvals.ps1

Lists all pull requests that have workflows pending manual approval.

#### Prerequisites
- PowerShell 5.1 or later (or PowerShell Core 6+)
- [GitHub CLI](https://cli.github.com/) installed and authenticated

#### Usage

```powershell
# List pending approvals for current repository (detailed format)
./list-pending-approvals.ps1

# List pending approvals for specific repository
./list-pending-approvals.ps1 -Repository "owner/repo"

# List pending approvals in table format
./list-pending-approvals.ps1 -OutputFormat "table"

# List pending approvals in JSON format
./list-pending-approvals.ps1 -OutputFormat "json"
```

#### Parameters

- **Repository** (optional): The GitHub repository in format "owner/repo". If not provided, uses current repository.
- **OutputFormat** (optional): Output format - "detailed" (default), "table", or "json".

#### Output

The script identifies PRs with workflows that are:
- Waiting for manual approval
- In "pending", "requested", or "waiting" status
- Queued for pull request events (may require approval)
- Have pending deployment approvals

#### Examples

**Detailed Output:**
```
📋 PR #123: Add new feature
   Author: developer
   URL: https://github.com/owner/repo/pull/123
   Branch: feature-branch → main
   Created: 2025-01-01T10:00:00Z

   🔄 Pending Workflows:
   • Deploy to Production
     Status: waiting
     Created: 2025-01-01T10:05:00Z
     URL: https://github.com/owner/repo/actions/runs/456789
     🚀 Pending Deployments:
       - Environment: production
       - Reviewers: admin-team
```

**Table Output:**
```
PR | Title | Pending Workflows
---|-------|------------------
#123 | Add new feature | Deploy to Production
#124 | Fix bug | Deploy to Staging, Deploy to Production
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