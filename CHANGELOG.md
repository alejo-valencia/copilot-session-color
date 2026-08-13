# Changelog

All notable changes will be documented in this file.

## 0.1.2 - 2026-08-13

- Add a centered, fixed-width 35-character title field.
- Truncate long session names to 32 characters plus `...`.
- Use a solid session-color title background with automatic contrast while
  keeping gradients only on the outer decoration.
- Document the GitHub CLI 2.90 requirement and Windows upgrade diagnostics.

## 0.1.1 - 2026-08-13

- Double the default gradient length.
- Migrate unchanged four-character decorations during installation.
- Document active-model behavior and native unnamed-session naming.
- Shorten the README and keep all documentation in versioned Markdown files.

## 0.1.0 - 2026-08-13

- Package the statusline formatter as an installable `color` Agent Skill.
- Add conflict-safe installation and uninstall workflows.
- Add local JSON configuration for palettes, named colors, decorations, and
  per-session overrides.
- Add mirrored gradient bars around the session title.
- Add public-content scanning for user-home paths and secret-shaped values.
