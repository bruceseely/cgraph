;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Argument and adjunct realization. Bridges NP-level rendering
;;  (realize-np.lisp) and clause-level assembly (realize-clause.lisp):
;;
;;    - realize-argument: emit a verb argument as either an NP or, when the
;;      concept's referent is a graph (PROPOSITION/SITUATION/...), as a
;;      'that <inner clause>' embedded clause (Sowa Rule 4).
;;    - realize-pp / realize-adv: PP and adverbial adjuncts.
;;    - tense resolution: annotation -> TIME-arc inference -> :present.
;;
;;  *time-tense-hints* lives here because temporal-adverb-form ('yesterday',
;;  'tomorrow') and tense-from-time-relation share the same word table.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *time-tense-hints*
  '((:past    "yesterday" "last-week" "last-month" "last-year" "last-night"
              "earlier"   "ago")
    (:future  "tomorrow"  "next-week" "next-month" "next-year"
              "later"     "soon")
    (:present "now" "today" "currently"))
  "Lemma -> implied tense for tense inference from a TIME relation.")

(defun tense-from-time-relation (predicate)
  "Inspect PREDICATE's TIME arc; if its target's lemma matches a known
   time word, return the implied tense. NIL when there is no TIME arc or
   the time word isn't known."
  (let ((time-rel (find-if (lambda (r)
                             (string-equal (label (relation-type r)) "time"))
                           (concept-relations predicate))))
    (when time-rel
      (let* ((other (other-end time-rel predicate))
             (lemma (and other (string-downcase (base-lemma other)))))
        (when lemma
          (loop for (tense . words) in *time-tense-hints*
                when (find lemma words :test #'string=)
                  return tense))))))

(defun resolve-tense (predicate)
  "Annotation wins; otherwise infer from a TIME arc; otherwise :present."
  (or (concept-tense predicate)
      (tense-from-time-relation predicate)
      :present))

;;; --- Argument realization (NP or embedded clause) -------------------------
;;; Sowa Rule 4: when a concept's referent is itself a graph (PROPOSITION,
;;; SITUATION, BELIEF, ...), it expresses as an embedded clause introduced
;;; by 'that' rather than as a noun phrase. Any preposition the caller would
;;; otherwise prepend is suppressed for clausal complements.

(defun clausal-concept-p (concept)
  (and concept (graph-referent-p concept)))

(defun realize-nested-graph (inner-graph state)
  "Generate a clause from the inner graph held as a concept's referent.
   Walk-state is shared so anaphora carries across the nesting boundary.
   Dispatches through realize-graph-clause so '@passive', AND/OR
   coordination, have-clauses, etc. all fire inside the nesting."
  (let ((head (and (typep inner-graph 'graph) (head inner-graph))))
    (realize-graph-clause (graph-nodes inner-graph) state head)))

(defun realize-argument (concept state &key (case :nominative) preposition)
  "Render CONCEPT as a verb argument. If CONCEPT has a graph referent,
   emit 'that <inner clause>' (with PREPOSITION suppressed). Otherwise
   render as an NP and prepend PREPOSITION when supplied."
  (cond ((clausal-concept-p concept)
         (mark-uttered state concept)
         (format nil "that ~a"
                 (realize-nested-graph (graph-referent concept) state)))
        (t
         (let ((np (realize-np concept state :case case)))
           (if preposition
               (format nil "~a ~a" preposition np)
               np)))))

;;; --- Prepositional phrase / object NPs -------------------------------------

(defun temporal-adverb-form (concept)
  "If CONCEPT's name is a recognized temporal adverb ('yesterday' /
   'tomorrow' / 'now' / ...), return the lowercase form. NIL otherwise.
   Used to drop the 'at' preposition for adverbial time complements:
   'A girl ate a pie yesterday', not 'A girl ate a pie at Yesterday'."
  (let ((lemma (and concept (string-downcase (base-lemma concept)))))
    (when lemma
      (loop for entry in *time-tense-hints*
            when (find lemma (rest entry) :test #'string=)
              return lemma))))

(defun realize-pp (rel main-concept state)
  (let* ((prep  (or (relation-preposition rel) ""))
         (other (other-end rel main-concept))
         (rel-label (label (relation-type rel))))
    ;; 'time' arc with a deictic adverb target ('yesterday', 'tomorrow', ...)
    ;; surfaces as a bare adverb instead of 'at <Name>'.
    (let ((adv (and other (string-equal rel-label "time")
                    (temporal-adverb-form other))))
      (cond (adv (mark-uttered state other) adv)
            (t (or (and other
                        (realize-argument other state
                                          :case :accusative
                                          :preposition (and (plusp (length prep)) prep)))
                   ""))))))

(defun realize-adv (rel main-concept state)
  (declare (ignore state))
  (let ((other (other-end rel main-concept)))
    (cond ((null other) "")
          ;; Lexicon override wins (e.g. MANNER -> "somehow") so we don't
          ;; suffix-derive nonsense like "mannerly" from abstract categories.
          ((lexicon-prop (concept-type other) :adv-form))
          (t (adverbify (string-downcase (label (concept-type other))))))))
