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

(defun copy-relation (relation)
  "Copy Rule: Create an identical copy of a relation.
   The copy has the same type but is a distinct object."
  (make-relation (relation-type relation)))

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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  RESTRICT RULE  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun restrict-concept-type (concept new-type)
  "Restrict Rule: Specialize a concept's type to a more specific subtype.
   Returns a new concept with the restricted type, same referent.
   Fails if new-type is not a subtype of the concept's current type."
  (let ((current-type (concept-type concept)))
    (unless (subtype-p new-type current-type)
      (error "Cannot restrict ~A to ~A: not a subtype" current-type new-type))
    (make-concept new-type
                  (referent concept)
                  :context (context concept))))

(defun restrict-concept-referent (concept new-referent)
  "Restrict Rule: Specialize a concept's referent to be more specific.
   Generic concepts can be restricted to have individual referents.
   Individual referents can be restricted to be more specific if compatible."
  (let ((current-referent (referent concept))
        (concept-type (concept-type concept)))
    ;; Check if restriction is valid
    (unless (referent-restriction-valid-p current-referent new-referent concept-type)
      (error "Cannot restrict referent ~A to ~A for type ~A"
             current-referent new-referent concept-type))
    (make-concept concept-type
                  new-referent
                  :context (context concept))))

(defun referent-restriction-valid-p (current-referent new-referent concept-type)
  "Check if a referent restriction is valid according to CG rules"
  (cond
    ;; Generic to individual is always valid
    ((null current-referent) t)
    ;; Same referent is valid
    ((referents-equal current-referent new-referent) t)
    ;; Referent to individual must be compatible
    ((and (typep current-referent 'referent) (individual-p new-referent))
     (let ((current-individual (content current-referent)))
       (or (individuals-equal current-individual new-referent)
           (and (types-equal (individual-type current-individual) (concept-type new-referent))
                (or (null (properties current-individual))
                    (properties-compatible-p (properties current-individual)
                                             (properties new-referent)))))))
    ;; Individual to individual must be compatible
    ((and (individual-p current-referent) (individual-p new-referent))
     (and (types-equal (concept-type current-referent) (concept-type new-referent))
          (or (null (properties current-referent))
              (properties-compatible-p (properties current-referent)
                                       (properties new-referent)))))
    ;; Otherwise invalid
    (t nil)))

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

(defun join-concepts (concept1 concept2)
  "Join Rule: Combine two compatible concepts into a single concept.
   The concepts must have compatible types and referents.
   Returns a new concept that represents their combination."
  (unless (concepts-joinable-p concept1 concept2)
    (error "Cannot join incompatible concepts ~A and ~A" concept1 concept2))

  (let ((joined-type (join-types (concept-type concept1) (concept-type concept2)))
        (joined-referent (join-referents (referent concept1) (referent concept2))))
    (make-concept joined-type
                  joined-referent
                  :context (context concept1))))

(defun concepts-joinable-p (concept1 concept2)
  "Check if two concepts can be joined according to CG rules"
  (and (types-joinable-p (concept-type concept1) (concept-type concept2))
       (referents-joinable-p (referent concept1) (referent concept2))))

(defun types-joinable-p (type1 type2)
  "Check if two concept types can be joined"
  (or (types-equal type1 type2)
      (subtype-p type1 type2)
      (subtype-p type2 type1)))

(defun referents-joinable-p (ref1 ref2)
  "Check if two referents can be joined"
  (cond
    ;; At least one is generic
    ((or (null ref1) (null ref2)) t)
    ;; Same individual (both are referent objects containing individuals)
    ((and (typep ref1 'referent) (typep ref2 'referent))
     (individuals-equal (content ref1) (content ref2)))
    ;; Same individual (both are individual objects directly)
    ((and (individual-p ref1) (individual-p ref2))
     (individuals-equal ref1 ref2))
    ;; Direct equality
    (t (equal ref1 ref2))))

(defun join-types (type1 type2)
  "Join two types - result is the most specific common supertype"
  (cond
    ((types-equal type1 type2) type1)
    ((subtype-p type1 type2) type1)     ; type1 is more specific
    ((subtype-p type2 type1) type2)     ; type2 is more specific
    (t (minimal-common-supertype type1 type2))))

(defun join-referents (ref1 ref2)
  "Join two referents - prefer the more specific one"
  (cond
    ;; Both generic - result is generic
    ((and (null ref1) (null ref2)) nil)
    ;; One generic - use the specific one
    ((null ref1) ref2)
    ((null ref2) ref1)
    ;; Both specific - they must be equal (checked by joinable-p)
    (t (or ref1 ref2))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  SIMPLIFY RULE  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun simplify-duplicate-relations (concept)
  "Simplify Rule: Remove duplicate relations from a concept.
   Two relations are duplicates if they have the same type and
   connect to equivalent concepts."
  (let* ((unique-relations (remove-duplicates (arcs concept) :test #'relations-equivalent-p))
         (removed (set-difference (arcs concept) unique-relations)))
    ;; Update the concept's arcs to only include unique relations
    (setf (arcs concept) unique-relations)
    removed))

(defun equivalent-relation (relation relation-list)
  "Find a relation equivalent to the given relation in the list"
  (find-if (lambda (other-relation)
             (relations-equivalent-p relation other-relation))
           relation-list))

(defun relations-equivalent-p (rel1 rel2)
  "Check if two relations are equivalent (same type, equivalent arcs)"
  (and (types-equal rel1 rel2)
       (= (length (arcs rel1)) (length (arcs rel2)))
       ;; ?? do concepts in arcs need to be in the same order? ??
       (every (lambda (arc1 arc2)
                (concepts-equivalent-p arc1 arc2))
              (arcs rel1) (arcs rel2))))

(defun concepts-equivalent-p (concept1 concept2)
  "Check if two concepts are equivalent for simplification purposes"
  (and (types-equal concept1 concept2)
       (referents-equal concept1 concept2)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  UTILITY FUNCTIONS  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defmethod referents-equal (ref1 ref2 &key (ignore-id t))
;;   "Check if two referents are equal"
;;   (cond
;;     ((and (null ref1) (null ref2)) t)
;;     ((or (null ref1) (null ref2)) nil)
;;     ((and (individual-p ref1) (individual-p ref2))
;;      (individuals-equal ref1 ref2))
;;     (t (equal ref1 ref2))))

;; (defmethod referents-equal ((concept1 concept) (concept2 concept) &key (ignore-id t))
;;   (referents-equal (referent concept1) (referent concept2)))
