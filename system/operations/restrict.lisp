;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; restrict rule  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; - may replace the type label of a concept with the label of a subtype
;; - may convert a generic concept to an individual concept
;; - checks conformity
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; combined-referent

(defmethod combine-referents ((individual1 individual) (individual2 individual))
  (when (eql (id individual1) (id individual2))
    (cond ((nodes-eq individual1 individual2)  individual1)
          ((types-equal (concept-type individual1) (concept-type individual2))
           (let* ((properties1 (properties individual1))
                  (properties2 (properties individual2))
                  (properties (combine-plists properties1 properties2)))
             (setf (properties individual1) properties)
             individual1))
          (t nil))))


(defmethod combine-referents ((ref1 individual) (ref2 (eql 'nil)))
  ref1)

(defmethod combine-referents ((ref1 (eql 'nil)) (ref2 individual))
  ref2)

(defmethod combine-referents ((ref1 (eql 'nil)) (ref2 (eql 'nil)))
  nil)

(defmethod combine-referents ((referent1 referent) (referent2 referent))
  (combine-referents (content referent1) (content referent2)))

(defmethod combine-referents ((concept1 concept) (concept2 concept))
  (combine-referents (referent concept1) (referent concept2)))



(defmethod restrictable-concepts-p ((concept1 concept) (concept2 concept))
  (let ((common-subtype (maximal-common-subtype concept1 concept2)))
    (when common-subtype
      (and (conforms concept1 common-subtype)
           (conforms concept2 common-subtype)))))



(defmethod restrict-concept-type ((concept concept) (restriction-concept-type concept-type))
  "Modifies concept's type according to the restriction-concept-type"
  (cond ((proper-subtype-p (concept-type concept) restriction-concept-type)
         (warn "The concept ~a cannot be restricted to a supertype, ~a"
               concept restriction-concept-type))
        ((proper-subtype-p restriction-concept-type (concept-type concept))
         (setf (concept-type concept) restriction-concept-type)))
  concept)

(defmethod restrict-concept-type ((concept concept) (restriction-concept-type symbol))
  (let ((concept-type (get-concept-type restriction-concept-type)))
    (when concept-type
      (restrict-concept-type concept concept-type))))

(defmethod restrict-concept-type ((concept concept) (restriction-concept concept))
  (let ((concept-type (concept-type concept)))
    (when concept-type
      (restrict-concept-type concept concept-type))))



;;;; (defmethod restrict-concept-referent ((concept concept) (restriction-properties list))
;;;;   (let ((changed nil))
;;;;     ;; ensure restriction-properties is clean
;;;;     (remf restriction-properties :id)
;;;;     (remf restriction-properties :variable)
;;;;     (cond ((null restriction-properties))
;;;;           ((generic-p concept)
;;;;            (setf (referent concept (make-referent
;;;;            )
;;;;           (t
;;;;            (let ((ref (referent concept))
;;;;                  referent)
;;;;              (when content
;;;;                (setf (properties (referent concept))
;;;;                              (combine-plists (referent concept)
;;;;                                              restriction-properties)))
;;;;            (setf changed t))))
;;;;     (values concept changed)))

(defmethod restrict-concept-referent ((concept concept) (individual individual))
  (let ((properties (properties individual)))
    (cond (properties
           (restrict-concept-referent concept properties))
          (t concept))))



(defmethod restrict-concept ((concept concept) (restriction concept))
  (when (restrictable-concepts-p concept restriction)
    (restrict-concept-type concept (concept-type restriction))
    (when (individual restriction)
      (restrict-concept-referent concept (properties (individual restriction)))))
  concept)

(defmethod restrict-concept ((concept concept) (restriction concept-type))
  (restrict-concept-type concept restriction))

(defmethod restrict-concept ((concept concept) (restriction symbol))
  (restrict-concept-type concept (get-concept-type restriction)))

(defmethod restrict-concept ((concept concept) (restriction list))
  (restrict-concept-referent concept restriction))



;;; concept is modified
(defgeneric restrict (concept restriction))

(defmethod restrict ((concept concept) (restriction concept-type))
  (cond ((null (referent concept))
         (restrict-concept-type concept restriction))
        ((subtype-p (concept-type concept) restriction)
         (warn "The concept ~a cannot be 'restricted' to a supertype, ~a" concept restriction))
        ((not (conforms (referent concept) restriction))
         (warn "Cannot restrict ~a to ~a; conforms issue." concept restriction))
        (t
         (restrict-concept concept restriction)
  (restrict-concept-type concept (concept-type restriction))
  concept)))



(defmethod restrict ((concept concept) (properties list))
  (cond ((null (referent concept))
         (let* ((individual (or (get-individual (concept-type concept) :properties properties)
                                (make-individual (concept-type concept) properties)))
                (referent individual))
           (setf (referent concept) referent)))
        (t
         (cond ((individual-p (referent concept))
                (let* ((new-props (combine-plists (properties (referent concept)) properties))
                       (individual (or (get-individual (concept-type concept) :properties  new-props)
                                       (make-individual (concept-type concept) new-props)))
                       (referent individual))
                  (setf (referent concept) referent))))))
  concept)


(defmethod restrict ((concept concept) (restricting-concept concept))
  (let* ((common-subtype (maximal-common-subtype concept restricting-concept))
         (restricting-referent (referent restricting-concept))
         (restricting-content (when restricting-referent restricting-referent))
         (initial-type (concept-type concept)))
    ;;(restrict-concept-type concept (concept-type restricting-concept))
    (restrict-concept-type concept common-subtype)
    (cond ((null (referent restricting-concept)))
          ((null (referent concept))
           (setf (referent concept) (referent restricting-concept)))
          (t
           (setf (referent concept)
                 (combine-referents (referent concept) (referent restricting-concept)))))
    concept))


(defmethod restrict ((concept concept) (restriction string))
  (let ((properties (parse-properties restriction)))
    (when properties
      (restrict concept properties))))

(defmethod restrict ((concept concept) (restriction symbol))
  (restrict-concept concept restriction))


(defmethod restrict ((concept concept) (restriction individual))
  (cond ((generic-p concept)
         (setf (referent concept) restriction))
        (t
         (let ((common-subtype (maximal-common-subtype (concept-type concept)
                                                       (concept-type restriction))))
           (restrict-concept-type concept common-subtype)
           (setf (referent concept) restriction))))
  concept)


(defvar *bad-ref-concept* nil)
;; check conformity
(defmethod restrict :around (concept restriction)
  (let ((concept (call-next-method)))
    (cond ((and (referent concept)
                (not (conforms (referent concept) restriction )))
           (setf *bad-ref-concept* (list concept restriction))
           (error "restrict of ~s causes a conformity violation" concept)
           nil)
          (t concept))))




;; (defmethod restrict :after (concept restriction)
;;   ;;(declare (ignore restriction))
;;   (when (and (individual concept)
;;              (not (conforms (individual concept) restriction )))
;;     (error "restrict of ~s causes a conformity violation" concept)))



;;; concept1 is modified
;; (defmethod mutually-restrict ((concept1 concept) (concept2 concept))
;;   (let ((common-subtype (maximal-common-subtype concept1 concept2)))
;;     (restrict-concept-type concept1 common-subtype)
;;     (restrict-concept-type concept2 common-subtype))
;;   (setf (individual concept1)
;;         (combined-referent (individual concept1) (individual concept2)))
;;   concept1)
