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
- Prompting can be disabled with `perspective-project-bridge-confirm-on-interactive-find-file`.
- If the current perspective already matches the target project perspective, no prompt is shown.
- If the opened file is not in a detected project, you are asked whether to switch to `persp-initial-frame-name`.
- If the opened file is not in a detected project (or project root is unavailable) and non-project prompting is disabled, the file stays in the current perspective.
- The non-project prompt text is customizable via `perspective-project-bridge-non-project-file-prompt-format`.

### `consult-buffer` file selection behavior
When `consult` is available, `consult--file-action` is integrated too:

- Selecting a file candidate from `consult-buffer` can prompt for project perspective switching.
- Existing file buffers and newly opened files are handled with the same switching rules.
- Prompting can be disabled with `perspective-project-bridge-consult-prompt-on-file-action`.
- Prompt text is customizable via `perspective-project-bridge-consult-prompt-format`.
- Non-project file candidates also prompt for a switch to `persp-initial-frame-name` by default.
