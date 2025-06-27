# PR Failure Comment Workflow

This directory contains the automated PR failure comment system that posts helpful comments on PRs when Azure pipeline builds fail.

## How it works

1. **Trigger**: The workflow is triggered when a GitHub check suite completes with a failure status
2. **Filter**: Only runs for PRs created by bots/AI (like GitHub Copilot, Dependabot, etc.)
3. **Analysis**: Analyzes the failed check runs and extracts error messages and annotations
4. **Comment**: Posts a formatted comment on the PR mentioning @github-copilot to request assistance

## Files

- `pr-failure-comment.yml` - The main GitHub Actions workflow
- `post-failure-comment.ps1` - PowerShell script that handles the API calls and comment generation
- `test-post-failure-comment.ps1` - Basic test script for validation

## Configuration

The workflow automatically uses:
- `github.repository` - Current repository
- `github.event.check_suite.id` - The ID of the failed check suite
- `github.event.check_suite.pull_requests[0].number` - PR number
- `github.event.check_suite.pull_requests[0].user.login` - PR author

## Bot Detection

The script currently identifies the following as bot/AI users:
- `dependabot[bot]`
- `github-copilot[bot]`
- `copilot`
- Any username containing `[bot]`
- Any username containing `copilot`

## Permissions Required

The workflow requires these permissions:
- `pull-requests: write` - To post comments on PRs
- `checks: read` - To read check suite and check run details
- `contents: read` - To checkout the repository

## Comment Format

The generated comment includes:
- A clear indication that the build failed
- Links to failed jobs with their details URLs
- Extracted error messages and annotations
- A mention of @github-copilot requesting analysis and fixes
- Instructions for what kind of help is needed

## Testing

Run the test script to validate basic functionality:

```bash
pwsh ./.github/scripts/test-post-failure-comment.ps1
```

Note: Full testing requires actual failed check suites and valid GitHub tokens.