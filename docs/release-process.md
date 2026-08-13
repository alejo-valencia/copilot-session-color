# Release process

## Prerequisites

- GitHub CLI 2.90 or later
- PowerShell 7
- Push access to the repository

## Validate

Run:

```powershell
pwsh -NoLogo -NoProfile -File .\tests\Test-ColorSkill.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-PublicContent.ps1
gh skill publish --dry-run
git diff --check
```

Review the repository for:

- local paths;
- real session IDs or names;
- secrets or tokens;
- generated configuration files;
- internal project names;
- unreviewed executable changes.

## Version

Update:

- `CHANGELOG.md`;
- Wiki documentation when behavior or configuration changes;
- `schemaVersion` only for breaking configuration changes.

## Publish

Create a versioned GitHub release through the Agent Skills workflow:

```powershell
gh skill publish --tag v1.0.0
```

Consumers can pin installations to a release:

```powershell
gh skill install alejo-valencia/copilot-session-color color --agent github-copilot --scope user --pin v0.1.0
```

## Update

Consumers update an unpinned installation with:

```powershell
gh skill update color
```
