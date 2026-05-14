;;; org-sync-mode.el --- Automatically sync Org notes with Git -*- lexical-binding: t; -*-

;; Author: zauberen
;; Keywords: org, git, sync
;; Version: 0.1.0

;;; Commentary:
;; This package automatically commits and syncs Org-mode notes to a Git repository on save.
;; It includes debouncing to prevent commit spam.
;;
;; State (save counts and timers) is tracked per Git repo root, so multiple
;; org files in different repos are handled independently.

;;; Code:

(require 'org)

(defgroup org-sync-mode nil
  "Settings for org-sync-mode."
  :group 'org)

(defcustom org-sync-mode-wait-seconds 60
  "Number of seconds to wait after a save before committing."
  :type 'integer
  :group 'org-sync-mode)

(defcustom org-sync-mode-auto-push nil
  "If non-nil, automatically push after committing."
  :type 'boolean
  :group 'org-sync-mode)

(defcustom org-sync-mode-auto-pull nil
  "If non-nil, automatically pull before committing."
  :type 'boolean
  :group 'org-sync-mode)

(defcustom org-sync-mode-commit-message "Auto-sync Org notes"
  "Commit message to use for automatic commits."
  :type 'string
  :group 'org-sync-mode)

(defcustom org-sync-mode-save-threshold 5
  "Number of saves to trigger an immediate sync regardless of timer."
  :type 'integer
  :group 'org-sync-mode)

;; Per-repo state, keyed by repo root directory string.
(defvar org-sync-mode--save-counts (make-hash-table :test 'equal)
  "Hash table mapping repo root directories to save counts since last sync.")

(defvar org-sync-mode--timers (make-hash-table :test 'equal)
  "Hash table mapping repo root directories to their debounce timers.")

(defun org-sync-mode--git-run (dir &rest args)
  "Run git with ARGS in DIR.  Returns the exit code (integer)."
  (let ((default-directory dir))
    (apply #'call-process "git" nil nil nil args)))

(defun org-sync-mode--get-repo-root (dir)
  "Return the absolute git repo root for DIR, or nil if not in a git repo."
  (let ((default-directory dir))
    (with-temp-buffer
      (when (= 0 (call-process "git" nil t nil "rev-parse" "--show-toplevel"))
        (let ((root (string-trim (buffer-string))))
          (when (file-directory-p root)
            root))))))

(defun org-sync-mode--cancel-timer (repo-root)
  "Cancel any pending debounce timer for REPO-ROOT."
  (when-let ((timer (gethash repo-root org-sync-mode--timers)))
    (cancel-timer timer))
  (remhash repo-root org-sync-mode--timers))

(defun org-sync-mode-sync (repo-root)
  "Perform the git sync operations for the repo at REPO-ROOT.
Safe to call from a timer — the directory is explicit, not inferred
from the current buffer."
  (message "Org-sync-mode: Starting sync for %s..." repo-root)
  (puthash repo-root 0 org-sync-mode--save-counts)
  (when (= 0 (org-sync-mode--git-run repo-root "rev-parse" "--is-inside-work-tree"))
    (when org-sync-mode-auto-pull
      (if (= 0 (org-sync-mode--git-run repo-root "pull"))
          (message "Org-sync-mode: Pulled latest changes.")
        (message "Org-sync-mode: WARNING - git pull failed for %s." repo-root)))

    (org-sync-mode--git-run repo-root "add" ".")
    ;; Only commit if there are staged changes
    (if (not (= 0 (org-sync-mode--git-run repo-root "diff-index" "--quiet" "HEAD" "--")))
        (if (= 0 (org-sync-mode--git-run repo-root "commit" "-m" org-sync-mode-commit-message))
            (progn
              (message "Org-sync-mode: Committed changes.")
              (when org-sync-mode-auto-push
                (if (= 0 (org-sync-mode--git-run repo-root "push"))
                    (message "Org-sync-mode: Pushed changes.")
                  (message "Org-sync-mode: WARNING - git push failed for %s." repo-root))))
          (message "Org-sync-mode: WARNING - git commit failed for %s." repo-root))
      (message "Org-sync-mode: No changes to commit.")))
  (org-sync-mode--cancel-timer repo-root))

(defun org-sync-mode-after-save ()
  "Hook function called after saving a buffer.
Only acts on org-mode buffers that belong to a Git repository."
  (when (and (derived-mode-p 'org-mode) (buffer-file-name))
    (let* ((file-dir  (file-name-directory (buffer-file-name)))
           (repo-root (org-sync-mode--get-repo-root file-dir)))
      (when repo-root
        (let ((count (1+ (gethash repo-root org-sync-mode--save-counts 0))))
          (puthash repo-root count org-sync-mode--save-counts)
          (if (>= count org-sync-mode-save-threshold)
              ;; Threshold hit — sync immediately, cancelling any pending timer.
              (progn
                (org-sync-mode--cancel-timer repo-root)
                (org-sync-mode-sync repo-root))
            ;; Otherwise restart the debounce timer for this repo.
            (org-sync-mode--cancel-timer repo-root)
            (puthash repo-root
                     (run-with-timer org-sync-mode-wait-seconds nil
                                     #'org-sync-mode-sync repo-root)
                     org-sync-mode--timers)))))))

;;;###autoload
(define-minor-mode org-sync-mode
  "Minor mode to automatically sync Org notes with Git."
  :lighter " OrgSync"
  :global t
  (if org-sync-mode
      (add-hook 'after-save-hook #'org-sync-mode-after-save)
    (remove-hook 'after-save-hook #'org-sync-mode-after-save)
    ;; Cancel all pending timers and reset state on disable.
    (maphash (lambda (_root timer) (cancel-timer timer)) org-sync-mode--timers)
    (clrhash org-sync-mode--timers)
    (clrhash org-sync-mode--save-counts)))

(provide 'org-sync-mode)
;;; org-sync-mode.el ends here
