;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(declaim (sb-ext:disable-package-locks set))
(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  conformity ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod conforms ((concept-type1 concept-type) (concept-type2 concept-type))
  (subtype-p concept-type2 concept-type1))

;;; use: Ask can this concept's type be changed to this ctype?
(defmethod conforms ((individual individual) (concept-type concept-type))
  (let* ((individual-type (individual-type individual))
         (mcs (maximal-common-subtype individual-type concept-type)))
    (or
     (eq individual-type *concept-type-top*)
     (and
      (or
       (subtype-p individual-type concept-type)
       ;; not sure about this part
       (subtype-p individual-type concept-type))
      (subtype-p mcs individual-type)
      (not (eql individual-type *concept-type-bottom*))))))

(defmethod conforms ((individual individual) (concept-type symbol))
  (let ((type (get-concept-type concept-type)))
    (when type
      (conforms individual type))))

(defmethod conforms ((individual individual) (concept-type string))
  (let ((type (get-concept-type concept-type)))
    (when type
      (conforms individual type))))


;;; move to concept code
;; (defmethod conforms ((individual individual) (concept concept))
;;   (let ((concept-type (concept-type concept)))
;;     (when concept-type
;;       (conforms individual concept-type))))

(defmethod conforms ((individual1 individual) (individual2 individual))
  (individuals-equal individual1 individual2))

(defmethod conforms ((individual-id number) concept-type)
  (let ((individual (get-individual :id individual-id)))
    (when individual
      (conforms individual concept-type))))


(defmethod conforms ((individual individual) (properties list))
  (cond ((null (properties individual)) t)
        (t
         ;; probably not right, want something like subsumes
         (properties-equal (properties individual) properties))))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  ;;  processing  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;; (defmethod expand-individual ((concept graph-node))
;;   (assert (typep concept 'concept))
;;   (let* ((individual (individual concept))
;;          (properties (properties individual)))
;;     (cond ((name individual)
;;            (let* ((name-relation (make-relation 'name))
;;                   ;;(word-ctype (label (get-word-concept-type (name individual))))
;;                   (word-ctype (label (get-concept-type (name individual))))
;;                   ;;(name-concept (make-instance 'concept :type word-ctype))
;;                   (name-concept (make-concept word-ctype nil))
;;                   (arc1 (make-arc "->"))
;;                   (arc2 (make-arc "->"))
;;                   (mod-properties (remove :name properties :key #'car))
;;                   )
;;              (setf (individual concept) (make-individual mod-properties concept))
;;              (linkup (list concept arc1 name-relation arc2 name-concept))))
;;           ((measure-p properties)
;;            (let* ((meas-relation (make-relation 'meas))
;;                   (meas-concept (make-concept 'measure nil))
;;                   (name-relation (make-relation 'name))
;;                   (meas-ctype (string-left-trim '(#\@) (label (get-concept-type (measure individual)))))
;;                   (meas-val-concept (make-concept meas-ctype nil))
;;                   (arc1 (make-arc "->"))
;;                   (arc2 (make-arc "->"))
;;                   (arc3 (make-arc "->"))
;;                   (arc4 (make-arc "->"))
;;                   (mod-properties (remove :measure properties :key #'car))
;;                   )
;;              (setf (individual concept) (make-individual mod-properties concept))
;;              (print (list concept arc1 meas-relation arc2 meas-concept arc3 name-relation arc4 meas-val-concept ))
;;              (linkup (list concept arc1 meas-relation arc2 meas-concept arc3 name-relation arc4 meas-val-concept )))))))


;;; modify object direcctly.....
;; (defmethod add-property-to-individual ((individual individual) (property-def list) )
;;   (let* ((slots (sb-mop:class-direct-slots (find-class 'individual)))
;;          ;;(slot (find property-name slots :test #'sb-mop:slot-definition-name))
;;          (property (car property-def))
;;          (value (cadr property-def))
;;          (slot nil))
;;     (format t "~%property: ~s" property)
;;     (block nil
;;       (dolist (direct-slot slots)
;;         ;;(format t "~%: ~s" )
;;         (format t "~%slot: ~s" slot)
;;         (format t "~%(sb-mop:slot-definition-name slot): ~s" (sb-mop:slot-definition-name direct-slot))
;;         (let ((sname (sb-mop:slot-definition-name direct-slot)))
;;           (format t "~%(equal sname property): ~s" (equal sname property))
;;           ;;(format t "~%: ~s" )
;;           (when (equal sname property)
;;             (setf slot direct-slot)
;;             (return)))))
;;     (setf (slot-value individual property) value))
;;     t)


;; (defmethod compact-individual ((concept graph-node))
;;   (assert (typep concept 'concept))
;;   (let ((individual (individual concept)))
;;     (when individual
;;       (let* ((links (links concept)))
;;         (let ((name-link (find 'name links :key (lambda (x) (label (relation-type (rel x)))))))
;;           (when name-link
;;             (setf (arcs concept) (remove (rel name-link) (arcs concept) :test #'nodes-eq))
;;             (add-property-to-individual individual :name (string-trim '(#\") (label (concept-type (con name-link)))))))
;;         (let ((measure-link (find 'meas links :key (lambda (x) (label (relation-type (rel x)))))))
;;           (when measure-link
;;             (setf (arcs concept) (remove (rel measure-link) (arcs concept) :test #'nodes-eq))
;;             (add-property-to-individual individual :measure (string-trim '(#\") (label (concept-type (con measure-link)))))))))
;;     concept))

;;; (compact-referent (pcg "[person:#123]->(name)->[\"Judy\"]"))
;;; (compact-referent (pcg "[person:#123]->(meas)->[measure: ]"))




;; ;;; Should there be some checking?
;; (defmethod combined-individual-properties ((individual1 individual) (individual2 individual))
;;   (let* ((properties1 (properties individual1))
;;          (generic-p1 (generic-p properties1))
;;          (properties2 (properties individual2))
;;          (generic-p2 (generic-p properties2))
;;          (all-properties (append properties1 properties2)))
;;     ;; (format t "~&properties1: ~s" properties1)
;;     ;; (format t "~&properties2: ~s" properties2)
;;     ;; (format t "~&all-properties: ~s" all-properties)
;;     (when (or generic-p1 generic-p2)
;;       (delete :gen all-properties :key #'car))))
;;
;; (defmethod combined-individual ((individual1 individual) (individual2 individual))
;;   (let* ((original-ctype1 (concept-type individual1))
;;          (original-ctype2 (concept-type individual2))
;;          (original-ctype (cond ((null original-ctype1)
;;                                 original-ctype2)
;;                                ((null original-ctype2)
;;                                 original-ctype1)
;;                                ((eq original-ctype1 original-ctype2)
;;                                 original-ctype1)
;;                                ((subtype-p original-ctype1 original-ctype2)
;;                                 original-ctype1)
;;                                ((subtype-p original-ctype2 original-ctype1)
;;                                 original-ctype2)
;;                                ((and original-ctype1 original-ctype1)
;;                                 ;; ?? correct ??
;;                                 (maximal-common-subtype original-ctype1 original-ctype2))
;;                                (t nil)))
;;          (name1 (name-property individual1))
;;          (name2 (name-property individual2))
;;          (id1 (id individual1))
;;          (id2 (id individual2))
;;          (properties1 (properties individual1))
;;          (properties2 (properties individual2))
;;          (different-subjects (cond ((and name1 name2 (not (equal name1 name2))))
;;                                    ((and id1 id2 (not (equal id1 id2))))))
;;          (combined-properties (unless different-subjects
;;                               (append properties1 properties2))))
;;     (unless different-subjects
;;       (make-instance 'individual
;;                      :type original-ctype
;;                      :properties combined-properties
;;                      ;; ??
;;                      :id id1))))
