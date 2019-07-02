;;; helm-chrome-history.el --- Browse Chrome History with Helm  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Xu Chunyang

;; Author: Xu Chunyang <mail@xuchunyang.me>
;; Homepage: https://github.com/xuchunyang/helm-chrome-history.el
;; Package-Requires: ((emacs "25.1") (helm-core "3.0"))
;; Keywords: tools
;; Version: 0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Browse Chrome History with Helm.

;;; Code:

(require 'helm)
(require 'seq)

(eval-when-compile
  (require 'subr-x)
  (require 'url-parse))

(defvar helm-chrome-history-file
  (seq-find
   #'file-exists-p
   `("~/Library/Application Support/Google/Chrome/Profile 1/History"
     ;; The following are based on `helm-chrome-file'
     "~/Library/Application Support/Google/Chrome/Default/History"
     "~/AppData/Local/Google/Chrome/User Data/Default/History"
     "~/.config/google-chrome/Default/History"
     "~/.config/chromium/Default/History"
     ,(substitute-in-file-name
       "$LOCALAPPDATA/Google/Chrome/User Data/Default/History")
     ,(substitute-in-file-name
       "$USERPROFILE/Local Settings/Application Data/Google/Chrome/User Data/Default/History")))
  "Chrome history SQLite database file.")

(defun helm-chrome-history-file-read ()
  (pcase helm-chrome-history-file
    ('nil (user-error "`helm-chrome-history-file' is not set"))
    ((pred file-exists-p) nil)
    (f (user-error "'%s' doesn't exist, please reset `helm-chrome-history-file'" f)))
  (with-temp-buffer
    (let ((tmp (make-temp-name "helm-chrome-history")))
      (copy-file helm-chrome-history-file tmp)
      (if (zerop
           (call-process "sqlite3" nil t nil
                         "-ascii"
                         tmp
                         "select url, title, last_visit_time from urls"))
          (let (result)
            (goto-char (point-min))
            ;; -ascii delimited by 0x1F and 0x1E
            (while (re-search-forward (rx (group (+? anything)) "\x1e") nil t)
              (push (split-string (match-string 1) "\x1f") result))
            (delete-file tmp)
            (nreverse result))
        (error "Command sqlite3 failed: %s" (buffer-string))))))

(defvar helm-chrome-history-candidates nil
  "The `helm-chrome-history' cache.")

(defun helm-chrome-history-candidates ()
  (unless helm-chrome-history-candidates
    (message "[helm-chrome-history] Building cache...")
    (setq helm-chrome-history-candidates
          (mapcar
           (pcase-lambda (`(,url ,title ,last-visit-time))
             (let ((display
                    (format "%s %s %s"
                            (format-time-string
                             "%Y-%m-%d"
                             (- (/ (string-to-number last-visit-time) 1000000)
                                ;; https://stackoverflow.com/a/26233663/2999892
                                11644473600))
                            title
                            (if-let ((host (url-host (url-generic-parse-url url))))
                                (propertize host 'face 'italic)
                              "")))
                   (real url))
               (cons display real)))
           (helm-chrome-history-file-read))))
  helm-chrome-history-candidates)

(defvar helm-chrome-history-action
  (helm-make-actions
   "Browse Url"
   (lambda (candidate)
     (browse-url candidate))
   "Copy Url"
   (lambda (url)
     (kill-new url)
     (message "`%s' copied to kill-ring" url))))

(defvar helm-chrome-history-source
  (helm-build-sync-source "Chrome History"
    :candidates #'helm-chrome-history-candidates
    :action helm-chrome-history-action))

;;;###autoload
(defun helm-chrome-history-clear-cache ()
  "Clear `helm-chrome-history' cache."
  (interactive)
  (setq helm-chrome-history-candidates nil))

;;;###autoload
(defun helm-chrome-history ()
  "Brwose Chrome History with helm."
  (interactive)
  (helm :sources helm-chrome-history-source
        :buffer "*Helm Chrome History*"))

(provide 'helm-chrome-history)
;;; helm-chrome-history.el ends here
