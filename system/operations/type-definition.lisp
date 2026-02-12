;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-
;;;
;;; Type Definitions with Lambda Expressions (Type Expansion)
;;;
;;; A type definition uses a lambda expression to define a concept type
;;; in terms of a conceptual graph. The defining concept is marked with
;;; the reserved variable name *lambda.
;;;
;;; Example:
;;;   (:label pet-owner :supertypes (person)
;;;    :definition "[PERSON: *lambda]->(poss)->[PET]")
;;;
;;; Expansion replaces a concept of the defined type with a copy of the
;;; definition graph, transferring the original concept's referent and arcs
;;; to the lambda concept in the copy.

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  type-definition class
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass type-definition ()
  ((graph :initarg :graph
          :accessor definition-graph)
   (lambda-concept :initarg :lambda-concept
                   :accessor lambda-concept)
   (defining-type :initarg :defining-type
                  :accessor defining-type)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  parse-type-definition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun find-lambda-concept (graph)
  "Find the concept with variable name LAMBDA in a graph.
   Returns the concept node, or nil if not found."
  (let ((concepts (graph-concepts graph)))
    (find-if (lambda (concept)
               (let ((var (ignore-errors (node-variable concept))))
                 (and var (string-equal (string var) "LAMBDA"))))
             concepts)))


(defun parse-type-definition (definition-string concept-type-node)
  "Parse a definition string into a type-definition object.
   Returns a type-definition instance, or nil if parsing fails."
  (let* ((*allow-dynamic-individual-creation* t)
         (graph (parse-cgraph definition-string))
         (lambda-concept (find-lambda-concept graph)))
    (unless lambda-concept
      (warn "Type definition for ~a has no *lambda concept: ~a"
            (label concept-type-node) definition-string)
      (return-from parse-type-definition nil))
    (make-instance 'type-definition
                   :graph graph
                   :lambda-concept lambda-concept
                   :defining-type concept-type-node)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ensure-definition-parsed — lazy parsing
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod ensure-definition-parsed ((concept-type-node concept-type))
  "Ensure the type definition is parsed (lazy).
   Parses on first access and caches in the definition slot.
   Returns the type-definition object, or nil if no definition."
  (let ((current (definition concept-type-node)))
    (cond
      ;; Already parsed
      ((typep current 'type-definition) current)
      ;; No definition string — nothing to parse
      ((null (definition-string concept-type-node)) nil)
      ;; Parse and cache
      (t (let ((td (parse-type-definition
                     (definition-string concept-type-node)
                     concept-type-node)))
           (when td
             (setf (definition concept-type-node) td))
           td)))))

(defmethod ensure-definition-parsed ((type-label symbol))
  (let ((node (get-concept-type type-label)))
    (when node
      (ensure-definition-parsed node))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  copy-definition-graph — deep copy tracking the lambda concept
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun copy-definition-graph (type-def)
  "Deep-copy the definition graph from a type-definition.
   Returns (values copied-head copied-lambda-concept).
   Uses the same node-map approach as copy-cgraph but tracks the
   lambda concept through the copy."
  (let* ((original-graph (definition-graph type-def))
         (original-head (head original-graph))
         (original-lambda (lambda-concept type-def))
         (old-nodes (collect-nodes original-head))
         (new-nodes (mapcar #'copy-node old-nodes))
         (node-map (mapcar (lambda (orig new) (cons orig new))
                           old-nodes new-nodes)))

    (flet ((lookup (node)
             (let ((pair (find (node-ref node) node-map
                               :key (lambda (n) (node-ref (car n)))
                               :test #'=)))
               (cdr pair))))

      ;; Rebuild arc lists with new nodes
      (dolist (old-node old-nodes)
        (let ((new-node (lookup old-node)))
          (setf (arcs new-node) (mapcar #'lookup (arcs old-node)))))

      ;; Re-establish variables on copied nodes (except lambda — we'll clear it)
      (dolist (old-node old-nodes)
        (when (and (node-variable old-node)
                   (not (eq old-node original-lambda)))
          (set-variable (lookup old-node))))

      (values (lookup original-head)
              (lookup original-lambda)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  expand-type — the main operation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod expand-type ((concept concept))
  "Expand a concept's type definition.

   Given a concept like [PET-OWNER: Sue]<-(agnt)<-[GIVE]:
   1. Get/parse the definition for PET-OWNER
   2. Deep-copy the definition graph, tracking the lambda concept
   3. Restrict the lambda concept's referent to match the original concept
   4. Transfer the original concept's arcs to the lambda concept
   5. Update graph head if needed
   6. Clear the lambda variable on the copy
   7. Return the expanded lambda concept

   If the concept's type has no definition, returns the concept unchanged."

  (let* ((ctype (concept-type concept))
         (type-def (ensure-definition-parsed ctype)))

    ;; No definition — return unchanged
    (unless type-def
      (return-from expand-type concept))

    ;; Fresh variable context for the copy
    (initialize-variables)

    (multiple-value-bind (copied-head copied-lambda)
        (copy-definition-graph type-def)

      ;; Restrict the lambda concept's type and referent to match original
      (when (referent concept)
        (setf (referent copied-lambda) (referent concept)))

      ;; Transfer arcs: relink the original concept's relations to copied-lambda
      (let ((original-relations (arcs concept)))
        (dolist (relation original-relations)
          ;; In each relation's arc list, substitute copied-lambda for original concept
          (setf (arcs relation) (substitute copied-lambda concept (arcs relation))))
        ;; Add the original relations to the lambda concept's arc list
        (setf (arcs copied-lambda) (union (arcs copied-lambda) original-relations)))

      ;; Update graph head if the original concept was the head of its graph
      (let ((original-graph (graph concept)))
        (when (and original-graph
                   (eq (head original-graph) concept))
          (setf (head original-graph) copied-lambda)))

      ;; Wrap the copied definition in a graph if it isn't already
      (unless (graph copied-head)
        (make-graph-from-nodes copied-head))

      ;; Clear the lambda variable on the copy
      (ignore-errors (unset-variable copied-lambda))

      copied-lambda)))
