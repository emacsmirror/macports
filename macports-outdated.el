;;; macports-outdated.el --- A porcelain for MacPorts -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Aaron Madlon-Kay

;; Author: Aaron Madlon-Kay
;; Version: 0.1.0
;; URL: https://github.com/amake/.emacs.d
;; Package-Requires: ((emacs "28.1"))

;;; Commentary:

;; A porcelain for MacPorts: major mode for managing outdated ports

;;; Code:

(require 'macports-core)

;;;###autoload
(defun macports-outdated ()
  "List outdated ports."
  (interactive)
  (pop-to-buffer "*macports-outdated*")
  (macports-outdated-mode))

(defvar macports-outdated-columns
  [("Port" 32 t)
   ("Current" 16 t)
   ("Latest" 16 t)]
  "Columns to be shown in `macports-outdated-mode'.")

(defvar macports-outdated-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "u" #'macports-outdated-mark-upgrade)
    (define-key map "U" #'macports-outdated-mark-upgrades)
    (define-key map "x" #'macports-outdated-upgrade)
    (define-key map "\177" #'macports-installed-backup-unmark)
    (define-key map "?" #'macports)
    map)
  "Keymap for `macports-outdated-mode'.")

(defun macports-outdated-mark-upgrade (&optional _num)
  "Mark a port for upgrade and move to the next line."
  (interactive "p" macports-outdated-mode)
  (tabulated-list-put-tag "U" t))

(defun macports-outdated-mark-upgrades ()
  "Mark all ports for upgrade."
  (interactive nil macports-outdated-mode)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (macports-outdated-mark-upgrade))))

(defun macports-outdated-upgrade ()
  "Perform marked upgrades."
  (interactive nil macports-outdated-mode)
  (let (ports)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (cond ((eq (char-after) ?U)
               (push (tabulated-list-get-id) ports)))
        (forward-line)))
    (if ports
        (when (y-or-n-p
               (format "Ports to upgrade: %s.  Proceed? " (string-join ports " ")))
          (compilation-start (string-join `("sudo port upgrade" ,@ports) " ") t))
      (user-error "No ports specified"))))

(defun macports-outdated-backup-unmark ()
  "Back up one line and clear any marks on that port."
  (interactive nil macports-outdated-mode)
  (forward-line -1)
  (tabulated-list-put-tag " "))

(define-derived-mode macports-outdated-mode tabulated-list-mode "MacPorts outdated"
  "Major mode for handling a list of outdated MacPorts ports."
  (setq tabulated-list-format macports-outdated-columns)
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key `("Port" . nil))
  (add-hook 'tabulated-list-revert-hook #'macports-outdated-refresh nil t)
  (tabulated-list-init-header))

(defun macports-outdated-refresh ()
  "Refresh the list of outdated ports."
  (setq tabulated-list-entries
        (mapcar #'macports-outdated--parse-outdated (macports-outdated--outdated-lines))))

(defun macports-outdated--outdated-lines ()
  "Return linewise output of `port outdated'."
  (let ((output (string-trim (shell-command-to-string "port outdated"))))
    (cond ((string-prefix-p "No installed ports are outdated." output) nil)
          ((string-prefix-p "The following installed ports are outdated:" output)
           (cdr (split-string output "\n"))))))

(defun macports-outdated--parse-outdated (line)
  "Parse a LINE output by `macports--outdated-lines'."
  (let ((fields (split-string line)))
    (list (nth 0 fields) (vector (nth 0 fields) (nth 1 fields) (nth 3 fields)))))

(provide 'macports-outdated)
;;; macports-outdated.el ends here
