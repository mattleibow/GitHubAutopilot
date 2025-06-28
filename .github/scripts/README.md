# GitHub Workflow Status Script

This script lists all workflow runs in a GitHub repository and highlights pending ones.

## Features

- **Lists ALL workflow runs** (not just PR-triggered ones)
- **Highlights pending workflows** in queued, pending, waiting, or requested states
- **Shows running workflows** with duration information
- **Multiple output formats**: detailed, table, and JSON
- **Works with any trigger type**: PRs, pushes, manual triggers, scheduled events, etc.

## Usage

```powershell
# Basic usage - detailed output
./.github/scripts/list-pending-workflows.ps1

# Table format for quick overview
./.github/scripts/list-pending-workflows.ps1 -OutputFormat "table"

# JSON for automation
./.github/scripts/list-pending-workflows.ps1 -OutputFormat "json"

# Limit results
./.github/scripts/list-pending-workflows.ps1 -PerPage 20 -MaxPages 3
```

## Sample Output

### Detailed Format
```
🔄 Listing all workflow runs and highlighting pending ones...
Repository: mattleibow/GitHubAutopilot
Found 15 workflow run(s). Categorizing by status...

📊 Workflow Runs Summary:
Pending: 2
Running: 1
Completed: 12
Total: 15

⏳ PENDING WORKFLOW RUNS:

🔴 Workflow: CI
   ID: 12345678
   Status: queued
   Event: pull_request
   Branch: feature-branch
   Triggered by: developer
   Created: 2025-06-28T10:30:00Z
   URL: https://github.com/owner/repo/actions/runs/12345678

🏃 RUNNING WORKFLOW RUNS:

🟡 Workflow: Deploy
   ID: 12345679
   Status: in_progress
   Event: push
   Branch: main
   Triggered by: maintainer
   Started: 2025-06-28T10:25:00Z
   Duration: 5m 30s
   URL: https://github.com/owner/repo/actions/runs/12345679
```

### Table Format
```
📊 Workflow Runs Summary:
Pending: 2
Running: 1
Completed: 12

⏳ PENDING WORKFLOW RUNS:
ID | Workflow | Status | Event | Branch | Created
---|----------|--------|-------|--------|--------
12345678 | CI | queued | pull_request | feature-branch | 2025-06-28 10:30
12345679 | Build | pending | push | main | 2025-06-28 10:28
```

## Prerequisites

- PowerShell 5.1+ or PowerShell Core 6+
- GitHub CLI (`gh`) installed and authenticated
- Read access to repository and actions

## Authentication

### Local Development
```bash
gh auth login
```

### GitHub Actions
```yaml
env:
  GH_TOKEN: ${{ github.token }}
```

## Parameters

- **Repository**: GitHub repository in "owner/repo" format (auto-detected if not provided)
- **OutputFormat**: "detailed", "table", or "json" (default: "detailed")
- **PerPage**: Number of runs per page, 1-100 (default: 50)
- **MaxPages**: Maximum pages to fetch, 1-20 (default: 5)
- **Help**: Show detailed help information