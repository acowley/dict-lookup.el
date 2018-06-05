;;; dict-lookup.el --- Interface to the `dict` dictionary client

;; Copyright (C) 2014-2016 by Chunyang Xu
;; Copyright (C) 2018 Anthony Cowley

;; Author: Anthony Cowley <acowley@gmail.com>
;; Version: 1.0
;; Package-Requires ()
;; Keywords: dictionary
;; URL: https://github.com/acowley/dict-lookup

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Lookup words using the `dict` dictionary client and present the
;; results in an Emacs buffer.  Adapted from the `osx-dictionary`
;; package by Chunyang Xu.

;;; Code:
(require 'thingatpt)

(defcustom dict-lookup-dictionary "wn"
  "Dictionary to use (default: WordNet (i.e. `wn')).

 Run `dict -D' to see a list of dictionaries available on your system."
  :type 'string
  :group 'external)

(defvar dict-lookup--previous-window-configuration nil
  "Window configuration before switching to dictionary buffer.")

(defvar dict-lookup--mode-header-line
  '(
    (:propertize "s" face mode-line-buffer-id) ": Search Word"
    "    "
    (:propertize "q" face mode-line-buffer-id) ": Quit")
  "Header-line used for `dict-lookup-mode`.")

(defvar dict-lookup--mode-font-lock-keywords
  '(
      (;; (rx (seq line-start (* space) (group (or "n" "adj" "v" "adv"))
       ;;          (+ space) (+ (any digit)) ":"))
       "^[[:space:]]*\\(\\(?:ad[jv]\\|[nv]\\)\\)[[:space:]]+[[:digit:]]+:"
       1 font-lock-builtin-face)))

(defvar dict-lookup-mode-map
    (let ((map (make-sparse-keymap)))
      (define-key map "q" 'dict-lookup-quit)
      (define-key map "s" 'dict-lookup-search-input)
      map)
    "Keymap for `dict-lookup-mode'.")

(define-derived-mode dict-lookup-mode fundamental-mode "dict-lookup"
  "Major mode to look up word through dict.
\\{dict-lookup-mode-map}.
Turning on Text mode runs the normal hook `dict-lookup-mode-hook'."

  (setq header-line-format dict-lookup--mode-header-line)
  (setq font-lock-defaults '(dict-lookup--mode-font-lock-keywords)))

(add-hook 'dict-lookup-mode-hook #'read-only-mode)
(add-hook 'dict-lookup-mode-hook #'visual-line-mode)

(defun dict-lookup-quit ()
  "Quit dict viewer; reselect previously selected buffer."
  (interactive)
  (if (window-configuration-p dict-lookup--previous-window-configuration)
      (progn
        (set-window-configuration dict-lookup--previous-window-configuration)
        (setq dict-lookup--previous-window-configuration nil)
        (bury-buffer (get-buffer-create "dictionary lookup")))
    (bury-buffer)))

(defun dict-lookup--get-buffer ()
  "Get the dict-lookup buffer; create one if none exists."
  (let ((buffer (get-buffer-create "dictionary lookup")))
    (with-current-buffer buffer
      (unless (eq major-mode 'dict-lookup-mode)
        (dict-lookup-mode)))
    buffer))

(defun dict-lookup--goto-dictionary ()
  "Switch to the dict buffer in other window."
  (unless dict-lookup--previous-window-configuration
    (setq dict-lookup--previous-window-configuration (current-window-configuration)))
  ;; (setq dict-previous-window (get-buffer-window))
  (let* ((buffer (get-buffer-create "dictionary lookup"))
         (window (get-buffer-window buffer)))
    (if (null window)
        (switch-to-buffer-other-window buffer)
      (select-window window))))

(defun dict-lookup--region-or-word ()
  "Lookup a word in the region or at point if there is no region."
  (if (use-region-p)
      (buffer-substring-no-properties (region-beginning) (region-end))
    (word-at-point)))

(defun dict-lookup--search-word (word)
  "Search for WORD using the WordNet dictionary."
  (shell-command-to-string
   (format "dict -d %s %s" dict-lookup-dictionary (shell-quote-argument word))))

(defun dict-lookup--view-result (word)
  "Replace dictionary buffer's contents with the search results for WORD."
  (if word
      (with-current-buffer (dict-lookup--get-buffer)
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (dict-lookup--search-word word))
          (dict-lookup--goto-dictionary)
          (goto-char (point-min))
          (whitespace-cleanup)))
    (message "Nothing to look up")))

;;;###autoload
(defun dict-lookup-search-input ()
  "Search for a word given at an input prompt."
  (interactive)
  (let* ((default (dict-lookup--region-or-word))
         (prompt (if default
                     (format "Word (%s): " default)
                   "Word: "))
         (word (read-string prompt nil nil default)))
    (dict-lookup--view-result word)))

;;;###autoload
(defun dict-lookup-search-pointer ()
  "Lookup the highlighted word or the word at point."
  (interactive)
  (let ((word (dict-lookup--region-or-word)))
    (dict-lookup--view-result word)))

;;; dict-lookup.el ends here
