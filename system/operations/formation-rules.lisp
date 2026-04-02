;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Sowa's Four Formation Rules for Conceptual Graphs
;;; Atomic operations on individual concepts and relations
;;;

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  COPY RULE  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun copy-concept (concept)
  "Copy Rule: Create an identical copy of a concept.
   The copy has the same type and referent but is a distinct object."
  (make-concept (concept-type concept)
                (referent concept)
                :context (context concept)))

;; (defun copy-relation (relation)
;;   "Copy Rule: Create an identical copy of a relation.
;;    The copy has the same type but is a distinct object."
;;   (make-relation (relation-type relation)))

(defmethod copy-relation ((relation relation))
  (let* ((type (relation-type relation))
         (new-relation (make-relation type)))
    (push (list relation new-relation) *copy-map*)
    new-relation))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  GRAPH-LEVEL COPY OPERATION ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod copy-cgraph ((node graph-node))
  "Copy an entire conceptual graph starting from a node"
  (let* ((old-nodes (collect-nodes node))
         (new-nodes (mapcar #'copy-node old-nodes))
         (node-map (mapcar (lambda (orig new) (cons orig new))
                           old-nodes new-nodes)))

    (flet ((lookup (node)
             (let ((pair (find (node-ref node) node-map
                               :key (lambda (n) (node-ref (car n)))
                               :test #'=)))
               (cdr pair))))

      ;; after copy, new nodes have no arc lists
      ;; replace old nodes with new nodes in the arc lists
      (dolist (old-node old-nodes)
        (let ((new-node (lookup old-node)))
          (setf (arcs new-node) (mapcar #'lookup (arcs old-node)))))

      ;; check for variables
      (dolist (old-node old-nodes)
        (when (node-variable old-node)
          (set-variable (lookup old-node))))

      ;;return the copy of the supplied node
      (lookup node))))

(defmethod copy-cgraph ((graph graph))
  (copy-cgraph (head graph)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  RESTRICT RULE  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;; (defun restrict-by-concept-type (concept new-type)
;;   "Restrict Rule: Specialize a concept's type to a more specific subtype.
;;    Returns a new concept with the restricted type, same referent.
;;    Fails if new-type is not a subtype of the concept's current type."
;;   (let ((current-type (concept-type concept)))
;;     (unless (subtype-p new-type current-type)
;;       (error "Cannot restrict ~A to ~A: not a subtype" current-type new-type))
;;     (make-concept new-type
;;                   (referent concept)
;;                   :context (context concept))))


;; (defun restrict-by-referent (concept new-referent)
;;   "Restrict Rule: Specialize a concept's referent to be more specific.
;;    Generic concepts can be restricted to have individual referents.
;;    Individual referents can be restricted to be more specific if compatible."
;;   (let ((current-referent (referent concept))
;;         (concept-type (concept-type concept)))
;;     ;; Check if restriction is valid
;;     (unless (referent-restriction-valid-p current-referent new-referent concept-type)
;;       (error "Cannot restrict referent ~A to ~A for type ~A"
;;              current-referent new-referent concept-type))
;;     (make-concept concept-type
;;                   new-referent
;;                   :context (context concept))))



(defmethod restrict-by-type ((concept concept) (restrict-type concept-type))
  (let ((concept-type (concept-type concept)))
    (cond ((not (conforms concept restrict-type))
           (warn "Cannot RESTRICT concept ~a to the concept-type ~a (doesn't conform)" concept restrict-type))
          ((subtype-p restrict-type concept-type)
           (setf (concept-type concept) restrict-type)
           t)
          (t
           (warn "Cannot RESTRICT concept ~a to the concept-type ~a (not a subtype)" concept restrict-type)
           nil))))


(defmethod restrict-by-referent ((concept concept) (referent referent))
  (let* ((concept-type (concept-type concept))
         (concept-referent (referent concept))
         (concept-content (content concept-referent)))

    (cond ((not (conforms concept (content referent)))
           (warn "Cannot RESTRICT concept ~a to the referent ~a (doesn't conform)" concept referent)
           nil)
          ((generic-p concept)
           (setf (referent concept) referent)
           t)
          (t
           (warn "Cannot restrict referent of ~a to ~a" concept referent)
           nil))))

;;; for individuals, sets, graphs, etc
(defmethod restrict-by-referent ((concept concept) referent-content)
  (let* ((concept-type (concept-type concept))
         (concept-referent (referent concept))
         (concept-content (content concept-referent)))
    concept-type

    (format t "~&concept-referent: ~s~%"  concept-referent)
    (format t "~&concept-content: ~s~%"  concept-content)
    (format t "~&referent-content: ~s~%"  referent-content)
    ;;(format t "~&subsetp: ~s~%"  (subsetp (properties concept-content) (properties referent-content)))


    (cond ((not (conforms concept referent-content))
           (warn "Cannot RESTRICT concept ~a to the referent ~a (doesn't conform)" concept referent-content)
           nil)
          ((generic-p concept)
           (setf (referent concept) (make-referent referent-content))
           t)
          (t
           (warn "Cannot restrict referent of ~a to ~a" concept referent-content)
           nil))))

(defmethod restrict-by-referent ((concept concept) (individual individual))
  (when (types-equal (concept-type concept) (individual-type individual))
    ;; (format t "~&individual: ~s~%"  individual)
    ;; (format t "~&(generic-p concept): ~s~%"  (generic-p concept))
    ;; (format t "~&(typep (content (referent concept)) 'individual): ~s~%"  (typep (content (referent concept)) 'individual))
    ;; (format t "~&(content (referent concept)): ~s~%"  (content (referent concept)))
    ;; (format t "~&(properties (content (referent concept))): ~s~%"  (properties (content (referent concept))))
    ;; (format t "~&(properties individual): ~s~%"  (properties individual))
    ;; (format t "~&(subsetp (properties (content (referent concept)))
    ;;                      (properties individual)): ~s~%"  (subsetp (properties (content (referent concept)))
    ;;                                                                (properties individual)))
    ;; (format t "~&(make-referent individual concept): ~s~%"  (make-referent individual concept))

    (let ((*ALWAYS-FORMAT-NODES* t)
          (ref (make-referent individual concept)))

      ;;(format t "~&ref: ~s~%"  ref)
      (cond ((generic-p concept)
             (setf (referent concept) (make-referent individual concept))
             ;;(format t "~&concept: ~s~%"  concept)
             t)

            ((and (typep (content (referent concept)) 'individual)
                  (subsetp (properties (content (referent concept)))
                           (properties individual)))
             ;; (format t "~&individual: ~s~%"  individual)
             ;; (format t "~&concept: ~s~%"  concept)
             ;; (format t "~&(properties (content (referent concept))): ~s~%"  (properties (content (referent concept))))
             (setf (properties (content (referent concept)))
                   (properties individual))

             ;; (format t "~&(properties (content (referent concept))): ~s~%"  (properties (content (referent concept))))
             ;; (format t "~&(content (referent concept)): ~s~%"  (content (referent concept)))
             ;; (format t "~&(referent concept): ~s~%"  (referent concept))
             ;; (format t "~&concept: ~s~%"  concept)
             (content (referent concept))
             t)

            ))

      ;;(format t "~&concept: ~s~%"  concept)
      ))


(defmethod restrict-by-referent ((concept concept) (restriction (eql nil)))
  concept)

(defmethod restrict-by-concept ((concept1 concept) (concept2 concept))
  (and
   (restrict-by-type concept1 (concept-type concept2))
   (restrict-by-referent concept1 (referent concept2))
   ))




;; (defmethod restrict ((concept1 concept) (concept-type concept-type) referent-content)
;;   (unless (conforms (referent concept1) (concept-type concept1))
;;     (warn "Before RESTRICT, referent and type of ~a do not conform" concept1))

;;   (let ((concept1-type (concept-type concept1))
;;         (concept1-referent (copy-referent (referent concept1)))
;;         (success nil))

;;     (unwind-protect
;;          (progn
;;            (restrict-by-concept-type concept1 concept-type)
;;            (restrict-by-referent concept1 referent-content)
;;            (setf success (conforms (referent concept1) (concept-type concept1))))
;;       (unless success
;;         (setf (concept-type concept1) concept1-type)
;;         (setf (referent concept1) concept1-referent)))
;;     success))



;;; restrict concept1 to be concept2 if possible
(defmethod restrict-concept (concept1 concept2)
  "Restricts (possibly modifying) concept1 to concept2"
  (let ((success
          (and
           (restrict-by-type concept1 (concept-type concept2))
           (restrict-by-referent concept1 (referent concept2)))))
    (unless success
      (warn "Cannot RESTRICT ~a to ~a" concept1 concept2)
      success)))



(defmethod restrict ((concept1 concept) (concept2 concept))
  (restrict-concept concept1 concept2))

(defmethod restrict ((concept1 concept) (restriction concept-type))
  (restrict-by-type concept1 restriction))

(defmethod restrict ((concept1 concept) (restriction individual))
  (restrict-by-referent concept1 restriction))

(defmethod restrict ((concept1 concept) (properties list))
  (restrict-by-referent concept1 properties))


;; (defun referent-restriction-valid-p (current-referent new-referent concept-type)
;;   "Check if a referent restriction is valid according to CG rules"
;;   (cond
;;     ;; Generic to individual is always valid
;;     ((null current-referent) t)
;;     ;; Same referent is valid
;;     ((referents-equal current-referent new-referent) t)
;;     ;; Referent to individual must be compatible
;;     ((and (typep current-referent 'referent) (individual-p new-referent))
;;      (let ((current-individual (content current-referent)))
;;        (or (individuals-equal current-individual new-referent)
;;            (and (types-equal (individual-type current-individual) (concept-type new-referent))
;;                 (or (null (properties current-individual))
;;                     (properties-compatible-p (properties current-individual)
;;                                              (properties new-referent)))))))
;;     ;; Individual to individual must be compatible
;;     ((and (individual-p current-referent) (individual-p new-referent))
;;      (and (types-equal (concept-type current-referent) (concept-type new-referent))
;;           (or (null (properties current-referent))
;;               (properties-compatible-p (properties current-referent)
;;                                        (properties new-referent)))))
;;     ;; Otherwise invalid
;;     (t nil)))

(defun properties-compatible-p (props1 props2)
  "Check if two property lists are compatible (props2 extends props1)"
  (every (lambda (prop)
           (let ((key (first prop))
                 (value (second prop)))
             (let ((other-value (getf props2 key)))
               (or (null other-value)
                   (equal value other-value)))))
         (plist-to-pairs props1)))

(defun plist-to-pairs (plist)
  "Convert plist to list of (key value) pairs"
  (loop for (key value) on plist by #'cddr
        collect (list key value)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  JOIN RULE  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; The graph containing concept1 is kept with connections fron concept-2's graph added
;; (defmethod join ((concept1 concept) (concept2 concept))
;;   (when (objects-equal concept1 concept2)
;;     (let ((relations (arcs concept2)))
;;       (dolist (relation-to-relink relations)
;;         (substitute concept1 concept2 (arcs relation-to-relink)))
;;       (setf (arcs concept1) (append (arcs concept1) relations)))
;;     t))


;; (defmethod join-concepts ((concept1 concept) (concept2 concept))
;;   (join concept1 concept2))



(defun types-joinable-p (type1 type2)
  "Check if two concept types can be joined"
  (or (types-equal type1 type2)
      (subtype-p type1 type2)
      (subtype-p type2 type1)))


(defun concepts-joinable-p (concept1 concept2)
  "Check if two concepts can be joined according to CG rules"
  (and (types-joinable-p (concept-type concept1)
                         (concept-type concept2))
       (referents-joinable-p (referent concept1)
                             (referent concept2))))


(defun referents-joinable-p (ref1 ref2)
  "Check if two referents can be joined"
  (cond ;; at least one is generic
    ((or (null ref1)
         (null ref2))
     t) ;; Same individual (both are referent objects containing individuals)
    ((and (typep ref1 'referent)
          (typep ref2 'referent))
     (individuals-equal (content ref1)
                        (content ref2))) ;; Same individual (both are individual objects directly)
    ((and (individual-p ref1)
          (individual-p ref2))
     (individuals-equal ref1 ref2)) ;; Direct equality
    (t (equal ref1 ref2))))


(defun join-types (type1 type2)
  "Join two types - result is the most specific common supertype"
  (cond((types-equal type1 type2) type1)
       ((subtype-p type1 type2) type1) ; type1 is more specific
       ((subtype-p type2 type1) type2)     ; type2 is more specific
       (t (minimal-common-supertype type1 type2))))


(defun join-referents (ref1 ref2)
  "Join two referents - prefer the more specific one"
  (cond
    ;; both generic - result is generic
    ((and (null ref1) (null ref2)) nil)
    ;; One generic - use the specific one
    ((null ref1) ref2)
    ((null ref2) ref1)
    ;; Both specific - they must be equal (checked by joinable-p)
    (t (or ref1 ref2))))


(defmethod join-concepts ((concept1 concept) (concept2 concept))
  "Join Rule: Destructively combine two compatible concepts.
   Modifies concept1 to have the joined type/referent and absorbs concept2's relations.
   If concept2 is the head of a graph, updates that graph's head to concept1.
   Returns concept1."
  (unless (concepts-joinable-p concept1 concept2)
    (error "Cannot join incompatible concepts ~A and ~A" concept1 concept2))

  ;; Before orphaning concept2, check if it's a graph's head
  (let ((concept2-graph (graph concept2)))
    (when (and concept2-graph
               (eq (head concept2-graph) concept2))
      ;; Update the graph's head to point to the surviving concept
      (setf (head concept2-graph) concept1)))

  ;; Update concept1's type and referent
  (setf (concept-type concept1) (join-types (concept-type concept1) (concept-type concept2)))
  (setf (referent concept1) (join-referents (referent concept1) (referent concept2)))

  ;; Relink concept2's relations to point to concept1
  (let ((relations (arcs concept2)))
    (dolist (relation relations)
      (setf (arcs relation) (substitute concept1 concept2 (arcs relation))))
    ;; Absorb concept2's relations into concept1
    (setf (arcs concept1) (union (arcs concept1) relations)))

  concept1)




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  SIMPLIFY RULE  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod simplify ((concept concept))
  "Simplify Rule: Remove duplicate relations from a concept.
   Two relations are duplicates if they have the same type and connect to equivalent concepts."
  (let* ((unique-relations (remove-duplicates (arcs concept) :test #'relations-equivalent-p))
         (removed (set-difference (arcs concept) unique-relations)))
    ;; Update the concept's arcs to only include unique relations
    (setf (arcs concept) unique-relations)
    ;; Note: Don't modify the removed relations' arcs here - that corrupts them
    ;; for other concepts that may still reference them. The relations will be
    ;; removed from the graph separately in simplify-graph.
    removed))

(defmethod simplify-duplicate-relations ((concept concept))
  (simplify concept))


(defun equivalent-relation (relation relation-list)
  "Find a relation equivalent to the given relation in the list"
  (find-if (lambda (other-relation)
             (relations-equivalent-p relation other-relation))
           relation-list))

(defun relations-equivalent-p (rel1 rel2)
  "Check if two relations are equivalent (same type, equivalent arcs).
   Outarcs must match; inarcs can be in any order."
  (and (types-equal rel1 rel2)
       (= (length (arcs rel1)) (length (arcs rel2)))
       ;; Outarc (car) must match exactly
       (objects-equal (car (arcs rel1)) (car (arcs rel2)))
       ;; Inarcs can be in any order - use find instead of positional comparison
       (every (lambda (arc1)
                (find arc1 (cdr (arcs rel2)) :test #'objects-equal))
              (cdr (arcs rel1)))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  UTILITY FUNCTIONS  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defmethod referents-equal (ref1 ref2)
;;   "Check if two referents are equal"
;;   (cond
;;     ((and (null ref1) (null ref2)) t)
;;     ((or (null ref1) (null ref2)) nil)
;;     ((and (individual-p ref1) (individual-p ref2))
;;      (individuals-equal ref1 ref2))
;;     (t (equal ref1 ref2))))

;; (defmethod referents-equal ((concept1 concept) (concept2 concept))
;;   (referents-equal (referent concept1) (referent concept2)))
