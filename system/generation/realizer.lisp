;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Token realization. Phase 4 adds relative clauses (Sowa Rule 3) so that
;;  multi-clause graphs like [BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]
;;  produce "a boy gives a dog that eats" — the dog NP picks up a trailing
;;  relative because it is the agent of an act not yet uttered.
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

;;; --- Argument realization (NP or embedded clause) -------------------------
;;; Sowa Rule 4: when a concept's referent is itself a graph (PROPOSITION,
;;; SITUATION, BELIEF, ...), it expresses as an embedded clause introduced
;;; by 'that' rather than as a noun phrase. Any preposition the caller would
;;; otherwise prepend is suppressed for clausal complements.

(defun clausal-concept-p (concept)
  (and concept (graph-referent-p concept)))

(defun realize-nested-graph (inner-graph state)
  "Generate a clause from the inner graph held as a concept's referent.
   Walk-state is shared so anaphora carries across the nesting boundary."
  (let* ((nodes (graph-nodes inner-graph))
         (inner-main (find-main-predicate nodes)))
    (cond ((null inner-main) "")
          (t (let ((buckets (classify-relations inner-main)))
               (realize-clause inner-main buckets state))))))

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

(defun realize-pp (rel main-concept state)
  (let* ((prep  (or (relation-preposition rel) ""))
         (other (other-end rel main-concept)))
    (or (and other
             (realize-argument other state
                               :case :accusative
                               :preposition (and (plusp (length prep)) prep)))
        "")))

(defun realize-adv (rel main-concept state)
  (declare (ignore state))
  (let ((other (other-end rel main-concept)))
    (cond ((null other) "")
          ;; Lexicon override wins (e.g. MANNER -> "somehow") so we don't
          ;; suffix-derive nonsense like "mannerly" from abstract categories.
          ((lexicon-prop (concept-type other) :adv-form))
          (t (adverbify (string-downcase (label (concept-type other))))))))

;;; --- Predicate body (verb + complements, no subject NP) --------------------

(defun realize-predicate-body (predicate buckets state
                               &key subject-concept)
  "Emit verb + dobj + iobj + PPs + adverbs. SUBJECT-CONCEPT is consulted
   for verb agreement only; the subject NP is not rendered here. Used both
   by the main clause (with the subject prepended) and by relative clauses
   (where the head fills the subject slot)."
  (let ((parts '()))
    (labels ((push-part (s)
               (when (and s (plusp (length s))) (push s parts))))
      (let* ((numbr  (if subject-concept (concept-number subject-concept) :singular))
             (person (if subject-concept (concept-person subject-concept) 3))
             (lemma  (base-lemma predicate))
             (tense  (or (concept-tense predicate) :present))
             (verb   (inflect-verb lemma :tense tense
                                         :person person :numbr numbr)))
        (push-part verb))
      (mark-uttered state predicate)
      ;; Argument frame: by default the CG :dobj is the surface direct object
      ;; and the CG :iobj surfaces with the relation's preposition (typically
      ;; "to"). Communication verbs like INFORM/TELL flip this — the recipient
      ;; is the direct object and the information is a PP ("inform her about
      ;; news"). The flip is driven by lexicon overrides on the verb.
      (let* ((ptype (concept-type predicate))
             (rcpt-direct (lexicon-prop ptype :rcpt-direct))
             (cg-dobj-rel (first (gethash :dobj buckets)))
             (cg-iobj-rel (first (gethash :iobj buckets)))
             (surface-dobj-rel (if rcpt-direct cg-iobj-rel cg-dobj-rel))
             (surface-iobj-rel (if rcpt-direct cg-dobj-rel cg-iobj-rel))
             (surface-iobj-prep
              (cond (rcpt-direct (lexicon-prop ptype :obj-prep "about"))
                    (surface-iobj-rel
                     (or (relation-preposition surface-iobj-rel) "to"))
                    (t nil))))
        (when surface-dobj-rel
          (push-part (realize-argument (other-end surface-dobj-rel predicate) state
                                       :case :accusative)))
        (when surface-iobj-rel
          (push-part (realize-argument
                      (other-end surface-iobj-rel predicate) state
                      :case :accusative
                      :preposition surface-iobj-prep))))
      (dolist (rel (gethash :pp buckets))
        (push-part (realize-pp rel predicate state)))
      (dolist (rel (gethash :adv buckets))
        (push-part (realize-adv rel predicate state))))
    (format nil "~{~a~^ ~}" (nreverse parts))))

;;; --- Clause assembly --------------------------------------------------------

(defun mark-clause-relations-traversed (buckets state)
  "Mark every relation in BUCKETS as traversed, so that subordinate NPs
   don't try to relativize a relation already accounted for."
  (maphash (lambda (k rels)
             (declare (ignore k))
             (dolist (r rels)
               (mark-traversed state r)))
           buckets))

(defun unexpressed-poss-relations (nodes state)
  "POSS relations that weren't folded into an NP as a possessive modifier
   (typically because the parser didn't coref the possessed concept across
   commas). Returned in graph order."
  (remove-if (lambda (r)
               (or (not (eq (relation-role r) :poss))
                   (traversed-p state r)))
             (graph-relations-of nodes)))

(defun realize-leftover-poss (rels state)
  "Append leftover POSS relations as coordinated 'and X has Y' clauses
   so the possession isn't silently dropped."
  (cond ((null rels) "")
        (t (format
            nil ", and ~{~a~^, and ~}"
            (mapcar
             (lambda (r)
               (mark-traversed state r)
               (let* ((possessed (outarc r))
                      (possessor (first (other-arcs r possessed)))
                      (have-form (if (eq (verb-agreement-number possessor state)
                                         :plural)
                                     "have" "has"))
                      (p-np (realize-np possessor state :case :nominative))
                      (q-np (realize-np possessed state :case :accusative)))
                 (format nil "~a ~a ~a" p-np have-form q-np)))
             rels)))))

(defun realize-have-clause (possessor state)
  "Render 'POSSESSOR has/have X (and Y ...)' for a POSS-only graph."
  (let* ((number    (concept-number possessor))
         (have-form (if (eq number :plural) "have" "has"))
         (parts     '())
         (objects   '()))
    (mark-uttered state possessor)
    ;; Mark the POSS relations traversed BEFORE rendering the topic NP
    ;; so they aren't folded back in as possessive prefixes.
    (dolist (rel (concept-relations possessor))
      (when (eq (relation-role rel) :poss)
        (mark-traversed state rel)))
    (push (realize-full-np possessor state) parts)
    (push have-form parts)
    (dolist (rel (concept-relations possessor))
      (when (and (traversed-p state rel) (eq (relation-role rel) :poss))
        (let ((possessed (other-end rel possessor)))
          (when possessed
            (push (realize-np possessed state :case :accusative) objects)))))
    (push (format nil "~{~a~^ and ~}" (nreverse objects)) parts)
    (format nil "~{~a~^ ~}" (nreverse parts))))

(defun realize-passive-with-agent (predicate buckets state)
  "Head-driven passive (Sowa transformation): the OBJ becomes the surface
   subject and the AGNT is demoted to a 'by X' phrase. Used when the graph
   head is the patient/object rather than the agent."
  (mark-clause-relations-traversed buckets state)
  (let* ((dobj-rel     (first (gethash :dobj buckets)))
         (subj-rel     (first (gethash :subject buckets)))
         (surface-subj (and dobj-rel (other-end dobj-rel predicate)))
         (agent        (and subj-rel (other-end subj-rel predicate)))
         (number       (if surface-subj (concept-number surface-subj) :singular))
         ;; Tense from the predicate, falling back to present. :progressive
         ;; doesn't combine with passive in this single-slot scheme; treat
         ;; it as present for now.
         (tense        (let ((t* (concept-tense predicate)))
                         (if (or (null t*) (eq t* :progressive)) :present t*)))
         (be-form      (be-form-for tense number))
         (parts        '()))
    (labels ((push-part (s) (when (and s (plusp (length s))) (push s parts))))
      (when surface-subj
        (push-part (realize-np surface-subj state :case :nominative)))
      (push-part be-form)
      (push-part (past-participle (base-lemma predicate)))
      (mark-uttered state predicate)
      (when agent
        (push-part (format nil "by ~a"
                           (realize-np agent state :case :accusative))))
      (let ((iobj (first (gethash :iobj buckets))))
        (when iobj
          (push-part (realize-argument
                      (other-end iobj predicate) state
                      :case :accusative
                      :preposition (or (relation-preposition iobj) "to")))))
      (dolist (rel (gethash :pp buckets))
        (push-part (realize-pp rel predicate state)))
      (dolist (rel (gethash :adv buckets))
        (push-part (realize-adv rel predicate state))))
    (format nil "~{~a~^ ~}" (nreverse parts))))

(defun head-is-object-of-p (head predicate buckets)
  "True when HEAD is the SURFACE direct object of PREDICATE — i.e. what
   would appear as the unmarked NP after the verb in an active sentence.
   For verbs like INFORM that take rcpt-as-direct, this is the recipient."
  (let* ((rcpt-direct (and predicate
                           (lexicon-prop (concept-type predicate) :rcpt-direct)))
         (surface-dobj-rel (first (if rcpt-direct
                                      (gethash :iobj buckets)
                                      (gethash :dobj buckets)))))
    (and head surface-dobj-rel (eq head (other-end surface-dobj-rel predicate)))))

(defun realize-passive-clause (predicate buckets state)
  "Render PREDICATE in passive voice: OBJ + 'is/are' + past-participle +
   the rest of the complements. Used when there is no AGNT/EXPR but the
   verb has a direct object (Phase 6)."
  (mark-clause-relations-traversed buckets state)
  (let* ((dobj-rel     (first (gethash :dobj buckets)))
         (subj-concept (and dobj-rel (other-end dobj-rel predicate)))
         (number       (if subj-concept (concept-number subj-concept) :singular))
         (tense        (let ((t* (concept-tense predicate)))
                         (if (or (null t*) (eq t* :progressive)) :present t*)))
         (be-form      (be-form-for tense number))
         (parts '()))
    (labels ((push-part (s) (when (and s (plusp (length s))) (push s parts))))
      (when subj-concept
        (push-part (realize-np subj-concept state :case :nominative)))
      (push-part be-form)
      (push-part (past-participle (base-lemma predicate)))
      (mark-uttered state predicate)
      (let ((iobj (first (gethash :iobj buckets))))
        (when iobj
          (push-part (realize-argument
                      (other-end iobj predicate) state
                      :case :accusative
                      :preposition (or (relation-preposition iobj) "to")))))
      (dolist (rel (gethash :pp buckets))
        (push-part (realize-pp rel predicate state)))
      (dolist (rel (gethash :adv buckets))
        (push-part (realize-adv rel predicate state))))
    (format nil "~{~a~^ ~}" (nreverse parts))))

(defun realize-copula-clause (topic state)
  "Render a verbless graph as TOPIC + 'is/are' + complements.
   Used when the graph has no subject-introducing relation (Phase 6)."
  (let* ((number  (concept-number topic))
         (copula  (if (eq number :plural) "are" "is"))
         (complements '()))
    (mark-uttered state topic)
    ;; Mark predicate-bearing relations traversed BEFORE rendering the topic
    ;; NP, so they don't get folded in as pre-modifiers of the noun.
    (dolist (rel (concept-relations topic))
      (when (member (relation-role rel) '(:adj :pp))
        (mark-traversed state rel)))
    (let ((topic-np (realize-full-np topic state)))
      (dolist (rel (concept-relations topic))
        (let ((role (relation-role rel))
              (other (other-end rel topic)))
          (when (and other (member role '(:adj :pp)))
            (cond ((eq role :adj)
                   (push (base-lemma other) complements))
                  ((eq role :pp)
                   (push (format nil "~@[~a ~]~a"
                                 (relation-preposition rel)
                                 (realize-np other state :case :accusative))
                         complements))))))
      (cond ((null complements) topic-np)
            (t (let ((joined (format nil "~{~a~^ and ~}" (nreverse complements))))
                 (format nil "~a ~a ~a" topic-np copula joined)))))))

(defun clause-level-pp-on-p (rel concept)
  "True if REL is a :pp adjunct on CONCEPT that should be emitted at clause
   level (e.g. 'sits at the place') rather than as an NP post-modifier."
  (and (eq (relation-role rel) :pp)
       (let* ((label (label (relation-type rel))))
         (find label *clause-level-pp-relations* :test #'string-equal))
       ;; CONCEPT must be the source side; otherwise the relation describes
       ;; the dest concept and shouldn't be lifted to this clause.
       (not (eq (outarc rel) concept))))

(defun promote-subject-adjuncts (subject-concept main-concept state)
  "For each clause-level :pp relation on SUBJECT-CONCEPT, mark it traversed
   so the subject NP doesn't fold it in, and return a list of PP strings to
   append after the verb. MAIN-CONCEPT is the predicate (used for ordering
   only — the relations themselves attach to the subject)."
  (declare (ignore main-concept))
  (let ((promoted '()))
    (dolist (rel (concept-relations subject-concept))
      (when (and (clause-level-pp-on-p rel subject-concept)
                 (not (traversed-p state rel)))
        (mark-traversed state rel)
        (let* ((other (other-end rel subject-concept))
               (prep  (or (np-pp-preposition rel subject-concept)
                          (relation-preposition rel))))
          (when (and other prep)
            (push (format nil "~a ~a" prep
                          (realize-np other state :case :accusative))
                  promoted)))))
    (nreverse promoted)))

(defun realize-clause (main-concept buckets state)
  (mark-clause-relations-traversed buckets state)
  (let ((parts '()))
    (labels ((push-part (s)
               (when (and s (plusp (length s))) (push s parts))))
      (let* ((subj-rel        (first (gethash :subject buckets)))
             (subject-concept (when subj-rel
                                (other-end subj-rel main-concept)))
             (adjuncts (and subject-concept
                            (promote-subject-adjuncts subject-concept
                                                      main-concept state))))
        (when subject-concept
          (push-part (realize-np subject-concept state :case :nominative)))
        (push-part (realize-predicate-body main-concept buckets state
                                           :subject-concept subject-concept))
        (dolist (pp adjuncts)
          (push-part pp))))
    (format nil "~{~a~^ ~}" (nreverse parts))))
