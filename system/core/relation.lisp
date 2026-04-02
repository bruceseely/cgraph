;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  relation  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defclass relation (graph-node)
  ((rtype  :initarg :type
           :accessor relation-type)))


(defmethod make-relation ((rtype relation-type))
  (make-instance 'relation :type rtype))

(defmethod make-relation ((label string))
  (make-relation (intern (string-upcase label))))

(defmethod make-relation ((rtype symbol))
  (let ((relation-type (get-relation-type rtype)))
    (when relation-type
      (make-relation relation-type))))


(defun relation-p (thing)
  (typep thing 'relation))

(defmethod types-equal ((relation1 relation) (relation2 relation))
  (types-equal (relation-type relation1) (relation-type relation2)))

;; (defmethod 1relations-equal ((rel1 relation) (rel2 relation))
;;   "Check if two relations are equivalent (same type, equivalent arcs)"
;;   (and (types-equal rel1 rel2)
;;        (= (length (arcs rel1)) (length (arcs rel2)))
;;        (every (lambda (arc1)
;;                 (find arc1 (arcs rel2) :test #'objects-equal))
;;               (arcs rel1))))

(defmethod relations-equal ((rel1 relation) (rel2 relation))
  "Check if two relations are equivalent (same type, equivalent arcs)"
  (or (nodes-eq rel1 rel2)
      (and
       (types-equal rel1 rel2)
       (equal (num-arcs rel1) (num-arcs rel1))
       ;; arcs should be in the same order
       (every (lambda (con1 con2)
                (objects-equal con1 con2))
              (arcs rel1)
              (arcs rel2)))))



;; (defmethod copy-relation ((relation relation))
;;   (make-relation (relation-type relation)))

;; (defmethod copy-relation ((relation relation))
;;   (let* ((type (relation-type relation))
;;          (new-relation (make-relation type)))
;;     (push (list relation new-relation) *copy-map*)
;;     new-relation))

(defmethod copy-node ((relation relation))
  (copy-relation relation))

(defmethod print-object ((node relation) stream)
  (let ((*package* (find-package :conceptual-graphs)))
  (cond (*always-format-nodes*
         (princ (format-relation node) stream))
        (*include-node-ref*
         (print-unreadable-object (node stream :type t)
           (format stream "~(~a~);~d"
                   (label (relation-type node))
                   (node-ref node))))
        (t
         (print-unreadable-object (node stream :type t)
           (format stream "~(~a~)" (label (relation-type node))))))))

(defmethod format-relation ((node relation) &key &allow-other-keys)
  (let* ((relation-type (relation-type node))
         (node-ref (node-ref node))
         (node-ref-text (format nil "~:[~; +~d~]"  *always-show-node-ref* node-ref))
         (relation-text (format nil "~((~a~a)~)" relation-type (string-right-trim " " node-ref-text))))
    relation-text))

(defmethod format-relation :around ((node relation) &key &allow-other-keys)
  (let ((id (if *include-node-ref* (node-ref node) nil))
        (marked (if (and (marked node) *debug-mode*) marked-string nil))
        (node-text (string-trim "()" (call-next-method))))
    (format nil "(~@[~a~]~a~@[+~a~])" marked node-text id)))


(defmethod format-node ((node relation) &rest keys &key &allow-other-keys)
  (apply #'format-relation node keys))


(defmethod outarc ((rel relation))
  (car (arcs rel)))

(defsetf outarc set-arc-from-relation)

(defmethod inarcs ((rel relation))
  (cdr (arcs rel)))


(defmethod connecting-relation ((con1 concept) (con2 concept))
  (or (find-if (lambda (rel)
                 (nodes-eq (outarc rel) con1))
               (outarcs con2))
      (find-if (lambda (rel)
                 (nodes-eq (outarc rel) con2))
               (outarcs con1))))

;;; 0 :: outgoing arc
;;; 1... incoming arcs
(defmethod arc-number ((relation relation) (arc concept))
  (let ((arcs (arcs relation)))
    (position arc arcs :test #'nodes-equal)))



(defmethod signature ((rel relation))
  (mapcar #'concept-type (arcs rel)))

(defmethod valence ((rel relation))
  (length (arcs rel)))



;; (defmethod placement ((concept concept) (relation relation))
;;   (position concept (arcs relation)))
