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
  (cond ((uttered-p state concept)
         (or (pronoun-for concept :case case)
             (format nil "the ~a" (noun-form concept))))
        (t
         (mark-uttered state concept)
         (realize-full-np concept state))))

(defun realize-full-np (concept state)
  (let ((mods-pre  '())
        (head      (noun-form concept))
        (article   nil))
    (dolist (rel (concept-relations concept))
      (let ((role (relation-role rel)))
        ;; Skip relations already traversed (e.g. consumed by a copular
        ;; clause as a predicate complement) to avoid double-emission.
        (cond ((and (eq role :adj) (not (traversed-p state rel)))
               (let ((mod (other-end rel concept)))
                 (when (and mod (not (eq mod concept)))
                   (push (base-lemma mod) mods-pre))))
              ((and (eq role :poss) (not (traversed-p state rel)))
               (let ((owner (other-end rel concept)))
                 (when owner
                   (push (format nil "~a's"
                                 (if (eq (concept-definiteness owner) :proper)
                                     (cap (base-lemma owner))
                                     (base-lemma owner)))
                         mods-pre)))))))
    (setf mods-pre (nreverse mods-pre))
    (let ((first-word (or (first mods-pre) head)))
      (setf article (article-for concept first-word)))
    (when (some (lambda (m) (search "'s" m)) mods-pre)
      (setf article nil))
    (let ((np-text (string-trim
                    " "
                    (format nil "~@[~a ~]~{~a ~}~a"
                            article mods-pre head)))
          (rel-clauses (relative-clauses-for concept state)))
      (cond (rel-clauses
             (format nil "~a ~{~a~^, ~}" np-text rel-clauses))
            (t np-text)))))

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
      (let ((dobj (first (gethash :dobj buckets))))
        (when dobj
          (push-part (realize-argument (other-end dobj predicate) state
                                       :case :accusative))))
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

;;; --- Clause assembly --------------------------------------------------------

(defun mark-clause-relations-traversed (buckets state)
  "Mark every relation in BUCKETS as traversed, so that subordinate NPs
   don't try to relativize a relation already accounted for."
  (maphash (lambda (k rels)
             (declare (ignore k))
             (dolist (r rels)
               (mark-traversed state r)))
           buckets))

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
