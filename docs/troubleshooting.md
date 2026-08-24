# Troubleshooting

## `unknown command "skill" for "gh"`

`gh skill` requires GitHub CLI 2.90 or later. This error usually means the
current shell is resolving an older `gh.exe`, even when a newer version is
installed elsewhere.

Inspect every executable on `PATH` and check the standard Windows
installation directly:

```powershell
gh --version
Get-Command gh -All
& "C:\Program Files\GitHub CLI\gh.exe" --version
```

Upgrade GitHub CLI if the resolved version is older than 2.90:

```powershell
winget upgrade --id GitHub.cli -e
```

Open a new PowerShell window after upgrading. If `gh` still resolves to an
older executable, bypass aliases or stale `PATH` entries:

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" skill install alejo-valencia/copilot-session-color color --agent github-copilot --scope user
```

## `/color` is not recognized

```text
/skills reload
```

Confirm installation with `copilot skill list`.

## The statusline does not appear

After the first `/color` command in a session, the statusline might not be
visible until Copilot restarts. Confirm `pwsh --version` works, then run:

```text
/restart
```

## Another statusline is already configured

Installation stops rather than replacing an unknown command. Review the
current `statusLine` setting before choosing forced installation.

## Configuration error appears

Validate:

```text
%USERPROFILE%\.copilot\session-color\config.json
```

The installed `default-config.json` contains a clean reference configuration.

## The session says `Copilot session`

The session has no name yet. Run `/rename` to generate one from the
conversation, or `/rename <name>` to set it directly.

## Existing installations still show the shorter gradient

Update and refresh the runtime:

```powershell
gh skill update color
```

```text
/skills reload
/color install
```

The installer expands the original unmodified four-character decoration while
preserving custom decorations.
