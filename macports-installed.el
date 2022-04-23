;;; macports-installed.el --- A porcelain for MacPorts -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Aaron Madlon-Kay

;; Author: Aaron Madlon-Kay
;; Version: 0.1.0
;; URL: https://github.com/amake/.emacs.d
;; Package-Requires: ((emacs "28.1"))

;;; Commentary:

;; A porcelain for MacPorts: major mode for managing installed ports

;;; Code:

(require 'macports-core)

;;;###autoload
(defun macports-installed ()
  "List installed ports."
  (interactive)
  (pop-to-buffer "*macports-installed*")
  (macports-installed-mode))

(defvar macports-installed-columns
  [("Port" 32 t)
   ("Version" 48 t)
   ("Active" 8 t)
   ("Requested" 10 t)
   ("Leaf" 8 t)]
  "Columns to be shown in `macports-installed-mode'.")

(defvar macports-installed-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "RET" #'macports-installed-describe-port)
    (keymap-set map "u" #'macports-installed-mark-uninstall)
    (keymap-set map "U" #'macports-installed-mark-inactive)
    (keymap-set map "l" #'macports-installed-mark-leaves)
    (keymap-set map "a" #'macports-installed-mark-toggle-activate)
    (keymap-set map "r" #'macports-installed-mark-toggle-requested)
    (keymap-set map "x" #'macports-installed-exec)
    (keymap-set map "DEL" #'macports-installed-backup-unmark)
    (keymap-set map "?" #'macports)
    map)
  "Keymap for `macports-installed-mode'.")

(defun macports-installed-describe-port ()
  "Show details about the current port."
  (interactive nil macports-installed-mode)
  (macports-describe-port (elt (tabulated-list-get-entry) 0)))

(defun macports-installed-mark-uninstall (&optional _num)
  "Mark a port for uninstall and move to the next line."
  (interactive "p" macports-installed-mode)
  (tabulated-list-put-tag "U" t))

(defun macports-installed-mark-toggle-activate (&optional _num)
  "Mark a port for activate/deactivate and move to the next line."
  (interactive "p" macports-installed-mode)
  (let ((active (macports-installed-item-active-p)))
    (cond ((and active (eq (char-after) ?D))
           (tabulated-list-put-tag " " t))
          ((and (not active) (eq (char-after) ?A))
           (tabulated-list-put-tag " " t))
          (active (tabulated-list-put-tag "D" t))
          ((not active) (tabulated-list-put-tag "A" t)))))

(defun macports-installed-item-active-p ()
  "Return non-nil if the current item is activated."
  (not (string-empty-p (elt (tabulated-list-get-entry) 2))))

(defun macports-installed-mark-inactive ()
  "Mark all inactive ports for uninstall."
  (interactive nil macports-installed-mode)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (if (macports-installed-item-active-p)
          (forward-line)
        (macports-installed-mark-uninstall)))))

(defun macports-installed-item-leaf-p ()
  "Return non-nil if the current item is a leaf."
  (not (string-empty-p (elt (tabulated-list-get-entry) 4))))

(defun macports-installed-mark-leaves ()
  "Mark all leaf ports for uninstall."
  (interactive nil macports-installed-mode)
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (if (macports-installed-item-leaf-p)
          (macports-installed-mark-uninstall)
        (forward-line)))))

(defun macports-installed-item-requested-p ()
  "Return non-nil if the current item is requested."
  (not (string-empty-p (elt (tabulated-list-get-entry) 3))))

(defun macports-installed-mark-toggle-requested (&optional _num)
  "Mark a port as requested/unrequested and move to the next line."
  (interactive "p" macports-installed-mode)
  (let ((requested (macports-installed-item-requested-p)))
    (cond ((and requested (eq (char-after) ?r))
           (tabulated-list-put-tag " " t))
          ((and (not requested) (eq (char-after) ?R))
           (tabulated-list-put-tag " " t))
          (requested (tabulated-list-put-tag "r" t))
          ((not requested) (tabulated-list-put-tag "R" t)))))

(defun macports-installed-backup-unmark ()
  "Back up one line and clear any marks on that port."
  (interactive nil macports-installed-mode)
  (forward-line -1)
  (tabulated-list-put-tag " "))

(defun macports-installed-exec ()
  "Perform marked actions."
  (interactive nil macports-installed-mode)
  (let (uninstall deactivate activate requested unrequested)
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (cond ((eq (char-after) ?U)
               (push (tabulated-list-get-entry) uninstall))
              ((eq (char-after) ?D)
               (push (tabulated-list-get-entry) deactivate))
              ((eq (char-after) ?A)
               (push (tabulated-list-get-entry) activate))
              ((eq (char-after) ?R)
               (push (tabulated-list-get-entry) requested))
              ((eq (char-after) ?r)
               (push (tabulated-list-get-entry) unrequested)))
        (forward-line)))
    (if (or uninstall deactivate activate requested unrequested)
        (when (macports-installed-prompt-transaction-p uninstall deactivate activate requested unrequested)
          (let ((uninstall-cmd (when uninstall
                                 (macports-privileged-command
                                  `("-q" "uninstall" ,@(macports-installed-list-to-args uninstall)))))
                (deactivate-cmd (when deactivate
                                  (macports-privileged-command
                                   `("-q" "deactivate" ,@(macports-installed-list-to-args deactivate)))))
                (activate-cmd (when activate
                                (macports-privileged-command
                                 `("-q" "activate" ,@(macports-installed-list-to-args activate)))))
                (requested-cmd (when requested
                                 (macports-privileged-command
                                  `("-q" "setrequested" ,@(macports-installed-list-to-args requested)))))
                (unrequested-cmd (when unrequested
                                   (macports-privileged-command
                                    `("-q" "unsetrequested" ,@(macports-installed-list-to-args unrequested))))))
            (macports-core--exec
             (string-join
              (remq nil (list uninstall-cmd deactivate-cmd activate-cmd requested-cmd unrequested-cmd))
              " && ")
             (macports-core--revert-buffer-func))))
      (user-error "No ports specified"))))

(defun macports-installed-prompt-transaction-p (uninstall deactivate activate requested unrequested)
  "Prompt the user about UNINSTALL, DEACTIVATE, ACTIVATE, REQUESTED, UNREQUESTED."
  (y-or-n-p
   (concat
    (when uninstall
      (format
       "Ports to uninstall: %s.  "
       (macports-installed-list-to-prompt uninstall)))
    (when deactivate
      (format
       "Ports to deactivate: %s.  "
       (macports-installed-list-to-prompt deactivate)))
    (when activate
      (format
       "Ports to activate: %s.  "
       (macports-installed-list-to-prompt activate)))
    (when requested
      (format
       "Ports to set as requested: %s.  "
       (macports-installed-list-to-prompt requested)))
    (when unrequested
      (format
       "Ports to set as unrequested: %s.  "
       (macports-installed-list-to-prompt unrequested)))
    "Proceed? ")))

(defun macports-installed-list-to-prompt (entries)
  "Format ENTRIES for prompting."
  (format "%d (%s)"
          (length entries)
          (mapconcat
           (lambda (entry) (concat (elt entry 0) (elt entry 1)))
           entries
           " ")))

(defun macports-installed-list-to-args (entries)
  "Format ENTRIES as command arguments."
  (apply #'nconc (mapcar
                  (lambda (entry) `(,(elt entry 0) ,(elt entry 1)))
                  entries)))

(define-derived-mode macports-installed-mode tabulated-list-mode "MacPorts installed"
  "Major mode for handling a list of installed MacPorts ports."
  (setq tabulated-list-format macports-installed-columns)
  (setq tabulated-list-padding 2)
  (setq tabulated-list-sort-key `("Port" . nil))
  (add-hook 'tabulated-list-revert-hook #'macports-installed-refresh nil t)
  (tabulated-list-init-header))

(defun macports-installed-refresh ()
  "Refresh the list of installed ports."
  (let ((installed (macports-installed--installed-items))
        (leaves (make-hash-table :test #'equal))
        (requested (make-hash-table :test #'equal)))
    (mapc (lambda (e) (puthash e t leaves))
          (macports-installed--leaf-items))
    (mapc (lambda (e) (puthash e t requested))
          (macports-installed--requested-items))
    (setq tabulated-list-entries
          (mapcar
           (lambda (e)
             (let ((name (nth 0 e))
                   (version (nth 1 e))
                   (active (nth 2 e)))
               (list
                (concat name version)
                (vector
                 name
                 version
                 (if active "Yes" "")
                 (if (gethash name requested) "Yes" "")
                 (if (gethash name leaves) "Yes" "")))))
           installed))))

(defun macports-installed--installed-items ()
  "Return linewise output of `port installed'."
  (let ((output (string-trim (shell-command-to-string "port -q installed"))))
    (mapcar
     (lambda (line) (split-string (string-trim line)))
     (split-string output "\n"))))

(defun macports-installed--leaf-items ()
  "Return linewise output of `port echo leaves'."
  (split-string (string-trim (shell-command-to-string "port -q echo leaves"))))

(defun macports-installed--requested-items ()
  "Return linewise output of `port echo requested'."
  (split-string (string-trim (shell-command-to-string "port -q echo requested"))))

(defun macports-installed--parse-installed (line)
  "Parse a LINE output by `macports--installed-lines'."
  (let ((fields (split-string line)))
    (list (nth 0 fields) (vector (nth 0 fields) (nth 1 fields) (if (nth 2 fields) "Yes" "")))))

(provide 'macports-installed)
;;; macports-installed.el ends here
