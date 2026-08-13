# Contributing

Contributions are welcome through GitHub issues and pull requests.

## Development

Requirements:

- Windows
- PowerShell 7
- GitHub CLI 2.90 or later

Run the test suite:

```powershell
pwsh -NoLogo -NoProfile -File .\tests\Test-ColorSkill.ps1
pwsh -NoLogo -NoProfile -File .\tests\Test-PublicContent.ps1
```

Validate the Agent Skill package:

```powershell
gh skill publish --dry-run
```

## Design expectations

- Preserve existing Copilot settings unless a user explicitly chooses to
  replace them.
- Keep session IDs, names, paths, and other local context out of repository
  content and logs.
- Validate configuration instead of silently accepting malformed values.
- Keep the renderer fast and free of network calls.
- Add tests for behavioral changes.
- Update the Wiki and extensibility investigation when adding an extension
  point or changing the configuration schema.
