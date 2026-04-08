# Changelog

## Unreleased
- Fixed `void-variable consult-buffer-sources` error when `consult-buffer-with-project-perspective` is called before `consult.el` is loaded (e.g. via autoload).
- Added a plain universal-argument override (`C-u`) that temporarily treats `always` and `never` like `prompt` for interactive file and consult actions.
- Expanded interactive file-action prompt settings into 3-state switch policies: `prompt`, `always`, and `never`.
- Kept legacy boolean compatibility for file-action switch settings (`t` => `prompt`, `nil` => `never`).
- Added interactive `find-file` integration that asks whether to switch to the file's project perspective.
- Suppressed the interactive `find-file` prompt when already in the target project perspective.
- Added `consult-buffer-with-project-perspective` as a standalone consult command instead of modifying standard `consult-buffer`.
- Added buffer-aware consult handling with `prompt`/`always`/`never` policy, allowing switch, move, or cancel for existing buffers.
- Disabled buffer preview in `consult-buffer-with-project-perspective` to avoid preview-time perspective pollution.
- Added prompting for non-project files to switch to `persp-initial-frame-name` by default.
- Added new customization variables for project command hooks, find-file command scope, consult buffer switching, and interactive prompt behavior.
- Added ERT coverage for consult command helpers, buffer switch/move/cancel behavior, and source transformation.
