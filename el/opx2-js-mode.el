;;;; -*- coding: windows-1252 -*-
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
;;;; (:require-patch "")
;;;; HISTORY :
;;;; $Log$
;;;; Revision 3.23  2015/09/18 13:48:59  troche
;;;; * smarter control c point in js mode
;;;;
;;;; Revision 3.22  2015/09/17 14:38:24  troche
;;;; * remove messages
;;;;
;;;; Revision 3.21  2015/09/17 14:37:39  troche
;;;; * new function to check js syntax
;;;; * better ctrl+c . in js modes
;;;;
;;;; Revision 3.20  2015/07/20 16:41:40  mgautier
;;;; - lock file with the user using emacs
;;;;
;;;; Revision 3.19  2015/06/29 08:17:24  mgautier
;;;; - remove useless message
;;;;
;;;; Revision 3.18  2015/06/29 08:15:56  mgautier
;;;; - add functions to lock/unlock dataset from buffer
;;;; - C-cl -> lock
;;;; - C-cu -> unlock
;;;;
;;;; Revision 3.17  2015/06/15 08:44:16  troche
;;;; * new shortcut Ctrl-c+s to synchronize script in the database from
;;;;   emacs
;;;; * Checks that the file we are using to compile / synchronize is
;;;;   correct
;;;;
;;;; Revision 3.16  2015/06/02 12:59:38  mgautier
;;;; - bind \C_c c to %ojs-list-who-calls (find caller of function)
;;;;
;;;; Revision 3.15  2015/05/21 11:28:03  mgautier
;;;; - \C-c\C-b save ojs file and compile
;;;;
;;;; Revision 3.14  2015/05/21 07:09:05  mgautier
;;;; - my bad. \C-c\C-b to compile a whole ojs file
;;;;
;;;; Revision 3.13  2015/05/21 07:06:25  mgautier
;;;; - \C-c\C-c to compile a whole ojs
;;;;
;;;; Revision 3.12  2015/05/19 15:13:15  mgautier
;;;; - add comment/uncomment shortcut
;;;;
;;;; Revision 3.11  2015/04/20 12:20:00  troche
;;;; * OJS menu proprification
;;;;
;;;; Revision 3.10  2015/04/20 12:11:56  troche
;;;; * remove non international strings
;;;;
;;;; Revision 3.9  2015/04/16 08:46:08  troche
;;;; * don't add the closing } automatically
;;;;
;;;; Revision 3.8  2015/01/22 14:07:51  troche
;;;; * Display ojs compilation traces in a different window (request of C Lebaron)
;;;;
;;;; Revision 3.7  2015/01/15 09:53:55  troche
;;;; * C-c . improvement : Now manages ojs files and if definition is not found, try to do a regexp search
;;;;
;;;; Revision 3.6  2015/01/06 17:03:37  troche
;;;; * update of the opx2 javascript mode with (almost) intelligent syntax highlighting and completion
;;;; * update of the javascript evaluator, now you don't exit it if you have a lisp error
;;;;
;;;; Revision 3.5  2014/12/16 08:40:24  troche
;;;; * debug
;;;;
;;;; Revision 3.4  2014/12/15 18:10:00  troche
;;;; * OPX2 javascript menu in Emacs
;;;; * New functions to compile script
;;;;
;;;; Revision 3.3  2014/10/31 15:05:57  troche
;;;; * autocompletion for ojs files in emacs (requires sc8567 v3.12)
;;;; ** to use, add (defvar *use-opx2-js-mode* t) to your emacs conf file before loading the common configuration
;;;;
;;;; Revision 3.2  2014/10/28 12:57:56  troche
;;;; * New opx2 javascript emacs mode.
;;;; ** Add (defvar *use-opx2-js-mode* t) to your .emacs to use
;;;; * New opx2 javascript listener based on an emacs comint mode (still in testing).
;;;; ** Add (defvar *javascript-evaluator-mode* :comint) to your .emacs
;;;;  (header added automatically)
;;;;
;;; new emacs mode for opx2 javascript

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; syntax table
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'cc-mode)

(defvar opx2-js-mode-syntax-table
  (let ((table (make-syntax-table)))
    (c-populate-syntax-table table)
    ;; The syntax class of underscore should really be `symbol' ("_")
    ;; but that makes matching of tokens much more complex as e.g.
    ;; "\\<xyz\\>" matches part of e.g. "_xyz" and "xyz_abc". Defines
    ;; it as word constituent for now.
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?: "_" table)
    (modify-syntax-entry ?- "_" table)
    table)
  "Syntax table used in JavaScript mode.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; auto add closing }
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ojs-mode-insert-lcurly-on-ret ()
  (interactive)
  ;; do we have a { at the point ?
  (if (looking-back "{")
      (let ((pps (syntax-ppss)))
	(when (and (not (or (nth 3 pps) (nth 4 pps)))) ;; EOL and not in string or comment
	  (c-indent-line-or-region)
	  (insert "\n\n}")
	  (c-indent-line-or-region)
	  (forward-line -1)
	  (c-indent-line-or-region)))
    (newline-and-indent)))

(defun ojs-mode-insert-lcurly ()
  (interactive)
  (insert "{")
  (let ((pps (syntax-ppss)))
    (when (and (eolp) (not (or (nth 3 pps) (nth 4 pps)))) ;; EOL and not in string or comment
      (c-indent-line-or-region)
      (insert "\n\n}")
      (c-indent-line-or-region)
      (forward-line -1)
      (c-indent-line-or-region))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; menu and keyboard shortcuts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *ojs-mode-map* (make-sparse-keymap))

;; we don't want to stack definition declarations
(setq fi:maintain-definition-stack nil)

;; try to get a full symbol from the position given
(defun find-symbol-at-point (start end)
  ;; is the previous char a : ?
  (save-excursion
    (goto-char start)
    (backward-char)
    (when (looking-at ":")
      (while (and (not (or (looking-at "[ (]")
			   (looking-at "^")))
		  (> (point) (point-min)))
	(backward-char))
      (if (looking-at "^")
	  (setq start (point))
	(setq start (1+ (point))))))
  (buffer-substring-no-properties start end))
    
;; <ctrl-c .> in ojs file
;; works with ojs and lisp file and properly do the search
(defun %ojs-find-definition (tag)
  (interactive
   (if current-prefix-arg
       '(t)
     (list (car (fi::get-default-symbol "Lisp locate source" t t)))))
  (if (string-match ":" tag)
      (fi::lisp-find-definition-common tag nil)
    (fi::lisp-find-definition-common (concat "js::" tag) nil)))
  
(defun %ojs-list-who-calls (tag)
  (interactive
   (if current-prefix-arg
       '(nil)
     (list (car (fi::get-default-symbol "Lisp locate source" t t)))))
  (if (string-match ":" tag)
      (fi:list-who-calls tag nil)
    (fi:list-who-calls (concat "js::" tag) nil)))

(defvar *ojs-compilation-buffer-name* "*OJS compilation traces*")

(defun compile-ojs-file ()
  (interactive)
  (do-compile-and-sync-ojs-file :compile)
  )

(defun save-and-compile-ojs-file ()
  (interactive)
  (save-buffer)
  (compile-ojs-file)
  )

(defun save-compile-and-sync-ojs-file ()
  (interactive)
  (save-buffer)
  (do-compile-and-sync-ojs-file :compile-and-sync)
  )

(defun check-script-path (script-name file-name)
  ;; checks that the path of the current file matches the one in the database
  (when (fi::lep-open-connection-p) (fi:eval-in-lisp (format "(when (fboundp 'jvs::compare-javascript-source-file)(jvs::compare-javascript-source-file \"%s\" \"%s\"))" script-name file-name))))

(defun lock-status(script)
  (fi:eval-in-lisp (format "(jvs::lock-status \"%s\")" script-name)))

(defun do-lock-file (kind)
  ;; find the script name
  (let* ((script-name      (file-name-base (buffer-file-name)))
	 (status           (lock-status script-name))
	 (user             (user-login-name)))
    (case kind
      (:lock
       (cond ((string-equal status "NOT-LOCKED")
	      (fi:eval-in-lisp (format "(let ((archive::*current-user* \"%s\")) (jvs::lock-file-by-name \"%s\"))" user script-name))
	      (message "File locked"))
	     ((string-equal status "LOCKED-BY-YOURSELF")
	      (message "File already locked by yourself"))
	     ((stringp status)
	      (message "File locked by %s" status))
	     (t
	      (message "Err: Unable to lock file"))))
      (:unlock
       (cond ((string-equal status "LOCKED-BY-YOURSELF")
	      (fi:eval-in-lisp (format "(let ((archive::*current-user* \"%s\")) (jvs::unlock-file-by-name \"%s\"))" user script-name))
	      (message "File unlocked"))
	     ((string-equal status "NOT-LOCKED")
	      (message "File already unlocked"))
	     ((stringp status)
	      (message "File locked by %s" status))
	     (t
	      (message "Err: Unable to lock file")))))))

(defun lock-file()
  (interactive)
  (do-lock-file :lock))

(defun unlock-file()
  (interactive)
  (do-lock-file :unlock))

(defun check-ojs-region (beg end)
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (list (point-min) (point-max))))
  (let* ((selection (buffer-substring-no-properties beg end))
	 (buffer-name *ojs-compilation-buffer-name*)
	 (buffer (or (get-buffer buffer-name)
		     (get-buffer-create buffer-name)))
	 (proc (get-buffer-process buffer)))
    (unless proc
      (setq proc
	    (fi:open-lisp-listener
	     -1
	     *ojs-compilation-buffer-name*)))
    (set-process-filter proc 'ojs-compilation-filter)
    (process-send-string *ojs-compilation-buffer-name* (format "(javascript::check-js-syntax %S)\n" selection))))
	 

(defun do-compile-and-sync-ojs-file (type)
  ;; find the script name
  (let* ((script-name      (file-name-base (buffer-file-name)))
	 (script           (when (fi::lep-open-connection-p) (fi:eval-in-lisp (format "(when (fboundp 'jvs::find-script)(jvs::find-script \"%s\"))" script-name))))
	 (buffer-name *ojs-compilation-buffer-name*)
	 (buffer (or (get-buffer buffer-name)
		     (get-buffer-create buffer-name)))
	 (proc (get-buffer-process buffer))
	 )
    (if script
	(catch 'exit
	  ;; checks that the file matches
	  (unless (check-script-path script (buffer-file-name))
	    (message "Impossible to %s the script because the current file does not match script source file :
     Current file is                : %s
     Source file in the database is : %s"
		     (if (eq type :compile) "compile" "synchronize")
		     (buffer-file-name)
		     (fi:eval-in-lisp (format "(jvs::javascript-synchronize-with-file (object::get-object 'jvs::javascript \"%s\"))" script))
		     )
	    (throw 'exit nil))
	  ;; check that our file is commited
	  (when (and (eq type :compile-and-sync)
		     (equal (fi:eval-in-lisp (format "(jvs::javascript-local-file-up-to-date \"%s\")" script)) "LOCALLY-MODIFIED"))
	    (unless (y-or-n-p "File is not commited, do you really want to synchronize it in the database ?")
	      (throw 'exit nil)))
	  (save-buffer)
	  (switch-to-buffer-other-window buffer-name t)
	  ;; we erase previous content
	    (erase-buffer)
	    ;; run a new listener if needed
	    (unless proc
	      (setq proc
		    (fi:open-lisp-listener
		     -1
		     *ojs-compilation-buffer-name*)))
	    (set-process-filter proc 'ojs-compilation-filter)
	    (cond ((eq type :compile)
		   (process-send-string *ojs-compilation-buffer-name* (format "(:rjs \"%s\")\n" script))
		   )
		  ((eq type :compile-and-sync)
		   ;; check that the file is correct 		   
		   (process-send-string *ojs-compilation-buffer-name* (format "(:sjs \"%s\")\n" script))
		   ))
	    )
      (message "Script %s not found" script-name))))

(defun ojs-compilation-filter (proc string)
  (let ((case-fold-search nil))
    (cond ((and (stringp string)
		(string-match "\\`[[:upper:]-]+([0-9]+): \\'" string));; exit when we go back to the top level (ie :res, :pop, etc)
	   ;;(delete-process proc)
	   )
	  ((and (stringp string)
		(string-match ":EXIT-JS" string)) ;; exit when we read this, returned by the compilation functions
	   (fi::subprocess-filter proc (substring string 0 (string-match ":EXIT-JS" string)))
	   ;;(delete-process proc)
	   )	  
	  (t
	   (fi::subprocess-filter proc string)))))

(defun trace-ojs-function(tag)
  (interactive
   (if current-prefix-arg
       '(nil)
     (list (car (fi::get-default-symbol "Lisp (un)trace function" t t)))))
  (let ((js-symbol (concat "js::" tag)))
    (fi:toggle-trace-definition js-symbol)))

(defvar *ignore-pattern* "// NOINT")

;; find non international strings in buffer
(defun find-non-international-strings ()
  (interactive)

  ;; go to the beginning of the buffer
  ;; search all strings ie text between \"\"
  ;; filter out some strings : write_text_key/get_text_key, "OPXstuff", etc)
  ;; copy line number + line into a new buffer
  (save-excursion
    (goto-char 0)
    (let* ((match (re-search-forward "\".+\"" (point-max) t))
	   (i 0)
	   (filename (buffer-name))
	   (buffer-name "*Non international strings*")
	   (buffer (or (get-buffer buffer-name)
		       (get-buffer-create buffer-name)))
	   strings
	   )
      (while (and (< i 10000)
		  match)
	(setq i (1+ i))
	;;  we treat the whole line
	(let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
	  (unless (ignore-string line)
	    (push (format "\n%s : %s" (line-number-at-pos) line) strings)))
	(setq match (re-search-forward "\".+\"" (point-max) t)))
      
      ;; iterate through the found strings
      (switch-to-buffer-other-window buffer-name)
      (opx2-js-mode)
      (erase-buffer)
      
      (insert "// Non international strings for " filename)
      
      (insert (format "\n// %s strings found. If you want to ignore a line, add this at the end of it: %s\n" (length strings) *ignore-pattern*))
      
      (dolist (str (reverse strings))
	(insert str))
      (goto-char 0)
      )))

(defconst *functions-to-ignore*
  (regexp-opt
   '( "get"
      "hashtable"
      "instanceof"
      "color"
      "font"
      "matchregexp"
      "set"
      "sort"
      "callmacro"
      "fillroundrect"
      "searchchar"
      "serialize_a_field"
      "write_text_key"
      "get_text_key_message_string"
      )))

(defun ignore-string (str)
  ;; test if the string contained in the string is meant to be international
  ;; or is already internatioanlized
  ;; the str in argument is the whole line
  (or
   ;; no empty strings
   (string-match-p "\"\"" str)
   ;; no comments
   (string-match-p "[ \t]*//.*" str)  
   ;; no opxclassname
   (string-match-p "\"[Oo][Pp][Xx].*\"" str)
   ;; no "functionname".call()
   (string-match-p "\".+\".call(.*)" str)
   ;; no lispcall "functionname" ()
   (string-match-p "lispcall[ \t]*\".*\"" str)    
   ;; functions to ignore
   (string-match-p *functions-to-ignore* str)
;   (let (func-ignored)
;     (dolist (func *functions-to-ignore*)
;       (when (string-match-p (format "%s[ \t]*(.*\".*\".*)" func) str)
;	 (setq func-ignored t)))
;     func-ignored)
   ;; ignore line finishing by the ignore pattern // NOINT
   (string-match-p (format ".*%s" *ignore-pattern*) str)
   ;; ignore writeln("$Id
   (string-match-p "writeln(\"$Id.*\");" str)
   ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; new mode definition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;(define-derived-mode opx2-js-mode prog-mode "OPX2 javascript"
(define-derived-mode opx2-js-mode prog-mode "OPX2 javascript"
  :syntax-table opx2-js-mode-syntax-table

  ;; load a little bit of cc-mode for indentation
  (c-initialize-cc-mode t)
  (c-init-language-vars-for 'c-mode)
  (c-common-init 'c-mode)

  ;; set up syntax hightlighting
  (setup-ojs-syntax-highlighting)

  ;; custom keybindings from menu
  (define-key *ojs-mode-map* "\C-c." '%ojs-find-definition)
  (define-key *ojs-mode-map* "\C-cc" '%ojs-list-who-calls)
  (define-key *ojs-mode-map* "\C-ce" 'compile-ojs-file)
  (define-key *ojs-mode-map* "\C-cs" 'check-ojs-region)
  (define-key *ojs-mode-map* "\C-c\C-b" 'save-and-compile-ojs-file)
  (define-key *ojs-mode-map* "\C-cs" 'save-compile-and-sync-ojs-file)
  (define-key *ojs-mode-map* "\C-ct" 'trace-ojs-function)

  (define-key *ojs-mode-map* "\C-cl" 'lock-file)
  (define-key *ojs-mode-map* "\C-cu" 'unlock-file)

  ;; comment / un-comment
  (define-key *ojs-mode-map* "\C-c;" 'comment-region)
  (define-key *ojs-mode-map* "\C-c:" 'uncomment-region)

  ;; autoindentation on new line and add a closing } if needed
  (define-key *ojs-mode-map* (kbd "RET") 'newline-and-indent)
;;  (define-key *ojs-mode-map* (kbd "RET") 'ojs-mode-insert-lcurly-on-ret)
  ;; auto insert closing }
;;  (define-key *ojs-mode-map* (kbd "{") 'ojs-mode-insert-lcurly)
  
  ;; menu
  (easy-menu-define ojs-menu *ojs-mode-map* "OPX2 Javascript Menu"
    '("OPX2 Javascript"
      ["Compile and load file..." compile-ojs-file
       t]
      ["Check syntax of selected region" check-ojs-region
       t]	    
      ["Compile, load and synchronize file..." save-compile-and-sync-ojs-file
       t]
      ["Find function definition..." %ojs-find-definition
       t]
      ["Trace/Untrace function..." trace-ojs-function
       t]
      ))

  ;; custom keymap
  (use-local-map *ojs-mode-map*)  
  
  ;; rebuild  function and vars cache on save and when we open a file
  (add-hook 'after-save-hook 'ojs-reset-cache nil t)
  (add-hook 'find-file-hook 'ojs-reset-cache nil t)
)

;; kludge : in opx2 script, the first line sets the mode to C++, and we want to avoid that
;; so we call our function from the c++ mode hook
(defun override-c++-mode ()
  (when (equal (downcase (substring buffer-file-name -3 nil)) "ojs")
    (opx2-js-mode)))

(when *use-opx2-js-mode*
  (add-hook 'c++-mode-hook 'override-c++-mode))

;; replace for new files
(defun put-alist (item value alist)
  "Modify ALIST to set VALUE to ITEM.
If there is a pair whose car is ITEM, replace its cdr by VALUE.
If there is not such pair, create new pair (ITEM . VALUE) and
return new alist whose car is the new pair and cdr is ALIST.
\[tomo's ELIS like function]"
  (let ((pair (assoc item alist)))
    (if pair
	(progn
	  (setcdr pair value)
	  alist)
      (cons (cons item value) alist)
      )))