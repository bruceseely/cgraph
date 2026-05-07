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

(defun active-verb-form (predicate subject-concept)
  "Inflect PREDICATE in active voice, agreeing with SUBJECT-CONCEPT (or
   3rd person singular when none). Returns a one-element list — caller
   splices it into the surface order. Particles are placed by
   realize-active-arguments (split or joined depending on dobj)."
  (let* ((numbr  (if subject-concept (concept-number subject-concept) :singular))
         (person (if subject-concept (concept-person subject-concept) 3))
         (verb   (inflect-verb (base-lemma predicate)
                               :tense  (resolve-tense predicate)
                               :aspect (or (concept-aspect predicate) :simple)
                               :voice  :active
                               :person person :numbr numbr)))
    (list verb)))

(defun realize-active-arguments (predicate buckets state &key particle)
  "Render the direct- and indirect-object NPs of PREDICATE in surface
   order. Default frame: CG :dobj surfaces as the verb's direct object,
   CG :iobj as a 'to'-prep complement. Communication verbs
   (INFORM/TELL/...) flip this via the :rcpt-direct lexicon override —
   the recipient becomes the direct object and the information is
   demoted to a PP ('inform her about the news'). The :obj-prep override
   picks the preposition for the demoted info-arg, defaulting to 'about'.

   When PARTICLE is supplied (a phrasal-verb particle like 'up'/'out'),
   it splits around the dobj: 'pick up a pie' (joined; dobj is full NP)
   vs. 'pick it up' (split; dobj surfaces as a pronoun). Particle is
   emitted right after the verb when there is no dobj at all
   ('he shows off')."
  (let* ((ptype             (concept-type predicate))
         (rcpt-direct       (lexicon-prop ptype :rcpt-direct))
         (cg-dobj-rel       (first (gethash :dobj buckets)))
         (cg-iobj-rel       (first (gethash :iobj buckets)))
         (surface-dobj-rel  (if rcpt-direct cg-iobj-rel cg-dobj-rel))
         (surface-iobj-rel  (if rcpt-direct cg-dobj-rel cg-iobj-rel))
         (surface-iobj-prep
          (cond (rcpt-direct (lexicon-prop ptype :obj-prep "about"))
                (surface-iobj-rel
                 (or (relation-preposition surface-iobj-rel) "to"))
                (t nil)))
         (dobj-concept (and surface-dobj-rel
                            (other-end surface-dobj-rel predicate)))
         (split-particle-p (and particle dobj-concept
                                (would-surface-as-pronoun-p dobj-concept state)))
         (parts '()))
    (when (and particle (not split-particle-p))
      (push particle parts))
    (when dobj-concept
      (push (realize-argument dobj-concept state :case :accusative) parts))
    (when split-particle-p
      (push particle parts))
    (when surface-iobj-rel
      (push (realize-argument (other-end surface-iobj-rel predicate) state
                              :case :accusative
                              :preposition surface-iobj-prep)
            parts))
    (nreverse parts)))

(defun realize-adjuncts (predicate buckets state)
  "Render PP and adverbial adjuncts on PREDICATE, in bucket order.
   Voice-agnostic: shared by active and the two passive renderers."
  (let ((parts '()))
    (dolist (rel (gethash :pp buckets))
      (push (realize-pp rel predicate state) parts))
    (dolist (rel (gethash :adv buckets))
      (push (realize-adv rel predicate state) parts))
    (nreverse parts)))

(defun realize-predicate-body (predicate buckets state
                               &key subject-concept)
  "Emit verb + dobj + iobj + PPs + adverbs. SUBJECT-CONCEPT is consulted
   for verb agreement only; the subject NP is not rendered here. Used both
   by the main clause (with the subject prepended) and by relative clauses
   (where the head fills the subject slot)."
  (let ((parts '()))
    (labels ((push-part (s)
               (when (and s (plusp (length s))) (push s parts))))
      (mapc #'push-part (active-verb-form predicate subject-concept))
      (mark-uttered state predicate)
      (let ((particle (lexicon-prop (concept-type predicate) :particle)))
        (mapc #'push-part (realize-active-arguments predicate buckets state
                                                    :particle particle)))
      (mapc #'push-part (realize-adjuncts predicate buckets state)))
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

(defun realize-possessed-objects (possessor state)
  "Render the 'possessed' end of each POSS relation on POSSESSOR as an
   accusative NP. Returns the strings in graph order. Caller must have
   marked these relations traversed first, so the possessor NP doesn't
   fold them in as 's-prefixes."
  (let ((objects '()))
    (dolist (rel (concept-relations possessor))
      (when (and (traversed-p state rel) (eq (relation-role rel) :poss))
        (let ((possessed (other-end rel possessor)))
          (when possessed
            (push (realize-np possessed state :case :accusative) objects)))))
    (nreverse objects)))

(defun realize-have-clause (possessor state)
  "Render 'POSSESSOR has/have X (and Y ...)' for a POSS-only graph."
  (let ((have-form (if (eq (concept-number possessor) :plural) "have" "has")))
    (mark-uttered state possessor)
    ;; Mark the POSS relations traversed BEFORE rendering the topic NP
    ;; so they aren't folded back in as possessive prefixes.
    (dolist (rel (concept-relations possessor))
      (when (eq (relation-role rel) :poss)
        (mark-traversed state rel)))
    (let ((possessor-np (realize-full-np possessor state))
          (objects      (realize-possessed-objects possessor state)))
      (format nil "~a ~a ~{~a~^ and ~}" possessor-np have-form objects))))

(defun passive-verb-form (predicate surface-subj)
  "Inflect PREDICATE as a passive form agreeing in number with
   SURFACE-SUBJ (the patient promoted to surface subject). Returns a list
   of one or two strings: the verb plus the particle when registered."
  (let* ((number   (if surface-subj (concept-number surface-subj) :singular))
         (verb     (inflect-verb (base-lemma predicate)
                                 :tense  (resolve-tense predicate)
                                 :aspect (or (concept-aspect predicate) :simple)
                                 :voice  :passive :numbr number))
         (particle (lexicon-prop (concept-type predicate) :particle)))
    (if particle (list verb particle) (list verb))))

(defun realize-iobj-pp (predicate buckets state)
  "When PREDICATE has an :iobj relation, render it as a prepositional
   phrase ('to her' / 'about the news'). NIL otherwise. Used by both
   passive renderers; active goes through realize-active-arguments
   which folds in the rcpt-direct surface-frame flip."
  (let ((iobj (first (gethash :iobj buckets))))
    (when iobj
      (realize-argument (other-end iobj predicate) state
                        :case :accusative
                        :preposition (or (relation-preposition iobj) "to")))))

(defun clause-subject-concept (predicate buckets)
  "The CG subject concept of PREDICATE — the other end of the AGNT/EXPR
   relation in BUCKETS' :subject bucket. NIL when there is no subject
   relation."
  (let ((subj-rel (first (gethash :subject buckets))))
    (and subj-rel (other-end subj-rel predicate))))

(defun realize-passive-with-agent (predicate buckets state)
  "Head-driven passive (Sowa transformation): the OBJ becomes the surface
   subject and the AGNT is demoted to a 'by X' phrase. Used when the graph
   head is the patient/object rather than the agent."
  (mark-clause-relations-traversed buckets state)
  (let* ((dobj-rel     (first (gethash :dobj buckets)))
         (surface-subj (and dobj-rel (other-end dobj-rel predicate)))
         (agent        (clause-subject-concept predicate buckets))
         (parts        '()))
    (labels ((push-part (s) (when (and s (plusp (length s))) (push s parts))))
      (when surface-subj
        (push-part (realize-np surface-subj state :case :nominative)))
      (mapc #'push-part (passive-verb-form predicate surface-subj))
      (mark-uttered state predicate)
      (when agent
        (push-part (format nil "by ~a"
                           (realize-np agent state :case :accusative))))
      (push-part (realize-iobj-pp predicate buckets state))
      (mapc #'push-part (realize-adjuncts predicate buckets state)))
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
         (surface-subj (and dobj-rel (other-end dobj-rel predicate)))
         (parts        '()))
    (labels ((push-part (s) (when (and s (plusp (length s))) (push s parts))))
      (when surface-subj
        (push-part (realize-np surface-subj state :case :nominative)))
      (mapc #'push-part (passive-verb-form predicate surface-subj))
      (mark-uttered state predicate)
      (push-part (realize-iobj-pp predicate buckets state))
      (mapc #'push-part (realize-adjuncts predicate buckets state)))
    (format nil "~{~a~^ ~}" (nreverse parts))))

(defun realize-copula-complements (topic state)
  "Walk TOPIC's :adj and :pp relations and render them as predicate
   complements: adjectives as bare lemmas ('red'), PPs as
   preposition + NP ('in the bottle'). Returns the strings in graph
   order. Caller must have marked these relations traversed BEFORE
   rendering the topic NP, otherwise realize-full-np will fold them in
   a second time as pre-modifiers."
  (let ((complements '()))
    (dolist (rel (concept-relations topic))
      (let ((role  (relation-role rel))
            (other (other-end rel topic)))
        (when (and other (member role '(:adj :pp)))
          (cond ((eq role :adj)
                 (push (base-lemma other) complements))
                ((eq role :pp)
                 (push (format nil "~@[~a ~]~a"
                               (relation-preposition rel)
                               (realize-np other state :case :accusative))
                       complements))))))
    (nreverse complements)))

(defun realize-copula-clause (topic state)
  "Render a verbless graph as TOPIC + 'is/are' + complements.
   Used when the graph has no subject-introducing relation (Phase 6)."
  (let ((copula (if (eq (concept-number topic) :plural) "are" "is")))
    (mark-uttered state topic)
    ;; Mark predicate-bearing relations traversed BEFORE rendering the
    ;; topic NP, so they don't get folded in as pre-modifiers of the noun.
    (dolist (rel (concept-relations topic))
      (when (member (relation-role rel) '(:adj :pp))
        (mark-traversed state rel)))
    (let* ((topic-np    (realize-full-np topic state))
           (complements (realize-copula-complements topic state)))
      (cond ((null complements) topic-np)
            (t (format nil "~a ~a ~{~a~^ and ~}"
                       topic-np copula complements))))))

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
  ;; promote-subject-adjuncts MUST run before realize-np on the subject:
  ;; it marks clause-level PPs traversed so the NP doesn't fold them
  ;; back in as post-modifiers.
  (let* ((subject  (clause-subject-concept main-concept buckets))
         (adjuncts (and subject (promote-subject-adjuncts subject
                                                          main-concept state)))
         (parts    '()))
    (labels ((push-part (s)
               (when (and s (plusp (length s))) (push s parts))))
      (when subject
        (push-part (realize-np subject state :case :nominative)))
      (push-part (realize-predicate-body main-concept buckets state
                                         :subject-concept subject))
      (dolist (pp adjuncts)
        (push-part pp)))
    (format nil "~{~a~^ ~}" (nreverse parts))))

;;; --- Raising (Sowa Rule 4 second half) -------------------------------------
;;; A cognitive verb with :raising in the lexicon and a clausal :dobj
;;; surfaces in the no-agent case as 'X is believed to be Y' instead of
;;; the awkward fallback ('A believe.', 'It is believed that X is Y').
;;; The detector raising-info lives in generate.lisp next to active-
;;; conjunct-info; this file holds the renderers.

(defun realize-verbal-infinitive (main buckets state)
  "Render 'to <verb> <complements>' for raising — the inner predicate
   stripped of its subject. Particles thread through realize-active-
   arguments; PP/adv adjuncts follow."
  (mark-clause-relations-traversed buckets state)
  (mark-uttered state main)
  (let* ((particle (lexicon-prop (concept-type main) :particle))
         (verb     (base-lemma main))
         (args     (realize-active-arguments main buckets state :particle particle))
         (adjuncts (realize-adjuncts main buckets state))
         (parts    (append (list "to" verb) args adjuncts)))
    (format nil "~{~a~^ ~}"
            (remove-if (lambda (s) (or (null s) (zerop (length s)))) parts))))

(defun realize-copula-infinitive (topic state)
  "Render 'to be <complements>' for raising — the inner copular clause
   stripped of its topic NP (which has been lifted to the outer
   surface subject). Mirrors realize-copula-clause without the topic."
  (mark-uttered state topic)
  (dolist (rel (concept-relations topic))
    (when (member (relation-role rel) '(:adj :pp))
      (mark-traversed state rel)))
  (let ((complements (realize-copula-complements topic state)))
    (cond ((null complements) "to be")
          (t (format nil "to be ~{~a~^ and ~}" complements)))))

(defun realize-passive-raising (predicate buckets state)
  "Render the passive-raising form: '<inner-subject> is/are <past-
   participle> to <inner-infinitive>'. Lifts the inner clause's subject
   to the outer surface and strips it from the inner rendering. Returns
   the empty string when raising-info doesn't apply."
  (multiple-value-bind (mode inner-subj inner-main inner-buckets dobj-concept)
      (raising-info predicate buckets)
    (cond ((null mode) "")
          (t
           (mark-clause-relations-traversed buckets state)
           (mark-uttered state predicate)
           (mark-uttered state dobj-concept)
           ;; Active inner: pre-mark its :subject relation traversed so
           ;; the lifted NP doesn't pick the inner predicate up as a
           ;; relative clause.
           (when (eq mode :active)
             (dolist (rel (gethash :subject inner-buckets))
               (mark-traversed state rel)))
           ;; Copular inner: pre-mark :adj/:pp on the topic so they
           ;; don't fold into the lifted NP — they'll surface as the
           ;; 'to be X' complements instead.
           (when (eq mode :copula)
             (dolist (rel (concept-relations inner-subj))
               (when (member (relation-role rel) '(:adj :pp))
                 (mark-traversed state rel))))
           (let* ((subj-np    (realize-np inner-subj state :case :nominative))
                  (verb-list  (passive-verb-form predicate inner-subj))
                  (infinitive (case mode
                                (:active (realize-verbal-infinitive
                                          inner-main inner-buckets state))
                                (:copula (realize-copula-infinitive
                                          inner-subj state)))))
             (format nil "~a ~{~a~^ ~} ~a" subj-np verb-list infinitive))))))
