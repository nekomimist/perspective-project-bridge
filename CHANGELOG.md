# Changelog

## Unreleased
- Expanded interactive file-action prompt settings into 3-state switch policies: `prompt`, `always`, and `never`.
- Kept legacy boolean compatibility for file-action switch settings (`t` => `prompt`, `nil` => `never`).
- Added interactive `find-file` integration that asks whether to switch to the file's project perspective.
- Suppressed the interactive `find-file` prompt when already in the target project perspective.
- Added optional `consult--file-action` integration for `consult-buffer` file candidates with project perspective switch prompts.
- Added prompting for non-project files to switch to `persp-initial-frame-name` by default.
- Added new customization variables for project command hooks, find-file command scope, and interactive prompt behavior.
- Added customization for consult prompt behavior, non-project file prompting, and prompt text.
- Added ERT coverage for interactive/non-interactive find-file advice behavior, missing project roots, and reentry guard handling.
