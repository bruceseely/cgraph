;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Graph Query System for Conceptual Graphs
;;; Query a context (knowledge base) for graphs matching a pattern
;;; and return variable bindings.
;;;

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; QUERY - Main Entry Point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgeneric query (pattern context &key all-solutions)
  (:documentation
   "Query a context for graphs matching a pattern.
    Returns a list of results, each containing:
      (:graph <head-concept> :bindings ((var . concept) ...))
    Pattern may contain variables (*x, *y) which will be bound
    to the matching concepts in each result."))


(defmethod query ((pattern string) (context context) &key all-solutions)
  "Parse pattern and query context for matching graphs."
  (let* ((pattern-graph (parse-cgraph pattern))
         (pattern-head (head pattern-graph))
         (saved-variables *variables*)
         (results (list)))
    (dolist (node-list (graphs context))
      (let* ((target-head (find-if (lambda (node) (typep node 'concept)) node-list))
             (mappings (when target-head
                         (let ((*variables* saved-variables))
                           (if all-solutions
                               (project pattern-head target-head :all-solutions t)
                               (let ((m (project pattern-head target-head)))
                                 (when m (list m))))))))
        (dolist (mapping mappings)
          (push (list :graph target-head
                      :bindings (extract-bindings mapping saved-variables))
                results))))
    (nreverse results)))


(defmethod query ((pattern graph-node) (context context) &key all-solutions)
  "Query context using an already-parsed pattern graph node."
  (let ((results (list)))
    (dolist (node-list (graphs context))
      (let* ((target-head (find-if (lambda (node) (typep node 'concept)) node-list))
             (mappings (when target-head
                         (if all-solutions
                             (project pattern target-head :all-solutions t)
                             (let ((m (project pattern target-head)))
                               (when m (list m)))))))
        (dolist (mapping mappings)
          (push (list :graph target-head
                      :bindings (extract-bindings mapping *variables*))
                results))))
    (nreverse results)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; EXTRACT-BINDINGS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun extract-bindings (mapping variable-cache)
  "Extract variable bindings from a projection mapping.
   For each (pattern-concept . target-concept) pair where the pattern
   concept has a variable, return (variable-symbol . target-concept)."
  (let ((bindings (list)))
    (dolist (pair mapping)
      (let* ((pattern-concept (car pair))
             (target-concept (cdr pair))
             (var-name (gethash pattern-concept (variables variable-cache))))
        (when var-name
          (push (cons var-name target-concept) bindings))))
    (nreverse bindings)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; FORMAT-QUERY-RESULTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun format-query-results (results &optional (stream *standard-output*))
  "Pretty-print query results."
  (if (null results)
      (format stream "~&No matches found.~%")
      (progn
        (format stream "~&~d match~:p found:~%" (length results))
        (dolist (result results)
          (let ((target (getf result :graph))
                (bindings (getf result :bindings)))
            (format stream "~&  Graph: ~a~%" (format-cgraph target))
            (when bindings
              (dolist (binding bindings)
                (format stream "~&    ~a = ~a~%"
                        (car binding)
                        (format-concept (cdr binding)))))))))
  (values))
