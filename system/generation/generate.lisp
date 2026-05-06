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

(defun realize-coordination (label concepts state)
  "Render N propositions joined by 'and' or 'or'. Each concept must
   carry a graph referent; we recurse through realize-nested-graph
   (which routes through realize-graph-clause so per-conjunct tense,
   voice, etc. flow naturally) and join with Oxford-comma punctuation:
   'A and B' (binary), 'A, B, and C' (n-ary)."
  (let ((clauses (mapcar (lambda (c)
                           (let ((g (graph-referent c)))
                             (and g (realize-nested-graph g state))))
                         concepts)))
    (cond ((some (lambda (s) (or (null s) (zerop (length s)))) clauses) "")
          (t (join-with-conjunction clauses label)))))

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
