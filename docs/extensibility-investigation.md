# Customization and extensibility investigation

## Scope

This investigation identifies what the project must create or modify to remain
safe to publish, easy to customize, and practical to extend.

Confidence labels:

- **Verified**: supported by current documentation, command behavior, or tests.
- **Observed**: confirmed by public examples or the current implementation but
  not fully documented as a stable platform contract.
- **Proposed**: recommended project design, not a Copilot platform guarantee.

## Platform findings

### Agent Skill packaging

**Verified**

- Agent Skills use a `SKILL.md` file with required `name` and `description`
  frontmatter and may include scripts and other resources in the same
  directory.
- GitHub CLI discovers publishable skills under layouts such as
  `skills/<name>/SKILL.md`.
- `gh skill install` can install a skill at user scope for GitHub Copilot and
  copies all bundled resources.
- Installed skills receive provenance metadata that enables
  `gh skill update`.
- `gh skill publish --dry-run` validates the skill and repository release
  settings before publication.
- `gh skill` is currently a preview feature and requires GitHub CLI 2.90 or
  later.

Implication: the project must remain a small, clean repository with every
runtime dependency inside `skills/color`.

### Copilot custom statusline

**Verified**

Copilot's user settings support a command-based `statusLine` with:

- `type`;
- `command`;
- `padding`;
- `refreshInterval`.

The custom footer is enabled through `footer.showCustom`.

GitHub staff confirmed that the statusline JSON payload includes `session_id`
and `session_name`; `session_name` reflects `/rename`.

**Observed**

- Public payload captures contain more fields, including working directory,
  model, usage, and transcript information. Those fields are not all documented
  as a stable schema.
- A thin Windows `.cmd` wrapper around PowerShell is a common integration
  pattern.
- Older Copilot CLI versions had reports where `statusLine.command` did not
  render.

Implication: version 1 should depend only on `session_id`, `session_name`, and
`cwd`, tolerate missing fields, and avoid treating undocumented fields as a
stable extension API.

### UI limitations

**Verified**

Copilot themes are global. Current feature requests show that fine-grained
per-element theming and custom theme definitions remain unsupported.

Implication: this project can customize only the command-rendered statusline.
It cannot reliably color the input box or prompt border per session.

## Current publishable baseline

The repository now includes:

| Capability | Status |
|---|---|
| Standard `skills/color` package layout | Implemented |
| User-scope install through `gh skill` | Validated locally |
| Conflict-safe Copilot settings installer | Implemented |
| Reversible uninstall with prior-setting restoration | Implemented |
| Named, hexadecimal, ANSI, and automatic colors | Implemented |
| Schema-versioned local configuration | Implemented |
| Custom palette and named color registry | Implemented |
| Data-driven mirrored decoration | Implemented |
| Directory display disabled by default | Implemented |
| Atomic writes and concurrent-session locking | Implemented |
| Control-character and ANSI injection sanitization | Implemented |
| PowerShell behavioral tests | Implemented |
| Agent Skill publish dry run | Passing locally |
| Public repository Wiki | Prepared for publication |

## Changes needed for deeper customization

### 1. Named theme files

**Proposed**

Move reusable visual styles into versioned files:

```text
skills/color/themes/
├── default.json
├── emerald.json
├── minimal.json
└── violet.json
```

Add:

```text
/color theme violet
/color preview emerald
```

Each theme should contain only data. Themes should not execute scripts.

### 2. Decoration presets

**Proposed**

Separate decoration from color:

```json
{
  "name": "gradient-blocks",
  "leftGlyphs": ["░", "▒", "▓", "█"],
  "rightGlyphs": ["█", "▓", "▒", "░"],
  "intensities": [0.35, 0.55, 0.75, 1.0]
}
```

Add built-in presets such as:

- `gradient-blocks`;
- `brackets`;
- `minimal`;
- `none`.

The renderer should continue validating equal array lengths and printable
glyphs.

### 3. Configurable segments

**Proposed**

Introduce a versioned segment model rather than hardcoding the directory after
the title:

```json
{
  "segments": {
    "order": ["session", "directory"],
    "directory": {
      "enabled": false
    }
  }
}
```

Initial built-in segments could include:

- session title;
- leaf directory;
- Git branch, only if supplied in the Copilot payload or obtained within a
  strict runtime budget;
- model name;
- context usage.

Avoid arbitrary user scripts in version 1. They complicate latency, error
handling, and trust boundaries.

### 4. Foreground and background modes

**Proposed**

Add a rendering mode:

```json
{
  "colorMode": "foreground"
}
```

Potential values:

- `foreground`;
- `background`;
- `decoration-only`.

Background rendering requires terminal-contrast testing and accessibility
guidance before becoming a default.

### 5. Configuration commands and migration

**Proposed**

Add maintenance commands:

```text
/color config
/color validate
/color migrate
/color reset
```

`gh skill update` updates package files but does not run migration hooks.
Therefore:

- every config must include `schemaVersion`;
- the renderer must reject unsupported versions explicitly;
- migration should run only through an explicit maintenance command;
- upgrades must never overwrite `config.json`.

### 6. Statusline composition

**Proposed**

Only one Copilot `statusLine.command` can be active. Version 1 should continue
to refuse replacement of an unknown command.

Future composition should be opt-in and should use a documented adapter model.
Do not automatically chain unknown shell commands because their output,
latency, quoting, and side effects cannot be safely assumed.

## Changes needed for stronger release engineering

### Privacy scrub

**Implemented baseline; proposed expansion**

CI should reject:

- absolute user-home paths;
- token-like values;
- transcript or session-state paths;
- unredacted payload fixtures;
- generated user configuration;
- screenshots with visible private identifiers.

Fixtures must use synthetic session IDs, names, and paths.

The current scan checks text files for user-home paths, token-shaped values,
session-state paths, and private-key headers. Future expansion should inspect
archives and image assets before release.

### Performance budget

**Proposed**

No official hard timeout for `statusLine.command` is currently documented.
The renderer should nevertheless:

- avoid network access;
- avoid Git and other subprocess calls;
- parse only small local JSON files;
- emit one line;
- avoid timer-based polling by default because PowerShell process startup
  dominates total latency.

Add a benchmark that records startup and rendering latency separately without
making timing-sensitive CI tests flaky. If frequent polling becomes a
requirement, evaluate a lighter runtime or a long-lived process instead of
spawning PowerShell repeatedly.

### Release controls

**Verified and proposed**

Before each release:

1. run PowerShell behavior tests;
2. run the privacy scrub;
3. run `gh skill publish --dry-run`;
4. review executable diffs;
5. publish a semantic version tag;
6. document configuration compatibility in the changelog.

Repository hardening should include:

- secret scanning;
- code scanning where practical;
- protected release tags;
- minimal workflow permissions;
- pinned release installation examples.

## Cross-platform roadmap

### Windows v1

**Implemented**

- `.cmd` launcher;
- PowerShell 7 renderer and management scripts;
- Windows path and settings handling;
- path-with-spaces tests.

### macOS and Linux

**Proposed**

Add:

- a POSIX shell launcher;
- cross-platform settings path tests;
- terminal capability and Unicode rendering tests;
- a CI matrix for Windows, macOS, and Linux.

PowerShell 7 could remain the shared renderer initially. A future neutral
runtime should be considered only if it materially improves installation,
startup time, or host compatibility.

## Recommended delivery phases

| Phase | Outcome |
|---|---|
| `v0.1` | Publish Windows-first skill, installer, config, tests, and Wiki |
| `v0.2` | Add theme presets, preview, and validation commands |
| `v0.3` | Add versioned segments and measured performance budget |
| `v0.4` | Add configuration migrations and release compatibility policy |
| `v1.0` | Stabilize schema and command behavior |
| `v2.0` | Add supported macOS and Linux launchers |

## Sources

- [Agent Skills specification](https://agentskills.io/specification)
- [Adding agent skills for GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
- [`gh skill` command reference](https://cli.github.com/manual/gh_skill)
- [GitHub Copilot CLI configuration directory](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference)
- [GitHub Copilot CLI command reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)
- [GitHub Copilot CLI changelog](https://github.com/github/copilot-cli/blob/main/changelog.md)
- [`session_name` and `session_id` statusline support](https://github.com/github/copilot-cli/issues/3566)
- [Older `statusLine.command` rendering issue](https://github.com/github/copilot-cli/issues/3192)
- [Fine-grained theming request](https://github.com/github/copilot-cli/issues/2123)
- [Custom theme request](https://github.com/github/copilot-cli/issues/2830)
