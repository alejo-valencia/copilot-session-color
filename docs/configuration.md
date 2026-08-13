# Configuration

The installer creates:

```text
%USERPROFILE%\.copilot\session-color\config.json
```

Changes are read on the next statusline refresh. Keep `schemaVersion` set to
`1`.

## Palette

Automatic mode hashes the active session ID into `theme.palette`:

```json
{
  "theme": {
    "palette": [39, 45, 81, 114, 141, 171]
  }
}
```

Each value is an ANSI 256-color index from `0` through `255`.

## Named colors

Names accepted by `/color` come from `theme.namedColors`:

```json
{
  "theme": {
    "namedColors": {
      "ocean": 39,
      "forest": 114,
      "sunset": 208
    }
  }
}
```

After saving:

```text
/color forest
```

## Decoration

The default mirrored gradient is:

```text
░▒▓█ Example Session █▓▒░
```

It is configured with matching arrays:

```json
{
  "theme": {
    "decoration": {
      "leftGlyphs": ["░", "▒", "▓", "█"],
      "rightGlyphs": ["█", "▓", "▒", "░"],
      "intensities": [0.35, 0.55, 0.75, 1.0]
    }
  }
}
```

All three arrays must have the same length. Use empty arrays to remove the
decoration.

A simple bracket theme uses one element:

```json
{
  "theme": {
    "decoration": {
      "leftGlyphs": ["["],
      "rightGlyphs": ["]"],
      "intensities": [1.0]
    }
  }
}
```

## Directory display

Directory display is disabled by default:

```json
{
  "theme": {
    "showDirectory": false,
    "directorySeparator": "·"
  }
}
```

When enabled, the renderer shows only the final directory name, not the full
path.

## Session overrides

The `/color` skill writes session overrides automatically. They have this
shape:

```json
{
  "sessions": {
    "11111111-2222-4333-8444-555555555555": {
      "ansiColor": 114
    }
  }
}
```

An optional local title override can be added manually:

```json
{
  "sessions": {
    "11111111-2222-4333-8444-555555555555": {
      "ansiColor": 114,
      "title": "Example Session"
    }
  }
}
```

Session IDs and titles remain local and should not be committed to a public
repository.

## Validation failures

If configuration is malformed, the statusline renders:

```text
[session-color configuration error]
```

Correct the JSON or restore `default-config.json` as `config.json`.
