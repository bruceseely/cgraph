

;;; unused
(defun cg-previous-line-string-start-pos ()
  "Get indentation of previous non-empty line."
  (save-excursion
   (forward-line -1)
   ;; Skip empty lines
   (while (and (not (bobp))
               (looking-at "^[ \t]*$"))
          (forward-line -1))
   (cg-current-line-string-start-pos)))


;;; unused
(defun cg-previous-line-ends-with-concept-p ()
  "Check if previous line ends with a concept."
  (save-excursion
    (forward-line -1)
    (looking-at ".*\\[.*\\][ \t]*$")))



;;; unused
(defun cg-previous-line-ends-with-arrow-p ()
  "Check if previous line ends with any arrow type: ->, <-, or -"
  (save-excursion
    (forward-line -1)
    (or (looking-at ".*->[ \t]*\\(\\[.*\\]\\)?[ \t]*$")
        (looking-at ".*<-[ \t]*\\(\\[.*\\]\\)?[ \t]*$")
        (looking-at ".*-[ \t]*$"))))  ; Multi-relation connector


;;; unused
(defun cg-line-ends-with-continuation-p ()
  "Check if line ends with - (continuation for multiple relations)."
  (save-excursion
    (end-of-line)
    (looking-back "-[ \t]*" (line-beginning-position))))



;;; unused
(defun cg-current-line-starts-with-closing-bracket-p ()
  "Check if current line starts with a closing bracket."
  (save-excursion
    (beginning-of-line)
    (looking-at "[ \t]*\\]")))


;;; unused
(defun cg-current-line-starts-with-relation-p ()
  "Check if current line starts with a relation."
  (save-excursion
    (beginning-of-line)
    (looking-at "[ \t]*(.*)")))



;;; unused
(defun cg-current-line-is-start-line-p ()
  (let ((line-start (pos-bol))
        (line-end (pos-eol)))
    (<= line-start (cg-find-graph-start-pos) line-end)))




;;; unused
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

;;; unused
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

;;; unused
(defun cg-indent-after-arrowH ()
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

;;; unused
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

;;; unused
(defun cg-graph-base-column ()
  "Get tthe column that lines are indented from"
  (save-excursion
   (goto-char (cg-find-graph-start-pos))
   (current-column)))
