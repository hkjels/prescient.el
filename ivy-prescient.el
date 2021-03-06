;;; ivy-prescient.el --- Prescient sorting for Ivy. -*- lexical-binding: t -*-

;; Copyright (C) 2018 Radon Rosborough

;; Author: Radon Rosborough <radon.neon@gmail.com>
;; Homepage: https://github.com/raxod502/prescient.el
;; Keywords: extensions
;; Created: 7 Aug 2017
;; Package-Requires: ((emacs "25.1") (prescient "1.0") (ivy "0.10.0"))
;; Version: 1.0

;;; Commentary:

;; This package is under construction.

;;; Code:

;;;; Libraries

(eval-when-compile
  (require 'cl-macs))

(require 'ivy)
(require 'prescient)

;;;; Minor mode

(defun ivy-prescient-re-builder (query)
  "Generate an Ivy-formatted regexp list for the given QUERY string.
This is for use in `ivy-re-builders-alist'."
  (or
   (mapcar
    (lambda (regexp)
      (cons regexp t))
    (prescient-filter-regexps query))
   ;; For some reason, Ivy doesn't seem to like to be given an empty
   ;; list of regexps. Instead, it wants an empty string.
   ""))

(defvar ivy-prescient--old-re-builder nil
  "Previous default value in `ivy-re-builders-alist'.")

(defun ivy-prescient-advice-fix-sort-function (collection)
  "Retrieve sort function for COLLECTION from `ivy-sort-functions-alist'.
This is an `:override' advice for `ivy--sort-function' which
fixes what appears to be a bug whereby the default sort function
is not respected."
  (alist-get collection ivy-sort-functions-alist
             (alist-get t ivy-sort-functions-alist)))

(defun ivy-prescient-advice-sort-obarrays (ivy--sort-maybe collection)
  "Allow Ivy to sort collections that are given as obarrays.
This is an `:around' advice for `ivy--sort-maybe'."
  (cl-letf ((cl-sort-orig (symbol-function #'cl-sort))
            ((symbol-function #'cl-sort)
             (lambda (seq &rest args)
               (when (obarrayp seq)
                 (let ((lst nil))
                   (mapatoms
                    (lambda (sym)
                      (push sym lst))
                    seq)
                   (setq seq lst)))
               (apply cl-sort-orig seq args))))
    (funcall ivy--sort-maybe collection)))

(defalias 'ivy-prescient-sort-compare #'prescient-sort-compare
  "Comparison function that uses prescient.el to sort candidates.
This is for use in `ivy-sort-functions-alist'.")

(defvar ivy-prescient--old-ivy-sort-function nil
  "Previous default value in `ivy-sort-functions-alist'.")

(cl-defun ivy-prescient-read (ivy-read prompt collection &rest rest &key action caller
                                       &allow-other-keys)
  "Delegate to `ivy-read', recording information for `prescient-remember'.
This is an `:around' advice for `ivy-read'."
  (apply ivy-read prompt collection
         (append `(:action ,(lambda (result)
                              (prescient-remember result)
                              (when action
                                (funcall action result))))
                 rest)))

;;;###autoload
(define-minor-mode ivy-prescient-mode
  "Minor mode to use prescient.el in Ivy menus."
  :global t
  (if ivy-prescient-mode
      (progn
        (setq ivy-prescient--old-re-builder
              (alist-get t ivy-re-builders-alist))
        (setf (alist-get t ivy-re-builders-alist)
              #'ivy-prescient-re-builder)
        (setq ivy-prescient--old-ivy-sort-function
              (alist-get t ivy-sort-functions-alist))
        (setf (alist-get t ivy-sort-functions-alist)
              #'ivy-prescient-sort-compare)
        (advice-add #'ivy--sort-function :override
                    #'ivy-prescient-advice-fix-sort-function)
        (advice-add #'ivy--sort-maybe :around
                    #'ivy-prescient-advice-sort-obarrays)
        (advice-add #'ivy-read :around #'ivy-prescient-read))
    (when (equal (alist-get t ivy-re-builders-alist)
                 #'ivy-prescient-re-builder)
      (setf (alist-get t ivy-re-builders-alist)
            ivy-prescient--old-re-builder))
    (when (equal (alist-get t ivy-sort-functions-alist)
                 #'ivy-prescient-sort-compare)
      (setf (alist-get t ivy-sort-functions-alist)
            ivy-prescient--old-ivy-sort-function))
    (advice-remove #'ivy--sort-function #'ivy-prescient-advice-fix-sort-function)
    (advice-remove #'ivy--sort-maybe #'ivy-prescient-advice-sort-obarrays)
    (advice-remove #'ivy-read #'ivy-prescient-read)))

;;;; Closing remarks

(provide 'ivy-prescient)

;;; ivy-prescient.el ends here

;; Local Variables:
;; outline-regexp: ";;;;* "
;; End:
