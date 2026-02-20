# Changelog

## Unreleased
- Added interactive `find-file` integration that asks whether to switch to the file's project perspective.
- Suppressed the interactive `find-file` prompt when already in the target project perspective.
- Added new customization variables for project command hooks, find-file command scope, and interactive prompt behavior.
- Added ERT coverage for interactive/non-interactive find-file advice behavior, missing project roots, and reentry guard handling.
