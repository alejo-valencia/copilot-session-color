# Security policy

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature for this repository.
Please do not open a public issue for a suspected vulnerability.

Include:

- the affected version;
- the operating system and PowerShell version;
- reproduction steps;
- the expected and observed behavior;
- whether an existing Copilot statusline configuration was involved.

## Security boundaries

The skill writes only to the current user's Copilot configuration directory.
It does not require administrator access, make network requests, or collect
telemetry.

Agent Skills can contain executable scripts. Review the skill with
`gh skill preview` before installation and pin installations to a release when
reproducibility is required.
