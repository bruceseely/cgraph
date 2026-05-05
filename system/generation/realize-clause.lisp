;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Clause-level assembly: predicate body (verb + complements), and the
;;  five top-level clause shapes — active, head-driven passive,
;;  subjectless passive, copula, and have-clause — plus the leftover-POSS
;;  tail. Top-level dispatch among these lives in generate.lisp
;;  (realize-graph-clause); this file holds the renderers themselves.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
             (tense  (resolve-tense predicate))
             (aspect (or (concept-aspect predicate) :simple))
             (verb   (inflect-verb lemma :tense tense :aspect aspect
                                         :voice :active
                                         :person person :numbr numbr))
             (particle (lexicon-prop (concept-type predicate) :particle)))
        (push-part verb)
        (when particle (push-part particle)))
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
         (tense        (resolve-tense predicate))
         (aspect       (or (concept-aspect predicate) :simple))
         (verb         (inflect-verb (base-lemma predicate)
                                     :tense tense :aspect aspect
                                     :voice :passive :numbr number))
         (parts        '()))
    (labels ((push-part (s) (when (and s (plusp (length s))) (push s parts))))
      (when surface-subj
        (push-part (realize-np surface-subj state :case :nominative)))
      (push-part verb)
      (let ((particle (lexicon-prop (concept-type predicate) :particle)))
        (when particle (push-part particle)))
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
         (tense        (resolve-tense predicate))
         (aspect       (or (concept-aspect predicate) :simple))
         (verb         (inflect-verb (base-lemma predicate)
                                     :tense tense :aspect aspect
                                     :voice :passive :numbr number))
         (parts '()))
    (labels ((push-part (s) (when (and s (plusp (length s))) (push s parts))))
      (when subj-concept
        (push-part (realize-np subj-concept state :case :nominative)))
      (push-part verb)
      (let ((particle (lexicon-prop (concept-type predicate) :particle)))
        (when particle (push-part particle)))
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
