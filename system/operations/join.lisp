;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;;; still need to 'automate' the join operation


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  join rule  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; concept1 is modified
;;; assimes the concepts are restricted as necessary
;; (defmethod join ((concept1 concept) (concept2 concept))
;;   ;; (format t "~&(pcg concept1): ~s~%"  (pcg concept1))
;;   ;; (format t "~&(pcg concept2): ~s~%"  (pcg concept2))
;;   (let* ((arcs1 (arcs concept1))
;;          (arcs2 (arcs concept2))
;;          (rel-pairs (collect-common-relations arcs1 arcs2
;;                                               :key #'identity
;;                                               :test #'nodes-equal)))

;;     ;;(format t "~&rel-pairs: ~s~%"  rel-pairs)
;;     (dolist (rel-pair rel-pairs)
;;       (destructuring-bind (rel1 rel2) rel-pair
;;         ;; (describe rel1)
;;         ;; (describe rel2)
;;         ;; (format t "~&(arcs rel1): ~s~%" (arcs rel1))
;;         ;; (format t "~&(arcs rel2): ~s~%" (arcs rel2))

;;         (let ((index (remove-arc rel2 concept2)))
;;           ;; (format t "~&(arcs rel1): ~s~%" (arcs rel1))
;;           ;; (format t "~&(arcs rel2): ~s~%" (arcs rel2))

;;           (cond ((zerop index)
;;                  (set-arc-from-relation rel2 concept1))
;;                 (t
;;                  (add-arc-into-relation rel2 concept1)))))))
;;   concept1)


(defmethod join ((concept1 concept) (concept2 concept))
  ;; (format t "~&(pcg concept1): ~s~%"  (pcg concept1))
  ;; (format t "~&(pcg concept2): ~s~%"  (pcg concept2))
  (let* ((arcs1 (arcs concept1))
         (arcs2 (arcs concept2))
         (rel-pairs (collect-common-relations arcs1 arcs2
                                              :key #'identity
                                              :test #'nodes-equal)))

    ;;(format t "~&rel-pairs: ~s~%"  rel-pairs)
    (dolist (rel-pair rel-pairs)
      (destructuring-bind (rel1 rel2) rel-pair
        ;; (describe rel1)
        ;; (describe rel2)
        ;; (format t "~&(arcs rel1): ~s~%" (arcs rel1))
        ;; (format t "~&(arcs rel2): ~s~%" (arcs rel2))

        (setf (arcs rel1) (append (arcs rel1)
                                  (remove concept2 (arcs rel2))))



        )))
  concept1)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  from Claude version  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




(defun combine-cgraphs-test ()
  (reset-cgraph)
  (format t "~2&join-cg-test")
  (let* ((sue (make-individual 'person '(:name "Sue")))
         (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")
         (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")
         (g1 (pcg graph1-string))
         (g2 (pcg graph2-string))
         (joined (combine-conceptual-graphs g1 g2))
         )
    joined))








;;;
;;; correspondences


(defun get-all-concepts-in-context (context)
  "Get all concepts in this context and its child contexts"
  (let ((all-concepts (get-cached-concepts context)))
    (dolist (child (child-contexts context))
      (setf all-concepts (append all-concepts (get-all-concepts-in-context child))))
    all-concepts))

;; (defun get-all-relations-in-context (context)
;;   "Get all relations in this context and its child contexts"
;;   (let ((all-relations (copy-list (relations context))))
;;     (dolist (child (child-contexts context))
;;       (setf all-relations (append all-relations (get-all-relations-in-context child))))
;;     all-relations))

(defun find-correspondences (context1 context2)
  "Find pairs of concepts that represent the same thing across contexts"
  (let ((correspondences '()))
    (dolist (concept1 (get-all-concepts-in-context context1))
      (dolist (concept2 (get-all-concepts-in-context context2))
        (when (concepts-correspond-p concept1 concept2)
          (push (list concept1 concept2) correspondences))))
    correspondences))

(defun concepts-correspond-p (concept1 concept2)
  "Check if two concepts represent the same thing"
  (and (compatible-types-p (concept-type concept1) (concept-type concept2))
       (compatible-referents-p (referent concept1) (referent concept2))))



;;;
;;; compatiblity

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
  (dolist (relation (relations source-context))
    (let ((copied-relation (copy-relation relation)))
      ;; Update relation to point to copied concepts in new context
      (setf (arcs copied-relation)
            (mapcar (lambda (concept)
                      (find-concept-copy concept target-context))
                    (arcs relation)))
      (push copied-relation (relations target-context))))

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

;; (defun copy-concept (concept)
;;   "Create a copy of a concept"
;;   (let ((new-concept (make-instance 'concept
;;                                    :concept-type (concept-type concept)
;;                                    :referent (copy-referent (referent concept)))))
;;     ;; Copy arcs but they'll need to be updated to point to new objects
;;     (setf (arcs new-concept) (copy-list (arcs concept)))
;;     new-concept))

;; (defun copy-relation (relation)
;;   "Create a copy of a relation"
;;   ;;(format t "~3&(copy-relation ~a)~%" relation)
;;   (let ((new-relation (make-instance 'relation :type (relation-type relation))))
;;     (setf (arcs new-relation) (copy-list (arcs relation)))
;;     new-relation))

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
    (t (common-subtype type1 type2))))

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
    (dolist (relation (relations context))
      (let ((signature (list (relation-type relation) (arcs relation))))
        (unless (gethash signature seen-relations)
          (setf (gethash signature seen-relations) t)
          (push relation unique-relations))))
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

(defun get-connected-nodes (starting-concept)
  "Get all nodes connected to the starting concept (Sowa's implicit graph)"
  (list :concepts (collect-concepts starting-concept)
        :relations (collect-relations starting-concept)))



;;; Placeholder functions - implement based on your type hierarchy
;; (defun subsumes-p (type1 type2)
;;   "Check if type1 subsumes type2 in the type hierarchy"
;;   ;; Implement based on your specific type hierarchy
;;   nil)


;;; implemented as common-subtype()
;; (defun find-common-subtype (type1 type2)
;;   "Find a common subtype of type1 and type2"
;;   ;; Implement based on your specific type hierarchy
;;   (error "No common subtype found for ~A and ~A" type1 type2))










;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; (defmethod merge-concepts ((concept-1 concept) (concept-2 concept))
;;   (restrict concept-1 concept-2)
;;   (join concept-1 concept-2)
;;   (simplify concept-1))


;; ;;; returns nil if concepts cannot be merged
;; ;;; returns a modified concept-1 if successful
;; (defmethod merge-concepts ((concept-1 concept) (concept-2 concept))
;;   (let* ((properties (append (properties concept-1) (properties concept-2)))
;;          (type (common-subtype concept-1 concept-2)))
;;     (when type
;;       ;;(make-concept type annotations)
;;       (setf (concept-type concept-1) type)
;;       (setf (properties concept-1) properties))))

;; (defmethod merge-concepts :around (concept-1 concept-2)
;;   (let ((result (call-next-method)))
;;     (cond ((null result)
;;            (error "merge failed for concepts ~s and ~s" concept-1 concept-2))
;;           ((conforms result nil) result)
;;           (t (error "merged concept, ~s, fails conformity check" result)))))



;; ;; (defun eliminate-concept (concept)
;; ;;   "Removes the concept from all relations it is linked to."
;; ;;   (dolist (relation (arcs concept))
;; ;;     (setf (arcs relation) (remove concept (arcs relation) :test #'duplicate-p)))
;; ;;   (setf (arcs concept) (list)))

;; ;; (defun eliminate-relation (relation)
;; ;;   "Removes the relation from all concepts it is linked to."
;; ;;   (dolist (concept (arcs relation))
;; ;;     (setf (arcs concept) (remove relation (arcs concept) :test #'duplicate-p)))
;; ;;   (setf (arcs relation) (list)))

;; (defun insert (item list pos)
;;   (cond ((< pos (length list))
;;          (append (subseq list 0 pos) (list item) (subseq list pos)))
;;         (t (append list (list item)))))

;; ;;; This replaces the nth item
;; ;;; (setf (nth pos list) item)


;; (defun eliminate-relation (relation)
;;   "Removes the relation from all concepts it is linked to."
;;   (dolist (concept (arcs relation))
;;     (when (find relation (arcs concept) :test #'nodes-eq)
;;       (setf (arcs concept) (remove relation (arcs concept) :test #'nodes-eq))))
;;   (setf (arcs relation) nil)
;;   relation)


;; (defun eliminate-next-relation (from-relation to-relation)
;;   "Removes the relation from all concepts it is linked to."
;;   (dolist (concept (cdr (arcs from-relation)))
;;     (when (find from-relation (arcs concept) :test #'nodes-eq)
;;       (let ((pos (position from-relation (arcs concept) :test #'nodes-eq)))
;;         (setf (arcs concept) (remove from-relation (arcs concept) :test #'nodes-eq))
;;         ;; insert
;;         ;;(insert to-relation (arcs concept) pos)
;;         ;; replace
;;         (setf (nth pos (arcs concept)) to-relation)
;;         (setf (arcs from-relation)
;;               (remove concept (arcs from-relation) :test #'nodes-eq))))))



;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;; (or (and (individual-p concept1) (generic-p concept2)
;; ;;                  (types-equal concept1 concept2))
;; ;;             (and (generic-p concept1) (individual-p concept2)
;; ;;                  (types-equal concept1 concept2))
;; ;;             (and (individual-p concept1)
;; ;;                  (individual-p concept2)
;; ;;                  (individuals-eq (individual concept1) (individual concept2))
;; ;;                  (not (types-equal concept1 concept2))))


;; (defmethod combine-arc-lists ((concept1 concept) (concept2 concept))
;;   ;; replace pointers to concept1 in relations with pointers to concept2
;;   (dolist (relation (arcs concept1))
;;     (let ((position (position concept1 (arcs relation))))
;;       (setf (elt (arcs relation) position) concept2)) ;position matters
;;     (setf (arcs relation) (remove concept1 (arcs relation)))
;;     ;; keep the relations pointed to by concept1
;;     (setf (arcs concept2) (union (arcs concept1) (arcs concept2))))
;;   concept2)


;; ;;; relaced by JOIN-CONCEPTS
;; ;;; What about referents??  Need to "merge" them???
;; ;;; joins two concepts
;; ;; (defmethod RESTRICTING-JOIN ((concept1 concept) (concept2 concept))
;; ;;   "Deletes the more general concept, linking all of its arcs into the more specific concept"
;; ;;   (cond ((eq concept1 concept2)
;; ;;          concept1)
;; ;;         ((identical-objects-p concept1 concept2)
;; ;;          (combine-arc-lists concept1 concept2)
;; ;;          concept2)
;; ;;         ((subtype-p (concept-type concept2) (concept-type concept1)) ;concept2 is more specific
;; ;;          (restrict-concept concept2 concept1) ;restrict concept2
;; ;;          (combine-arc-lists concept2 concept1)
;; ;;          concept2)
;; ;;         ((subtype-p (concept-type concept1) (concept-type concept2)) ;concept1 is more specific
;; ;;          (restrict-concept concept1 concept2) ;restrict concept1
;; ;;          (combine-arc-lists concept1 concept2)
;; ;;          concept1)
;; ;;         (t nil)))


;; (defmethod RESTRICTING-JOIN  ((concept1 concept) (concept2 concept))
;;   "Deletes the more general concept, linking all of its arcs into the more specific concept"
;;   (let ((concept
;;           (cond ((eq concept1 concept2)
;;                  concept1)
;;                 ((identical-objects-p concept1 concept2)
;;                  (join concept1 concept2))
;;                 ((subtype-p (concept-type concept2) (concept-type concept1)) ;concept2 is more specific
;;                  (restrict-concept concept2 concept1) ;restrict concept2
;;                  (join concept1 concept2)
;;                  ;;(combine-arc-lists concept2 concept1)
;;                  concept2)
;;                 ((subtype-p (concept-type concept1) (concept-type concept2)) ;concept1 is more specific
;;                  (restrict-concept concept1 concept2) ;restrict concept1
;;                  (join concept1 concept2)
;;                  ;;(combine-arc-lists concept1 concept2)
;;                  concept1)
;;                 (t nil))))
;;     (when concept
;;       (simplify concept))
;;     concept))
;; #|

;; ;;(join-cgraphs (parse-cgraph "[t].") (parse-cgraph "[t: #]."))
;; ;;(join-cgraphs (parse-cgraph "[DOG].")(parse-cgraph "[t: #]."))


;; (pcg (join-cgraphs
;; 	(pcg "[ACT]->(AGNT)->[CAT: #].")
;; 	(pcg "[ACT]- (AGNT)->[ANIMATE] (OBJ)->[ENTITY].")))

;; (initialize-cgraph)
;; (setq g1 (pcg "[girl]<-(agnt)<-[eat]->(manr)->[fast]"))
;; (setq g2 (pcg "[girl:Sue]<-(agnt)<-[eat]->(obj)->[pie]"))
;; (format-cgraph g1)
;; (format-cgraph g2)
;; (join-cgraphs g1 g2)

;; (pcg (join-cgraphs
;;       (pcg "[girl]<-(agnt)<-[eat]->(manr)->[fast]")
;;       (pcg "[girl:Sue]<-(agnt)<-[eat]->(obj)->[pie]")))

;; |#





;; ;;; in relation, replace removed-concept with added-concept
;; (defmethod replace-concept-for-relation ((relation relation) (arc-number number) (added-concept concept))
;;   (let ((old-con (nth  arc-number (arcs relation))))
;;     ;; adjust relation's arc-list
;;     (setf (nth arc-number (arcs relation)) added-concept)
;;     (push relation (arcs added-concept))
;;     ;; remove pionter to relation from removed concept
;;     (setf (arcs old-con) (remove relation (arcs old-con) :test #'nodes-eq))
;;     relation))

;; (defmethod replace-concept-for-relation ((relation relation) (removed-concept concept) (added-concept concept))
;;   (let ((arc-number (arc-number relation removed-concept)))
;;     (replace-concept-for-relation relation arc-number added-concept))
;;   added-concept)

;; (defmethod replace-concept ((removed-concept concept) (added-concept concept))
;;   (let ((arcs (arcs removed-concept)))
;;     (dolist (relation arcs)
;;       (replace-concept-for-relation relation removed-concept added-concept))))

;; ;;; all relations in (arcs concept2) are moved to concept1
;; ;;; (concept-type concept1) may be changed
;; ;;; (referent concept1) is changed, combining referents for concept1 and concept2
;; ;;; conforms is checked
;; ;;; ---- is this being confused with restrict?????
;; (defmethod combine-concepts ((concept1 concept) (concept2 concept))
;;   (let (success)
;;     (let* ((ctype1 (concept-type concept1))
;;            (ctype2 (concept-type concept2))
;;            (ref1 (referent concept1))
;;            (ref2 (referent concept2))
;;            (combined-ctype (maximal-common-subtype ctype1 ctype2))
;;            (combined-referent (combined-referent ref1 ref2)))

;;       (when combined-ctype
;;         (setf (concept-type concept1) combined-ctype))

;;       (when combined-referent
;;         (setf (referent concept1) combined-referent))

;;       (setf success t)

;;       (format t "~&(links concept2): ~s~%"  (links concept2))
;;       (dolist (link (links concept2))
;;         (replace-concept-for-relation (rel link) concept2 concept1)
;;         (push (rel link) (arcs concept1))
;;         (setf (arcs concept2) (list))
;;         (setf (concept-type concept1) combined-ctype))
;;       (values concept1 success))))

;; #|
;; (set-exclusive-or '(a b c d e) '(a b c d e)) -> ()
;; (set-exclusive-or '(a b c d e) '(a b d e)) -> (c)
;; (set-exclusive-or '(c d e) '(a b d e)) -> (b a c)

;; (progn
;;       (setq c1 (parse-cgraph "[person: Sue]"))
;;       (setq c2 (pcg "[girl]"))
;;       (combine-concepts c1 c2))
;; ;; should be [GIRL: Sue] ?????
;; |#

;; (defun common-concepts (list1 list2)
;;   (let* ((unique-concepts (set-exclusive-or list1 list2 :test #'nodes-equal))
;;          (shared-concepts1 (set-difference list1 unique-concepts :test #'nodes-equal))
;;          (shared-concepts2 (set-difference list2 unique-concepts :test #'nodes-equal))
;;          (common (list)))
;;     (dolist (node1 shared-concepts1)
;;       (let ((node2 (find node1 shared-concepts2 :test #'nodes-equal)))
;;         (push (list node1 node2) common)))
;;     (list
;;      ;; in both lists
;;      (reverse common)
;;      ;; in list1 only
;;      (reverse (intersection list1 unique-concepts))
;;      ;; in list2 only
;;      (reverse (intersection list2 unique-concepts)))))


;; (defmethod combine-cgraphs ((cgraph1 concept) (cgraph2 concept))
;;   (format t "~%(pcg cgraph1): ~s" (pcg cgraph1))
;;   (format t "~%(pcg cgraph2): ~s" (pcg cgraph2))

;;   (let ((concepts1 (collect-concepts cgraph1))
;;         (concepts2 (collect-concepts cgraph2)))

;;     (format t "~%concepts1: ~s" concepts1)
;;     (format t "~%concepts2: ~s" concepts2)

;;     (destructuring-bind (common only1 only2)
;;         (common-concepts concepts1 concepts2)

;;       only1 only2
;;       ;;(format t "~%: ~s" )
;;       (format t "~%common: ~s" common)

;;       (dolist (pair common)
;;         (format t "~%pair: ~s" pair)
;;         (when (apply #'combine-concepts pair)
;;           (format t "~%(pcg cgraph1): ~s" (pcg cgraph1))


;;           ;; combine common concepts
;;           (mapc #'simplify (collect-concepts cgraph1))

;;           ;; add concepts unique to list2
;;           ;;HOW TO GET RELATIONS???
;;           ;; need to process links, not concepts???
;;           ))))
;;           cgraph1)



;; (defmethod cleanup ((node concept))
;;   (unless (marked node)
;;     (mark node)
;;     ;; discards elements earlier in the sequence
;;     (let ((links (remove-duplicates (reverse (links node)) :test #'links-equal)))
;;       ;;(format t "~&links: ~s" links)
;;       ;;(format t "~&: ~s" )
;;       (dolist (link links)
;;         (let ((con (con link)))
;;           (unless (marked con)
;;             (cleanup con)))))))





;; (defmethod mergeable-p ((concept-1 concept) (concept-2 concept))
;;   (let ((concept (cond ((same-object-p concept-1 concept-2)
;;                         concept-1)
;;                        ((subtype-p (concept-type concept-1) (concept-type concept-2))
;;                         concept-1)
;;                        ((subtype-p (concept-type concept-2) (concept-type concept-1))
;;                         ;;((minimal-common-supertype (concept-type concept-1) (concept-type concept-2)))
;;                         ;;((maximal-common-subtype (concept-type concept-1) (concept-type concept-2)))
;;                         )
;;                        (t nil))))
;;     (not (null concept))))


;; (defmethod make-join-list ((graph1 concept) (graph2 concept))
;;   (let ((concepts1 (collect-concepts graph1))
;;         (concepts2 (collect-concepts graph2))
;;         (collected (list))
;;         )
;;     ;; (format t "~&concepts1: ~s~%"  concepts1)
;;     ;; (format t "~&concepts2: ~s~%"  concepts2)s
;;     (dolist (con concepts1)
;;       (dolist (other concepts2)
;;         (when (mergeable-p con other)
;;           (push (list con other) collected))))
;;     (reverse collected)))


;; (defvar *node-pair-stack* ())
;; (defvar *other-graph* nil)



;; (defmethod join-cgraphs ((graph1 concept) (graph2 concept))
;;   (let ((join-list (make-join-list graph1 graph2)))
;;     (format t "~&join-list: ~s~%"  join-list)

;;     ;; RESTRICT
;;     (dolist (node-pair join-list)
;;       (apply #'restrict node-pair)
;;       ;; (format t "~&~a~%" (pcg g1))
;;       ;; (format t "~&~a~%" (pcg g2))
;;       )

;;     ;; JOIN
;;     (dolist (node-pair (reverse join-list))
;;       (apply #'join node-pair)
;;       ;;(format t "~&~a~%" (pcg g1))
;;       )

;;     ;; SIMPLIFY
;;     (dolist (node-pair (reverse join-list))
;;       (simplify (car node-pair))
;;       ;;(format t "~&~a~%" (pcg g1))
;;       ))
;;   graph1)



;; (defun join-cg-test ()
;;   (reset-cgraph)
;;   (format t "~2&join-cg-test")
;;   (let* ((sue (make-individual 'person '(:name "Sue")))
;;          (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")
;;          (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")
;;          (g1 (pcg graph1-string))
;;          (g2 (pcg graph2-string))
;;          (joined (join-cgraphs g1 g2))
;;          )
;;     joined))

;; (defun combine-cgraphs-test ()
;;   (reset-cgraph)
;;   (format t "~2&join-cg-test")
;;   (let* ((sue (make-individual 'person '(:name "Sue")))
;;          (graph1-string "[GIRL]<-(agnt)<-[EAT]- (manr)->[FAST] (obj)->[FOOD].")
;;          (graph2-string "[PERSON: Sue]<-(agnt)<-[EAT]->(obj)->[PIE].")
;;          (g1 (pcg graph1-string))
;;          (g2 (pcg graph2-string))
;;          (joined (combine-cgraphs g1 g2))
;;          )
;;     joined))









;; ;; (defmethod traverse-relation ((relation relation) (start-concept concept))
;; ;;   (let ((arcs (arcs relation)))
;; ;;     (if (equal (node-type start-concept) (node-type (first arcs)))
;; ;; 	(second arcs)
;; ;; 	(first arcs))))
;; ;;
;; ;; (defun JOIN1 (other result)
;; ;;   (when (and other result )
;; ;;     ;;join out-lying nodes if necessary
;; ;;     (unless (or (closed-p other) (closed-p result))
;; ;;       (mark other 'seen)
;; ;;       (mark result 'seen)
;; ;;       (dolist (link (links result))
;; ;;         (let ((result-relation (rel link))
;; ;;               (result-concept  (con link)))
;; ;;           (when result-concept
;; ;;             (mark result-relation t)
;; ;;             (mark result-concept t)
;; ;;             ;; ...and see if it matches a concept in "other"
;; ;;             (let ((other-concept
;; ;;                     (dolist (other-relation (arcs other))
;; ;;                       (let* ((other-concept (traverse-relation other-relation
;; ;;                                                                other))
;; ;;                              (match (and (equal (relation-type other-relation)
;; ;; 						(relation-type result-relation))
;; ;;                                          (mergeable-p other-concept
;; ;;                                                       result-concept))))
;; ;; 			(when match
;; ;;                           (mark other-relation t)
;; ;;                           (mark other-concept t)
;; ;;                           (return other-concept))))))
;; ;;               (when other-concept     ;if other concepts can be joined
;; ;;                 (join1 other-concept result-concept))))
;; ;;           (dolist (result-relation (arcs result))
;; ;;             ;;look at each connected concept ...
;; ;;             (let ((result-concept (traverse-relation result-relation result)))
;; ;;               (when result-concept
;; ;;                 (mark result-relation t)
;; ;;                 (mark result-concept t)
;; ;;                 ;; ...and see if it matches a concept in "other"
;; ;;                 (let ((other-concept
;; ;;                         (dolist (other-relation (arcs other))
;; ;;                           (let* ((other-concept (traverse-relation other-relation
;; ;;                                                                    other))
;; ;;                                  (match (and (equal (relation-type other-relation)
;; ;; 						    (relation-type result-relation))
;; ;;                                              (mergeable-p other-concept
;; ;;                                                           result-concept))))
;; ;; 			    (when match
;; ;;                               (mark other-relation t)
;; ;;                               (mark other-concept t)
;; ;;                               (return other-concept))))))
;; ;;                   (when other-concept ;if other concepts can be joined
;; ;;                     (join1 other-concept result-concept)))))))
;; ;;         ;;join these nodes
;; ;;         (prog1
;; ;;             ;;(restricting-join other result)
;; ;;             (combine-concepts other result)
;; ;;           (mark other 'closed)
;; ;;           (mark result 'closed))
;; ;;         ))))
