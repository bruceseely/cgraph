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

  ;; (format t "~2&___________________________________________________________~%")
  ;; (format t "~&Step 0. Setup")
  (let* ((correspondences (find-graph-correspondences graph1 graph2 alignment-strategy))
         (*concept-map* (list))
         (*relation-map* (list))
         (graph-list (list (list))))


    ;; Step 1: Process corresponding concept pairs
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 1. Process corresponding concept pairs")
    (dolist (correspondence correspondences)
      (destructuring-bind (concept1 concept2 confidence) correspondence
        (when (> confidence 0.5)
          (join-concepts concept1 concept2)
          (setf *concept-map* (list* (cons concept1 concept1) (cons concept2 concept1) *concept-map*))
          (push concept1 (car graph-list)))))

    ;; (format t "~&*concept-map*: ~s~%"  *concept-map*)
    ;; (format t "~&*relation-map*: ~s~%" *relation-map*)
    ;; (format t "~&graph-list: ~s~%"  graph-list)

    ;; Step 2: Copy non-corresponding concepts
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 2. Copy non-corresponding concepts~%")
    (copy-non-joined-concepts graph1 graph-list (mapcar #'first correspondences))
    (copy-non-joined-concepts graph2 graph-list (mapcar #'second correspondences))

    ;; (format t "~&*concept-map*: ~s~%"  *concept-map*)
    ;; (format t "~&*relation-map*: ~s~%" *relation-map*)
    ;; (format t "~&graph-list: ~s~%"  graph-list)

    ;; Step 3: Handle relations
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 3. Handle relations~%")
    (combine-graph-relations graph1 graph2 graph-list correspondences)

    ;; (format t "~&*concept-map*: ~s~%"  *concept-map*)
    ;; (format t "~&*relation-map*: ~s~%" *relation-map*)
    ;; (format t "~&graph-list: ~s~%"  graph-list)

    ;; Step 4: Simplify result
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 4. Simplify result~%")
    (simplify-graph graph-list)

    ;; (format t "~&*concept-map*: ~s~%"  *concept-map*)
    ;; (format t "~&*relation-map*: ~s~%" *relation-map*)
    ;; (format t "~&graph-list: ~s~%"  graph-list)

    ;; Step 5: Prune relations
    ;; (format t "~2&___________________________________________________________~%")
    ;; (format t "~&Step 5. Prune relations~%")
    (let ((referenced-relations (list)))
      (dolist (concept (get-graph-concepts graph-list))
        (let ((arcs (arcs concept)))
          (dolist (arc arcs)
            (pushnew arc referenced-relations))))
      (setf graph-list (set-difference graph-list referenced-relations)))

    ;; (format t "~&*concept-map*: ~s~%"  *concept-map*)
    ;; (format t "~&*relation-map*: ~s~%" *relation-map*)
    ;; (format t "~&graph-list: ~s~%"  graph-list)
    ;; (format t "~&Returning: ~a~% ~a" (reverse (car graph-list))   (pcg (reverse (car graph-list))))

    (reverse (car graph-list))

    ;; (format t "~2&============================================================================~2%")
    ))



;; (defmethod combine-conceptual-graphs ((graph1 graph-node) (graph2 graph-node) &key (alignment-strategy :automatic))
;;   (let ((graph-list
;;           (combine-conceptual-graph-lists (collect-nodes graph1) (collect-nodes graph2) :alignment-strategy alignment-strategy)))
;;     (setq gx1 (make-cgraph graph1))
;;     (setq gx2 (make-cgraph graph-list))

;;     graph1))



(defmethod combine-conceptual-graphs ((graph1 graph-node) (graph2 graph-node) &key (alignment-strategy :automatic))
  (combine-conceptual-graph-lists (collect-nodes graph1) (collect-nodes graph2) :alignment-strategy alignment-strategy)
  graph1)

(defmethod combine-conceptual-graphs ((graph1 graph) (graph2 graph) &key (alignment-strategy :automatic))
  (combine-conceptual-graphs (head graph1) (head graph2) :alignment-strategy alignment-strategy)
  graph1)

(defmethod combine-conceptual-graphs ((graph-string1 string) (graph-string2 string) &key (alignment-strategy :automatic))
  (combine-conceptual-graphs (car (parse-cgraph graph-string1)) (car (parse-cgraph graph-string2)) :alignment-strategy alignment-strategy))



(defun graphs-share-concepts-p (graph1 graph2)
  "Return T if the two graphs have any joinable concept pairs."
  (not (null (find-automatic-correspondences
              (collect-nodes (head graph1))
              (collect-nodes (head graph2))))))

(defmethod combine-cgraphs ((graphs list))
  "Partition graphs into connected components and combine within each.
   Returns a list of graphs — one per connected component.
   Two graphs belong to the same component if they share joinable concepts,
   directly or transitively.  Order of the input list does not matter."
  (assert (every #'graph-p graphs))
  (let ((components nil)
        (remaining (copy-list graphs)))
    ;; Grow one component at a time until all graphs are assigned
    (loop while remaining do
      (let ((component (list (pop remaining)))
            (progress t))
        ;; Keep pulling in any graph that connects to the current component
        (loop while progress do
          (setf progress nil)
          (let ((deferred nil))
            (dolist (g remaining)
              (if (some (lambda (c) (graphs-share-concepts-p c g)) component)
                  (progn (push g component) (setf progress t))
                  (push g deferred)))
            (setf remaining (nreverse deferred))))
        (push component components)))
    ;; Combine within each component using deferred/retry so that ordering
    ;; within the component doesn't matter.  Isolated graphs stay as-is.
    (mapcar (lambda (component)
              (let ((accumulator (car component))
                    (remaining (copy-list (cdr component))))
                (loop
                  (let ((deferred nil)
                        (progress nil))
                    (dolist (g remaining)
                      (cond ((graphs-share-concepts-p accumulator g)
                             (handler-case
                                 (progn
                                   (combine-conceptual-graphs accumulator g)
                                   (setf progress t))
                               (error (e)
                                 (warn "Skipping graph combination: ~A" e)
                                 (push g deferred))))
                            (t
                             (push g deferred))))
                    (setf remaining (nreverse deferred))
                    (unless progress (return))))
                accumulator))
            (nreverse components))))

(defmethod combine-cgraphs :around ((graphs list))
  (let* ((combined (list))
         (temp-context (make-context))
         (local-graphs (mapcar (lambda (g) (make-cgraph g temp-context)) graphs)))
    (setf combined (call-next-method local-graphs))
    (dolist (graph graphs)
      (remove-cgraph graph temp-context))
    ;; (mapc #'add-cgraph combined)
    ;; (graphs *context*)
    combined))



(defun include-cgraph (graph &optional (context *context*))
  (setf (graphs context)
        (combine-cgraphs (list* graph (graphs context)))))


(defun consolidate-cgraphs (&optional (kb *context*))
  (setf (graphs kb) (combine-cgraphs (graphs kb)))
  kb)



;; (defmethod combine-cgraphs :around ((graphs list))
;;   (let* ((current-context *context*)
;;          (*context* (make-context current-context))
;;          (local-graphs (mapcar (lambda (g) (make-cgraph g *context*)) graphs))
;;          (combined (call-next-method local-graphs)))
;;     (setf (graphs current-context) (append combined (graphs current-context)))
;;     combined))


;; (defmethod combine-cgraphs :around ((graphs list))
;;   (let* ((current-context *context*)
;;          (*context* (make-context ))
;;          (local-graphs (mapcar (lambda (g) (make-cgraph g *context*)) graphs))
;;          (combined (call-next-method local-graphs)))
;;     (format t "~&combined: ~s~3%"  combined)
;;     (print "-----------------------------------------------")
;;     (format t "~&(graphs current-context): ~s~3%"(graphs current-context))
;;     (print "-----------------------------------------------")
;;     (format t "~&(graphs *context*): ~s~3%"(graphs *context*))
;;     (print "-----------------------------------------------")
;;     (dolist (graph combined)
;;       (add-cgraph graph current-context)
;;       ;;(pushnew graph (graphs current-context) :test #'graphs-equal)
;;       )
;;     )
;;   ;;(graphs *context*)
;;   nil)





;; (defun consolidate-cgraphs (&optional (kb *context*))
;;   (let ((graphs (graphs kb)))
;;     (setf (graphs kb) (list))
;;     (let ((combined (combine-cgraphs graphs)))
;;       (setf (graphs kb) combined)))
;;   kb)



;; (defun include-cgraph (graph &optional (context *context*))
;;   (format t "~&(graphs context): ~s~%"  (graphs context))
;;   (setf (graphs context)
;;         (list (combine-cgraphs (list* graph (graphs context))))))




;; (defmethod combine-cgraphs ((graphs list))
;;   (assert (every #'graph-p graphs))
;;   (let ((graph (car graphs)))
;;     (dolist (next-graph (cdr graphs))
;;       (combine-conceptual-graphs graph next-graph))
;;     graph))

;;; good - sorta
;; (defmethod combine-cgraphs ((graphs list))
;;   (assert (every #'graph-p graphs))
;;   (let ((graph (make-cgraph (car graphs))))
;;     (dolist (next-graph (cdr graphs))
;;       (let ((next (make-cgraph next-graph)))
;;         (combine-conceptual-graphs graph next)))
;;     graph))

#|
(let ((graphs (list (car (parse-cgraph "[PERSON: Dave]←(agnt)←[DRIVE]"))
                    (make-cgraph "[PERSON: Dave]→(poss)→[CHEVY]")
                    (car (parse-cgraph "[DRIVE]→(inst)→[CHEVY]"))
                    (parse-cgraph "[CITY: Baltimore]←(dest)<-[DRIVE]")
                    "[CHEVY]→(attr)→[OLD]")))
   (combine-cgraphs graphs))
|#

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
  ;;(setq g1 graph1 g2 graph2)
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

        ;; Only record a correspondence if:
        ;;  1. Score is above threshold
        ;;  2. The concepts are joinable (types subtype/equal, referents compatible)
        ;;  3. When one concept has a specific individual and the other is generic,
        ;;     the types must be EXACTLY equal — not merely related by subtype.
        ;;     This prevents [GIRL] from auto-matching [PERSON: Dave] purely
        ;;     because GIRL⊂PERSON and structural arcs look similar.
        ;;     Explicit individual declarations or manual correspondence are needed
        ;;     to cross type boundaries with specific referents.
        (when (and best-match (> best-score 0.4)
                   (concepts-joinable-p concept1 best-match)
                   (auto-correspondable-p concept1 best-match))
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
    ((and (individual-p ref1) (individual-p ref2) (individuals-equal (individual ref1) (individual ref2))) 1.0)
    ;; Compatible individuals
    ((and (individual-p ref1) (individual-p ref2) (individuals-compatible-p (individual ref1) (individual ref2))) 0.8)
    ;; Different individuals
    (t 0.0)))




(defun individuals-compatible-p (ind1 ind2)
  "Check if individuals could potentially be joined"
  (and (types-equal (concept-type ind1) (concept-type ind2))
       (or (null (properties ind1))
           (null (properties ind2))
           (properties-compatible-p (properties ind1) (properties ind2)))))

(defun structural-similarity (concept1 concept2)
  "Structural similarity based on matching (relation-type, neighbor-type) pairs.
   Uses bidirectional arcs so both incoming and outgoing relations count.
   Requires both the relation type AND the neighbor concept's type to match,
   so (agnt)←[EAT] and (agnt)←[DRIVE] are NOT treated as a structural match.
   This is what distinguishes [GIRL] (agent of eating) from [PERSON: Dave]
   (agent of driving) even though both have an inward agnt arc."
  (labels ((neighbor-type (concept rel)
           ;; Return the type of the other concept(s) connected through rel.
           ;; For binary relations this is one concept; we take the first.
           (let ((others (remove concept (arcs rel) :test #'nodes-eq)))
             (when (and others (concept-p (car others)))
               (concept-type (car others)))))
         (arcs-match-p (rel1 c1 rel2 c2)
           ;; Two arcs match when they have the same relation type AND
           ;; the neighbor concepts have the same type (or either side has
           ;; no neighbor, e.g. a dangling relation).
           (and (types-equal (relation-type rel1) (relation-type rel2))
                (let ((nt1 (neighbor-type c1 rel1))
                      (nt2 (neighbor-type c2 rel2)))
                  (or (null nt1) (null nt2)
                      (types-equal nt1 nt2))))))
    (let ((arcs1 (arcs concept1))
          (arcs2 (arcs concept2)))
      (if (and (null arcs1) (null arcs2))
          0.0
          (let ((matched (count-if (lambda (rel1)
                                     (some (lambda (rel2)
                                             (arcs-match-p rel1 concept1 rel2 concept2))
                                           arcs2))
                                   arcs1))
                ;; Use max rather than union-size: arcs from different graph objects
                ;; are never eq even when semantically identical, so union always
                ;; over-counts and deflates the score.
                (total (max 1 (max (length arcs1) (length arcs2)))))
            (/ matched total))))))

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
  ;;(format t "~3&graph: ~s~%"  graph)
  ;;(format t "~&(pcg graph): ~s~%"  (pcg graph))

  "Apply simplify rule to remove duplicates throughout the graph"
  (dolist (concept (get-graph-concepts (car graph)))
    ;;(format t "~2&concept: ~s~%"  concept)
    (let ((removed (simplify-duplicate-relations concept)))
      ;;(format t "~&removed: ~s~%"  removed)
      (dolist (removed-rel removed)
        ;; (format t "~&removed-rel: ~s~%"  removed-rel)
        ;; (format t "~&(car graph): ~s~%"  (car graph))
        ;;(setf (car graph) (remove removed-rel (car graph) :test #'nodes-eq))
        (setf (car graph) (remove removed-rel (car graph) :test #'nodes-eq))
        ;;(format t "~&(car graph): ~s~%"  (car graph))
        )
      ))
  graph)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; UTILITY PREDICATES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun auto-correspondable-p (concept1 concept2)
  "Additional guard for automatic correspondence beyond concepts-joinable-p.
   When one concept has a specific individual and the other is generic, require
   EITHER equal types OR high structural similarity (> 0.5), meaning the two
   concepts occupy the same relational position in their respective graphs.
   This allows [GIRL] to auto-match [PERSON: Sue] when both are agents of
   the same verb type (EAT), while blocking [GIRL] from matching [PERSON: Dave]
   when their verbs differ (EAT vs DRIVE) — without needing individual declarations."
  (let ((ref1 (referent concept1))
        (ref2 (referent concept2)))
    (if (or (and (null ref1) ref2)      ; concept1 generic, concept2 specific
            (and ref1 (null ref2)))     ; concept1 specific, concept2 generic
        (or (types-equal (concept-type concept1) (concept-type concept2))
            (> (structural-similarity concept1 concept2) 0.5))
        t)))  ; both generic or both specific: subtype relationship already checked

(defun common-supertype-p (type1 type2)
  "Check if two types have a meaningful common supertype"
  (let ((common (minimal-common-supertype type1 type2)))
    (and common
         (not (eq common *concept-type-top*)))))  ; Assuming you have a top type
