# Architecture

## Overview
`perspective-project-bridge` connects `project.el` commands with `perspective.el` workspaces by assigning project buffers to project-named perspectives and switching to the matching perspective when needed.

## Core Components
- `perspective-project-bridge-find-perspective-for-buffer`
  - Resolves a buffer's project root.
  - Creates or reuses a project perspective by project directory name.
  - Marks bridge-created perspectives with `perspective-project-bridge-persp`.
- `perspective-project-bridge`
  - Runtime switch operation for project commands.
  - Ensures the current buffer is shown in the target project perspective.

## Advice Layers
- Project commands (`:after`)
  - Configured via `perspective-project-bridge-project-functions`.
  - Default commands: `project-find-file`, `project-find-regexp`, `project-find-dir`.
  - Behavior: run command first, then move/switch current buffer to project perspective.
- Interactive find-file commands (`:around`)
  - Configured via `perspective-project-bridge-find-file-functions`.
  - Default commands: `find-file`, `find-file-other-window`, `find-file-other-frame`, `find-file-read-only`.
  - Behavior:
    1. Resolve the target file's project from the command argument.
    2. If no project is found, target `persp-initial-frame-name` unless non-project prompting is disabled.
    3. If call was interactive, apply the configured switch policy: `prompt`, `always`, or `never`.
    4. On `prompt` confirmation or `always`, switch to the selected perspective.
    5. Execute the original find-file command in the selected perspective.
  - Safety:
    - No prompt/switch for non-interactive calls.
    - No prompt/switch when already in the target perspective.
    - No prompt/switch when no project root is available and non-project prompting is disabled.
    - Reentry guard avoids nested advice behavior.
- Consult file action (`:around`)
  - Added when `consult--file-action` is available.
  - Behavior:
    1. Resolve the selected file's project.
    2. If no project is found, target `persp-initial-frame-name` unless non-project prompting is disabled.
    3. Apply the configured switch policy: `prompt`, `always`, or `never`.
    4. On `prompt` confirmation or `always`, switch to the selected perspective.
    5. Run `consult--file-action` to select/open the target buffer.
  - Safety:
    - Existing file buffers and newly opened files use the same project switch decision.
    - No prompt/switch when already in the target perspective.
    - No prompt/switch when no project root is available and non-project prompting is disabled.

## Customization Surface
- `perspective-project-bridge-project-functions`
  - Which project commands trigger automatic project perspective switching.
- `perspective-project-bridge-find-file-functions`
  - Which find-file commands prompt for perspective switching.
- `perspective-project-bridge-confirm-on-interactive-find-file`
  - Switch policy for interactive find-file calls (`prompt`, `always`, `never`; legacy `t`/`nil` also supported).
- `perspective-project-bridge-consult-prompt-on-file-action`
  - Switch policy for consult file actions (`prompt`, `always`, `never`; legacy `t`/`nil` also supported).
- `perspective-project-bridge-consult-prompt-format`
  - Prompt format used for consult file actions.
- `perspective-project-bridge-prompt-on-non-project-file`
  - Whether non-project files prompt for switching to `persp-initial-frame-name`.
- `perspective-project-bridge-non-project-file-prompt-format`
  - Prompt format used when non-project files target the initial perspective.
