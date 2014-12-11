;;;;
;;;; COPYRIGHT (C) PLANISWARE $Date$ 
;;;;
;;;; All Rights Reserved
;;;;
;;;; This program and the information contained herein are confidential to
;;;; and the property of PLANISWARE and are made available only to PLANISWARE
;;;; employees for the sole purpose of conducting PLANISWARE business.
;;;;
;;;; This program and copy therof and the information contained herein shall
;;;; be maintained in strictest confidence ; shall not be copied in whole or
;;;; in part except as authorized by the employee's manager ; and shall not
;;;; be disclosed or distributed (a) to persons who are not PLANISWARE employees,
;;;; or (b) to PLANISWARE employees for whom such information is not necessary in
;;;; connection with their assigned responsabilities.
;;;;
;;;; There shall be no exceptions to the terms and conditions set forth
;;;; herein except as authorized in writing by the responsible PLANISWARE General
;;;; Manager.

;;;;
;;;; FILE    : $RCSfile$
;;;;
;;;; AUTHOR  : $Author$
;;;;
;;;; VERSION : $Id$
;;;;
;;;; PURPOSE :
;;;;
;;;; (when (fboundp :set-source-info) (:set-source-info "$RCSfile$" :id "$Id$" :version "$Revision$" :date "$Date$ "))
;;;; (when (fboundp :doc-patch) (:doc-patch ""))
;;;; (when (fboundp :require-patch) (:require-patch ""))
;;;; HISTORY :
;;;; $Log$
;;;; Revision 3.3  2014/12/11 13:05:34  folli
;;;; in-package is mandatory
;;;;
;;;; Revision 3.2  2014/12/11 12:49:11  troche
;;;; * debug of opx2-redefine-function
;;;;
;;;; Revision 3.1  2011/07/21 15:16:46  folli
;;;; - (plw)CVS support in emacs
;;;; - New common files shared between xemacs & emacs
;;;;  (header added automatically)
;;;;
;; -*-no-byte-compile: t; -*-

(defun update-db (message)
" @PURPOSE Updates the database using message content
   It opens the database and sets the global var *current-db-string*
  @ARGUMENTS
    $message String that is the database name
  @RESULT Does not matter
  @NB Callback function in menu defintion"
  (let ((db-buffer (find-file (concat *opx2-network-folder-work-path* "/database.ini"))))
    (save-excursion 
      (beginning-of-buffer)
      (re-search-forward "\*intranet-database\*" nil t)
      (fi:beginning-of-defun)
      (down-list)
      (let ((start (progn (forward-sexp 2) (point)))
	    (end (progn (forward-sexp 1) (point))))
	(delete-region start end)
	(insert " \"")
	(insert message)
	(insert "\"")
	)
      (save-buffer)
      (setq *current-db-string* message)
      (set-menubar-dirty-flag))
    (kill-buffer db-buffer)))

(defun opx2-add-documentation ()
  ;; Usable with M-x, displaying 
  (interactive) 
  (save-excursion
    (let ((message (message "\n\" @PURPOSE\n  @ARGUMENTS\n")))
      (fi:beginning-of-defun)
      (down-list)
      (forward-sexp 2) ;; go after function name
      (let* ((start (point))
	     (end 
	      (progn (forward-sexp)
		    (point)))
	     (arg-list (car (read-from-string (buffer-substring start end))))
	   (mode  " "))
	(dolist (arg arg-list)
	  (case (type-of arg)
	    (symbol
	     (case arg
	       ('NIL
		)
	       (&key
		(setq mode " [key]"))
	       (&optional
		(setq mode " [optional]"))
	       (&rest
		(setq mode " [rest]"))
	       (&aux
		(return))
	       (otherwise
		(setq message (concat  message "    $"  (format "%S" arg) mode "\n")
		      ))))
	    (cons
	     (setq message (concat message "    $" (format "%S" (car arg)) mode "\n    [Default]" (format "%S" (second arg)) "\n")))))
	
	(setq message (concat message "  @RESULT\n  @NB\"\n" ))
	
      
	;; check that no string comes righet after function definition
	(let* ((start (point))
	       (end (save-excursion 
		      (forward-sexp)
		      (point))))
	  (unless (stringp (car (read-from-string (buffer-substring start end))))
	    (insert message)))))))

(defvar *sources-dir-cache* nil)

(defun get-sources-dir (full-path short-path)
  (or *sources-dir-cache*
      (setq *sources-dir-cache* (get-sources-subdir full-path short-path))))

(defun get-sources-subdir (full-path short-path)
  "computes strings that are relative paths to subdirectories
   of the dev root directory"
  (let ((res-lst nil))
    (dolist (file (directory-files full-path))
      (unless (or (equal file ".")
		  (equal file ".."))
	(let ((full-file-name (concat full-path
				      file
				      "/"))
	    (rel-file-name (concat  short-path
				   file
				   "/")))
	  (when (file-directory-p full-file-name)
	    (push rel-file-name res-lst)
	    (setq res-lst
		  (concatenate 'list 
			       (get-sources-subdir full-file-name rel-file-name)
			       res-lst))))))

    res-lst))


(defun opx2-create-test-template()
  "Creates a test template from an open buffer"
  (interactive)
  (let* ((template-path (concat *opx2-network-folder-work-path* "/devenv/test-template.lisp"))
	(patch-buffer (current-buffer))
	(patch-name (subseq (buffer-name patch-buffer) 0 (- (length (buffer-name patch-buffer)) 5)))
	(test-patch-name (concat *opx2-network-folder-work-path*
				 "/kernel/tests/dev/test-"
				 patch-name
				 ".lisp")))
    (cond ((file-exists-p test-patch-name)
	   ;; test fix exists do not replace
	   (find-file test-patch-name))
	  ((file-exists-p template-path)
	   (let ((template-buffer (find-file template-path)))
	     (when template-buffer
	       (setq template-buffer (write-file test-patch-name))
	       (beginning-of-buffer)
	       (while (re-search-forward "#scyourpatch#" nil t)
		 (replace-match patch-name nil nil)))))
	  (t ;; no template provided
	   ))))


(defun opx2-compare-redefinition()
  (interactive)
;;;; VERSION: sc3817.lisp 3.2
  (let ((function-name ""))
    ;; look for the VERSION tag 
    (when (save-excursion 
	    (re-search-backward   "[ /]\\([^ ]*.lisp\\)")
	    )
      
      (let* ((default-major-mode 'fi:common-lisp-mode)
	     (patch-name (match-string 1))
	     (old-buff (current-buffer))
	     (original-subbuff (get-buffer-create (format "CMP-original %s" patch-name)))
	     (redef-subbuff (get-buffer-create (format "CMP-redefinition %s" (buffer-name (current-buffer)))))
	     (paths-list (get-sources-dir (concat *opx2-network-folder-work-path* "/kernel/") "/kernel/"))) ;; look only into kernel dir
	;; search original source file that contains the redefined function
	(dolist (path-part paths-list)
	  (when (file-exists-p (concat *opx2-network-folder-work-path* path-part patch-name))
	    (setq original-file (concat *opx2-network-folder-work-path* path-part patch-name))))
	(if original-file
	    (progn 
	      ;;process redefinition
	      (save-excursion
		(let* ((end (progn (end-of-defun)(point)))	
		       (start (save-excursion (beginning-of-defun)(point)))
		       (redefined-body (buffer-substring start end)))
		  
		  
		  (with-current-buffer redef-subbuff
		    (normal-mode)
		    (insert-buffer-substring old-buff start end)
		    (set-window-buffer (selected-window) redef-subbuff))))
	      ;;process original function
	      
	      (let (start end f-name
			  (original-buffer (generate-new-buffer "*TMP-CMP*.lisp")))
		(save-excursion (fi:beginning-of-defun)
				(setq start (point))
				(if (re-search-forward "\\(.+\\)" nil t)
				    (progn 
				      (setq f-name (regexp-quote (match-string 1)))
				      )
				  (progn
				    (fi:beginning-of-defun)
				    (down-list)
				    (forward-sexp)
				    (setq start (point))
				    (forward-sexp)
				    (setq end (point))
				    (setq f-name  (concat "[ ]*?" (regexp-quote (buffer-substring start end)) "[ ]*?("))))

				)

		(with-current-buffer original-buffer
		  (insert-file-contents original-file)

		  (save-excursion 
		    (beginning-of-buffer)

		    (if (re-search-forward f-name  nil t)  
		      (let* ((start (save-excursion (fi:beginning-of-defun)(point)))
			     (end (save-excursion (end-of-defun)(point)))
			     (original-body (buffer-substring start end)))

			(with-current-buffer original-subbuff
			  (normal-mode)
			  (insert-buffer-substring original-buffer start end)
			  ))
		      (progn
			(kill-buffer original-subbuff)
			(kill-buffer redef-subbuff )
			(kill-buffer original-buffer)
			(message-box (format "Could not locate symbol %s in file %s " f-name patch-name))))))
		(kill-buffer original-buffer))
	      (with-current-buffer original-subbuff
		(font-lock-fontify-buffer))
	      (with-current-buffer redef-subbuff
		(font-lock-fontify-buffer))
	      (ediff-buffers original-subbuff redef-subbuff))
	  
	  (progn
	    ;;warn the user it sucked
	    (kill-buffer original-subbuff)
	    (kill-buffer redef-subbuff)
	    (message-box (format "Could not locate patch %s" patch-name))
	    ))))))
    
(defun opx2-redefine-function ()
  "Fetch (in-package) and $Id: from a cvs file"
  (interactive)
  (let* ((location (buffer-file-name (current-buffer)))
	done package version absolute-prefix-pos
	revision)
    
    
    ;;building relative location 
    ;Unix separator
    (dotimes (idx (length location))
      (when (eq (aref location idx)
		?\\)
	(aset location idx ?\/)))

    ;;find relatibe path using regexps
    (setq absolute-prefix-pos (string-match (concat ".*" (regexp-quote *opx2-network-folder-work-path*) "\\(.*\\)" ) location))
    (when absolute-prefix-pos
      (setq location (match-string 1 location)))
    
    (save-excursion
      ;;go back until we found a (in-package )
      (when (re-search-backward "^\\s-*(\\([a-zA-Z0-9:\"_\\-]*:\\)?in-package \\([^)\n]*\\)")
	(if (match-string 2)
	    (setq package (match-string 2))
	  (setq package (match-string 1))))

      ;;from the beginning look for a $Id: line
      (beginning-of-buffer)
      (when (re-search-forward "^;+\\s-*VERSION\\s-*:\\s-*\\$Id:\\s-*\\(.*\\),v\\s-*\\([0-9.]+\\)" nil t)
	(setq revision (match-string 2)
	      version (concat (match-string 1) " " (match-string 2)))))

    (let* ((end (save-excursion (end-of-defun) (point)))
	   (start (save-excursion
		    (fi:beginning-of-defun) (point))))
      (kill-new (concat "(in-package " package ")\n\n;;;; VERSION: " (if absolute-prefix-pos
									(concat location " " revision)
								       version)
			"\n;;Changed: \n" (buffer-substring start end))))))

(defun add-redefinition-shortcuts ()
  ;;Redefinition management
  (define-key fi:common-lisp-mode-map "\C-or" 'opx2-redefine-function)
  (define-key fi:common-lisp-mode-map "\C-od" 'opx2-add-documentation)
  (define-key fi:common-lisp-mode-map "\C-ov" 'opx2-compare-redefinition)
  (define-key fi:common-lisp-mode-map "\C-ot" 'opx2-create-test-template))

(add-hook 'fi:common-lisp-mode-hook 'add-redefinition-shortcuts)


(defvar *restricted-commit-directories* '("patches-dev" "patches"))

(defun is-a-restricted-directory (full-path)
  (block nil
    (dolist (rp *restricted-commit-directories*)
      (if (string= (substring full-path (max (- (length full-path) (length rp) 1) 0) (- (length full-path) 1)) rp)
	  (return t)))))

;;new
(defun find-doc-string-when-needed()
  (let ((ext (file-name-extension (file-name-nondirectory (buffer-file-name))))
	(ret nil)
	(case-fold-search t)) ;;case insensitive search
    (cond ((equal ext "lisp")
	   (save-excursion
	     (beginning-of-buffer)
	     (if (re-search-forward "^;+\\s-*DOC:?\\s-*\\(.*\\)" nil t)
		 (setq ret (list (match-string 1)))
	       (error "No doc string was found")))))
	     
    (unless ret	  
      (setq ret (list (read-string "Description:"))))
    ret))
