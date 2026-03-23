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

(defcustom perspective-project-bridge-confirm-on-interactive-find-file t
  "Ask before switching perspectives for interactive `find-file' commands."
  :group 'perspective-project-bridge
  :type 'boolean)

(defcustom perspective-project-bridge-consult-prompt-on-file-action t
  "Ask before switching perspectives for `consult--file-action'."
  :group 'perspective-project-bridge
  :type 'boolean)

(defcustom perspective-project-bridge-consult-prompt-format
  "Move selected buffer to project perspective `%s'? "
  "Prompt format used for `consult--file-action' perspective switching."
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

(defconst perspective-project-bridge--find-file-project-prompt-format
  "Switch to project perspective `%s'? "
  "Prompt format used for project perspective switching in `find-file' advice.")

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

(defun perspective-project-bridge--maybe-prompt-and-switch (project-name prompt-format)
  "Prompt with PROMPT-FORMAT and switch to PROJECT-NAME when confirmed.
PROMPT-FORMAT must be a string accepted by `format' with one `%s' placeholder."
  (let* ((current-perspective (persp-curr))
	 (current-perspective-name (and current-perspective
					(persp-name current-perspective))))
    (when (and project-name
	       (not (equal current-perspective-name project-name))
	       (y-or-n-p (format prompt-format project-name)))
      (perspective-project-bridge--switch-to-project-perspective project-name))))

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
	     (target (and interactive-call
			  perspective-project-bridge-confirm-on-interactive-find-file
			  (perspective-project-bridge--switch-target-for-file
			   (car args)
			   perspective-project-bridge--find-file-project-prompt-format))))
	(when target
	  (perspective-project-bridge--maybe-prompt-and-switch
	   (car target)
	   (cdr target)))
	(apply orig-fun args)))))

(defun perspective-project-bridge-consult-file-action-advice (orig-fun file &rest args)
  "Around advice for `consult--file-action'."
  (if (or perspective-project-bridge--in-find-file-advice
	  (not perspective-project-bridge-mode))
      (apply orig-fun file args)
    (let* ((perspective-project-bridge--in-find-file-advice t)
	   (target (and perspective-project-bridge-consult-prompt-on-file-action
			(perspective-project-bridge--switch-target-for-file
			 file
			 perspective-project-bridge-consult-prompt-format))))
      (when target
	(perspective-project-bridge--maybe-prompt-and-switch
	 (car target)
	 (cdr target)))
      (apply orig-fun file args))))

(defun perspective-project-bridge--add-consult-advice-if-available ()
  "Add consult advice when consult is available."
  (when (fboundp 'consult--file-action)
    (perspective-project-bridge--add-advice-once
     'consult--file-action :around
     #'perspective-project-bridge-consult-file-action-advice)))

(defun perspective-project-bridge--remove-consult-advice-if-available ()
  "Remove consult advice when consult is available."
  (when (fboundp 'consult--file-action)
    (perspective-project-bridge--remove-advice-if-present
     'consult--file-action
     #'perspective-project-bridge-consult-file-action-advice)))

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
	    (perspective-project-bridge--add-consult-advice-if-available)
	    (with-eval-after-load 'consult
	      (when perspective-project-bridge-mode
		(perspective-project-bridge--add-consult-advice-if-available)))
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
       func #'perspective-project-bridge-find-file-advice))
    (perspective-project-bridge--remove-consult-advice-if-available)))

(provide 'perspective-project-bridge)

;;; perspective-project-bridge.el ends here
