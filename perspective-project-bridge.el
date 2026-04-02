;;; perspective-project-bridge.el --- Integration of perspective.el + project.el -*- lexical-binding: t; -*-

;; 
;; Author: Hiroyuki Ishikura <nekomist@gmail.com>
;; Original-Author: Arunkumar Vaidyanathan <arunkumarmv1997@gmail.com>
;; Version: 0.1+
;; Package-Requires: ((emacs "27.1") (perspective "2.18"))
;; SPDX-License-Identifier: GPL-3.0-or-later
;; Keywords: perspective, project, convenience, frames
;; URL: https://github.com/nekomimist/perspective-project-bridge
;; Original-URL: https://github.com/arunkmv/perspective-project-bridge

;;; License:

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; Creates a perspective for each project.el project.  Based on
;; persp-mode-projectile-bridge.
;;
;;; Usage:
;; Example configuration:
;;
;; (with-eval-after-load "perspective-project-bridge-autoloads"
;;   (add-hook 'perspective-project-bridge-mode-hook
;; 	    (lambda ()
;; 	      (if perspective-project-bridge-mode
;; 		  (perspective-project-bridge-find-perspectives-for-all-buffers)
;; 		(perspective-project-bridge-kill-perspectives))))
;;   (add-hook 'after-init-hook
;; 	    (lambda ()
;; 	      (perspective-project-bridge-mode 1))
;; 	    t))
;; 
;; With use-package:
;;
;; (use-package perspective-project-bridge
;;   :hook
;;   (perspective-project-bridge-mode
;;    .
;;    (lambda ()
;;      (if perspective-project-bridge-mode
;; 	 (perspective-project-bridge-find-perspectives-for-all-buffers)
;;        (perspective-project-bridge-kill-perspectives))))
;;   (persp-mode . perspective-project-bridge-mode))

;;; Code:


(require 'perspective)
(require 'project)
(require 'cl-lib)

(defvar consult-buffer-sources)
(defvar consult--buffer-display)

(declare-function consult-buffer "consult")

(defvar perspective-project-bridge-mode nil)

(defgroup perspective-project-bridge nil
  "Perspective project.el integration."
  :group 'perspective
  :group 'project
  :prefix "perspective-project-bridge-")

(defcustom perspective-project-bridge-project-functions
  (list 'project-find-file 'project-find-regexp 'project-find-dir)
  "Project commands that should trigger perspective switching."
  :group 'perspective-project-bridge
  :type '(repeat function))

(defvaralias 'perspective-project-bridge-funcs
  'perspective-project-bridge-project-functions)

(defcustom perspective-project-bridge-find-file-functions
  (list 'find-file 'find-file-other-window
	'find-file-other-frame 'find-file-read-only)
  "Interactive `find-file' commands that should ask about switching perspectives."
  :group 'perspective-project-bridge
  :type '(repeat function))

(defcustom perspective-project-bridge-confirm-on-interactive-find-file 'prompt
  "Switch policy for interactive `find-file' commands.
Use `prompt' to ask before switching, `always' to switch without
asking, or `never' to keep the current perspective.

Legacy boolean values are supported for compatibility: `t' means
`prompt' and `nil' means `never'.

With a plain universal argument (`C-u'), `always' and `never'
behave like `prompt' for that invocation only."
  :group 'perspective-project-bridge
  :type '(choice (const :tag "Prompt before switching" prompt)
		 (const :tag "Switch automatically" always)
		 (const :tag "Never switch" never)))

(defcustom perspective-project-bridge-consult-prompt-on-file-action 'prompt
  "Switch policy for file actions in `consult-buffer-with-project-perspective'.
Use `prompt' to ask before switching, `always' to switch without
asking, or `never' to keep the current perspective.

Legacy boolean values are supported for compatibility: `t' means
`prompt' and `nil' means `never'.

With a plain universal argument (`C-u'),
`consult-buffer-with-project-perspective' treats `always' and
`never' like `prompt' for that invocation only."
  :group 'perspective-project-bridge
  :type '(choice (const :tag "Prompt before switching" prompt)
		 (const :tag "Switch automatically" always)
		 (const :tag "Never switch" never)))

(defcustom perspective-project-bridge-consult-prompt-format
  "Move selected buffer to project perspective `%s'? "
  "Prompt format used for file actions in `consult-buffer-with-project-perspective'."
  :group 'perspective-project-bridge
  :type 'string)

(defcustom perspective-project-bridge-consult-buffer-switch-policy 'prompt
  "Switch policy for buffer actions in `consult-buffer-with-project-perspective'.
Use `prompt' to choose between switching or moving, `always' to
switch to the buffer's perspective, or `never' to keep the
current perspective and move the buffer there.

Compatibility aliases are supported: `query' and `t' mean
`prompt', and `nil' means `never'.

With a plain universal argument (`C-u'),
`consult-buffer-with-project-perspective' treats `always' and
`never' like `prompt' for that invocation only."
  :group 'perspective-project-bridge
  :type '(choice (const :tag "Choose switch or move" prompt)
		 (const :tag "Switch automatically" always)
		 (const :tag "Move automatically" never)))

(defcustom perspective-project-bridge-consult-buffer-prompt-format
  "Buffer `%s' belongs to perspective `%s' while current perspective is `%s'."
  "Prompt format used before choosing switch or move for consult buffer actions."
  :group 'perspective-project-bridge
  :type 'string)

(defcustom perspective-project-bridge-prompt-on-non-project-file t
  "Ask before switching to `persp-initial-frame-name' for non-project files."
  :group 'perspective-project-bridge
  :type 'boolean)

(defcustom perspective-project-bridge-non-project-file-prompt-format
  "Switch to initial perspective `%s'? "
  "Prompt format used when opening non-project files in the initial perspective."
  :group 'perspective-project-bridge
  :type 'string)

(defvar perspective-project-bridge-persp nil
  "Indicate if perspective is project-specific.")

(defvar perspective-project-bridge--in-find-file-advice nil
  "Non-nil while `find-file' advice is running.")

(defvar perspective-project-bridge--consult-buffer-action-function nil
  "Original consult buffer action used by `consult-buffer-with-project-perspective'.")

(defvar perspective-project-bridge--consult-file-action-function nil
  "Original consult file action used by `consult-buffer-with-project-perspective'.")

(defvar perspective-project-bridge--consult-prompt-override nil
  "Non-nil when consult actions should treat automatic policies as `prompt'.")

(defconst perspective-project-bridge--find-file-project-prompt-format
  "Switch to project perspective `%s'? "
  "Prompt format used for project perspective switching in `find-file' advice.")

(defun perspective-project-bridge--plain-universal-argument-p (arg)
  "Return non-nil when ARG is a plain universal argument.
This matches a single `C-u' and excludes numeric prefix arguments."
  (equal arg '(4)))

(defun perspective-project-bridge--normalize-switch-policy (policy)
  "Return canonical switch policy for POLICY.
Canonical values are `prompt', `always', and `never'."
  (cond
   ((or (eq policy 'prompt) (eq policy t))
    'prompt)
   ((eq policy 'always)
    'always)
   ((or (eq policy 'never) (null policy))
    'never)
   (t
    (error "Invalid perspective-project-bridge switch policy: %S" policy))))

(defun perspective-project-bridge--normalize-consult-buffer-switch-policy (policy)
  "Return canonical consult buffer switch policy for POLICY.
Canonical values are `prompt', `always', and `never'."
  (cond
   ((or (eq policy 'prompt) (eq policy 'query) (eq policy t))
    'prompt)
   ((eq policy 'always)
    'always)
   ((or (eq policy 'never) (null policy))
    'never)
   (t
    (error "Invalid perspective-project-bridge consult buffer switch policy: %S"
	   policy))))

(defun perspective-project-bridge--effective-switch-policy
    (policy &optional prompt-override)
  "Return effective file switch POLICY.
When PROMPT-OVERRIDE is non-nil, `always' and `never' behave like `prompt'."
  (let ((normalized (perspective-project-bridge--normalize-switch-policy policy)))
    (if (and prompt-override
	     (memq normalized '(always never)))
	'prompt
      normalized)))

(defun perspective-project-bridge--effective-consult-buffer-switch-policy
    (policy &optional prompt-override)
  "Return effective consult buffer switch POLICY.
When PROMPT-OVERRIDE is non-nil, `always' and `never' behave like `prompt'."
  (let ((normalized
	 (perspective-project-bridge--normalize-consult-buffer-switch-policy policy)))
    (if (and prompt-override
	     (memq normalized '(always never)))
	'prompt
      normalized)))

(defun perspective-project-bridge--project-root (project)
  "Return root directory for PROJECT, or nil if it is unavailable."
  (when project
    (if (fboundp 'project-root)
	(project-root project)
      (car (project-roots project)))))

(defun perspective-project-bridge--project-name-for-buffer (buffer)
  "Return project perspective name for BUFFER, or nil."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (buffer-name buffer)
	(let* ((project (project-current))
	       (root (perspective-project-bridge--project-root project)))
	  (when root
	    (file-name-nondirectory
	     (directory-file-name root))))))))

(defun perspective-project-bridge--project-name-for-file (file)
  "Return project perspective name for FILE, or nil."
  (when (and file (stringp file))
    (let* ((expanded-file (expand-file-name file))
	   (directory (or (and (file-directory-p expanded-file)
			       (file-name-as-directory expanded-file))
			  (file-name-directory expanded-file))))
      (when directory
	(let ((default-directory directory))
	  (let* ((project (project-current))
		 (root (perspective-project-bridge--project-root project)))
	    (when root
	      (file-name-nondirectory
	       (directory-file-name root)))))))))

(defun perspective-project-bridge--non-project-perspective-name ()
  "Return the initial perspective name for non-project files, or nil."
  (when (and perspective-project-bridge-prompt-on-non-project-file
	     (stringp persp-initial-frame-name)
	     (not (string= persp-initial-frame-name "")))
    persp-initial-frame-name))

(defun perspective-project-bridge--switch-target-for-file
    (file project-prompt-format)
  "Return switch target for FILE as a cons of name and prompt format.
PROJECT-PROMPT-FORMAT is used when FILE belongs to a detected project."
  (let ((project-name (perspective-project-bridge--project-name-for-file file))
	(non-project-name (perspective-project-bridge--non-project-perspective-name)))
    (cond
     (project-name
      (cons project-name project-prompt-format))
     (non-project-name
      (cons non-project-name
	    perspective-project-bridge-non-project-file-prompt-format)))))

(defun perspective-project-bridge--switch-to-project-perspective (name)
  "Switch to perspective NAME and mark it as project-specific."
  (let ((persp (persp-new name)))
    (with-perspective (persp-name persp)
      (setq perspective-project-bridge-persp t))
    (persp-switch (persp-name persp))))

(defun perspective-project-bridge--add-advice-once (symbol where function)
  "Add FUNCTION as advice on SYMBOL at WHERE, unless it is already present."
  (unless (advice-member-p function symbol)
    (advice-add symbol where function)))

(defun perspective-project-bridge--remove-advice-if-present (symbol function)
  "Remove FUNCTION advice from SYMBOL when present."
  (when (advice-member-p function symbol)
    (advice-remove symbol function)))

(defun perspective-project-bridge--current-perspective-name ()
  "Return the current perspective name, or nil."
  (let* ((current-perspective (persp-curr))
	 (current-perspective-name (and current-perspective
					(persp-name current-perspective))))
    current-perspective-name))

(defun perspective-project-bridge--switch-if-needed (project-name)
  "Switch to PROJECT-NAME unless it is already current."
  (when (and project-name
	     (not (equal (perspective-project-bridge--current-perspective-name)
			 project-name)))
    (perspective-project-bridge--switch-to-project-perspective project-name)))

(defun perspective-project-bridge--switch-perspective-if-needed (name)
  "Switch to perspective NAME unless it is already current."
  (when (and name
	     (not (equal (perspective-project-bridge--current-perspective-name)
			 name)))
    (persp-switch name)))

(defun perspective-project-bridge--prompt-and-switch-if-needed
    (project-name prompt-format)
  "Prompt with PROMPT-FORMAT and switch to PROJECT-NAME when confirmed.
PROMPT-FORMAT must be a string accepted by `format' with one `%s' placeholder."
  (when (and project-name
	     (not (equal (perspective-project-bridge--current-perspective-name)
			 project-name))
	     (y-or-n-p (format prompt-format project-name)))
    (perspective-project-bridge--switch-to-project-perspective project-name)))

(defun perspective-project-bridge--apply-switch-policy
    (policy target &optional prompt-override)
  "Apply switch POLICY to TARGET.
TARGET must be a cons of perspective name and prompt format, or nil."
  (when target
    (pcase (perspective-project-bridge--effective-switch-policy
	    policy prompt-override)
      ('prompt
       (perspective-project-bridge--prompt-and-switch-if-needed
	(car target)
	(cdr target)))
      ('always
       (perspective-project-bridge--switch-if-needed (car target)))
      ('never
       nil))))

(defun perspective-project-bridge--consult-buffer-target-for-buffer (buffer)
  "Return consult buffer target plist for BUFFER, or nil.
The plist contains `:name' and `:kind'."
  (when (buffer-live-p buffer)
    (let ((project-name (perspective-project-bridge--project-name-for-buffer buffer)))
      (cond
       (project-name
	(list :name project-name :kind 'project))
       (t
	(let ((other-persp (persp-buffer-in-other-p buffer)))
	  (when (eq (car-safe other-persp) (selected-frame))
	    (list :name (cdr other-persp) :kind 'perspective))))))))

(defun perspective-project-bridge--consult-buffer-candidate-buffer (candidate)
  "Resolve consult buffer CANDIDATE to a live buffer, or nil."
  (cond
   ((bufferp candidate)
    (and (buffer-live-p candidate) candidate))
   ((stringp candidate)
    (get-buffer candidate))
   ((consp candidate)
    (or (perspective-project-bridge--consult-buffer-candidate-buffer (cdr candidate))
	(perspective-project-bridge--consult-buffer-candidate-buffer (car candidate))))
   (t
    nil)))

(defun perspective-project-bridge--consult-buffer-switch-choice (buffer target)
  "Prompt for how to open BUFFER using consult TARGET."
  (pcase
      (car
       (read-multiple-choice
	(format perspective-project-bridge-consult-buffer-prompt-format
		(buffer-name buffer)
		(plist-get target :name)
		(or (perspective-project-bridge--current-perspective-name) "none"))
	'((?s "switch" "Switch to the target perspective and open the buffer there")
	  (?m "move" "Move the buffer to the current perspective and open it here")
	  (?c "cancel" "Abort opening this candidate"))))
    (?s 'switch)
    (?m 'move)
    (?c 'cancel)))

(defun perspective-project-bridge--consult-buffer-open-target (target)
  "Switch to consult buffer TARGET when needed."
  (pcase (plist-get target :kind)
    ('project
     (perspective-project-bridge--switch-if-needed (plist-get target :name)))
    ('perspective
     (perspective-project-bridge--switch-perspective-if-needed
      (plist-get target :name)))))

(defun perspective-project-bridge--consult-buffer-open-buffer (candidate)
  "Open consult buffer CANDIDATE using bridge policy."
  (let* ((buffer (perspective-project-bridge--consult-buffer-candidate-buffer candidate))
	 (target (and buffer
		      (perspective-project-bridge--consult-buffer-target-for-buffer buffer)))
	 (target-name (plist-get target :name))
	 (current-name (perspective-project-bridge--current-perspective-name)))
    (if (or (not buffer)
	    (not target)
	    (equal target-name current-name))
	(funcall perspective-project-bridge--consult-buffer-action-function candidate)
      (pcase (perspective-project-bridge--effective-consult-buffer-switch-policy
	      perspective-project-bridge-consult-buffer-switch-policy
	      perspective-project-bridge--consult-prompt-override)
	('always
	 (perspective-project-bridge--consult-buffer-open-target target)
	 (funcall perspective-project-bridge--consult-buffer-action-function candidate))
	('never
	 (persp-set-buffer buffer)
	 (funcall perspective-project-bridge--consult-buffer-action-function candidate))
	('prompt
	 (pcase (perspective-project-bridge--consult-buffer-switch-choice buffer target)
	   ('switch
	    (perspective-project-bridge--consult-buffer-open-target target)
	    (funcall perspective-project-bridge--consult-buffer-action-function
		     candidate))
	   ('move
	    (persp-set-buffer buffer)
	    (funcall perspective-project-bridge--consult-buffer-action-function
		     candidate))
	   ('cancel
	    nil)))))))

(defun perspective-project-bridge--consult-transform-source (source)
  "Return temporary consult SOURCE with bridge-specific buffer behavior."
  (let ((plist (copy-tree (if (symbolp source) (symbol-value source) source))))
    (if (eq (plist-get plist :category) 'buffer)
	(let ((copy (copy-sequence plist)))
	  (setq copy (plist-put copy :state nil))
	  (plist-put copy :action
		     #'perspective-project-bridge--consult-buffer-open-buffer))
      plist)))

(defun perspective-project-bridge--consult-buffer-sources ()
  "Return consult buffer sources for `consult-buffer-with-project-perspective'."
  (mapcar #'perspective-project-bridge--consult-transform-source
	  consult-buffer-sources))

(defun perspective-project-bridge--consult-file-action (file &rest args)
  "Run consult file action for FILE with bridge file policy."
  (if (or perspective-project-bridge--in-find-file-advice
	  (not perspective-project-bridge-mode))
      (apply perspective-project-bridge--consult-file-action-function file args)
      (let* ((perspective-project-bridge--in-find-file-advice t)
	   (target (perspective-project-bridge--switch-target-for-file
		    file
		    perspective-project-bridge-consult-prompt-format)))
      (perspective-project-bridge--apply-switch-policy
       perspective-project-bridge-consult-prompt-on-file-action
       target
       perspective-project-bridge--consult-prompt-override)
      (apply perspective-project-bridge--consult-file-action-function file args))))

(defun perspective-project-bridge-find-perspective-for-buffer (buffer)
  "Find a project-specific perspective for BUFFER.

   If no such perspective exists, a new one is created and the buffer is
   added to it"
  (when perspective-project-bridge-mode
    (let* ((name (perspective-project-bridge--project-name-for-buffer buffer)))
      (when name
	(let ((persp (persp-new name)))
	  (with-perspective (persp-name persp)
	    (setq perspective-project-bridge-persp t)
	    (persp-add-buffer buffer))
	  persp)))))

(defun perspective-project-bridge-find-perspectives-for-all-buffers ()
  "Find project-specific perspectives for all buffers."
  (when perspective-project-bridge-mode
    (mapc #'perspective-project-bridge-find-perspective-for-buffer
          (buffer-list))))

(defun perspective-project-bridge-kill-perspectives ()
  "Kill all project-specific perspectives."
  (mapc #'persp-kill
	(cl-delete-if-not
	 (lambda (p)
	   (with-perspective p
	     perspective-project-bridge-persp))
	 (persp-names))))

(defun perspective-project-bridge (&rest _args)
  "Create/switch to a project perspective for current buffer.

   Provides bridge between perspective and project functions when
   switch between projects.  After switching to a new project, this
   creates a new perspective for that project."
  (let* ((b (current-buffer))
	 (persp (perspective-project-bridge-find-perspective-for-buffer b)))
    (when persp
      ;; Remove buffer from the perspective it was created in, if it
      ;; does not belong there.
      (when (not (eq persp (persp-curr)))
	(persp-remove-buffer b))
      (persp-switch (persp-name persp))
      (persp-switch-to-buffer b))))

(defun perspective-project-bridge-find-file-advice (orig-fun &rest args)
  "Around advice for interactive `find-file' style commands."
  (let ((interactive-call (called-interactively-p 'interactive)))
    (if (or perspective-project-bridge--in-find-file-advice
	    (not perspective-project-bridge-mode))
	(apply orig-fun args)
      (let* ((perspective-project-bridge--in-find-file-advice t)
	     (prompt-override
	      (perspective-project-bridge--plain-universal-argument-p
	       current-prefix-arg))
	     (target (and interactive-call
			  (perspective-project-bridge--switch-target-for-file
			   (car args)
			   perspective-project-bridge--find-file-project-prompt-format))))
	(perspective-project-bridge--apply-switch-policy
	 perspective-project-bridge-confirm-on-interactive-find-file
	 target
	 prompt-override)
	(apply orig-fun args)))))

(defun consult-buffer-with-project-perspective ()
  "Run `consult-buffer' with project perspective-aware actions."
  (interactive)
  (unless (fboundp 'consult-buffer)
    (user-error "consult-buffer-with-project-perspective requires consult"))
  (if (not (and perspective-project-bridge-mode persp-mode))
      (consult-buffer)
    (let ((perspective-project-bridge--consult-prompt-override
	   (perspective-project-bridge--plain-universal-argument-p
	    current-prefix-arg))
	  (perspective-project-bridge--consult-buffer-action-function
	   (symbol-function 'consult--buffer-action))
	  (perspective-project-bridge--consult-file-action-function
	   (and (fboundp 'consult--file-action)
		(symbol-function 'consult--file-action)))
	  (consult-buffer-sources
	   (perspective-project-bridge--consult-buffer-sources)))
      (if perspective-project-bridge--consult-file-action-function
	  (cl-letf (((symbol-function 'consult--file-action)
		     #'perspective-project-bridge--consult-file-action))
	    (consult-buffer))
	(consult-buffer)))))

;;;###autoload
(define-minor-mode perspective-project-bridge-mode
  "`perspective' and `project.el' integration.
Creates perspectives for project.el projects."
  :init-value nil
  :global t
  (if perspective-project-bridge-mode
      (if persp-mode
	(progn
	    ;; Add advices
	    (dolist (func perspective-project-bridge-project-functions)
	      (perspective-project-bridge--add-advice-once
	       func :after #'perspective-project-bridge))
	    (dolist (func perspective-project-bridge-find-file-functions)
	      (perspective-project-bridge--add-advice-once
	       func :around #'perspective-project-bridge-find-file-advice))
	    (persp-make-variable-persp-local 'perspective-project-bridge-persp))
	(message "You can not enable perspective-project-bridge-mode \
unless persp is active.")
	(perspective-project-bridge-mode -1))
    ;; Remove advices
    (dolist (func perspective-project-bridge-project-functions)
      (perspective-project-bridge--remove-advice-if-present
       func #'perspective-project-bridge))
    (dolist (func perspective-project-bridge-find-file-functions)
      (perspective-project-bridge--remove-advice-if-present
       func #'perspective-project-bridge-find-file-advice))))

(provide 'perspective-project-bridge)

;;; perspective-project-bridge.el ends here
