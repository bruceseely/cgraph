;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Noun-phrase realization: head form, set referents, full NP assembly,
;;  post-modifiers, and Sowa Rule 3 relative clauses for unrealized
;;  predications attached to the NP head. Argument-level dispatch lives
;;  in realize-pp.lisp; clause-level assembly in realize-clause.lisp.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Phase-1 stub kept for callers that just want a raw word.
(defun lemma-for-concept (concept)
  (base-lemma concept))

;;; --- Noun phrase -----------------------------------------------------------

(defun noun-form (concept)
  "Return the inflected noun form (singular or plural) for CONCEPT."
  (let* ((lemma (base-lemma concept)))
    (cond ((eq (concept-definiteness concept) :proper)
           (cap lemma))
          ((eq (concept-number concept) :plural)
           (or (lexicon-prop (concept-type concept) :plural)
               (pluralize lemma)))
          (t lemma))))

(defun realize-np (concept state &key (case :nominative))
  "Emit a noun phrase for CONCEPT. On the first visit, build the full NP
   (adjectives, possessive, determiner, possibly trailing relative clauses).
   On revisits (Sowa Rule 5), emit the pronoun in the given grammatical CASE."
  (cond ((uttered-or-coref-uttered-p state concept)
         (or (pronoun-for concept :case case :state state)
             (format nil "the ~a" (noun-form concept))))
        (t
         (mark-uttered state concept)
         (realize-full-np concept state))))

(defun set-member-tally (concept)
  "When CONCEPT's referent is a set, return (values named-list anon-count):
   named-list is the in-order list of :name strings, anon-count is the number
   of remaining members that resolved to individuals without names (e.g.
   '#123'). Returns NIL when CONCEPT isn't a set referent."
  (let* ((ref (referent concept))
         (set (and ref (typep (content ref) 'set) (content ref))))
    (when set
      (let ((named '()) (anon 0))
        (dolist (m (members set))
          (let ((name (getf (properties m) :name)))
            (cond ((and (stringp name) (plusp (length name)))
                   (push name named))
                  (t (incf anon)))))
        (values (nreverse named) anon)))))

(defun set-cardinality (concept)
  "Integer count from a set referent's '@N' annotation, or NIL when absent
   or when the measure carries units (a measurement, not a count)."
  (let ((raw (let ((ref (referent concept)))
               (and ref (measure-property ref)))))
    (when (and (consp raw) (integerp (first raw))
               (or (null (second raw))
                   (and (stringp (second raw))
                        (zerop (length (second raw))))))
      (first raw))))

(defun realize-named-set-np (concept)
  "Render a set referent with at least one named member. Extras come from
   either an explicit '@N' annotation (count - named) or, when no count is
   given, from anonymous-individual members like '#123'. Single extra
   surfaces as 'another dog'; multiple as 'two other dogs' / 'two others'
   for humans."
  (multiple-value-bind (names anon) (set-member-tally concept)
    (when names
      (let* ((count   (set-cardinality concept))
             (extras  (cond (count (- count (length names)))
                            (t     anon)))
             (singular (base-lemma concept))
             (plural   (or (lexicon-prop (concept-type concept) :plural)
                           (pluralize singular))))
        (when (and (integerp extras) (>= extras 0))
          (let* ((capped (mapcar #'cap names))
                 (tail   (cond ((zerop extras) nil)
                               ((= extras 1)
                                (cond ((human-p concept) "another")
                                      (t (format nil "another ~a" singular))))
                               ((human-p concept)
                                (format nil "~a others" (number-word extras)))
                               (t (format nil "~a other ~a"
                                          (number-word extras) plural))))
                 (items  (if tail (append capped (list tail)) capped))
                 (joined (cond ((= (length items) 1) (first items))
                               ((= (length items) 2)
                                (format nil "~a and ~a"
                                        (first items) (second items)))
                               (t (format nil "~{~a~^, ~}, and ~a"
                                          (butlast items) (car (last items)))))))
            (cond ((and tail (not (human-p concept))) joined)
                  ((human-p concept) joined)
                  (t (format nil "the ~a ~a" (noun-form concept) joined)))))))))

(defun concept-measure-phrase (concept)
  "Render a concept's :measure annotation as 'five feet' / '25.4 centimeters'.
   Returns NIL when the concept has no measure, the units are blank (the
   bare-cardinal case is handled by concept-count-word), or it's a counted
   set."
  (let ((raw (or (getf (properties concept) :measure)
                 (let ((ref (referent concept)))
                   (and ref (measure-property ref))))))
    (cond ((or (null raw) (set-spec concept)) nil)
          ((and (consp raw) (numberp (first raw)))
           (let* ((n     (first raw))
                  (units (second raw))
                  (head  (cond ((integerp n) (number-word n))
                               (t (princ-to-string n)))))
             (cond ((or (null units) (zerop (length units))) nil)
                   (t (format nil "~a ~a" head (expand-units units n)))))))))

(defun realize-full-np (concept state)
  (let ((named-set (realize-named-set-np concept)))
    (when named-set
      (return-from realize-full-np named-set)))
  (let ((adj-mods  '())
        (poss-mods '())
        (head      (noun-form concept))
        (article   nil)
        mods-pre)
    (dolist (rel (concept-relations concept))
      (let ((role (relation-role rel)))
        ;; Skip relations already traversed (e.g. consumed by a copular
        ;; clause as a predicate complement) to avoid double-emission.
        (cond ((and (eq role :adj) (not (traversed-p state rel)))
               (let ((mod (other-end rel concept)))
                 (when (and mod (not (eq mod concept)))
                   (push (base-lemma mod) adj-mods))))
              ((and (eq role :poss) (not (traversed-p state rel))
                    ;; POSS links animate (possessor, source) -> entity
                    ;; (possessed, dest=outarc). Only fold the other end in
                    ;; as a possessive modifier when WE are the possessed.
                    (eq (outarc rel) concept))
               (let ((owner (other-end rel concept)))
                 (when owner
                   (mark-traversed state rel)
                   (push (format nil "~a's"
                                 (if (eq (concept-definiteness owner) :proper)
                                     (cap (base-lemma owner))
                                     (base-lemma owner)))
                         poss-mods)))))))
    ;; English pre-modifier order: possessive precedes adjectives. The
    ;; ordering is fixed grammatically and must NOT depend on the order
    ;; the arcs happen to appear in concept-relations (which can vary
    ;; with parse history).
    (setf mods-pre (append (nreverse poss-mods) (nreverse adj-mods)))
    (let ((first-word (or (first mods-pre) head)))
      (setf article (article-for concept first-word)))
    (when (some (lambda (m) (search "'s" m)) mods-pre)
      (setf article nil))
    (let ((np-text (string-trim
                    " "
                    (format nil "~@[~a ~]~{~a ~}~a"
                            article mods-pre head)))
          (measure  (concept-measure-phrase concept))
          (pp-mods  (np-post-modifiers concept state))
          (rel-clauses (relative-clauses-for concept state)))
      (format nil "~a~@[ ~a~]~@[ ~{~a~^ ~}~]~@[ ~{~a~^, ~}~]"
              np-text measure pp-mods rel-clauses))))

(defun np-post-modifiers (concept state)
  "Collect post-modifiers for an NP head: PP relations ('in a bottle') and
   :nmod relations ('of length five feet'). Direction-aware for :pp via the
   np-pp-prepositions table; :nmod uses the relation's declared preposition."
  (let ((mods '()))
    (dolist (rel (concept-relations concept))
      (let ((role (relation-role rel)))
        (cond ((and (eq role :pp) (not (traversed-p state rel)))
               ;; Direction-aware override (np-pp-prepositions) wins; fall
               ;; back to the relation's declared preposition for the rest
               ;; (PLOC, AGE, FROM, ...).
               (let ((prep  (or (np-pp-preposition rel concept)
                                (relation-preposition rel)))
                     (other (other-end rel concept)))
                 (when (and prep other)
                   (mark-traversed state rel)
                   (push (format nil "~a ~a" prep
                                 (realize-np other state :case :accusative))
                         mods))))
              ((and (eq role :nmod) (not (traversed-p state rel)))
               (let ((prep  (relation-preposition rel))
                     (other (other-end rel concept)))
                 (when other
                   (mark-traversed state rel)
                   (push (format nil "~@[~a ~]~a" prep
                                 (realize-np other state :case :accusative))
                         mods)))))))
    (nreverse mods)))

;;; --- Relative clauses (Phase 4) --------------------------------------------

(defun unrealized-predications (concept state)
  "Find AGNT relations attached to CONCEPT whose act is not yet uttered.
   Each becomes a relative clause."
  (let ((preds '()))
    (dolist (rel (concept-relations concept))
      (let ((other (other-end rel concept)))
        (when (and other
                   (eq (relation-role rel) :subject)
                   (not (traversed-p state rel))
                   (not (uttered-p state other)))
          (push rel preds))))
    (nreverse preds)))

(defun relative-pronoun-for (concept)
  (cond ((human-p concept) "who")
        (t "that")))

(defun relative-clauses-for (concept state)
  (let ((rcs '()))
    (dolist (rel (unrealized-predications concept state))
      (push (realize-relative-clause concept rel state) rcs))
    (nreverse rcs)))

(defun realize-relative-clause (head-concept rel state)
  "REL is an AGNT linking HEAD-CONCEPT (the agent) to a sub-act.
   Emit 'who/that <verb-phrase>'."
  (mark-traversed state rel)
  (let* ((sub-act     (other-end rel head-concept))
         (rel-pron    (relative-pronoun-for head-concept))
         (sub-buckets (classify-relations sub-act)))
    (mark-clause-relations-traversed sub-buckets state)
    (format nil "~a ~a"
            rel-pron
            (realize-predicate-body sub-act sub-buckets state
                                    :subject-concept head-concept))))
