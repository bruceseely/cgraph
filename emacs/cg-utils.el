

;;  ;; Evaluating in Lisp
  ;;


;;; Comprehensive solution:

(defun eval-in-cl (form-string)
  "Evaluate FORM-STRING in Common Lisp and return the result as an Elisp value.
This function requires SLIME to be running and connected to a Lisp process."
  (unless (and (fboundp 'slime-connected-p) (slime-connected-p))
    (error "SLIME is not connected to a Common Lisp process"))

  (let ((result-string
         (slime-eval `(swank:eval-and-grab-output ,form-string))))
    ;; result-string is a list of (output-string result-string)
    (when result-string
      (let ((output (car result-string))
            (value (cadr result-string)))
        ;; You might want to parse the value string depending on your needs
        (if (string-empty-p output)
            value
            (list :output output :value value)))))
  )

;;; Alternative version that handles structured data better
(defun eval-in-cl-sexp (form)
  "Evaluate a Common Lisp FORM (as an s-expression) and return the result.
FORM should be a quoted s-expression that will be sent to CL."
  (unless (and (fboundp 'slime-connected-p) (slime-connected-p))
    (error "SLIME is not connected to a Common Lisp process"))

  (slime-eval form))

;;; Version that returns parsed Elisp data structures
(defun eval-in-cl-to-elisp (form-string)
  "Evaluate FORM-STRING in CL and attempt to parse the result as Elisp data.
Works best with simple data types (numbers, strings, lists, symbols)."
  (unless (and (fboundp 'slime-connected-p) (slime-connected-p))
    (error "SLIME is not connected to a Common Lisp process"))

  (let ((result
         (slime-eval
          `(cl:write-to-string
            (cl:progn ,@(read form-string))
            :readably t
            :escape t))))
    (condition-case nil
        (read result)
      (error result))))  ; If can't parse, return as string

;;; Synchronous evaluation with timeout
(defun eval-in-cl-sync (form-string &optional timeout)
  "Synchronously evaluate FORM-STRING in CL with optional TIMEOUT (in seconds).
Returns the result or signals an error if timeout occurs."
  (unless (and (fboundp 'slime-connected-p) (slime-connected-p))
    (error "SLIME is not connected to a Common Lisp process"))

  (let ((timeout (or timeout 10)))  ; Default 10 second timeout
    (slime-eval-with-transcript
     `(swank:eval-and-grab-output ,form-string)
     timeout))

  )


;;;  Here's also a more robust version that handles complex data exchange:
(defun cl-eval (form-string)
  "Evaluate Common Lisp form and intelligently return the result.
Handles multiple return values, output, and errors."
  (require 'slime)
  (unless (slime-connected-p)
    (error "No Common Lisp connection. Start SLIME first"))

  (condition-case err
      (let* ((wrapped-form
              (format "(cl:multiple-value-list (cl:progn %s))"
                      form-string))
             (result (slime-eval `(swank:eval-and-grab-output
                                   ,wrapped-form)))
             (output (car result))
             (values-string (cadr result))
             (values (ignore-errors (read values-string))))

        (cond
         ;; Single value, no output
         ((and (listp values)
               (= (length values) 1)
               (string-empty-p output))
          (car values))

         ;; Multiple values
         ((and (listp values) (> (length values) 1))
          `(:values ,values ,@(unless (string-empty-p output)
                                 `(:output ,output))))

         ;; Has output
         ((not (string-empty-p output))
          `(:value ,(car values) :output ,output))

         ;; Fallback
         (t values-string)))

    (error
     `(:error ,(error-message-string err)))))

;;; Helper function for common use case
(defun cl-eval-to-string (form-string)
  "Evaluate CL form and return result as a string."
  (let ((result (cl-eval form-string)))
    (if (stringp result)
        result
        (prin1-to-string result))))


;;; usage
;; Simple evaluation
;;(eval-in-cl "(+ 1 2 3)")
;; => "6"

;; Get structured data back
;;(eval-in-cl-to-elisp "(list 1 2 3)")
;; => (1 2 3)

;; Handle output and return values
;;(cl-eval "(progn (format t \"Hello\") (* 7 6))")
;; => (:value 42 :output "Hello")

;; Work with your CL session
;;(cl-eval "(defparameter *my-data* '(a b c))")
;;(cl-eval "*my-data*")
;; => (A B C)






(defun cl-funcall (function &rest args)
  "Call a Common Lisp function with arguments from Elisp."
  (let ((form (format "(%s %s)"
                      function
                      (mapconcat #'prin1-to-string args " "))))
    (cl-eval form)))

;; (cl-funcall '+ 4 8 7 34 9)


(defun rel-use (input-type output-type)
  "Relation types that are consistent with the supplied input and output concept types"
  (interactive "sinput-type: \nsoutput-type: ")
  (message "Input: %s, Output: %s" input-type output-type)
  (let* ((input-string (format "(cg-rel-use '%s '%s)" input-type output-type))
         (rels (cl-eval-to-string input-string)))
    (message "%s" rels)))

(defun unquote-string (str)
  "Remove matching quotes from STR, handling empty strings and edge cases."
  (let ((len (length str)))
    (if (and (>= len 2)
             (eq (aref str 0) (aref str (1- len)))
             (memq (aref str 0) '(?\" ?\')))
        (substring str 1 -1)
      str)))

(defun cg-normalize-cgraph-string ()
  (interactive)
  (let* ((start (cg-find-graph-start-pos))
         (end (cg-find-graph-end-pos))
         (text (buffer-substring-no-properties start end))
         (modified-text (cl-funcall 'normalize-cgraph-string text)))
    (message "modified-text: %s" modified-text)
    (replace-region-contents start
                             end
                             (lambda () (unquote-string modified-text)))))


;; keybinding
(global-set-key (kbd "C-M-'") 'cg-normalize-cgraph-string)



;; (defun cg-normalize-cgraph-string ()
;;   (interactive)
;;   (progn
;;     (setq start (cg-find-graph-start-pos))
;;     (setq end (cg-find-graph-end-pos))
;;     (setq text (buffer-substring-no-properties start end))
;;     (setq modified-text (cl-funcall 'normalize-cgraph-string text))
;;     (replace-region-contents start end
;;                              (lambda () modified-text))))



;;; Detect whether point is inside [...] (concept) or (...) (relation).
(defun cg--bracket-context-at-point ()
  "Return \"concept\" if point is inside [...], \"relation\" if inside (...), else nil."
  (save-excursion
    (skip-syntax-backward "w_")   ; move to start of word (skip-chars \"\\w\" is literal, not regex)
    (skip-chars-backward " \t")
    (let ((ch (char-before)))
      (cond ((eq ch ?\[) "concept")
            ((eq ch ?\() "relation")
            (t nil)))))

;;; Look up the symbol at point in the CG type catalogs and show info in minibuffer.
(defun cg-describe-type-at-point ()
  "Display concept-type or relation-type information for the symbol at point.
Uses bracket context ([...] vs (...)) to disambiguate when both a concept type
and a relation type share the same name."
  (interactive)
  (unless (and (fboundp 'slime-connected-p) (slime-connected-p))
    (user-error "SLIME is not connected"))
  (let* ((name (thing-at-point 'word t))
         (hint (cg--bracket-context-at-point)))
    (unless name
      (user-error "No symbol at point"))
    (let ((info (condition-case err
                    (slime-eval `(cg::cg-type-info-string ,name ,hint))
                  (error (message "CG lookup error: %s" err) nil))))
      (if info
          (message "%s" info)
        (message "No CG type found: %s" name)))))

(global-set-key (kbd "C-c ?") 'cg-describe-type-at-point)

;;; Unicode symbol insertion for CG type hierarchy
(global-set-key (kbd "C-c t") (lambda () (interactive) (insert "⊤")))
(global-set-key (kbd "C-c b") (lambda () (interactive) (insert "⊥")))


;; org-mode has C-c b bound to org-iswitchb, which was removed in newer org.
;; Define it as our ⊥ insertion command so the binding works correctly.
(unless (fboundp 'org-iswitchb)
  (defun org-iswitchb ()
    "Insert CG bottom type symbol ⊥ (replaces removed org-iswitchb)."
    (interactive)
    (insert "⊥")))

;;;;; approach 2
;; Define abbrevs that auto-expand
(define-abbrev global-abbrev-table "<-" "←")
(define-abbrev global-abbrev-table "->" "→")
(abbrev-mode 1)  ; Enable in current buffer
;;With this, typing <- followed by space or punctuation automatically converts to ←.


;;;;; (defun maybe-insert-arrow ()
;;;;;   "Convert <- or -> to arrow when appropriate."
;;;;;   (interactive)
;;;;;   (cond
;;;;;     ((looking-back "<-" 2)
;;;;;      (delete-char -2)
;;;;;      (insert "←"))
;;;;;     ((looking-back "->" 2)
;;;;;      (delete-char -2)
;;;;;      (insert "→"))
;;;;;     (t
;;;;;      (insert ">"))))
;;;;;
;;;;; ;; Bind to > key
;;;;;   (define-key lisp-mode-map (kbd ">") 'maybe-insert-arrow)




;;; CGraph customization options
;;;
;;; The sync machinery is system-agnostic and lives in clopt.el, in
;;; ~/repo/elisp-extensions (on load-path from dot-emacs) rather than here, so
;;; that other Lisp systems can use it without depending on cgraph.  This file
;;; only declares cgraph's own options.  To add one, write a single
;;; clopt-defcustom form below -- the Emacs/CL symbol pairing is registered
;;; from the form itself, so there is no second list to keep in step.
;;;
;;; Nothing here is required by the Lisp side: the options are ordinary
;;; DEFVARs in initializations.lisp, and cgraph runs unchanged with no Emacs
;;; and no SLIME.

(require 'clopt)

(defgroup cgraph nil
  "Options for the CGraph conceptual graphs system."
  :group 'tools)

(clopt-defcustom cgraph cgraph-always-format-nodes
    conceptual-graphs::*always-format-nodes* nil
  "Mirrors conceptual-graphs::*always-format-nodes* in Common Lisp."
  :type 'boolean
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-always-show-node-ref
    conceptual-graphs::*always-show-node-ref* nil
  "Mirrors conceptual-graphs::*always-show-node-ref* in Common Lisp."
  :type 'boolean
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-allow-dynamic-individual-creation
    conceptual-graphs::*allow-dynamic-individual-creation* nil
  "Mirrors conceptual-graphs::*allow-dynamic-individual-creation* in Common Lisp."
  :type 'boolean
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-always-print-ascii-arrows
    conceptual-graphs::*always-print-ascii-arrows* nil
  "Mirrors conceptual-graphs::*always-print-ascii-arrows* in Common Lisp."
  :type 'boolean
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-indent-graph-referents
    conceptual-graphs::*indent-graph-referents* nil
  "Mirrors conceptual-graphs::*indent-graph-referents* in Common Lisp."
  :type 'boolean
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-anaphora-cross-coref
    conceptual-graphs::*anaphora-cross-coref* nil
  "Mirrors conceptual-graphs::*anaphora-cross-coref* in Common Lisp.
When non-nil, generation treats coref'd concepts as the same referent
for pronoun selection - a second mention becomes 'he' instead of
repeating the proper noun. Off by default to avoid pronoun ambiguity
in nested mental-attitude contexts."
  :type 'boolean
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-run-tests-on-startup
    conceptual-graphs::*run-tests-on-startup* t
  "Mirrors conceptual-graphs::*run-tests-on-startup* in Common Lisp.
When non-nil, start-cgraph runs the test suite at startup. Useful
while making modifications; disable during regular use to skip the
test report."
  :type 'boolean
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-run-lexicon-lint-on-startup
    conceptual-graphs::*run-lexicon-lint-on-startup* :all
  "Mirrors conceptual-graphs::*run-lexicon-lint-on-startup* in Common Lisp.
Controls whether and how report-lexicon-lint runs at startup.
  Off                  - don't run.
  Errors only          - run, show only error-level findings (silent
                         unless something is broken).
  Errors and warnings  - run, show errors and warnings.
  All                  - run, show all findings.
Default is All. Use Errors only for regular use; switch to All while
modifying types or relations."
  :type '(choice (const :tag "Off"                   nil)
                 (const :tag "Errors only"           :errors-only)
                 (const :tag "Errors and warnings"   :errors-warnings)
                 (const :tag "All"                   :all))
  :group 'cgraph)

(clopt-defcustom cgraph cgraph-web-log-destination
    conceptual-graphs::*web-log-destination* :file
  "Mirrors conceptual-graphs::*web-log-destination* in Common Lisp.
Where the web server writes its access and message logs.
  Log file  - append to web-access.log / web-message.log under
              ~/.cgraph/logs/.  The default: the type editor makes a
              request per interaction, and each one would otherwise
              print a line to the REPL.
  REPL      - Hunchentoot's own default.  Useful while debugging a
              handler, when you want requests interleaved with your
              own output.
  Off       - no request logging at all.
Takes effect at start-web-server; call
conceptual-graphs::apply-web-log-destinations to change it on a
server that is already running."
  :type '(choice (const :tag "Log file" :file)
                 (const :tag "REPL"     :repl)
                 (const :tag "Off"      nil))
  :group 'cgraph)


;;; Kept as named entry points: initialize.lisp calls
;;; (cgraph-read-options-from-cl) through eval-in-emacs, and both are handy
;;; interactively.  They scope the generic functions to cgraph's options.

(defun cgraph-read-options-from-cl ()
  "Reconcile cgraph's options with the connected Lisp.  See `clopt-read-from-cl'."
  (interactive)
  (clopt-read-from-cl 'cgraph))

(defun cgraph-sync-options-to-cl ()
  "Push all Emacs cgraph option values to CL, overriding initializations.lisp."
  (interactive)
  (clopt-sync-to-cl 'cgraph))


(add-hook 'slime-connected-hook #'cgraph-read-options-from-cl)


(add-hook 'slime-repl-mode-hook 'goto-address-mode)


;;; probably belongs in Emacs init coder
;; Optional but recommended: open file:// URLs inside Emacs (find-file)
;; instead of handing them to the OS browser, which will route .md
;; files to whatever app is registered for them.
(with-eval-after-load 'browse-url
    (add-to-list 'browse-url-handlers
                 (cons "\\`file://" #'browse-url-emacs)))


;; (defun cg-open-md-in-typora (url &rest _)
;;   "Open a file:// URL pointing at a .md file in Typora via `open -a`."
;;   (let ((path (url-unhex-string
;;                (replace-regexp-in-string "\\`file://" "" url))))
;;     (call-process "open" nil 0 nil "-a" "Typora" path)))

(defun cg-open-md-in-typora (url &rest _)
  "Open URL (file:// .md) in Typora on macOS; fall back to find-file."
  (let* ((path (url-unhex-string
                (replace-regexp-in-string "\\`file://" "" url)))
         (opened (and (eq system-type 'darwin)
                      (zerop (call-process "open" nil nil nil
                                           "-a" "Typora" path)))))
    (unless opened
      (find-file path))))

(with-eval-after-load 'browse-url
  (add-to-list 'browse-url-handlers
               (cons "\\`file://.*\\.md\\'" #'cg-open-md-in-typora)))



;; cg-utils.el is loaded after SLIME's REPL buffer already exists,
;; so the hook above won't fire for it. Enable the mode on any REPL
;; that's already open when this file is loaded.
(dolist (buf (buffer-list))
  (with-current-buffer buf
    (when (derived-mode-p 'slime-repl-mode)
      (goto-address-mode 1))))




;;(filesets-init)
;;(filesets-reset-fileset)
;; (setq filesets-data '(("CGraph Definition"
;;                        (:file "~/repo/cgraph/cgraph.asd" ))
;;                       ("CGraph Types"
;;                        (:pattern "~/.cgraph/types/"     "^.+\\.lisp$"))
;;                       ("CGraph Code"
;;                        (:tree "~/repo/cgraph/system/" "^.+\\.lisp$"))))
;; (setq filesets-cache-save-often-flag t)
;; (setq filesets-sort-case-sensitive-flag nil)
;; (setq filesets-sort-menu-flag nil)
;; (setq filesets-menu-path nil)
;; (setq filesets-menu-before "Edit")
;; (setq filesets-menu-name "Filesets")
;; ;;(setq filesets-menu-cache-file "~/.emacs.d/filesets-cache.el")
;; (setq filesets-menu-cache-file "~/.cgraph/filesets-cache.el")
