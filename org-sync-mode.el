     1|;;; org-sync-mode.el --- Automatically sync Org notes with Git -*- lexical-binding: t; -*-
     2|
     3|;; Author: zauberen
     4|;; Keywords: org, git, sync
     5|;; Version: 0.1.0
     6|
     7|;;; Commentary:
     8|;; This package automatically commits and syncs Org-mode notes to a Git repository on save.
     9|;; It includes debouncing to prevent commit spam.
    10|
    11|;;; Code:
    12|
    13|(require 'org)
    14|
    15|(defgroup org-sync-mode nil
    16|  "Settings for org-sync-mode."
    17|  :group 'org)
    18|
    19|(defcustom org-sync-mode-wait-seconds 60
    20|  "Number of seconds to wait after a save before committing."
    21|  :type 'integer
    22|  :group 'org-sync-mode)
    23|
    24|(defcustom org-sync-mode-auto-push nil
    25|  "If non-nil, automatically push after committing."
    26|  :type 'boolean
    27|  :group 'org-sync-mode)
    28|
    29|(defcustom org-sync-mode-auto-pull nil
    30|  "If non-nil, automatically pull before committing."
    31|  :type 'boolean
    32|  :group 'org-sync-mode)
    33|
    34|(defcustom org-sync-mode-commit-message "Auto-sync Org notes"
    35|  "Commit message to use for automatic commits."
    36|  :type 'string
    37|  :group 'org-sync-mode)
    38|
    39|(defcustom org-sync-mode-save-threshold 5
    40|  "Number of saves to trigger an immediate sync regardless of timer."
    41|  :type 'integer
    42|  :group 'org-sync-mode)
    43|
    44|(defvar org-sync-mode--save-count 0
    45|  "Internal counter for saves since last sync.")
    46|
    47|(defvar org-sync-mode--timer nil
    48|  "Timer used for debouncing sync operations.")
    49|
    50|(defun org-sync-mode--git-run (&rest args)
    51|  "Run git with ARGS in the current buffer's directory."
    52|  (let ((default-directory (or (file-name-directory (buffer-file-name)) default-directory)))
    53|    (apply #'call-process "git" nil nil nil args)))
    54|
    55|(defun org-sync-mode-sync ()
    56|  "Perform the actual git sync operations."
    57|  (message "Org-sync-mode: Starting sync...")
    58|  (setq org-sync-mode--save-count 0)
    59|  (when (org-sync-mode--git-run "rev-parse" "--is-inside-work-tree")
    60|    (when org-sync-mode-auto-pull
    61|      (org-sync-mode--git-run "pull"))
    62|    
    63|    (org-sync-mode--git-run "add" ".")
    64|    ;; Only commit if there are changes
    65|    (if (not (= 0 (org-sync-mode--git-run "diff-index" "--quiet" "HEAD" "--")))
    66|        (progn
    67|          (org-sync-mode--git-run "commit" "-m" org-sync-mode-commit-message)
    68|          (message "Org-sync-mode: Committed changes.")
    69|          (when org-sync-mode-auto-push
    70|            (org-sync-mode--git-run "push")
    71|            (message "Org-sync-mode: Pushed changes.")))
    72|      (message "Org-sync-mode: No changes to commit.")))
    73|  (when org-sync-mode--timer
    74|    (cancel-timer org-sync-mode--timer))
    75|  (setq org-sync-mode--timer nil))
    76|
    77|(defun org-sync-mode-after-save ()
    78|  "Function to be called after saving an org file."
    79|  (when (derived-mode-p 'org-mode)
    80|    (setq org-sync-mode--save-count (1+ org-sync-mode--save-count))
    81|    (if (>= org-sync-mode--save-count org-sync-mode-save-threshold)
    82|        (org-sync-mode-sync)
    83|      (when org-sync-mode--timer
    84|        (cancel-timer org-sync-mode--timer))
    85|      (setq org-sync-mode--timer
    86|            (run-with-timer org-sync-mode-wait-seconds nil #'org-sync-mode-sync)))))
    87|
    88|;;;###autoload
    89|(define-minor-mode org-sync-mode
    90|  "Minor mode to automatically sync Org notes with Git."
    91|  :lighter " OrgSync"
    92|  :global t
    93|  (if org-sync-mode
    94|      (add-hook 'after-save-hook #'org-sync-mode-after-save)
    95|    (remove-hook 'after-save-hook #'org-sync-mode-after-save)
    96|    (when org-sync-mode--timer
    97|      (cancel-timer org-sync-mode--timer)
    98|      (setq org-sync-mode--timer nil))))
    99|
   100|(provide 'org-sync-mode)
   101|;;; org-sync-mode.el ends here
   102|