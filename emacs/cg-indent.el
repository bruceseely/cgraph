;;; cg-indent.el --- code for editing Conceptual Graphs



;;; (back-to-indentation) Move point to the first non-whitespace character on this line
;;; (bobp) Return t if point is at the beginning of the buffer

(defun file-char-position-to-line-offset (file-char-pos)
  "Converts a file character position to a character offset within the current line.
   FILE-CHAR-POS is the absolute character position from the beginning of the buffer."
  (interactive "nFile Character Position: ")
  (save-excursion
    (goto-char file-char-pos)
    (- (point) (line-beginning-position))))

(defun line-col-to-file-pos (line-num col-num &optional buffer)
  "Convert a line number (1-based) and column (0-based) to a file byte offset.
   Handles multi-byte characters and different coding systems."
  (let* ((buf (or buffer (current-buffer)))
         ;; Get buffer position (character index from start)
         (buffer-pos (line-col-to-buffer-position (1- line-num) col-num buf)))
    ;; Convert buffer position to file byte position
    (bufferpos-to-filepos buffer-pos)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Variables

;; (defgroup cg-mode nil
;;   "Major mode for editing conceptual graphs."
;;   :group 'languages)

(defcustom cg-indent-offset 3
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


(defun cg-find-graph-start-pos ()
  "Find the start of the current conceptual graph.
If inside a string, returns the position after the opening quote.
Otherwise uses the original logic."
  (save-excursion
    (let ((ppss (syntax-ppss)))
      (if (nth 3 ppss)
          ;; We're inside a string - go to start of string
          (progn
            (goto-char (nth 8 ppss))
            ;; Move past the opening quote
            (forward-char 1)
            (point))
        ;; Not in a string - use original logic
        (beginning-of-line)
        ;; Keep going back until we find a graph boundary
        (while (and (not (bobp))
                    (not (looking-at "^\\[.*\\]"))  ; A concept at start of line
                    (save-excursion
                      (forward-line -1)
                      (not (looking-at ".*\\.[ \t]*$"))))  ; Previous line ends graph
          (forward-line -1))
        (point)))))

(defun cg-find-graph-end-pos ()
  "Find the end of the current conceptual graph.
If inside a string, returns the position before the closing quote.
Otherwise uses the original logic."
  (save-excursion
    (let ((ppss (syntax-ppss)))
      (if (nth 3 ppss)
          ;; We're inside a string - find the closing quote
          (let ((string-start (nth 8 ppss)))
            ;; Search forward for the closing quote
            (goto-char string-start)
            (forward-char 1)  ; Move past opening quote
            ;; Find the matching closing quote
            (while (and (not (eobp))
                        (not (looking-at "\"")))
              (forward-char 1)
              ;; Skip escaped quotes
              (when (and (eq (char-before) ?\\)
                         (eq (char-after) ?\"))
                (forward-char 1)))
            ;; Now we're at the closing quote
            (point))
        ;; Not in a string - use original logic
        ;; Keep going forward until we find the period
        (while (and (not (eobp))
                    (not (looking-at ".*\\.[ \t]*$")))
          (forward-line 1))
        (end-of-line)
        (point)))))


(defun current-line-contains-quote-p ()
  "Test if the current line contains a double quote character."
  (save-excursion
    (beginning-of-line)
    (looking-at ".*\"")))

(defun find-first-brace-on-line ()
  "Finds the position of the first double quote character on the current line.
Returns nil if no double quote is found on the line."
  (save-excursion
    (beginning-of-line)
    (if (search-forward "\\[" (point-at-eol) t)
        (1- (point))
        nil)))


(defun cg-previous-line-indent ()
  "Get indentation of previous non-empty line."
  (save-excursion
    (forward-line -1)
    ;; Skip empty lines
    (while (and (not (bobp))
                (looking-at "^[ \t]*$"))
      (forward-line -1))
    (current-indentation)))



(defun cg-current-line-string-start-pos ()
  "Get indentation of previous non-empty line."
  (save-excursion
   (if (current-line-contains-quote-p)
       (file-char-position-to-line-offset
        (find-first-brace-on-line)))))



(defun cg-previous-line-ends-graph-p ()
  "Check if the previous non-blank line ends a graph (ends with period)."
  (save-excursion
    (forward-line -1)
    ;; Skip empty lines
    (while (and (not (bobp))
                (looking-at "^[ \t]*$"))
      (forward-line -1))
    (looking-at ".*\\.[ \t]*$")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Helper Functions - Context Detection



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Arrow Functions


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Indentation Calculation Functions

(defun cg-find-continuation-dash-column ()
  "Find the column position of a continuation dash on the PREVIOUS line.
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


(defun cg-previous-line-ends-context-p ()
  "Check if the previous line ends a context (ends with comma)."
  (save-excursion
    (forward-line -1)
    ;; Skip empty lines
    (while (and (not (bobp))
                (looking-at "^[ \t]*$"))
      (forward-line -1))
    (looking-at ".*,[ \t]*$")))


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


(defun cg-calculate-indent ()
  "Calculate the indentation for the current line."
  (save-excursion
   (beginning-of-line)
   (let ((dash-col (cg-find-continuation-dash-column)))
     (cond
       ;; First line of buffer
       ((bobp)  0)

       ;; After end of graph - start at column 0
       ((cg-previous-line-ends-graph-p)  0)

       ;; After end of inner context (comma) - return to same level as line with dash
       ((cg-previous-line-ends-context-p)
        (cg-find-context-start-indent))

       ;; After a continuation dash - indent relative to the dash position
       (dash-col
        (- dash-col cg-indent-offset))

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
       (t
        (cg-previous-line-indent))))))


(defun cg-indent-line ()
  "Indent current line for conceptual graph mode."
  (interactive)
  (let ((indent (cg-calculate-indent)))
    (when indent
      (indent-line-to indent))))


(defun cg-indent-graph ()
  "Indent all lines of the conceptual graph at point."
  (interactive)
  (save-excursion
   (let ((graph-end (cg-find-graph-end-pos)))
     (goto-char (cg-find-graph-start-pos))
     ;; first line is not moved
     (forward-line 1)
     (while (< (point) graph-end)
            (beginning-of-line)
            (cg-indent-line)
            ;; end has moved because of the indentation
            (setq graph-end (cg-find-graph-end-pos))
            (forward-line 1)))))



(defun remove-newlines-between (start-pos end-pos)
  "Removes all newline characters between START-POS and END-POS."
  (interactive "P") ; Allows interactive use with prefix arg
  (save-excursion ; Save current point and mark
    (goto-char start-pos) ; Move to the start
    (replace-regexp-in-region "\n *" "" start-pos end-pos) ; Replace newlines with nothing
    (message "Removed newlines between %d and %d" start-pos end-pos)))



(defun cg-flatten-graph ()
  (interactive)
  (save-excursion
   (let ((graph-start (cg-find-graph-start-pos))
         (graph-end (cg-find-graph-end-pos)))
     (remove-newlines-between graph-start graph-end))))


(defun cg-split-graph ()
  (interactive)
  (save-excursion
   (let* ((graph-start (cg-find-graph-start-pos))
          (graph-end (cg-find-graph-end-pos))
          (end-marker (make-marker)))
     (remove-newlines-between graph-start graph-end)
     (setq graph-end (cg-find-graph-end-pos))
     (when (<= (pos-bol) graph-start graph-end (pos-eol))
       ;; Set marker at end - it will move as we insert text
       (set-marker end-marker graph-end)
       ;; Process each pattern
       ;; Updated to support both ASCII (<-, ->) and Unicode (←, →) arrow syntax
       (dolist (pattern '(("\\(^\\|[^<>]\\)\\([-←→]\\)[ \t]*(" . "\\1\\2\n(")
                          (            "\\]\\([ \t]*\\)(" . "]\n(")
                          (              ",\\([ \t]*\\)(" . ",\n(")
                          (              ")\\([ \t]*\\)(" . ")\n(")
                          (              "\\(<-[0-9]+\\|←[0-9]+\\|->[0-9]+\\|→[0-9]+\\)" . "\n\\1")))
         (goto-char graph-start)
         (while (re-search-forward (car pattern) end-marker t)
                (replace-match (cdr pattern))))
       ;; Clean up marker
       (set-marker end-marker nil)))))


(defun cg-format-graph ()
  "Format a graph that's packed on a single line."
  (interactive)
  (cg-normalize-cgraph-string)
  (cg-split-graph)
  (cg-indent-graph))



;; keybinding
(global-set-key (kbd "C-M-z") 'cg-format-graph)



(defun cg-newline-indent ()
  (interactive)
  (end-of-line)
  (insert ?\n)
  (cg-indent-line))

;; keybinding
(global-set-key (kbd "C-<return>") 'cg-newline-indent)
