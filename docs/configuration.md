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
░░▒▒▓▓██          Example Session          ██▓▓▒▒░░
```

It is configured with matching arrays:

```json
{
  "theme": {
    "decoration": {
      "leftGlyphs": ["░", "░", "▒", "▒", "▓", "▓", "█", "█"],
      "rightGlyphs": ["█", "█", "▓", "▓", "▒", "▒", "░", "░"],
      "intensities": [0.2, 0.3, 0.4, 0.5, 0.65, 0.8, 0.9, 1.0]
    }
  }
}
```

All three arrays must have the same length. Use empty arrays to remove the
decoration.

## Title field

The title field is exactly 35 characters by default. Short names are centered;
long names keep the first 32 characters and add `...`.

```json
{
  "theme": {
    "titleWidth": 35,
    "titleBackground": "solid"
  }
}
```

`solid` fills the complete fixed-width field with the session color and
automatically chooses black or white text for contrast. `none` keeps the fixed
width with no background. Gradient color is used only by the outer decoration.

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
