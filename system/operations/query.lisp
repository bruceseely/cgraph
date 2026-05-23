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

(defgeneric query (pattern context &key first-only)
  (:documentation
   "Query a context for graphs matching a pattern.
    Returns a list of results, each containing:
      (:graph <head-concept> :bindings ((var . concept) ...))
    Pattern may contain variables (*x, *y) which will be bound
    to the matching concepts in each result.
    With :first-only t, stops after finding the first matching graph."))


(defmethod query ((pattern string) (context context) &key first-only)
  "Parse pattern and query context for matching graphs."
  (let* ((pattern-head (car (parse-cgraph pattern)))
         (saved-variables *variables*)
         (results (list)))
    (dolist (graph (graphs context))
      (let* ((graph-nodes (nodes graph))
             (target-head (find-if (lambda (node) (typep node 'concept)) graph-nodes))
             (mappings (when target-head
                         (let ((*variables* saved-variables))
                           (project pattern-head target-head :all-solutions t)))))
        (dolist (mapping mappings)
          (push (list :graph target-head
                      :bindings (extract-bindings mapping saved-variables))
                results))
        (when (and first-only mappings)
          (return))))
    (nreverse results)))






    ;; (let ((result (list)))
    ;;   (dolist (rec results)
    ;;     ;;(format t "~&rec: ~s~%"  rec)
    ;;     (dolist (binding (getf rec :bindings))
    ;;       (push binding result)))
    ;;   result)))


        ;;(format t "~&save: ~s~%"  save)
        ;;(format t "~&res: ~s~%"  res)
        ;;(format t "~&graph:  ~s  bindings: ~s~%" (getf res :graph) (getf res :bindings))
        ;;(print (mapcar (lambda (x) (getf x :bindings)) results))





(defmethod query ((pattern graph-node) (context context) &key first-only)
  "Query context using an already-parsed pattern graph node."
  (let ((results (list)))
    (dolist (node-list (graphs context))
      (let* ((target-head (find-if (lambda (node) (typep node 'concept)) node-list))
             (mappings (when target-head
                         (project pattern target-head :all-solutions t))))
        (dolist (mapping mappings)
          (push (list :graph target-head
                      :bindings (extract-bindings mapping *variables*))
                results))
        (when (and first-only mappings)
          (return))))
    (nreverse results)))


(defmethod query :around (pattern context &key first-only)
  (let ((results (call-next-method))
        (texts (list)))
    (dolist (result results)
      (push (say (pcg (getf result :graph))) texts))
    (values results texts)))


(defmethod say-query-results ((results list))
  (let ((texts (list)))
    (dolist (result results)
      (let ((graph (getf result :graph)))
        (push (say (pcg graph)) texts)))
    texts))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; EXTRACT-BINDINGS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun extract-bindings (mapping variable-cache)
  "Extract variable bindings from a projection mapping.
   For each (pattern-concept . target-concept) pair where the pattern
   concept has a variable, return (variable-symbol . target-concept).
   Recursively extracts bindings from nested graph referent projections."
  (let ((bindings (list)))
    (dolist (pair mapping)
      (let* ((pattern-concept (car pair))
             (target-concept (cdr pair))
             (var-name (gethash pattern-concept (variables variable-cache))))
        (when var-name
          (push (cons var-name target-concept) bindings))
        (let ((pattern-graph (graph-referent pattern-concept))
              (target-graph (graph-referent target-concept)))
          (when (and pattern-graph target-graph)
            (let ((inner-mapping (project (head pattern-graph) (head target-graph))))
              (when inner-mapping
                (dolist (binding (extract-bindings inner-mapping variable-cache))
                  (push binding bindings))))))))
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
