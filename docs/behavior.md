# Behavior and model selection

## Which model processes `/color`?

The active Copilot CLI session model processes the `/color` prompt and loads
the Agent Skill instructions.

Agent Skills do not have a `model` frontmatter field. Their supported metadata
includes fields such as `name`, `description`, `license`, `compatibility`,
`metadata`, and `allowed-tools`, but not model selection.

Copilot model selection is configured at the session or agent level through
features such as `/model` and per-subagent settings. The `color` skill cannot
force Haiku or another lower-cost model for only this command.

The model performs very little work: it interprets the requested operation and
runs deterministic local PowerShell scripts. Rendering and color selection do
not call an AI model.

## What happens when a session has no name?

If the statusline payload has no `session_name`, the renderer displays:

```text
Copilot session
```

The fallback can be changed through `theme.fallbackSessionName` in
`config.json`.

Use Copilot's native command to generate a session name from the conversation:

```text
/rename
```

Or provide one explicitly:

```text
/rename My session name
```

The renderer deliberately does not read transcript files or call a model to
invent a name. That would add latency, depend on undocumented storage, and
create unnecessary privacy risk.

## Title width and truncation

The center title field is exactly 35 text characters by default:

- shorter names are centered;
- longer names keep the first 32 characters and add `...`;
- the complete center field uses one solid session-color background;
- black or white title text is selected automatically for contrast;
- gradient color appears only in the outer decoration.

The width and background mode are configurable through `theme.titleWidth` and
`theme.titleBackground`.

## Sources

- [Agent Skills specification](https://agentskills.io/specification)
- [Adding agent skills for GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
- [GitHub Copilot CLI command reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)
