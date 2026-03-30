# Perspective project.el bridge

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Creates a perspective for each project.el project. Based on [persp-mode-projectile-bridge](https://github.com/Bad-ptr/persp-mode-projectile-bridge.el).

## Usage
### Example configuration:
```elisp
 (with-eval-after-load "perspective-project-bridge-autoloads"
   (add-hook 'after-init-hook
			 (lambda ()
				 (perspective-project-bridge-mode 1))
			 t))

```

### With use-package:
```elisp
 (use-package perspective-project-bridge
   :hook
   (perspective-project-bridge-mode . (lambda ()
									   (if perspective-project-bridge-mode
										   (perspective-project-bridge-find-perspectives-for-all-buffers)
										 (perspective-project-bridge-kill-perspectives))))
   (persp-mode . perspective-project-bridge-mode))
```

### Automatic buffer assignment
By adding the following hook, all buffers are automatically assigned a project-specific perspective when ```perspective-project-bridge-mode``` is enabled and all bridge perspectives are killed when the mode is disabled.
```elisp
   (add-hook 'perspective-project-bridge-mode-hook
			 (lambda ()
				 (if perspective-project-bridge-mode
					 (perspective-project-bridge-find-perspectives-for-all-buffers)
				   (perspective-project-bridge-kill-perspectives))))
```

### Interactive `find-file` behavior
When `perspective-project-bridge-mode` is enabled, interactive file-opening commands ask whether to switch to the target project's perspective before continuing in that project workspace.

- Prompted commands are controlled by `perspective-project-bridge-find-file-functions`.
- `perspective-project-bridge-confirm-on-interactive-find-file` accepts `prompt`, `always`, or `never`.
- Legacy values remain supported: `t` behaves like `prompt`, and `nil` behaves like `never`.
- If the current perspective already matches the target project perspective, no prompt is shown.
- If the opened file is not in a detected project, you are asked whether to switch to `persp-initial-frame-name`.
- If the opened file is not in a detected project (or project root is unavailable) and non-project prompting is disabled, the file stays in the current perspective.
- When the policy is `always`, the same target switch happens without prompting.
- The non-project prompt text is customizable via `perspective-project-bridge-non-project-file-prompt-format`.

### `consult-buffer-with-project-perspective`
Standard `consult-buffer` behavior is left untouched. When `consult` is available, use
`consult-buffer-with-project-perspective` for perspective-aware selection:

- File candidates follow the existing file-opening rules.
- `perspective-project-bridge-consult-prompt-on-file-action` accepts `prompt`, `always`, or `never`.
- Prompt text for file candidates is customizable via `perspective-project-bridge-consult-prompt-format`.
- Non-project file candidates also prompt for a switch to `persp-initial-frame-name` by default.
- Existing buffer candidates use `perspective-project-bridge-consult-buffer-switch-policy`.
- `prompt` asks whether to switch to the buffer's perspective, move the buffer into the current perspective, or cancel.
- `always` switches to the buffer's perspective automatically.
- `never` keeps the current perspective and moves the selected buffer there.
- Prompt text for buffer candidates is customizable via `perspective-project-bridge-consult-buffer-prompt-format`.
- Buffer preview is disabled in this command to avoid leaving buffers attached to the current perspective after preview or `C-g`.
- If you use `consult-customize` with command-specific settings, include `consult-buffer-with-project-perspective` explicitly.
