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

(defun realize-full-np (concept state)
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
          (pp-mods (np-post-modifiers concept state))
          (rel-clauses (relative-clauses-for concept state)))
      (format nil "~a~@[ ~{~a~^ ~}~]~@[ ~{~a~^, ~}~]"
              np-text pp-mods rel-clauses))))

(defun np-post-modifiers (concept state)
  "Collect PP post-modifiers (e.g. 'in a bottle', 'with a belly') for an NP
   head from its :pp relations. Direction-aware: the preposition flips
   depending on whether CONCEPT is the source or destination of the rel."
  (let ((mods '()))
    (dolist (rel (concept-relations concept))
      (when (and (eq (relation-role rel) :pp)
                 (not (traversed-p state rel)))
        (let ((prep  (np-pp-preposition rel concept))
              (other (other-end rel concept)))
          (when (and prep other)
            (mark-traversed state rel)
            (push (format nil "~a ~a" prep
                          (realize-np other state :case :accusative))
                  mods)))))
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
             (verb   (inflect-verb lemma :tense :present
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
         (be-form      (if (eq number :plural) "are" "is"))
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
         (be-form      (if (eq number :plural) "are" "is"))
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
      (let ((joined (format nil "~{~a~^ and ~}" (nreverse complements))))
        (format nil "~a ~a ~a" topic-np copula joined)))))

(defun realize-clause (main-concept buckets state)
  (mark-clause-relations-traversed buckets state)
  (let ((parts '()))
    (labels ((push-part (s)
               (when (and s (plusp (length s))) (push s parts))))
      (let* ((subj-rel        (first (gethash :subject buckets)))
             (subject-concept (when subj-rel
                                (other-end subj-rel main-concept))))
        (when subject-concept
          (push-part (realize-np subject-concept state :case :nominative)))
        (push-part (realize-predicate-body main-concept buckets state
                                           :subject-concept subject-concept))))
    (format nil "~{~a~^ ~}" (nreverse parts))))
