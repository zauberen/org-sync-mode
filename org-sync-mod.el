;;; org-sync-mod.el --- Automatically sync Org notes with Git -*- lexical-binding: t; -*-

;; Author: zauberen
;; Keywords: org, git, sync
;; Version: 0.1.0

;;; Commentary:
;; This package automatically commits and syncs Org-mode notes to a Git repository on save.
;; It includes debouncing to prevent commit spam.

;;; Code:

(require 'org)

(defgroup org-sync-mod nil
  "Settings for org-sync-mod."
  :group 'org)

(defcustom org-sync-mod-wait-seconds 60
  "Number of seconds to wait after a save before committing."
  :type 'integer
  :group 'org-sync-mod)

(defcustom org-sync-mod-auto-push nil
  "If non-nil, automatically push after committing."
  :type 'boolean
  :group 'org-sync-mod)

(defcustom org-sync-mod-auto-pull nil
  "If non-nil, automatically pull before committing."
  :type 'boolean
  :group 'org-sync-mod)

(defcustom org-sync-mod-commit-message "Auto-sync Org notes"
  "Commit message to use for automatic commits."
  :type 'string
  :group 'org-sync-mod)

(defcustom org-sync-mod-save-threshold 5
  "Number of saves to trigger an immediate sync regardless of timer."
  :type 'integer
  :group 'org-sync-mod)

(defvar org-sync-mod--save-count 0
  "Internal counter for saves since last sync.")

(defvar org-sync-mod--timer nil
  "Timer used for debouncing sync operations.")

(defun org-sync-mod--git-run (&rest args)
  "Run git with ARGS in the current buffer's directory."
  (let ((default-directory (or (file-name-directory (buffer-file-name)) default-directory)))
    (apply #'call-process "git" nil nil nil args)))

(defun org-sync-mod-sync ()
  "Perform the actual git sync operations."
  (message "Org-sync-mod: Starting sync...")
  (setq org-sync-mod--save-count 0)
  (when (org-sync-mod--git-run "rev-parse" "--is-inside-work-tree")
    (when org-sync-mod-auto-pull
      (org-sync-mod--git-run "pull"))
    
    (org-sync-mod--git-run "add" ".")
    ;; Only commit if there are changes
    (if (not (= 0 (org-sync-mod--git-run "diff-index" "--quiet" "HEAD" "--")))
        (progn
          (org-sync-mod--git-run "commit" "-m" org-sync-mod-commit-message)
          (message "Org-sync-mod: Committed changes.")
          (when org-sync-mod-auto-push
            (org-sync-mod--git-run "push")
            (message "Org-sync-mod: Pushed changes.")))
      (message "Org-sync-mod: No changes to commit.")))
  (when org-sync-mod--timer
    (cancel-timer org-sync-mod--timer))
  (setq org-sync-mod--timer nil))

(defun org-sync-mod-after-save ()
  "Function to be called after saving an org file."
  (when (derived-mode-p 'org-mode)
    (setq org-sync-mod--save-count (1+ org-sync-mod--save-count))
    (if (>= org-sync-mod--save-count org-sync-mod-save-threshold)
        (org-sync-mod-sync)
      (when org-sync-mod--timer
        (cancel-timer org-sync-mod--timer))
      (setq org-sync-mod--timer
            (run-with-timer org-sync-mod-wait-seconds nil #'org-sync-mod-sync)))))

;;;###autoload
(define-minor-mode org-sync-mod
  "Minor mode to automatically sync Org notes with Git."
  :lighter " OrgSync"
  :global t
  (if org-sync-mod
      (add-hook 'after-save-hook #'org-sync-mod-after-save)
    (remove-hook 'after-save-hook #'org-sync-mod-after-save)
    (when org-sync-mod--timer
      (cancel-timer org-sync-mod--timer)
      (setq org-sync-mod--timer nil))))

(provide 'org-sync-mod)
;;; org-sync-mod.el ends here
