


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
            (list :output output :value value))))))

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
     timeout)))


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
⊤
