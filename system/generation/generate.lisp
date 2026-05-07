;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Top-level entry point for graph-to-text generation.
;;  Dispatch order:
;;    1. Active verbal clause   — when a subject relation (AGNT/EXPR) exists.
;;    2. Passive verbal clause  — when there is an act/event/state concept
;;                                but no subject relation (e.g. [PIE]<-(obj)<-[EAT]).
;;    3. Copular clause         — verbless graphs with attributes/locations.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun coordinator-relations (relations)
  "Filter RELATIONS down to binary AND/OR relations (the ones that link
   two concepts via a single inarc and outarc). NIL when none."
  (remove-if-not
   (lambda (r)
     (and (= 2 (length (arcs r)))
          (member (label (relation-type r))
                  '("and" "or")
                  :test #'string-equal)))
   relations))

(defun order-coordinator-chain (coord-rels)
  "Treat each AND/OR relation as a directed edge inarc->outarc and walk
   them as a single linear chain. Returns the ordered list of concepts,
   or NIL when the relations don't form one chain (branching, cycles,
   disconnected pieces)."
  (let* ((edges (mapcar (lambda (r) (cons (first (inarcs r)) (outarc r)))
                        coord-rels))
         (sources (mapcar #'car edges))
         (dests   (mapcar #'cdr edges))
         (head    (find-if-not (lambda (s) (member s dests)) sources)))
    (when head
      (let ((chain    (list head))
            (next     head)
            (remaining edges))
        (loop
          (let ((edge (find next remaining :key #'car)))
            (cond ((null edge)
                   (return (and (null remaining) chain)))
                  (t (setf next (cdr edge))
                     (setf chain (append chain (list next)))
                     (setf remaining (remove edge remaining :test #'eq))))))))))

(defun coordinator-chain (relations)
  "Return (values label concept-list) when RELATIONS contains one or
   more AND-relations or OR-relations linking propositions in a single
   linear chain. The label is lowercased and concept-list is in surface
   order. Mixed and/or chains return NIL — the caller falls through to
   non-coordination dispatch."
  (let* ((coord-rels (coordinator-relations relations))
         (labels     (remove-duplicates
                      (mapcar (lambda (r)
                                (string-downcase (label (relation-type r))))
                              coord-rels)
                      :test #'string=)))
    (when (and coord-rels (= 1 (length labels)))
      (let ((chain (order-coordinator-chain coord-rels)))
        (when (and chain (>= (length chain) 2))
          (values (first labels) chain))))))

(defun active-conjunct-info (concept)
  "Inspect CONCEPT (a proposition referent in an AND/OR chain) and
   decide whether it would render as an active verbal clause. Returns
   (values main buckets head) when yes, NIL when the conjunct would
   dispatch to passive/copula/have/coord — in which case shared-subject
   collapse is skipped and the caller falls back to per-clause rendering."
  (let* ((g (and concept (graph-referent concept)))
         (nodes (and g (graph-nodes g)))
         (head  (and (typep g 'graph) (head g)))
         (relations (and nodes (graph-relations-of nodes))))
    (when (and relations (find-subject-relation relations))
      (let* ((main    (find-main-predicate nodes))
             (buckets (and main (classify-relations main))))
        (when main
          (let ((voice (concept-voice main)))
            (cond ((eq voice :passive) nil)
                  ((eq voice :active) (values main buckets head))
                  ((head-is-object-of-p head main buckets) nil)
                  (t (values main buckets head)))))))))

(defun shared-coordination-subject (concepts)
  "When every concept in CONCEPTS is a proposition that would render as
   an active clause AND all of those clauses' subjects refer to the
   same individual (instance equality, shared coref-bound-label, or
   matching referent id via same-individual-p), return the first
   conjunct's subject — that's the surface subject of the collapsed
   form. NIL when any conjunct would dispatch to a non-active clause
   shape, or when the subjects don't agree."
  (let ((shared nil))
    (dolist (c concepts shared)
      (multiple-value-bind (main buckets) (active-conjunct-info c)
        (cond ((null main) (return nil))
              (t (let ((subj (clause-subject-concept main buckets)))
                   (cond ((null subj) (return nil))
                         ((null shared) (setf shared subj))
                         ((not (same-individual-p shared subj))
                          (return nil))))))))))

(defun realize-shared-subject-coordination (label concepts shared-subj state)
  "Render the collapsed form: subject NP once, followed by a coordinated
   verb phrase. Each conjunct contributes only its predicate body (verb
   + complements, no subject NP) via realize-predicate-body. Verb
   agreement uses the conjunct's local subject concept, which carries
   the same number/person as SHARED-SUBJ."
  ;; Pre-mark each conjunct's subject relation traversed BEFORE rendering
  ;; the shared subject NP. Without this, realize-full-np finds the
  ;; first conjunct's AGNT relation as an unrealized predication and
  ;; emits a relative clause ('Sue who eats eats and drinks').
  (dolist (c concepts)
    (multiple-value-bind (main buckets) (active-conjunct-info c)
      (declare (ignore main))
      (when buckets
        (dolist (rel (gethash :subject buckets))
          (mark-traversed state rel)))))
  (let* ((subj-np (realize-np shared-subj state :case :nominative))
         (vps (mapcar
               (lambda (c)
                 (multiple-value-bind (main buckets) (active-conjunct-info c)
                   (when main
                     (let ((local-subj (clause-subject-concept main buckets)))
                       (mark-clause-relations-traversed buckets state)
                       (realize-predicate-body main buckets state
                                               :subject-concept local-subj)))))
               concepts)))
    (cond ((or (null subj-np) (zerop (length subj-np))) "")
          ((some (lambda (v) (or (null v) (zerop (length v)))) vps) "")
          (t (format nil "~a ~a" subj-np
                     (join-with-conjunction vps label))))))

(defun raising-info (predicate buckets)
  "When PREDICATE has :raising in its lexicon entry AND a clausal :dobj
   whose inner graph dispatches cleanly, return (values mode inner-subj
   inner-main inner-buckets dobj-concept). Mode is :active when the
   inner clause is verbal with a subject, :copula when it's verbless
   with a topic carrying :adj/:pp predicates. NIL when raising doesn't
   apply (no flag, no clausal dobj, or unsupported inner shape)."
  (when (lexicon-prop (concept-type predicate) :raising)
    (let* ((dobj-rel (first (gethash :dobj buckets)))
           (dobj-concept (and dobj-rel (other-end dobj-rel predicate))))
      (when (and dobj-concept (clausal-concept-p dobj-concept))
        ;; Try active dispatch first (inner clause has a subject).
        (multiple-value-bind (main inner-buckets) (active-conjunct-info dobj-concept)
          (let ((subj (and main (clause-subject-concept main inner-buckets))))
            (cond (subj (values :active subj main inner-buckets dobj-concept))
                  (t
                   ;; Fall back to copular inner: topic with :adj/:pp.
                   (let* ((g (graph-referent dobj-concept))
                          (nodes (and g (graph-nodes g)))
                          (topic (and nodes (find-copula-topic nodes))))
                     (when (and topic
                                (some (lambda (r)
                                        (member (relation-role r) '(:adj :pp)))
                                      (concept-relations topic)))
                       (values :copula topic nil nil dobj-concept)))))))))))

(defun find-passive-raising-predicate (concepts)
  "When CONCEPTS contains a single state/event concept whose lexicon
   entry has :raising and whose buckets pass raising-info, return
   (values predicate buckets). NIL otherwise. Used by realize-graph-
   clause's no-subject branch to dispatch to passive raising before
   falling through to act-or-event/copula."
  (dolist (c concepts)
    (when (lexicon-prop (concept-type c) :raising)
      (let ((buckets (classify-relations c)))
        (when (raising-info c buckets)
          (return-from find-passive-raising-predicate
            (values c buckets))))))
  nil)

(defun realize-coordination (label concepts state)
  "Render N propositions joined by 'and' or 'or'. When all conjuncts
   share a subject ('Sue eats and Sue drinks'), collapse to shared-
   subject form ('Sue eats and drinks'). Otherwise render each conjunct
   as a full clause via realize-nested-graph and join with Oxford-comma
   punctuation: 'A and B' (binary), 'A, B, and C' (n-ary)."
  (let ((shared-subj (shared-coordination-subject concepts)))
    (cond (shared-subj
           (realize-shared-subject-coordination label concepts shared-subj state))
          (t
           (let ((clauses (mapcar (lambda (c)
                                    (let ((g (graph-referent c)))
                                      (and g (realize-nested-graph g state))))
                                  concepts)))
             (cond ((some (lambda (s) (or (null s) (zerop (length s)))) clauses) "")
                   (t (join-with-conjunction clauses label))))))))

(defun realize-graph-clause (nodes state &optional head)
  "Render NODES as a single clause: AND/OR coordination, voice-annotated /
   head-driven passive, active, subjectless passive, have-clause, or
   copula. Shared by the top-level entry point and by realize-nested-graph
   so a nested graph dispatches the same way as a top-level one."
  (let ((relations (graph-relations-of nodes))
        (concepts  (graph-concepts-of nodes)))
    (or (multiple-value-bind (lbl concepts) (coordinator-chain relations)
          (and lbl (realize-coordination lbl concepts state)))
        (cond ((find-subject-relation relations)
               (let* ((main    (find-main-predicate nodes))
                      (buckets (and main (classify-relations main))))
                 (cond ((null main) "")
                       ;; '@passive' on the verb forces the passive
                       ;; transformation regardless of which side the
                       ;; head is on; '@active' explicitly suppresses
                       ;; the head-driven passive choice.
                       ((eq (concept-voice main) :passive)
                        (realize-passive-with-agent main buckets state))
                       ((eq (concept-voice main) :active)
                        (realize-clause main buckets state))
                       ;; Sowa transformation: when the graph head is the
                       ;; patient rather than the agent, render in passive
                       ;; voice with a 'by X' phrase. The head is the user's
                       ;; topical entry point into the graph.
                       ((head-is-object-of-p head main buckets)
                        (realize-passive-with-agent main buckets state))
                       (t (realize-clause main buckets state)))))
              ;; Passive raising: a cognitive verb with :raising in its
              ;; lexicon entry and a clausal :dobj. 'Ivan is believed to
              ;; be in a place' rather than the awkward fallback that
              ;; would otherwise kick in for a stative verb without
              ;; an EXPR/AGNT.
              ((multiple-value-bind (pred buckets)
                   (find-passive-raising-predicate concepts)
                 (and pred (realize-passive-raising pred buckets state))))
              ((find-if #'act-or-event-concept-p concepts)
               (let* ((main    (find-if #'act-or-event-concept-p concepts))
                      (buckets (classify-relations main)))
                 (realize-passive-clause main buckets state)))
              ((have-clause-p nodes)
               (let ((possessor (find-poss-source nodes)))
                 (cond ((null possessor) "")
                       (t (realize-have-clause possessor state)))))
              (t
               (let ((topic (find-copula-topic nodes)))
                 (cond ((null topic) "")
                       (t (realize-copula-clause topic state)))))))))

(defun graph-to-text (graph)
  "Convert a conceptual graph to an English sentence."
  (let* ((nodes  (graph-nodes graph))
         (head   (and (typep graph 'graph) (head graph)))
         (state  (make-walk-state))
         (clause (realize-graph-clause nodes state head)))
    (cond ((zerop (length clause)) "")
          (t (let* ((leftover (unexpressed-poss-relations nodes state))
                    (tail     (realize-leftover-poss leftover state)))
               (finalize-sentence (concatenate 'string clause tail)))))))

(defun finalize-sentence (clause)
  (capitalize-first (string-trim " " (format nil "~a." clause))))

(defun capitalize-first (s)
  (cond ((zerop (length s)) s)
        (t (concatenate 'string
                        (string (char-upcase (char s 0)))
                        (subseq s 1)))))


(defun say (graph &optional stream)
  (let ((text (graph-to-text graph)))
    (cond ((null stream) text)
          (t (format stream "~a" text)))))
