# Copilot Session Color

Give each GitHub Copilot CLI session a distinct, customizable statusline:

```text
░▒▓█ Example Session █▓▒░
```

This repository packages the formatter as an installable Agent Skill. Session
colors are keyed by the active Copilot session ID, so concurrent terminals can
use different colors without changing the global CLI theme.

## Requirements

- Windows 10 or later
- GitHub Copilot CLI
- PowerShell 7 (`pwsh`)
- GitHub CLI 2.90 or later for `gh skill install`

## Install

Preview the skill before installing it:

```powershell
gh skill preview alejo-valencia/copilot-session-color color
```

Install it for GitHub Copilot CLI at user scope:

```powershell
gh skill install alejo-valencia/copilot-session-color color --agent github-copilot --scope user
```

Reload skills in existing Copilot sessions:

```text
/skills reload
```

Set the current session color:

```text
/color green
```

Other examples:

```text
/color purple
/color #7C3AED
/color 208
/color automatic
```

The first invocation installs the statusline renderer and updates Copilot's
user settings. If another custom statusline is already configured, installation
stops instead of replacing it.

## Update

```powershell
gh skill update color
```

Then refresh the installed runtime files:

```text
/skills reload
/color install
```

## Customize

User configuration is stored locally at:

```text
%USERPROFILE%\.copilot\session-color\config.json
```

It controls:

- the automatic color palette;
- named colors;
- gradient glyphs and intensities;
- title emphasis;
- whether the current directory name is shown;
- per-session color and optional title overrides.

See the repository Wiki for configuration examples, architecture,
troubleshooting, and extension guidance.

## Privacy

- No telemetry or network calls are made by the scripts.
- Session IDs and overrides remain in the local Copilot configuration folder.
- The default configuration does not display the working directory.
- The repository contains no user-specific paths, session IDs, or saved
  session names.

## Uninstall

Restore the previous statusline configuration:

```text
/color uninstall
```

Then remove the skill:

```powershell
copilot skill remove color
```

## Status

The initial release is Windows-first. Cross-platform launchers and a richer
theme command are documented in the extensibility investigation.

## License

[MIT](LICENSE)
