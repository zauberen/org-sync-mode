# org-sync-mode

An Emacs package to automatically sync Org-mode notes on save with smart debouncing and Git integration.

## Features
- **Auto-commit on save**: Triggers a git commit when Org files are saved.
- **Smart Debouncing**: Batches multiple saves within a short window into a single commit to prevent commit spam.
- **Auto Push/Pull**: Configurable options to automatically sync with remote repositories.
- **Configurable Thresholds**: Set the number of saves or the time window for syncing.

## Installation
*Coming soon.*

## Configuration
Example configuration:
```elisp
(setq org-sync-mode-auto-push t)
(setq org-sync-mode-auto-pull t)
(setq org-sync-mode-wait-seconds 60)
```
