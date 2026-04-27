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

(defun graph-to-text (graph)
  "Convert a conceptual graph to an English sentence."
  (let* ((nodes     (graph-nodes graph))
         (head      (and (typep graph 'graph) (head graph)))
         (relations (graph-relations-of nodes))
         (concepts  (graph-concepts-of nodes))
         (state     (make-walk-state))
         (clause
          (cond ((find-subject-relation relations)
                 (let* ((main    (find-main-predicate nodes))
                        (buckets (and main (classify-relations main))))
                   (cond ((null main) "")
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
                         (t (realize-copula-clause topic state))))))))
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
