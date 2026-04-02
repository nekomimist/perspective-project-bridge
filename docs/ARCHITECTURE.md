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
       A plain universal argument (`C-u`) temporarily treats `always` and `never` like `prompt`.
    4. On `prompt` confirmation or `always`, switch to the selected perspective.
    5. Execute the original find-file command in the selected perspective.
  - Safety:
    - No prompt/switch for non-interactive calls.
    - No prompt/switch when already in the target perspective.
    - No prompt/switch when no project root is available and non-project prompting is disabled.
    - Reentry guard avoids nested advice behavior.
- `consult-buffer-with-project-perspective`
  - Standalone interactive command; standard `consult-buffer` is not advised or modified.
  - Behavior:
    1. Reuse `consult-buffer` sources with temporary source transformation at call time.
    2. Disable preview for buffer-category sources to avoid perspective pollution during preview and `C-g`.
    3. For file candidates, resolve the selected file's project and reuse the existing file switch policy.
    4. For buffer candidates, resolve a target perspective in this order:
       - project perspective from the buffer's project root
       - first other perspective on the selected frame via `persp-buffer-in-other-p`
    5. Apply buffer policy: `prompt`, `always`, or `never`.
       A plain universal argument (`C-u`) temporarily treats `always` and `never` like `prompt`.
    6. `prompt` offers switch, move, or cancel.
  - Safety:
    - Standard `consult-buffer` behavior remains unchanged.
    - File actions reuse the reentry guard so nested `find-file` prompts do not occur.
    - Cross-frame non-project buffer membership is ignored.

## Customization Surface
- `perspective-project-bridge-project-functions`
  - Which project commands trigger automatic project perspective switching.
- `perspective-project-bridge-find-file-functions`
  - Which find-file commands prompt for perspective switching.
- `perspective-project-bridge-confirm-on-interactive-find-file`
  - Switch policy for interactive find-file calls (`prompt`, `always`, `never`; legacy `t`/`nil` also supported).
    A plain universal argument (`C-u`) temporarily treats `always` and `never` like `prompt`.
- `perspective-project-bridge-consult-prompt-on-file-action`
  - Switch policy for file candidates in `consult-buffer-with-project-perspective` (`prompt`, `always`, `never`; legacy `t`/`nil` also supported).
    A plain universal argument (`C-u`) temporarily treats `always` and `never` like `prompt`.
- `perspective-project-bridge-consult-prompt-format`
  - Prompt format used for file candidates in `consult-buffer-with-project-perspective`.
- `perspective-project-bridge-consult-buffer-switch-policy`
  - Switch policy for existing buffer candidates in `consult-buffer-with-project-perspective` (`prompt`, `always`, `never`; `query`/`t` => `prompt`, `nil` => `never`).
    A plain universal argument (`C-u`) temporarily treats `always` and `never` like `prompt`.
- `perspective-project-bridge-consult-buffer-prompt-format`
  - Prompt format used before choosing switch, move, or cancel for existing buffer candidates.
- `perspective-project-bridge-prompt-on-non-project-file`
  - Whether non-project files prompt for switching to `persp-initial-frame-name`.
- `perspective-project-bridge-non-project-file-prompt-format`
  - Prompt format used when non-project files target the initial perspective.
