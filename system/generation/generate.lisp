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

(defun coordinator-pair (relations)
  "Return (values label left-concept right-concept) when RELATIONS contains
   an AND/OR relation linking exactly two concepts; NIL otherwise. The
   label is lowercased ('and' / 'or') and ready to splice into output."
  (let ((rel (find-if (lambda (r)
                        (member (label (relation-type r))
                                '("and" "or")
                                :test #'string-equal))
                      relations)))
    (when (and rel (= 2 (length (arcs rel))))
      (values (string-downcase (label (relation-type rel)))
              (first (inarcs rel))
              (outarc rel)))))

(defun realize-coordination (label left right state)
  "Render two propositions joined by 'and'/'or'. Both sides must carry a
   graph referent; we recurse through realize-nested-graph (the same
   machinery that produces 'that <inner>' for embedded clauses, minus the
   leading 'that') and join the two clauses with the conjunction."
  (let* ((g1 (graph-referent left))
         (g2 (graph-referent right))
         (s1 (and g1 (realize-nested-graph g1 state)))
         (s2 (and g2 (realize-nested-graph g2 state))))
    (cond ((or (null s1) (null s2) (zerop (length s1)) (zerop (length s2))) "")
          (t (format nil "~a ~a ~a" s1 label s2)))))

(defun realize-graph-clause (nodes state &optional head)
  "Render NODES as a single clause: AND/OR coordination, voice-annotated /
   head-driven passive, active, subjectless passive, have-clause, or
   copula. Shared by the top-level entry point and by realize-nested-graph
   so a nested graph dispatches the same way as a top-level one."
  (let ((relations (graph-relations-of nodes))
        (concepts  (graph-concepts-of nodes)))
    (or (multiple-value-bind (lbl l r) (coordinator-pair relations)
          (and lbl (realize-coordination lbl l r state)))
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
