;;; Context-Based Conceptual Graph Combination Algorithm for Sowa's CGs
;;; Combines graphs by merging contexts and connecting corresponding concepts

;; Using your existing class definitions:
;; (defclass basic-node ()
;;   ((marked :initform nil :initarg :marked :accessor marked)
;;    (node-ref :initform (get-node-ref) :reader node-ref)))
;;
;; (defclass graph-node (basic-node)
;;   ((arcs :initarg :arcs :initform (list) :accessor arcs)))
;;
;; (defclass concept (graph-node)
;;   ((concept-type :initarg :concept-type :accessor concept-type)
;;    (referent :initarg :referent :accessor referent :initform nil)
;;    (context :initform *context* :initarg :context :accessor context)
;;    (coreference :initform (list) :accessor coreference)))
;;
;; (defclass relation (graph-node)
;;   ((rtype :initarg :type :accessor relation-type)))
;;
;; (defclass referent (basic-node)
;;   ((content :initform nil :initarg :content :accessor content)
;;    (concept :initform nil :initarg :concept :accessor concept)))
;;
;; (defclass context ()
;;   ((concepts :initform nil :initarg :concepts :accessor concepts)
;;    (relations :initform nil :initarg :relations :accessor relations) ; added
;;    (contexts :initform (list) :initarg :contexts :accessor child-contexts)
;;    (parent-context :initform nil :initarg :parent :accessor parent)))


(defmethod combine-conceptual-graphs ((concept1 concept) (concept2 concept) &optional (target-context nil))
  "Combines two conceptual graphs by merging their contexts and connecting corresponding concepts"
  (let* ((context1 (context concept1))
         (context2 (context concept2))
         (combined-context (or target-context (make-instance 'context)))
         (correspondence-map (find-correspondences context1 context2)))

    ;; Step 1: Copy both contexts into combined context
    (copy-context-into combined-context context1)
    (copy-context-into combined-context context2)

    ;; Step 2: Process corresponding concept pairs within the combined context
    (dolist (pair correspondence-map)
      (let ((concept1 (first pair))
            (concept2 (second pair)))
        (process-corresponding-pair combined-context concept1 concept2)))

    ;; Step 3: Final cleanup and simplification
    (simplify-context combined-context)
    combined-context))

(defun find-correspondences (context1 context2)
  "Find pairs of concepts that represent the same thing across contexts"
  (let ((correspondences '()))
    (dolist (concept1 (get-all-concepts-in-context context1))
      (dolist (concept2 (get-all-concepts-in-context context2))
        (when (concepts-correspond-p concept1 concept2)
          (push (list concept1 concept2) correspondences))))
    correspondences))

(defun get-all-concepts-in-context (context)
  "Get all concepts in this context and its child contexts"
  (let ((all-concepts (copy-list (concepts context))))
    (dolist (child (child-contexts context))
      (setf all-concepts (append all-concepts (get-all-concepts-in-context child))))
    all-concepts))

(defun get-all-relations-in-context (context)
  "Get all relations in this context and its child contexts"
  (let ((all-relations (copy-list (relations context))))
    (dolist (child (child-contexts context))
      (setf all-relations (append all-relations (get-all-relations-in-context child))))
    all-relations))




(defun concepts-correspond-p (concept1 concept2)
  "Check if two concepts represent the same thing"
  (and (compatible-types-p (concept-type concept1) (concept-type concept2))
       (compatible-referents-p (referent concept1) (referent concept2))))

(defun compatible-types-p (type1 type2)
  "Check if concept types are compatible (same or subsumption relation)"
  (or (equal type1 type2)
      (subsumes-p type1 type2)
      (subsumes-p type2 type1)))

(defun compatible-referents-p (ref1 ref2)
  "Check if referents are compatible"
  (cond
    ;; Both nil (generic concepts)
    ((and (null ref1) (null ref2)) t)
    ;; One generic, one specific - always compatible
    ((or (null ref1) (null ref2)) t)
    ;; Both are referent objects
    ((and (typep ref1 'referent) (typep ref2 'referent))
     (compatible-referent-objects-p ref1 ref2))
    ;; Direct value comparison (for backward compatibility)
    ((equal ref1 ref2) t)
    ;; Different specific referents
    (t nil)))

(defun compatible-referent-objects-p (ref1 ref2)
  "Check if two referent objects are compatible"
  (or
    ;; Same content
    (equal (content ref1) (content ref2))
    ;; One has no content (more general)
    (null (content ref1))
    (null (content ref2))
    ;; Both point to same concept
    (and (concept ref1) (concept ref2)
         (eq (concept ref1) (concept ref2)))))

(defun copy-context-into (target-context source-context)
  "Copy all concepts and relations from source context into target context"
  ;; Copy concepts, updating their context references
  (dolist (concept (concepts source-context))
    (let ((copied-concept (copy-concept concept)))
      (setf (context copied-concept) target-context)
      (push copied-concept (concepts target-context))))

  ;; Copy relations, updating their context if they have one
  ;; (dolist (relation (relations source-context))
  ;;   (let ((copied-relation (copy-relation relation)))
  ;;     ;; Update relation to point to copied concepts in new context
  ;;     (setf (arcs copied-relation)
  ;;           (mapcar (lambda (concept)
  ;;                     (find-concept-copy concept target-context))
  ;;                   (arcs relation)))
  ;;     (push copied-relation (relations target-context))))

  ;; Recursively copy child contexts
  (dolist (child (child-contexts source-context))
    (let ((copied-child (make-instance 'context :parent target-context)))
      (copy-context-into copied-child child)
      (push copied-child (child-contexts target-context)))))

(defun find-concept-copy (original-concept target-context)
  "Find the copy of original-concept in target-context"
  (find-if (lambda (concept)
             (and (eq (concept-type concept) (concept-type original-concept))
                  (equal (referent concept) (referent original-concept))))
           (concepts target-context)))

(defun copy-concept (concept)
  "Create a copy of a concept"
  (let ((new-concept (make-instance 'concept
                                   :concept-type (concept-type concept)
                                   :referent (copy-referent (referent concept))
                                   :coreference (copy-list (coreference concept)))))
    ;; Copy arcs but they'll need to be updated to point to new objects
    (setf (arcs new-concept) (copy-list (arcs concept)))
    new-concept))

(defun copy-relation (relation)
  "Create a copy of a relation"
  (make-instance 'relation :type (relation-type relation)))

(defun copy-referent (referent)
  "Create a copy of a referent object"
  (when referent
    (if (typep referent 'referent)
        (make-instance 'referent
                       :content (content referent)
                       :concept (concept referent))
        referent)))

(defun process-corresponding-pair (context concept1 concept2)
  "Apply restrict, join, and simplify to corresponding concept pair within context"
  (let ((restricted-concept (restrict-concepts concept1 concept2)))

    ;; Collect all relations from both concepts
    (let ((all-relations (remove-duplicates
                         (append (arcs concept1) (arcs concept2)))))

      ;; Set the new concept's arcs to include all relations
      (setf (arcs restricted-concept) all-relations)
      (setf (context restricted-concept) context)

      ;; Update all relations to point to the new concept
      (dolist (relation all-relations)
        (setf (arcs relation)
              (substitute restricted-concept concept1
                         (substitute restricted-concept concept2
                                   (arcs relation)))))

      ;; Remove old concepts from context and add new one
      (setf (concepts context)
            (substitute restricted-concept concept1
                       (substitute restricted-concept concept2
                                 (concepts context))))

      ;; Handle coreference lists
      (merge-coreference-lists restricted-concept concept1 concept2))))

(defun restrict-concepts (concept1 concept2)
  "Restrict two concepts to create a more specific unified concept"
  (let ((new-concept (make-instance 'concept
                                   :concept-type (restrict-types (concept-type concept1)
                                                               (concept-type concept2))
                                   :referent (restrict-referents (referent concept1)
                                                               (referent concept2)))))
    ;; Combine coreference lists
    (setf (coreference new-concept)
          (remove-duplicates (append (coreference concept1)
                                   (coreference concept2))))
    new-concept))

(defun restrict-types (type1 type2)
  "Find the most specific type that subsumes both input types"
  (cond
    ((equal type1 type2) type1)
    ((subsumes-p type1 type2) type2)  ; type2 is more specific
    ((subsumes-p type2 type1) type1)  ; type1 is more specific
    (t (find-common-subtype type1 type2))))

(defun restrict-referents (ref1 ref2)
  "Combine referents, preferring specific over generic"
  (cond
    ;; Both nil - result is nil (generic)
    ((and (null ref1) (null ref2)) nil)
    ;; One nil - use the specific one
    ((null ref1) ref2)
    ((null ref2) ref1)
    ;; Both are referent objects
    ((and (typep ref1 'referent) (typep ref2 'referent))
     (restrict-referent-objects ref1 ref2))
    ;; Same referent values
    ((equal ref1 ref2) ref1)
    ;; Incompatible referents
    (t (error "Incompatible referents: ~A and ~A" ref1 ref2))))

(defun restrict-referent-objects (ref1 ref2)
  "Combine two referent objects into a more specific one"
  (cond
    ;; Same content - use either
    ((equal (content ref1) (content ref2)) ref1)
    ;; One has no content - use the one with content
    ((null (content ref1)) ref2)
    ((null (content ref2)) ref1)
    ;; Both point to same concept - use either
    ((and (concept ref1) (concept ref2)
          (eq (concept ref1) (concept ref2))) ref1)
    ;; One points to concept, other has content - prefer concept reference
    ((concept ref1) ref1)
    ((concept ref2) ref2)
    ;; Different content - error or create combined referent
    (t (error "Cannot restrict referents with different content: ~A and ~A"
              (content ref1) (content ref2)))))

(defun merge-coreference-lists (new-concept old-concept1 old-concept2)
  "Update coreference lists to point to the new unified concept"
  ;; Update any concepts that had old concepts in their coreference lists
  (dolist (context-to-check (get-all-accessible-contexts (context new-concept)))
    (dolist (concept (concepts context-to-check))
      (when (or (member old-concept1 (coreference concept))
                (member old-concept2 (coreference concept)))
        (setf (coreference concept)
              (substitute new-concept old-concept1
                         (substitute new-concept old-concept2
                                   (coreference concept))))))))

(defun get-all-accessible-contexts (context)
  "Get all contexts accessible from this context (parent, children, siblings)"
  (let ((all-contexts (list context)))
    ;; Add parent and its children (siblings)
    (when (parent context)
      (push (parent context) all-contexts)
      (setf all-contexts (append all-contexts (child-contexts (parent context)))))
    ;; Add all children recursively
    (dolist (child (child-contexts context))
      (setf all-contexts (append all-contexts (get-all-accessible-contexts child))))
    (remove-duplicates all-contexts)))

(defun simplify-context (context)
  "Remove duplicate relations and perform other simplifications within context"
  (remove-duplicate-relations-in-context context)
  (remove-isolated-concepts-in-context context)
  ;; Recursively simplify child contexts
  (dolist (child (child-contexts context))
    (simplify-context child)))

(defun remove-duplicate-relations-in-context (context)
  "Remove relations that are identical within this context"
  (let ((seen-relations (make-hash-table :test 'equal))
        (unique-relations '()))
    ;; (dolist (relation (relations context))
    ;;   (let ((signature (list (relation-type relation) (arcs relation))))
    ;;     (unless (gethash signature seen-relations)
    ;;       (setf (gethash signature seen-relations) t)
    ;;       (push relation unique-relations))))
    (setf (relations context) unique-relations)))

(defun remove-isolated-concepts-in-context (context)
  "Remove concepts that are not referenced by any relation in this context"
  (let ((referenced-concepts (make-hash-table :test 'eq)))
    ;; Find all referenced concepts
    (dolist (relation (relations context))
      (dolist (concept (arcs relation))
        (when (typep concept 'concept)
          (setf (gethash concept referenced-concepts) t))))

    ;; Keep only referenced concepts
    (setf (concepts context)
          (remove-if-not (lambda (concept)
                          (gethash concept referenced-concepts))
                        (concepts context)))))

;;; Graph traversal utilities for context-based graphs

;; (defun get-connected-graph (starting-concept)
;;   "Get all nodes connected to the starting concept (Sowa's implicit graph)"
;;   (let ((visited (make-hash-table :test 'eq))
;;         (concepts '())
;;         (relations '()))

;;     (labels ((traverse (node)
;;                (unless (gethash node visited)
;;                  (setf (gethash node visited) t)
;;                  (cond
;;                    ((typep node 'concept)
;;                     (push node concepts)
;;                     (dolist (relation (arcs node))
;;                       (traverse relation)))
;;                    ((typep node 'relation)
;;                     (push node relations)
;;                     (dolist (concept (arcs node))
;;                       (traverse concept)))))))

;;       (traverse starting-concept)
;;       (list :concepts concepts :relations relations))))

;;; Placeholder functions - implement based on your type hierarchy
;; (defun subsumes-p (type1 type2)
;;   "Check if type1 subsumes type2 in the type hierarchy"
;;   ;; Implement based on your specific type hierarchy
;;   nil)

(defun find-common-subtype (type1 type2)
  "Find a common subtype of type1 and type2"
  ;; Implement based on your specific type hierarchy
  (error "No common subtype found for ~A and ~A" type1 type2))
