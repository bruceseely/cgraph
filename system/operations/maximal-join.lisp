;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Maximal Join Operation for Conceptual Graphs
;;; Finds the largest structurally-compatible overlap between two CGs,
;;; copies both graphs, joins the overlapping concepts, and returns the merged result.
;;;

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MAXIMAL JOIN - Main Entry Points
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgeneric maximal-join (graph1 graph2)
  (:documentation
   "Compute the maximal join of two conceptual graphs.
    Finds the largest set of joinable concept pairs that are structurally
    compatible, copies both graphs, joins the overlapping concepts, and
    returns the head node of the merged result.
    Returns a copy of graph1 if no overlap exists."))


(defmethod maximal-join ((graph1 graph-node) (graph2 graph-node))
  "Maximal join of two graphs starting from head nodes."
  (let* ((concepts1 (collect-concepts graph1))
         (concepts2 (collect-concepts graph2))
         (relations1 (collect-relations graph1))
         (relations2 (collect-relations graph2))
         (mapping (find-maximal-compatible-mapping
                   concepts1 concepts2 relations1 relations2)))
    (execute-maximal-join graph1 graph2 mapping)))


(defmethod maximal-join ((graph1 graph) (graph2 graph))
  "Maximal join of two graph objects."
  (maximal-join (head graph1) (head graph2)))


(defmethod maximal-join ((graph1 string) (graph2 string))
  "Parse strings and compute maximal join."
  (let ((g1 (parse-cgraph graph1))
        (g2 (parse-cgraph graph2)))
    (maximal-join g1 g2)))


(defmethod maximal-join ((graph1 graph-node) (graph2 graph))
  "Maximal join of node and graph object."
  (maximal-join graph1 (head graph2)))


(defmethod maximal-join ((graph1 graph) (graph2 graph-node))
  "Maximal join of graph object and node."
  (maximal-join (head graph1) graph2))


(defmethod maximal-join ((graph1 string) (graph2 graph-node))
  "Parse first string, join with second."
  (maximal-join (parse-cgraph graph1) graph2))


(defmethod maximal-join ((graph1 graph-node) (graph2 string))
  "Join first with parsed second string."
  (maximal-join graph1 (parse-cgraph graph2)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PHASE 1: Find Maximal Compatible Mapping
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun build-candidate-map (concepts1 concepts2)
  "For each concept in concepts1, find all concepts in concepts2 that are joinable.
   Returns an alist of (c1 . candidates) pairs."
  (mapcar (lambda (c1)
            (cons c1 (remove-if-not (lambda (c2)
                                      (concepts-joinable-p c1 c2))
                                    concepts2)))
          concepts1))


(defun find-maximal-compatible-mapping (concepts1 concepts2 relations1 relations2)
  "Find the largest set of (c1 . c2) pairs such that:
   - Each c1 is from concepts1, each c2 is from concepts2
   - concepts-joinable-p holds for each pair
   - The mapping is injective (each c2 used at most once)
   - Relations among mapped concepts have matching counterparts in both graphs.
   Uses branch-and-bound backtracking with MRV heuristic."
  (let* ((candidate-map (build-candidate-map concepts1 concepts2))
         ;; Order by fewest candidates first (MRV heuristic)
         (ordered (sort (copy-list candidate-map) #'<
                        :key (lambda (entry) (length (cdr entry)))))
         (best-mapping nil)
         (best-size 0))

    (labels ((do-search (remaining current-mapping used-targets current-size)
               ;; Pruning: even mapping all remaining cannot beat best
               (when (<= (+ current-size (length remaining)) best-size)
                 (return-from do-search))

               (cond
                 ;; Base case: no more concepts to consider
                 ((null remaining)
                  ;; Full consistency check as safety net
                  (when (and (> current-size best-size)
                             (full-join-consistent-p current-mapping
                                                    relations1 relations2))
                    (setf best-mapping (copy-alist current-mapping))
                    (setf best-size current-size)))

                 ;; Recursive case
                 (t
                  (let* ((entry (car remaining))
                         (c1 (car entry))
                         (candidates (cdr entry))
                         (rest (cdr remaining)))

                    ;; Branch 1: Skip this concept (don't map it)
                    (do-search rest current-mapping used-targets current-size)

                    ;; Branch 2: Try each candidate
                    (dolist (c2 candidates)
                      (unless (member c2 used-targets :test #'nodes-eq)
                        ;; Check incremental structural consistency
                        (let ((new-mapping (acons c1 c2 current-mapping)))
                          (when (check-involved-relations
                                 c1 c2 new-mapping relations1 relations2)
                            (do-search rest
                                       new-mapping
                                       (cons c2 used-targets)
                                       (1+ current-size)))))))))))

      (do-search ordered '() '() 0))
    best-mapping))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; STRUCTURAL CONSISTENCY CHECKS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun check-involved-relations (c1 c2 mapping relations1 relations2)
  "Check that adding (c1 . c2) to the mapping doesn't violate structural consistency.
   For any relation in g1 that involves c1 and whose other arcs are all mapped,
   there must be a matching relation in g2, and vice versa."
  (and (relations-consistent-in-direction-p c1 mapping relations1 relations2)
       (relations-consistent-in-direction-p c2 mapping relations2 relations1 t)))


(defun relations-consistent-in-direction-p (concept mapping
                                            source-relations target-relations
                                            &optional reverse-mapping)
  "Check that fully-mapped relations involving concept in source have counterparts in target.
   When reverse-mapping is true, swap the lookup direction in the mapping."
  (let ((involved (remove-if-not
                   (lambda (rel)
                     (member concept (arcs rel) :test #'nodes-eq))
                   source-relations)))
    (every (lambda (rel)
             (let ((mapped-arcs
                     (mapcar (lambda (arc)
                               (if reverse-mapping
                                   (car (rassoc arc mapping :test #'nodes-eq))
                                   (cdr (assoc arc mapping :test #'nodes-eq))))
                             (arcs rel))))
               ;; Only check if all arcs are mapped
               (if (every #'identity mapped-arcs)
                   (some (lambda (target-rel)
                           (and (types-equal (relation-type rel)
                                             (relation-type target-rel))
                                (= (length (arcs rel))
                                   (length (arcs target-rel)))
                                (every #'nodes-eq
                                       mapped-arcs
                                       (arcs target-rel))))
                         target-relations)
                   t)))
           involved)))


(defun full-join-consistent-p (mapping relations1 relations2)
  "Full consistency check: verify all fully-mapped relations in both directions.
   Used as a safety net at leaf nodes."
  (and (all-mapped-relations-consistent-p mapping relations1 relations2 nil)
       (all-mapped-relations-consistent-p mapping relations2 relations1 t)))


(defun all-mapped-relations-consistent-p (mapping source-relations target-relations
                                          reverse-mapping)
  "Check that every fully-mapped relation in source has a counterpart in target."
  (every (lambda (rel)
           (let ((mapped-arcs
                   (mapcar (lambda (arc)
                             (if reverse-mapping
                                 (car (rassoc arc mapping :test #'nodes-eq))
                                 (cdr (assoc arc mapping :test #'nodes-eq))))
                           (arcs rel))))
             (if (every #'identity mapped-arcs)
                 (some (lambda (target-rel)
                         (and (types-equal (relation-type rel)
                                           (relation-type target-rel))
                              (= (length (arcs rel))
                                 (length (arcs target-rel)))
                              (every #'nodes-eq
                                     mapped-arcs
                                     (arcs target-rel))))
                       target-relations)
                 t)))
         source-relations))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PHASE 2: Execute the Join
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun execute-maximal-join (g1 g2 mapping)
  "Execute the maximal join: copy both graphs and join mapped concept pairs.
   Returns the head node of the result."
  (let* ((*copy-map* (list))
         ;; Collect originals before copying
         (old-nodes-1 (collect-nodes g1))
         (old-nodes-2 (collect-nodes g2))
         ;; Copy both graphs
         (new-head-1 (copy-cgraph g1))
         (new-head-2 (copy-cgraph g2))
         ;; Build node maps: original -> copy
         (new-nodes-1 (collect-nodes new-head-1))
         (new-nodes-2 (collect-nodes new-head-2))
         (node-map-1 (mapcar #'cons old-nodes-1 new-nodes-1))
         (node-map-2 (mapcar #'cons old-nodes-2 new-nodes-2)))

    (if (null mapping)
        ;; No overlap — return copy of g1
        new-head-1
        ;; Join mapped pairs
        (let ((result-head new-head-1))
          (dolist (pair mapping)
            (let* ((orig-c1 (car pair))
                   (orig-c2 (cdr pair))
                   (copy-c1 (cdr (assoc orig-c1 node-map-1 :test #'nodes-eq)))
                   (copy-c2 (cdr (assoc orig-c2 node-map-2 :test #'nodes-eq))))
              (when (and copy-c1 copy-c2)
                ;; Join: concept1 absorbs concept2
                (let ((joined (join-concepts copy-c1 copy-c2)))
                  ;; Update node-map-2 so subsequent joins reference the survivor
                  (dolist (entry node-map-2)
                    (when (nodes-eq (cdr entry) copy-c2)
                      (setf (cdr entry) joined)))
                  ;; Track if the result head needs updating
                  (when (nodes-eq new-head-2 copy-c2)
                    (setf new-head-2 joined))))))

          ;; Simplify all concepts in the result to remove duplicate relations
          (dolist (concept (collect-concepts result-head))
            (simplify concept))
          ;; Also simplify concepts reachable from g2's head if it wasn't fully absorbed
          (unless (nodes-eq result-head new-head-2)
            (dolist (concept (collect-concepts new-head-2))
              (simplify concept)))

          result-head))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; UTILITY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun maximal-join-mapping (graph1 graph2)
  "Return just the mapping without executing the join. Useful for debugging."
  (let* ((g1 (etypecase graph1
               (graph-node graph1)
               (graph (head graph1))
               (string (parse-cgraph graph1))))
         (g2 (etypecase graph2
               (graph-node graph2)
               (graph (head graph2))
               (string (parse-cgraph graph2))))
         (concepts1 (collect-concepts g1))
         (concepts2 (collect-concepts g2))
         (relations1 (collect-relations g1))
         (relations2 (collect-relations g2)))
    (find-maximal-compatible-mapping concepts1 concepts2 relations1 relations2)))


(defun format-join-mapping (mapping)
  "Format a maximal join mapping for display."
  (with-output-to-string (s)
    (format s "{")
    (let ((first t))
      (dolist (pair mapping)
        (unless first (format s ", "))
        (setf first nil)
        (format s "~a <=> ~a"
                (format-concept (car pair))
                (format-concept (cdr pair)))))
    (format s "}")))
