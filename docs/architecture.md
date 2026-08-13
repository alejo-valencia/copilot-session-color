# Architecture

Copilot Session Color has three layers: distribution, control, and rendering.

## Distribution layer

The `skills/color` directory follows the Agent Skills layout used by
`gh skill`. Installation at user scope copies the complete skill directory into
the user's Copilot skills folder.

```text
skills/color/
├── SKILL.md
├── install.ps1
├── uninstall.ps1
├── set-session-color.ps1
├── skill-lib.ps1
├── session-status.cmd
├── session-status.ps1
├── default-config.json
└── config.schema.json
```

The skill itself contains no local session data. It installs runtime files only
after a user invokes `/color`.

## Control layer

### Installer

`install.ps1`:

1. resolves the current Copilot configuration directory;
2. checks for an existing statusline;
3. records the prior settings needed for uninstall;
4. copies the renderer and default configuration into a runtime directory;
5. enables the custom footer and points `statusLine.command` to the runtime
   command wrapper.

An existing statusline is never replaced unless `-Force` is supplied.

### Color setter

`set-session-color.ps1` reads `COPILOT_AGENT_SESSION_ID` and changes only that
session's local entry. It supports named colors, ANSI values, RGB hex values,
and deterministic automatic selection.

### Uninstaller

`uninstall.ps1` restores the settings captured during installation. It keeps
the user's color configuration by default and removes it only when
`-RemoveUserData` is explicitly supplied.

Control operations use named mutexes and atomic file replacement to avoid
partial writes when several Copilot sessions are open.

## Rendering layer

Copilot CLI invokes `session-status.cmd`, which launches
`session-status.ps1`. The CLI sends session metadata as JSON through standard
input.

The renderer:

1. reads local configuration;
2. resolves an explicit session override or hashes the session ID into the
   configured palette;
3. applies optional local title overrides;
4. renders the title and decoration with ANSI color sequences;
5. optionally appends only the leaf directory name.

The renderer performs no network or subprocess calls beyond the PowerShell
wrapper itself.

## Local data

Runtime state is stored under:

```text
%USERPROFILE%\.copilot\session-color\
```

| File | Purpose |
|---|---|
| `config.json` | User theme and per-session overrides |
| `config.schema.json` | Configuration schema |
| `install-state.json` | Previous settings required for uninstall |
| `session-status.ps1` | Installed renderer |
| `session-status.cmd` | Windows command wrapper |

These files are intentionally excluded from the published repository.

## Extension boundaries

Version 1 exposes data-driven extension points through `config.json`:

- automatic palette;
- named color registry;
- left and right decoration glyphs;
- gradient intensities;
- bold title behavior;
- directory visibility and separator;
- per-session color and title overrides.

Future executable extensions should use a versioned segment interface rather
than loading arbitrary scripts into the statusline process.
