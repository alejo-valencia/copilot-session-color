---
name: color
description: Install and customize a per-session GitHub Copilot CLI statusline. Use when the user requests /color, asks to set the current session to a named, hexadecimal, or ANSI color, wants automatic color selection, or wants to install or uninstall the session-color statusline.
license: MIT
compatibility: Requires Windows 10 or later, GitHub Copilot CLI with custom statusLine support, and PowerShell 7.
---

# Copilot session color

Operate only on the current user's Copilot configuration. Never infer the
active session from timestamps or recently modified folders.

## Set a color

When the user invokes `/color <value>`:

1. Run `install.ps1` from this skill directory. Do not pass `-Force` unless the
   user explicitly approved replacing another custom statusline.
2. Run `set-session-color.ps1 -Color "<value>"` from this skill directory.
3. Report the selected color and session ID returned by the script.

The setter reads `COPILOT_AGENT_SESSION_ID`, which identifies the session that
invoked the skill.

Supported values:

- named colors from the local configuration;
- hexadecimal RGB colors such as `#7C3AED`;
- ANSI 256-color numbers from `0` through `255`;
- `automatic` or `default` to remove the explicit override;
- `list` to display configured named colors.

## Install

For `/color install`, run:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

If another custom statusline is configured, stop and explain the conflict.
Only rerun with `-Force` after the user explicitly approves replacement.

## Uninstall

For `/color uninstall`, run:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

This restores the pre-install statusline setting and keeps the user's color
configuration. Use `-RemoveUserData` only when the user explicitly requests
complete removal.

## Safety and privacy

- Resolve scripts relative to this `SKILL.md`, not the current repository.
- Do not print or summarize the contents of the local configuration file.
- Do not expose session names, session IDs, or paths beyond the single session
  ID returned by the setter.
- Do not modify the global Copilot theme.
- Do not make network requests.

The statusline should refresh automatically. If it does not, tell the user to
run `/restart` once.

## Session names and models

- If `session_name` is empty, the renderer uses the configured fallback
  `Copilot session`.
- Recommend native `/rename` with no argument to generate a name from the
  conversation. Do not read transcripts or infer a name inside the renderer.
- This skill is processed by the active session model. Agent Skills have no
  per-skill model field; do not claim that `/color` can force a cheaper model.
