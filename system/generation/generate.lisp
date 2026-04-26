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
         (relations (graph-relations-of nodes))
         (concepts  (graph-concepts-of nodes))
         (state     (make-walk-state)))
    (cond ((find-subject-relation relations)
           (let* ((main    (find-main-predicate nodes))
                  (buckets (and main (classify-relations main))))
             (cond ((null main) "")
                   (t (finalize-sentence
                       (realize-clause main buckets state))))))
          ((find-if #'act-or-event-concept-p concepts)
           (let* ((main    (find-if #'act-or-event-concept-p concepts))
                  (buckets (classify-relations main)))
             (finalize-sentence
              (realize-passive-clause main buckets state))))
          (t
           (let ((topic (find-copula-topic nodes)))
             (cond ((null topic) "")
                   (t (finalize-sentence
                       (realize-copula-clause topic state)))))))))

(defun finalize-sentence (clause)
  (capitalize-first (string-trim " " (format nil "~a." clause))))

(defun capitalize-first (s)
  (cond ((zerop (length s)) s)
        (t (concatenate 'string
                        (string (char-upcase (char s 0)))
                        (subseq s 1)))))
