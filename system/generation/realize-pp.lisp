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

(defun clausal-situation-p (concept)
  "True when CONCEPT is a clausal complement wrapped as a SITUATION -- an
   infinitival that surfaces as 'to <verb>' (e.g. 'wants to go') rather than a
   PROPOSITION that surfaces as a 'that'-clause ('knows that S'). The wrapper type
   is the extractor's choice (INF-S -> situation, THAT-S -> proposition), so the
   realizer defers to it. Unknown SITUATION type (older ontology) -> NIL -> the
   safe 'that'-clause form."
  (and (clausal-concept-p concept)
       (ignore-errors (safe-subtype-p (label (concept-type concept)) 'situation))))

(defun realize-nested-graph (inner-graph state &key negated)
  "Generate a clause from the inner graph held as a concept's referent.
   Walk-state is shared so anaphora carries across the nesting boundary.
   Dispatches through realize-graph-clause so '@passive', AND/OR
   coordination, have-clauses, etc. all fire inside the nesting.

   NEGATED is the holding concept's own negation: ~[PROPOSITION: G] denies G
   just as [PROPOSITION: ~[G]] does, and says 'not' on G's verb. A negation
   inside as well cancels it -- ~[PROPOSITION: ~[G]] is G."
  (multiple-value-bind (graph negated) (unwrap-negation inner-graph negated)
    (if negated
        (realize-conjunct graph t state)
        (realize-graph-clause (context-nodes graph) state
                              (and (typep graph 'graph) (head graph))))))

(defun unwrap-negation (inner-graph &optional outer-negated)
  "For a SITUATION holding a bare negation, [SITUATION: ~[[GO]...]], return
   (values the negated graph T); otherwise (values INNER-GRAPH NIL).
   OUTER-NEGATED is the holding concept's own negation, ~[SITUATION: ...]:
   it denies the graph too, and a negation inside as well cancels it."
  (let ((negation (and (typep inner-graph 'graph)
                       (negated-context-concept (context-nodes inner-graph)))))
    (if negation
        (values (graph-referent negation) (not outer-negated))
        (values inner-graph (and outer-negated t)))))

(defun situation-predicate (graph)
  "The verb of a SITUATION's graph: its main predicate, wherever the graph
   happens to start. The head is where the writer began, and
   [SITUATION: [PERSON: Bob]<-(agnt)<-[EAT]] begins at Bob -- inflecting
   that said 'Bob desires to Bob'."
  (and (typep graph 'graph)
       (let ((nodes (context-nodes graph)))
         (or (and (find-subject-relation (graph-relations-of nodes))
                  (find-main-predicate nodes))
             (find-if #'act-or-event-concept-p (graph-concepts-of nodes))
             (head graph)))))

(defun realize-nested-infinitive (inner-graph state &optional outer-negated)
  "Render an embedded SITUATION as a 'to <verb> ...' infinitive, dropping its
   (controlled, coreferential) subject -- 'the boy wants to go', not 'the boy wants
   that a boy goes'. Reuses realize-verbal-infinitive on the inner predicate head.
   A negated situation is 'not to go'. Falls back to 'that <clause>' when the
   inner graph has no realizable predicate."
  (multiple-value-bind (graph negated) (unwrap-negation inner-graph outer-negated)
    (let* ((head    (situation-predicate graph))
           (buckets (and head (classify-relations head))))
      (if (and head buckets)
          (format nil "~:[~;not ~]~a" negated
                  (realize-verbal-infinitive head buckets state))
          (format nil "that ~a" (realize-nested-graph inner-graph state
                                                      :negated outer-negated))))))

(defun realize-nested-gerund (inner-graph state &optional outer-negated)
  "Render an embedded SITUATION as a '<verb>ing ...' gerund, for a clause that
   sits under a preposition -- 'about eating a pie', or 'about not eating a pie'
   when negated. Otherwise REALIZE-NESTED-INFINITIVE's twin, including the
   'that <clause>' fallback when there is no realizable predicate to inflect."
  (multiple-value-bind (graph negated) (unwrap-negation inner-graph outer-negated)
    (let* ((head    (situation-predicate graph))
           (buckets (and head (classify-relations head))))
      (if (and head buckets)
          (format nil "~:[~;not ~]~a" negated
                  (realize-verbal-gerund head buckets state))
          (format nil "that ~a" (realize-nested-graph inner-graph state
                                                      :negated outer-negated))))))

(defun realize-argument (concept state &key (case :nominative) preposition)
  "Render CONCEPT as a verb argument. A clausal SITUATION emits '<verb>ing' under
   a preposition and 'to <verb>' without one; any other clausal complement emits
   'that <inner clause>' with PREPOSITION suppressed. A non-clausal concept
   renders as an NP, with PREPOSITION prepended when supplied.

   The preposition is what decides infinitive against gerund, and it decides it
   for every verb at once. English prepositions govern gerunds -- 'informs Sue
   about eating', never 'about to eat' -- while a bare complement takes the
   infinitive: 'wishes to eat'. INFORM reaches here with a preposition because
   ':rcpt-direct' demotes its info-arg to a PP; WISH reaches here without one.
   So this needs no per-verb knowledge, and every verb carrying an ':obj-prep'
   -- notify, advise, warn, ask, remind -- is fixed by the same line."
  (cond ((clausal-situation-p concept)
         (mark-uttered state concept)
         (let ((inner (graph-referent concept))
               (negated (and (negated concept) t)))
           (if preposition
               (format nil "~a ~a" preposition (realize-nested-gerund inner state negated))
               (realize-nested-infinitive inner state negated))))
        ((clausal-concept-p concept)
         (mark-uttered state concept)
         (format nil "that ~a"
                 (realize-nested-graph (graph-referent concept) state
                                       :negated (negated concept))))
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

(defparameter *arc-preposition-keys*
  '(("inst" . :inst-prep)
    ("time" . :time-prep))
  "Relations whose preposition the FILLER may override, and the lexicon key it
   says so with. A relation's own preposition is one word for every filler, and
   for these two that is not enough of English: :inst says \"with\", right for a
   device and wrong for a medium -- you reach someone BY telephone but WITH a
   telephone -- and :time says \"at\", right for a clock time and wrong for a
   day, which takes \"on\". Extend the table rather than adding another
   special case.")

(defun filler-preposition (rel other)
  "The preposition REL's filler asks for, or NIL to let the relation's own
   stand. Only the arcs in *ARC-PREPOSITION-KEYS* can be overridden this way:
   everywhere else a relation means one thing in English and says it one way."
  (let ((key (and other
                  (concept-p other)
                  (cdr (assoc (label (relation-type rel)) *arc-preposition-keys*
                              :test #'string-equal)))))
    (and key (lexicon-prop (concept-type other) key))))

(defun realize-pp (rel main-concept state)
  (let* ((other (other-end rel main-concept))
         (prep  (or (filler-preposition rel other)
                    (relation-preposition rel)
                    ""))
         (rel-label (label (relation-type rel))))
    ;; 'time' arc with a deictic adverb target ('yesterday', 'tomorrow', ...)
    ;; surfaces as a bare adverb instead of 'at <Name>'.
    (let ((adv (and other (string-equal rel-label "time")
                    (temporal-adverb-form other)))
          (measure nil))
      (cond (adv (mark-uttered state other) adv)
            ((setf measure (measure-phrase rel other state prep)) measure)
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
