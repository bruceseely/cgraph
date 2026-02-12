;;; cg-mode.el --- Major mode for editing Conceptual Graphs -*- lexical-binding: t -*-

;; Copyright (C) 2025
;; Author: Bruce Seely

;;;; Issues
;; indention after "-" is wrong
;; "," is ignored


;;; m-x eval-buffer
;;; Commentary:

;; A major mode for editing Conceptual Graphs with intelligent indentation
;; that handles concepts [...], relations (...), and various arrow types
;; (→, ←, and continuation -).


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Variables

(defgroup cg-mode nil
  "Major mode for editing conceptual graphs."
  :group 'languages)

(defcustom cg-indent-offset 4
  "Number of spaces for each indentation level."
  :type 'integer
  :group 'cg-mode)

(defvar cg-mode-syntax-table
  (let ((st (make-syntax-table)))
    ;; Set up bracket pairs
    (modify-syntax-entry ?\[ "(]" st)  ; [ is open paren matching ]
    (modify-syntax-entry ?\] ")[" st)  ; ] is close paren matching [
    (modify-syntax-entry ?\( "()" st)  ; ( is open paren matching )
    (modify-syntax-entry ?\) ")(" st)  ; ) is close paren matching (

    ;; Comments (using ; like Lisp)
    (modify-syntax-entry ?\; "<" st)   ; ; starts comment
    (modify-syntax-entry ?\n ">" st)   ; newline ends comment

    ;; Strings
    (modify-syntax-entry ?\" "\"" st)  ; " is string delimiter

    st)
  "Syntax table for CG mode.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Helper Functions - Line Analysis

;; (defun cg-previous-line-indent ()
;;   "Get indentation of previous non-empty line."
;;   (save-excursion
;;     (forward-line -1)
;;     ;; Skip empty lines
;;     (while (and (not (bobp))
;;                 (looking-at "^[ \t]*$"))
;;       (forward-line -1))
;;     (current-indentation)))


(defun cg-previous-line-indent ()
  "Get indentation of previous non-empty line."
  (save-excursion
    (forward-line -1)
    ;; Skip empty lines
    (while (and (not (bobp))
                (looking-at "^[ \t]*$"))
      (forward-line -1))
    ;; Force recalculation of indentation
    (back-to-indentation)
    (current-column)))




(defun cg-previous-line-is-concept-p ()
  "Check if previous line contains a concept."
  (save-excursion
    (forward-line -1)
    (looking-at ".*\\[.*\\][ \t]*$")))

(defun cg-previous-line-ends-with-arrow-p ()
  "Check if previous line ends with any arrow type: ->, <-, or -"
  (save-excursion
    (forward-line -1)
    (or (looking-at ".*->[ \t]*\\(\\[.*\\]\\)?[ \t]*$")
        (looking-at ".*<-[ \t]*\\(\\[.*\\]\\)?[ \t]*$")
        (looking-at ".*-[ \t]*$"))))  ; Multi-relation connector

(defun cg-previous-line-ends-graph-p ()
  "Check if the previous non-blank line ends a graph (ends with period)."
  (save-excursion
    (forward-line -1)
    ;; Skip empty lines
    (while (and (not (bobp))
                (looking-at "^[ \t]*$"))
      (forward-line -1))
    (looking-at ".*\\.[ \t]*$")))

(defun cg-line-ends-with-continuation-p ()
  "Check if line ends with - (continuation for multiple relations)."
  (save-excursion
    (end-of-line)
    (looking-back "-[ \t]*" (line-beginning-position))))

(defun cg-at-closing-bracket-p ()
  "Check if current line starts with a closing bracket."
  (save-excursion
    (beginning-of-line)
    (looking-at "[ \t]*\\]")))

(defun cg-current-line-starts-with-relation-p ()
  "Check if current line starts with a relation."
  (save-excursion
    (beginning-of-line)
    (looking-at "[ \t]*(.*)")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Helper Functions - Context Detection

(defun cg-inside-multiline-concept-p ()
  "Check if point is inside a multi-line concept."
  (save-excursion
    (let ((open-count 0)
          (close-count 0)
          (limit (point)))
      ;; Count backwards from current position
      (goto-char (point-min))
      (while (< (point) limit)
        (cond
         ((looking-at "\\[")
          (setq open-count (1+ open-count))
          (forward-char))
         ((looking-at "\\]")
          (setq close-count (1+ close-count))
          (forward-char))
         (t (forward-char))))
      (> open-count close-count))))

(defun cg-in-multi-relation-context-p ()
  "Check if we're in a multi-relation context (after concept-)."
  (save-excursion
    (let ((found-continuation nil))
      (while (and (not (bobp))
                  (not found-continuation)
                  ;; Stop if we hit another concept
                  (not (and (looking-at ".*\\[.*\\][ \t]*$")
                           (not (looking-at ".*->[ \t]*\\[.*\\]"))
                           (not (looking-at ".*<-[ \t]*\\[.*\\]")))))
        (forward-line -1)
        ;; Look for [Concept]- or [Concept: x]-
        (when (looking-at ".*\\]-[ \t]*$")
          (setq found-continuation t)))
      found-continuation)))

(defun cg-count-brackets-on-line ()
  "Count [ minus ] on current line."
  (save-excursion
    (beginning-of-line)
    (let ((open 0) (close 0))
      (while (re-search-forward "\\[" (line-end-position) t)
        (setq open (1+ open)))
      (beginning-of-line)
      (while (re-search-forward "\\]" (line-end-position) t)
        (setq close (1+ close)))
      (- open close))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Arrow Functions

(defun cg-get-arrow-info ()
  "Get information about arrows on current line.
Returns a list of (ARROW-TYPE COLUMN POSITION) for each arrow."
  (save-excursion
    (beginning-of-line)
    (let ((arrows '())
          (end (line-end-position)))
      ;; Find all arrows on the line
      (while (re-search-forward "\\(->\\|<-\\|-\\)[ \t]*" end t)
        (let ((arrow-type (match-string 1))
              (col (- (current-column) (length (match-string 1))))
              (pos (match-beginning 1)))
          ;; Check if standalone - (not part of -> or <-)
          (when (or (not (string= arrow-type "-"))
                   (and (not (looking-back "->" pos))
                        (not (looking-back "<-" pos))
                        (looking-at "[ \t]*$")))
            (push (list arrow-type col pos) arrows))))
      (nreverse arrows))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Indentation Calculation Functions

(defun cg-multiline-concept-indent ()
  "Calculate indentation inside a multi-line concept.
   Example: [Person:
               name: John
               age: 30]"
  (save-excursion
    (let ((bracket-start nil))
      ;; Search backwards for the opening bracket
      (while (and (not (bobp))
                  (not bracket-start))
        (beginning-of-line)
        ;; Look for line with unmatched [
        (when (and (re-search-forward "\\[" (line-end-position) t)
                   ;; Make sure it's not closed on same line
                   (not (re-search-forward "\\]" (line-end-position) t)))
          (setq bracket-start (point)))
        (unless bracket-start
          (forward-line -1)))

      (if bracket-start
          ;; Indent relative to the [ position
          (progn
            (goto-char bracket-start)
            (if (looking-at ".*:[ \t]*$")
                ;; After [Type: indent more
                (+ (current-column) cg-indent-offset)
              ;; Otherwise align with content after [
              (+ (current-column) 1)))
        ;; Fallback: use previous line indent
        (cg-previous-line-indent)))))

(defun cg-find-relation-alignment ()
  "Find proper alignment for relations, considering all arrow types."
  (save-excursion
    (let ((current-line-start (line-beginning-position))
          (relation-column nil)
          (in-multi-relation (cg-in-multi-relation-context-p)))

      ;; If we're in multi-relation context after -, align all relations
      (if in-multi-relation
          (progn
            ;; Find the parent concept with -
            (while (and (not (bobp))
                       (not (looking-at ".*\\]-[ \t]*$")))
              (forward-line -1))
            (+ (current-indentation) cg-indent-offset))

        ;; Otherwise look for previous relation at same level
        (forward-line -1)
        (while (and (not (bobp))
                    (not relation-column)
                    ;; Stop at concept without arrow
                    (not (and (looking-at ".*\\[.*\\][ \t]*$")
                             (not (looking-at ".*->[ \t]*\\["))
                             (not (looking-at ".*<-[ \t]*\\[")))))

          ;; Check for any relation pattern
          (when (or (looking-at "[ \t]*(.*)->")
                   (looking-at "[ \t]*(.*)<-")
                   (looking-at "[ \t]*->[ \t]*(")
                   (looking-at "[ \t]*<-[ \t]*("))
            (setq relation-column (current-indentation)))

          (forward-line -1))

        (or relation-column
            (+ (cg-previous-line-indent) cg-indent-offset))))))


(defun cg-find-continuation-dash-column ()
  "Find the column position of a continuation dash on the previous line.
Returns nil if previous line doesn't end with a dash."
  (save-excursion
    (forward-line -1)
    ;; Skip blank lines
    (while (and (not (bobp))
                (looking-at "^[ \t]*$"))
      (forward-line -1))
    ;; Check if line ends with dash
    (when (looking-at ".*-[ \t]*$")
      (end-of-line)
      (search-backward "-" (line-beginning-position) t)
      (current-column))))

(defun cg-indent-after-arrow ()
  "Calculate indentation after an arrow of any type."
  (save-excursion
    (forward-line -1)
    (cond
     ;; After continuation dash - indent for relations list
     ((looking-at ".*\\]-[ \t]*$")
      (+ (current-indentation) cg-indent-offset))

     ;; After -> arrow
     ((re-search-forward "->" (line-end-position) t)
      (+ (current-column) 1))

     ;; After <- arrow
     ((re-search-forward "<-" (line-end-position) t)
      (+ (current-column) 1))

     ;; After standalone - (continuation)
     ((and (re-search-forward "-[ \t]*$" (line-end-position) t)
           (not (looking-back "->[ \t]*" (line-beginning-position)))
           (not (looking-back "<-[ \t]*" (line-beginning-position))))
      (+ (current-indentation) cg-indent-offset))

     ;; Default
     (t (+ (current-indentation) cg-indent-offset)))))


(defun cg-previous-line-ends-context-p ()
  "Check if the previous line ends a context (ends with comma)."
  (save-excursion
    (forward-line -1)
    ;; Skip empty lines
    (while (and (not (bobp))
                (looking-at "^[ \t]*$"))
      (forward-line -1))
    (looking-at ".*,[ \t]*$")))

(defun cg-find-parent-continuation-dash-column ()
  "Find the column of the parent context's continuation dash.
This looks back past the most recent context to find the previous dash."
  (save-excursion
    (forward-line -1)
    ;; Skip back to find the comma that ended the previous context
    (while (and (not (bobp))
                (not (looking-at ".*,[ \t]*$")))
      (forward-line -1))
    ;; Now look back for the dash that started the parent context
    (while (and (not (bobp))
                (not (looking-at ".*-[ \t]*$")))
      (forward-line -1))
    (when (looking-at ".*-[ \t]*$")
      (end-of-line)
      (search-backward "-" (line-beginning-position) t)
      (current-column))))


(defun cg-find-context-start-indent ()
  "Find the indentation of the line that started the current context.
This looks back for the most recent line ending with dash."
  (save-excursion
    (forward-line -1)
    ;; Find the most recent line ending with dash
    (while (and (not (bobp))
                (not (looking-at ".*-[ \t]*$")))
      (forward-line -1))
    (if (looking-at ".*-[ \t]*$")
        (current-indentation)
        0)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Main Indentation Functions

;; (defun cg-calculate-indent ()
;;   "Calculate the indentation for the current line."
;;   (save-excursion
;;     (beginning-of-line)
;;     (cond
;;      ;; First line of buffer
;;      ((bobp) 0)

;;      ;; After end of graph - start at column 0
;;      ((cg-previous-line-ends-graph-p) 0)

;;      ;; After end of inner context (comma) - return to same level as line with dash
;;      ((cg-previous-line-ends-context-p)
;;       (cg-find-context-start-indent))

;;      ;; After a continuation dash - indent relative to the dash position
;;      ((let ((dash-col (cg-find-continuation-dash-column)))
;;         (when dash-col
;;           (- dash-col cg-indent-offset))))

;;      ;; Empty line - maintain previous indentation
;;      ((looking-at "^[ \t]*$")
;;       (forward-line -1)
;;       (current-indentation))

;;      ;; Otherwise maintain current level
;;      (t (cg-previous-line-indent)))))

(defun cg-calculate-indent ()
  "Calculate the indentation for the current line."
  (save-excursion
    (beginning-of-line)
    (cond
     ;; First line of buffer
     ((bobp) 0)

     ;; After end of graph - start at column 0
     ((cg-previous-line-ends-graph-p) 0)

     ;; After end of inner context (comma) - return to same level as line with dash
     ((cg-previous-line-ends-context-p)
      (cg-find-context-start-indent))

     ;; After a continuation dash - indent relative to the dash position
     ((let ((dash-col (cg-find-continuation-dash-column)))
        (when dash-col
          (- dash-col cg-indent-offset))))

     ;; If current line starts with a relation and previous line also starts with a relation,
     ;; maintain the same indentation (we're in a list of relations)
     ((and (looking-at "[ \t]*(")
           (save-excursion
             (forward-line -1)
             (looking-at "[ \t]*(")))
      (cg-previous-line-indent))

     ;; Empty line - maintain previous indentation
     ((looking-at "^[ \t]*$")
      (cg-previous-line-indent))

     ;; Otherwise maintain current level
     (t (cg-previous-line-indent)))))






(defun cg-indent-line ()
  "Indent current line for conceptual graph mode."
  (interactive)
  (let ((indent (cg-calculate-indent)))
    (when indent
      (indent-line-to indent))))


;; (defun cg-indent-graph ()
;;   "Indent all lines of the conceptual graph at point."
;;   (interactive)
;;   (save-excursion
;;     (let ((start (cg-find-graph-start))
;;           (end (cg-find-graph-end))
;;           (line-count 0))
;;       (goto-char start)
;;       ;; Indent each line in the graph
;;       (while (and (< (point) end)
;;                   (not (eobp)))
;;         (beginning-of-line)
;;         (indent-line-to (cg-calculate-indent))
;;         (forward-line 1)
;;         (setq line-count (1+ line-count)))
;;       (message "Indented %d lines" line-count))))

(defun cg-indent-graph ()
  "Indent all lines of the conceptual graph at point."
  (interactive)
  (save-excursion
    (goto-char (cg-find-graph-start))
    (let ((found-end nil)
          (line-count 0))
      (while (and (not found-end)
                  (not (eobp)))
        (beginning-of-line)
        (indent-line-to (cg-calculate-indent))
        (setq found-end (looking-at ".*\\.[ \t]*$"))
        (forward-line 1)
        (setq line-count (1+ line-count)))
      (message "Indented %d lines" line-count))))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Test Functions

(defun cg-test-indentation ()
  "Test indentation on current buffer."
  (interactive)
  (goto-char (point-min))
  (while (not (eobp))
    (cg-indent-line)
    (forward-line 1))
  (message "Indentation complete"))

(defun cg-show-syntax-state ()
  "Show syntax state at point for debugging."
  (interactive)
  (let ((ppss (syntax-ppss)))
    (message "Depth: %d, In string: %s, In comment: %s, Multi-concept: %s, Multi-relation: %s"
             (nth 0 ppss)
             (if (nth 3 ppss) "yes" "no")
             (if (nth 4 ppss) "yes" "no")
             (if (cg-inside-multiline-concept-p) "yes" "no")
             (if (cg-in-multi-relation-context-p) "yes" "no"))))


(defun cg-find-graph-start ()
  "Find the start of the current conceptual graph."
  (save-excursion
    (beginning-of-line)
    ;; Keep going back until we find a graph boundary
    (while (and (not (bobp))
                (not (looking-at "^\\[.*\\]"))  ; A concept at start of line
                (save-excursion
                  (forward-line -1)
                  (not (looking-at ".*\\.[ \t]*$"))))  ; Previous line ends graph
      (forward-line -1))
    (point)))

(defun cg-find-graph-end ()
  "Find the end of the current conceptual graph."
  (save-excursion
    ;; Keep going forward until we find the period
    (while (and (not (eobp))
                (not (looking-at ".*\\.[ \t]*$")))
      (forward-line 1))
    (end-of-line)
    (point)))


(defun cg-test-graph-boundaries ()
  "Test function to show graph boundaries."
  (interactive)
  (let ((start (cg-find-graph-start))
        (end (cg-find-graph-end)))
    (message "Graph from %d to %d" start end)
    (pulse-momentary-highlight-region start end)))  ; Visual highlight

;; (defun cg-indent-graph-debug ()
;;   "Debug version of indent-graph with progress messages."
;;   (interactive)
;;   (save-excursion
;;     (let ((start (cg-find-graph-start))
;;           (end (cg-find-graph-end)))
;;       (message "Indenting region from %d to %d" start end)
;;       (goto-char start)
;;       (while (< (point) end)
;;         (message "Indenting line %d" (line-number-at-pos))
;;         (cg-indent-line)
;;         (forward-line 1))
;;       (message "Done indenting"))))



;; Add a keybinding for convenience
(defun cg-mode-setup-keybindings ()
  "Set up key bindings for cg-mode."
  (local-set-key (kbd "C-M-q") 'cg-format-graph))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Mode Definition

;;;###autoload
(define-derived-mode cg-mode fundamental-mode "CG"
  "Major mode for editing conceptual graphs.
\\{cg-mode-map}"
  :syntax-table cg-mode-syntax-table
  (setq-local indent-line-function #'cg-indent-line)
  (setq-local comment-start "; ")
  (setq-local comment-end "")
  (cg-mode-setup-keybindings))


;;;###autoload
(add-to-list 'auto-mode-alist '("\\.cg\\'" . cg-mode))

(provide 'cg-mode)



(defun cg-format-line-at-dash ()
  "Break line at continuation dash and subsequent relations."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (let ((line-end (line-end-position)))
      ;; Find standalone dash (not <- or ->)
      (when (re-search-forward "\\(^\\|[^<]\\)\\(-\\)\\([^>]\\|$\\)" line-end t)
        (let ((dash-pos (match-end 2)))
          (goto-char dash-pos)
          ;; Skip any whitespace after dash
          (skip-chars-forward " \t")
          ;; Insert newline if there's content after the dash
          (when (< (point) line-end)
            (insert "\n"))
          ;; Now break before each subsequent relation
          (while (re-search-forward "[ \t]+\\(([^)]+)\\)" line-end t)
            (goto-char (match-beginning 1))
            (delete-horizontal-space)
            (insert "\n")))))))






(defun cg-in-continuation-context-p ()
  "Check if we're in a continuation context (after a dash, before a comma or period)."
  (save-excursion
    (beginning-of-line)
    ;; Look backwards for either a dash (start of context) or period/comma (end)
    (let ((found-dash nil)
          (found-end nil))
      (while (and (not (bobp))
                  (not found-dash)
                  (not found-end))
        (forward-line -1)
        (cond
         ;; Found a line ending with dash - we're in continuation context
         ((looking-at ".*-[ \t]*$")
          (setq found-dash t))
         ;; Found a line ending with comma or period - we're not in continuation
         ((looking-at ".*[,.][ \t]*$")
          (setq found-end t))))
      found-dash)))


;;; simpler, ....cg-format-packed-graph
(defun cg-format-graph ()
  "Format a graph that's packed on a single line."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (let ((line-start (point))
          (line-end (line-end-position)))
      ;; Process each pattern
      (dolist (pattern '(("-\\([ \t]*\\)(" . "-\n(")
                        ("\\]\\([ \t]*\\)(" . "]\n(")
                        (",\\([ \t]*\\)(" . ",\n(")
                        (")\\([ \t]*\\)(" . ")\n(")))
        (goto-char line-start)
        (while (re-search-forward (car pattern) line-end t)
          (let* ((old-length (- (match-end 0) (match-beginning 0)))
                 (replacement (cdr pattern))
                 (new-length (length replacement)))
            (replace-match replacement)
            (setq line-end (+ line-end (- new-length old-length))))))))
  ;; Indent the result
  (cg-indent-graph))



;;;; ## Usage:

;;;; Place cursor anywhere in the packed graph:
;;;; [PERSON: Sue]<-(GIVE)<-[agnt]- (obj)->[FOOD] (rcpt)->[DOG: Spot].
;;;;
;;;; Run `M-x cg-format-graph-simple`
;;;;
;;;; Result:
;;;; [PERSON: Sue]<-(GIVE)<-[agnt]-
;;;;                          (obj)->[FOOD]
;;;;                          (rcpt)->[DOG: Spot].
