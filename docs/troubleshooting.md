# Troubleshooting

## `unknown command "skill" for "gh"`

`gh skill` requires GitHub CLI 2.90 or later:

```powershell
gh --version
winget upgrade --id GitHub.cli -e
```

Open a new PowerShell window after upgrading. If the error remains, inspect
which executable the shell resolves:

```powershell
Get-Command gh -All
```

On a standard Windows installation, bypass aliases or older PATH entries with:

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" skill install alejo-valencia/copilot-session-color color --agent github-copilot --scope user
```

## `/color` is not recognized

```text
/skills reload
```

Confirm installation with `copilot skill list`.

## The statusline does not appear

Confirm `pwsh --version` works, then run:

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
