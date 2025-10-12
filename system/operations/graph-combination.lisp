;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Graph Combination using Formation Rules
;;; High-level operations built from atomic formation rules
;;;

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GRAPH ALIGNMENT AND CORRESPONDENCE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; mapping (original-node . copied-node)
;;; see combine-graph-relations

(defvar *relation-map*)
(defvar *concept-map*)

(defmethod combine-conceptual-graph-lists ((graph1 list) (graph2 list) &key (alignment-strategy :automatic))
  "Combine two conceptual graphs by finding correspondences and applying formation rules."

  (let* ((correspondences (find-graph-correspondences graph1 graph2 alignment-strategy))
         (*concept-map* (list))
         (*relation-map* (list))
         (graph-list (list (list))))

    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 0. Setup")


    ;; Step 1: Process corresponding concept pairs
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 1. Process corresponding concept pairs")
    (dolist (correspondence correspondences)
      (destructuring-bind (concept1 concept2 confidence) correspondence
        (when (> confidence 0.5)
          (let ((joined-concept (join-concepts concept1 concept2)))
            (push (cons concept1 joined-concept) *concept-map*)
            (push (cons concept2 joined-concept) *concept-map*)
            (push joined-concept (car graph-list))))))


    ;; Step 2: Copy non-corresponding concepts
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 2. Copy non-corresponding concepts~%")
    (copy-non-joined-concepts graph1 graph-list (mapcar #'first correspondences))
    (copy-non-joined-concepts graph2 graph-list (mapcar #'second correspondences))



    ;; Step 3: Handle relations
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 3. Handle relations~%")
    (combine-graph-relations graph1 graph2 graph-list correspondences)


    ;; Step 4: Simplify result
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 4. Simplify result~%")
    (simplify-graph graph-list)

    ;; Step 5: Prune relations
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 5. Prune relations~%")
    (let ((referenced-relations (list)))
      (dolist (concept (get-graph-concepts graph-list))
        (let ((arcs (arcs concept)))
          (dolist (arc arcs)
            (pushnew arc referenced-relations))))
      (setf graph-list (set-difference graph-list referenced-relations)))
    ;;(car (last (car graph-list)))
    (car graph-list)
    ))


(defmethod combine-conceptual-graphs ((graph1 graph-node) (graph2 graph-node) &key (alignment-strategy :automatic))
  (let ((graph-list
          (combine-conceptual-graph-lists (collect-nodes graph1) (collect-nodes graph2) :alignment-strategy alignment-strategy)))
    ;;(format t "~&graph-list: ~s~%"  graph-list)
    (car (last graph-list))))



(defmethod combine-conceptual-graphs ((graph1 string) (graph2 string) &key (alignment-strategy :automatic))
  (combine-conceptual-graphs (pcg graph1) (pcg graph2) :alignment-strategy alignment-strategy))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; CORRESPONDENCE DETECTION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun find-graph-correspondences (graph1 graph2 strategy)
  "Find correspondences between concepts in two graphs.
   Returns list of (concept1 concept2 confidence-score) triples."
  (case strategy
    (:automatic (find-automatic-correspondences graph1 graph2))
    (:manual (error "Manual correspondence not yet implemented"))
    (:forced (find-forced-correspondences graph1 graph2))
    (t (error "Unknown alignment strategy: ~A" strategy))))

(defun find-automatic-correspondences (graph1 graph2)
  "Automatically find correspondences based on concept similarity"
  (let ((correspondences '())
        (concepts1 (get-graph-concepts graph1))
        (concepts2 (get-graph-concepts graph2)))

    ;; For each concept in graph1, find best match in graph2
    (dolist (concept1 concepts1)
      (let ((best-match nil)
            (best-score 0.0))

        (dolist (concept2 concepts2)
          (let ((similarity (concept-similarity concept1 concept2)))
            (when (> similarity best-score)
              (setf best-match concept2
                    best-score similarity))))

        ;; Only consider it a correspondence if similarity is high enough
        (when (and best-match (> best-score 0.4))
          (push (list concept1 best-match best-score) correspondences))))

    ;; Remove conflicts (ensure 1-1 mapping)
    (resolve-correspondence-conflicts correspondences)))

(defun concept-similarity (concept1 concept2)
  "Calculate similarity score between two concepts (0.0 to 1.0)"
  (let ((type-score (type-similarity (concept-type concept1) (concept-type concept2)))
        (referent-score (referent-similarity (referent concept1) (referent concept2)))
        (structural-score (structural-similarity concept1 concept2)))

    ;; Weighted combination
    (+ (* 0.6 type-score)
       (* 0.4 referent-score)
       (* 0.2 structural-score))))

(defun type-similarity (type1 type2)
  "Calculate type similarity score"
  (cond
    ((types-equal type1 type2) 1.0)
    ((or (subtype-p type1 type2) (subtype-p type2 type1)) 0.8)
    ((common-supertype-p type1 type2) 0.6)
    (t 0.0)))

(defun referent-similarity (ref1 ref2)
  "Calculate referent similarity score"
  (cond
    ;; Both generic
    ((and (null ref1) (null ref2)) 1.0)
    ;; One generic, one specific - could be joined
    ((or (null ref1) (null ref2)) 0.7)
    ;; Same individual
    ((and (individual-p ref1) (individual-p ref2) (individuals-equal ref1 ref2)) 1.0)
    ;; Compatible individuals
    ((and (individual-p ref1) (individual-p ref2) (individuals-compatible-p ref1 ref2)) 0.8)
    ;; Different individuals
    (t 0.0)))

(defun individuals-compatible-p (ind1 ind2)
  "Check if individuals could potentially be joined"
  (and (types-equal (concept-type ind1) (concept-type ind2))
       (or (null (properties ind1))
           (null (properties ind2))
           (properties-compatible-p (properties ind1) (properties ind2)))))

(defun structural-similarity (concept1 concept2)
  "Calculate structural similarity based on relation patterns"
  (let ((rels1 (mapcar #'relation-type (outarcs concept1)))
        (rels2 (mapcar #'relation-type (outarcs concept2))))
    (/ (length (intersection rels1 rels2 :test #'types-equal))
       (max 1 (length (union rels1 rels2 :test #'types-equal))))))

(defun resolve-correspondence-conflicts (correspondences)
  "Ensure 1-1 mapping by resolving conflicts"
  (let ((resolved '())
        (used-concepts2 '()))

    ;; Sort by confidence score (highest first)
    (setf correspondences (sort correspondences #'> :key #'third))

    (dolist (correspondence correspondences)
      (let ((concept1 (first correspondence))
            (concept2 (second correspondence))
            (score (third correspondence)))

        ;; Only add if concept2 hasn't been used
        (unless (member concept2 used-concepts2)
          (push correspondence resolved)
          (push concept2 used-concepts2))))

    resolved))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GRAPH MANIPULATION UTILITIES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defun get-graph-concepts (graph)
;;   "Extract all concepts from a graph representation"
;;   ;; This depends on your graph representation
;;   ;; Could be a context with concepts slot, or a list, etc.
;;   (cond
;;     ((typep graph 'context) (concepts graph))
;;     ((listp graph) (remove-if-not #'concept-p graph))
;;     (t (error "Unknown graph type: ~A" (type-of graph)))))


(defmethod get-graph-concepts ((graph context))
  (concepts graph))

(defmethod get-graph-concepts ((graph list))
  ;;(format t "~&graph: ~s~%"  graph)
  ;;(remove-if-not #'concept-p graph)
  (remove-if-not (lambda (node)
                   ;;(format t "~&node: ~s; type: ~s~%" node (type-of node))
                   (typep node 'concept))
                 graph))

(defmethod get-graph-concepts ((graph graph-node))
  (collect-concepts graph))

(defmethod get-graph-concepts (graph)
  (error "Unhandled graph type: ~a" (type-of graph)))


;; (defun get-graph-relations (graph)
;;   "Extract all relations from a graph representation"
;;   (cond
;;     ((typep graph 'context) (relations graph))
;;     ((listp graph) (remove-if-not #'relation-p graph))
;;     (t (error "Unknown graph type: ~A" (type-of graph)))))

(defmethod get-graph-relations ((graph context))
  (relations graph))

(defmethod get-graph-relations ((graph list))
  (remove-if-not #'relation-p graph))

(defmethod get-graph-relations ((graph graph-node))
  (collect-relations graph))

(defmethod get-graph-relations (graph)
  (error "Unhandled graph type: ~a" (type-of graph)))





(defmethod create-empty-graph-list ((graph-name string))
  "Create an empty graph structure"
  (make-symbol (string-upcase graph-name)))







;; (defun add-concept-to-graph (concept graph)
;;   "Add a concept to a graph"
;;   (push concept (concepts graph)))


;; (defmethod add-concept-to-graph ((concept concept) (graph context))
;;   (add-concept graph))

(defmethod add-concept-to-graph ((concept concept) (graph-name string))
  (let* ((name (string-upcase graph-name))
         (sym (find-symbol name)))
    (format t "~&sym: ~s~%"  sym)
    (format t "~&(null sym): ~s~%"  (null sym))
    (format t "~&(boundp sym): ~s~%"  (boundp sym))

    (cond ((null sym) nil)
          ((boundp sym)
           (push concept (symbol-value sym)))
          (t
           (setf (symbol-value sym) (list concept))))))

(defmethod add-concept-to-graph ((concept concept) (sym symbol))
  (let* (;;s(name (string-upcase graph-name))
         ;;(sym (find-symbol name))
         )
    (format t "~&sym: ~s~%"  sym)
    (format t "~&(null sym): ~s~%"  (null sym))
    (format t "~&(boundp sym): ~s~%"  (boundp sym))

    (cond ((null sym) nil)
          ((boundp sym)
           (push concept (symbol-value sym)))
          (t
           (setf (symbol-value sym) (list concept))))))




;; (defun add-relation-to-graph (relation graph)
;;   "Add a relation to a graph"
;;   (push relation (relations graph)))

;; (defmethod add-relation-to-graph ((relation relation) (graph symbol))
;;   (format t "~&relation: ~s~%"  relation)
;;   (format t "~&graph: ~s~%"  graph)
;;   (describe graph)
;;   (describe 'graph-list)
;;   (format t "~&(find ~a graph :test #'nodes-equal): ~s~%"  relation (find relation graph-list):test #'nodes-equal)
;;   (unless (find relation graph :test #'nodes-equal)
;;     (set (symbol-value graph) (cons relation graph-list))))

;; (defmethod add-relation-to-graph ((relation relation) (graph context))
;;   (push relation (relations graph)))


(defmethod copy-non-joined-concepts (source-graph target-graph (joined-concepts list))
  "Copy concepts that don't have correspondences"
  (let* ((source-concepts (get-graph-concepts source-graph))
         (non-joined-concepts (set-difference source-concepts joined-concepts)))
    (dolist (concept non-joined-concepts)
      (let ((copied-concept (copy-concept concept)))
        (push (cons concept copied-concept) *concept-map*)
        (push copied-concept (car target-graph))))))

(defvar *correspondence-mapping*)

(defun combine-graph-relations (graph1 graph2 combined-graph correspondences)
  "Combine relations from both graphs, updating references to joined concepts"
  (let ((correspondence-mapping (make-correspondence-mapping correspondences)))
    (setq *correspondence-mapping* correspondence-mapping )

    ;; Copy relations from both graphs
    (dolist (relation (append (get-graph-relations graph1)
                              (get-graph-relations graph2)))
      (let ((copied-relation (copy-relation relation)))
        (setf (arcs copied-relation)
              (mapcar (lambda (concept)
                        (cdr (assoc concept *concept-map*)))
                      (arcs relation)))
        (push (cons relation copied-relation) *relation-map*)

        ;; Update arcs to point to joined concepts where applicable
        (dolist (concept (arcs copied-relation))
          (pushnew copied-relation (arcs concept) :test #'nodes-eq))
        (push copied-relation (car combined-graph))))))


(defun make-correspondence-mapping (correspondences)
  "Create hash table mapping old concepts to joined concepts"
  (let ((mapping (make-hash-table :test #'eq)))
    (dolist (correspondence correspondences)
      (let ((concept1 (first correspondence))
            (concept2 (second correspondence)))
        ;; Both old concepts map to the same joined concept
        (let ((joined (join-concepts concept1 concept2)))
          (setf (gethash concept1 mapping) joined
                (gethash concept2 mapping) joined))))
    mapping))

(defun simplify-graph (graph)
  "Apply simplify rule to remove duplicates throughout the graph"
  (dolist (concept (get-graph-concepts (car graph)))
    (let ((removed (simplify-duplicate-relations concept)))
      (dolist (removed-rel removed)
        (setf (car graph) (remove removed-rel (car graph) :test #'nodes-eq)))))
  graph)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; UTILITY PREDICATES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun common-supertype-p (type1 type2)
  "Check if two types have a meaningful common supertype"
  (let ((common (minimal-common-supertype type1 type2)))
    (and common
         (not (eq common *concept-type-top*)))))  ; Assuming you have a top type
