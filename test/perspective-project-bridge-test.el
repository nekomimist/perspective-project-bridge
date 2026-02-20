;;; perspective-project-bridge-test.el --- Tests for perspective-project-bridge -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for perspective-project-bridge.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'project)

(unless (require 'perspective nil t)
  (defvar persp-mode t)
  (defmacro with-perspective (_name &rest body)
    `(progn ,@body))
  (defun persp-new (name)
    (list :name name))
  (defun persp-name (persp)
    (plist-get persp :name))
  (defun persp-add-buffer (&rest _args))
  (defun persp-curr ())
  (defun persp-remove-buffer (&rest _args))
  (defun persp-switch (&rest _args))
  (defun persp-switch-to-buffer (&rest _args))
  (defun persp-make-variable-persp-local (&rest _args))
  (defun persp-kill (&rest _args))
  (defun persp-names ()
    nil)
  (provide 'perspective))

(load-file (expand-file-name "../perspective-project-bridge.el"
                             (file-name-directory
                              (or load-file-name buffer-file-name))))

(ert-deftest perspective-project-bridge-find-perspective-for-buffer-skips-nil-root ()
  "Return nil without creating a perspective when project root is nil."
  (let ((perspective-project-bridge-mode t)
        (perspective-project-bridge-persp nil))
    (with-temp-buffer
      (cl-letf (((symbol-function 'project-current)
                 (lambda (&rest _args)
                   'mock-project))
                ((symbol-function 'project-root)
                 (lambda (_project)
                   nil))
                ((symbol-function 'persp-new)
                 (lambda (&rest _args)
                   (ert-fail "persp-new should not be called when project root is nil"))))
        (should-not
         (perspective-project-bridge-find-perspective-for-buffer (current-buffer)))))))

(ert-deftest perspective-project-bridge-find-perspective-for-buffer-creates-perspective ()
  "Create and return a perspective when project root exists."
  (let ((perspective-project-bridge-mode t)
        (perspective-project-bridge-persp nil)
        (added-buffer nil))
    (with-temp-buffer
      (cl-letf (((symbol-function 'project-current)
                 (lambda (&rest _args)
                   'mock-project))
                ((symbol-function 'project-root)
                 (lambda (_project)
                   "/tmp/sample-project/"))
                ((symbol-function 'persp-new)
                 (lambda (name)
                   (list :name name)))
                ((symbol-function 'persp-name)
                 (lambda (persp)
                   (plist-get persp :name)))
                ((symbol-function 'persp-add-buffer)
                 (lambda (buffer)
                   (setq added-buffer buffer))))
        (let ((persp (perspective-project-bridge-find-perspective-for-buffer
                      (current-buffer))))
          (should (equal (plist-get persp :name) "sample-project"))
          (should (eq added-buffer (current-buffer)))
          (should perspective-project-bridge-persp))))))

(provide 'perspective-project-bridge-test)

;;; perspective-project-bridge-test.el ends here
