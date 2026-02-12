;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Projection Operation for Conceptual Graphs
;;; The fundamental query operation that checks if a pattern graph can be
;;; specialized to match a subgraph of a target graph.
;;;

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; PROJECTION - Main Entry Points
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgeneric project (pattern target &key all-solutions)
  (:documentation
   "Project a pattern graph onto a target graph.
    Returns an alist mapping pattern concepts to target concepts on success.
    Returns NIL on failure.
    With :all-solutions t, returns a list of all valid mappings."))


(defmethod project ((pattern graph-node) (target graph-node) &key all-solutions)
  "Project pattern graph onto target graph, starting from head nodes."
  (let* ((pattern-concepts (collect-concepts pattern))
         (target-concepts (collect-concepts target))
         (pattern-relations (collect-relations pattern))
         (target-relations (collect-relations target)))
    (projection-search pattern-concepts target-concepts
                       pattern-relations target-relations
                       all-solutions)))


(defmethod project ((pattern graph) (target graph) &key all-solutions)
  "Project pattern graph object onto target graph object."
  (project (head pattern) (head target) :all-solutions all-solutions))


(defmethod project ((pattern string) (target string) &key all-solutions)
  "Parse strings and project pattern onto target."
  (let ((pattern-graph (parse-cgraph pattern))
        (target-graph (parse-cgraph target)))
    (project pattern-graph target-graph :all-solutions all-solutions)))


(defmethod project ((pattern graph-node) (target graph) &key all-solutions)
  "Project pattern node onto target graph object."
  (project pattern (head target) :all-solutions all-solutions))


(defmethod project ((pattern graph) (target graph-node) &key all-solutions)
  "Project pattern graph object onto target node."
  (project (head pattern) target :all-solutions all-solutions))


(defmethod project ((pattern string) (target graph-node) &key all-solutions)
  "Parse pattern string and project onto target."
  (project (parse-cgraph pattern) target :all-solutions all-solutions))


(defmethod project ((pattern graph-node) (target string) &key all-solutions)
  "Project pattern onto parsed target string."
  (project pattern (parse-cgraph target) :all-solutions all-solutions))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; CONCEPT PROJECTION PREDICATES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod concept-projects-p ((pattern concept) (target concept))
  "Check if a pattern concept can project onto a target concept.
   Pattern must be equal to or more general than target."
  (and
   ;; Type subsumption: pattern type must subsume target type
   (type-projects-p (concept-type pattern) (concept-type target))
   ;; Referent compatibility: generic patterns match anything
   (referent-projects-p (referent pattern) (referent target))))


(defmethod type-projects-p ((pattern-type concept-type) (target-type concept-type))
  "Check if pattern type subsumes target type (pattern is equal or more general)."
  (subsumes-p pattern-type target-type))


(defmethod referent-projects-p ((pattern-ref (eql nil)) target-ref)
  "Generic pattern (nil referent) matches any target referent."
  (declare (ignore target-ref))
  t)


(defmethod referent-projects-p ((pattern-ref referent) (target-ref (eql nil)))
  "Specific pattern cannot match generic target."
  nil)


(defmethod referent-projects-p ((pattern-ref referent) (target-ref referent))
  "Check if pattern referent can project onto target referent.
   Pattern individual must match target individual exactly."
  (referents-equal pattern-ref target-ref))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; RELATION PROJECTION PREDICATES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod relation-projects-p ((pattern relation) (target relation)
                                (concept-mapping list))
  "Check if a pattern relation projects onto a target relation given a concept mapping.
   The relation types must match, and the arc structure must be preserved."
  (and
   ;; Relation types must be equal or pattern subsumes target
   (relation-type-projects-p (relation-type pattern) (relation-type target))
   ;; Arc structure must match
   (arcs-project-p (arcs pattern) (arcs target) concept-mapping)))


(defmethod relation-type-projects-p ((pattern-type relation-type) (target-type relation-type))
  "Check if pattern relation type subsumes target relation type."
  ;; For now, require exact type match for relations
  ;; Could be extended to support relation type hierarchies
  (types-equal pattern-type target-type))


(defmethod arcs-project-p ((pattern-arcs list) (target-arcs list) (concept-mapping list))
  "Check if pattern arcs project onto target arcs given the concept mapping.
   Arc positions must be preserved: position 0 = outarc (destination),
   positions 1+ = inarcs (sources)."
  (and
   ;; Same number of arcs
   (= (length pattern-arcs) (length target-arcs))
   ;; Each pattern arc maps to corresponding target arc
   (every (lambda (pattern-concept target-concept)
            (let ((mapped-concept (cdr (assoc pattern-concept concept-mapping
                                              :test #'nodes-eq))))
              (nodes-eq mapped-concept target-concept)))
          pattern-arcs target-arcs)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; CANDIDATE FINDING
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod find-candidate-concepts ((pattern-concept concept) (target-concepts list))
  "Find all target concepts that could potentially match a pattern concept."
  (remove-if-not (lambda (target)
                   (concept-projects-p pattern-concept target))
                 target-concepts))


(defmethod count-candidates ((pattern-concept concept) (target-concepts list))
  "Count how many target concepts could match this pattern concept."
  (count-if (lambda (target)
              (concept-projects-p pattern-concept target))
            target-concepts))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; BACKTRACKING SEARCH ALGORITHM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun projection-search (pattern-concepts target-concepts
                          pattern-relations target-relations
                          all-solutions)
  "Perform backtracking search to find valid projection mappings.
   Uses MRV (Most Constrained Variable) heuristic: process concepts
   with fewest candidates first."
  ;; Early exit: if pattern has more concepts than target, no injection is possible
  (when (> (length pattern-concepts) (length target-concepts))
    (return-from projection-search (when all-solutions '())))

  ;; Early exit: check if any pattern concept has zero candidates
  (dolist (pc pattern-concepts)
    (when (zerop (count-candidates pc target-concepts))
      (return-from projection-search (when all-solutions '()))))

  (let ((solutions '()))
    ;; Order pattern concepts by number of candidates (MRV heuristic)
    (let ((ordered-concepts (order-by-candidates pattern-concepts target-concepts)))
      ;; Start recursive search with empty mapping
      (labels ((do-search (remaining-concepts current-mapping used-targets)
                 (cond
                   ;; All concepts mapped - verify relations and record solution
                   ((null remaining-concepts)
                    (when (relations-project-p pattern-relations target-relations
                                               current-mapping)
                      (if all-solutions
                          (push (copy-alist current-mapping) solutions)
                          (return-from projection-search current-mapping))))

                   ;; Try each candidate for the next concept
                   (t
                    (let* ((pattern-concept (car remaining-concepts))
                           (candidates (find-candidate-concepts pattern-concept
                                                                 target-concepts)))
                      ;; Filter out already-used targets (injective mapping)
                      (setf candidates (set-difference candidates used-targets
                                                       :test #'nodes-eq))
                      ;; Try each candidate
                      (dolist (target-concept candidates)
                        (let ((new-mapping (acons pattern-concept target-concept
                                                  current-mapping))
                              (new-used (cons target-concept used-targets)))
                          ;; Check partial relation consistency before recursing
                          (when (partial-relations-consistent-p
                                 pattern-concept target-concept
                                 pattern-relations target-relations
                                 new-mapping)
                            (do-search (cdr remaining-concepts)
                                       new-mapping
                                       new-used)))))))))
        (do-search ordered-concepts '() '())))
    ;; Return solutions if searching for all
    (when all-solutions
      (nreverse solutions))))


(defun order-by-candidates (pattern-concepts target-concepts)
  "Order pattern concepts by number of candidate matches (fewest first).
   This implements the MRV (Minimum Remaining Values) heuristic."
  (sort (copy-list pattern-concepts)
        #'<
        :key (lambda (concept)
               (count-candidates concept target-concepts))))


(defun relations-project-p (pattern-relations target-relations concept-mapping)
  "Check if all pattern relations project onto some target relations."
  (every (lambda (pattern-rel)
           (some (lambda (target-rel)
                   (relation-projects-p pattern-rel target-rel concept-mapping))
                 target-relations))
         pattern-relations))


(defun partial-relations-consistent-p (pattern-concept target-concept
                                       pattern-relations target-relations
                                       concept-mapping)
  "Check if relations involving the just-mapped concept are consistent.
   This prunes the search early when a partial mapping violates constraints."
  (let ((involved-relations (remove-if-not
                             (lambda (rel)
                               (member pattern-concept (arcs rel) :test #'nodes-eq))
                             pattern-relations)))
    ;; For each relation involving the pattern concept
    (every (lambda (pattern-rel)
             (let ((mapped-arcs (mapcar (lambda (arc)
                                          (cdr (assoc arc concept-mapping
                                                      :test #'nodes-eq)))
                                        (arcs pattern-rel))))
               ;; If all arcs are mapped, check the relation projects
               (if (every #'identity mapped-arcs)
                   (some (lambda (target-rel)
                           (relation-projects-p pattern-rel target-rel concept-mapping))
                         target-relations)
                   ;; If not all arcs mapped yet, still consistent
                   t)))
           involved-relations)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; UTILITY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod projection-p ((pattern-graph t) (target-graph t))
  "Predicate version of project - returns T if projection exists, NIL otherwise."
  (not (null (project pattern-graph target-graph))))


(defmethod projection-mapping ((pattern-graph t) (target-graph t))
  "Return the projection mapping if one exists."
  (project pattern-graph target-graph))


(defmethod all-projections ((pattern-graph t) (target-graph t))
  "Return all possible projection mappings."
  (project pattern-graph target-graph :all-solutions t))


(defmethod format-projection-mapping ((mapping list))
  "Format a projection mapping for display."
  (with-output-to-string (s)
    (format s "{")
    (let ((first t))
      (dolist (pair mapping)
        (unless first (format s ", "))
        (setf first nil)
        (format s "~a -> ~a"
                (format-concept (car pair))
                (format-concept (cdr pair)))))
    (format s "}")))
