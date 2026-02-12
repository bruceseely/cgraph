;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defgeneric read-referent (stream))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  referent  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; p 85


(defclass referent (basic-node)
  ;; only ENTITIES have names, other individuals do not
  ;; a named concept is an indiividual concept
  ;; :name "b" is shortcut in [a] for [a]->(NAME)->[WORD: "b"]

  ((content :initform nil
            :initarg :content
            :accessor content)
   (concept :initform nil
            :initarg :concept
            :accessor concept)
   (properties :initform (list)
               :initarg :properties
               :accessor properties)))

(defmethod content ((ingore (eql 'nil)))
  nil)

;; (defmethod print-object ((referent referent) stream)
;;   ;;(format t "~&-----")
;;   (let ((props (properties referent)))
;;     (print-unreadable-object (referent stream :type t)
;;       (when (individual referent)
;;         (format stream "~s" (concept-type (individual referent))))
;;       (when props
;;         (dolist (prop props)
;;           (format stream " ~s" prop))))))


(defmethod individual-p ((referent referent))
  (and (content referent)
       (typep (content referent) 'individual)))

(defmethod individual ((referent referent))
  (when (individual-p referent)
    (content referent)))


(defmethod concept-type ((referent referent))
  (when (content referent)
    (concept-type (content referent))))

;; properties accessor is now defined by the slot
;; (defmethod properties ((referent referent))
;;   (when (content referent)
;;     (properties (content referent))))

(defmethod conforms ((referent referent) restriction)
  (conforms (content referent) restriction))



(defmethod print-object ((node referent) stream)
  (print-unreadable-object (node stream :type t :identity nil)
    (princ (content node) stream)))



(defmethod copy-referent ((referent referent))
  (make-instance 'referent :content (content referent)
                           :concept (concept referent)
                           :properties (properties referent)))

(defgeneric make-referent (content &optional concept))

(defmethod make-referent ((individual individual) &optional concept)
  (let* ((props (properties individual))
         (referent (make-instance 'referent :content individual :concept concept :properties props)))
    ;;(setf (individual-referent individual) referent)
    referent))

;;; concept can be either a concept or just a concept-type
(defmethod make-rererent ((properties list) &optional concept)
  (let* ((props (sans-prop properties :id :variable))
         (ctype (cond ((typep concept 'concept)
                       (concept-type concept))
                      ((typep concept 'concept-type)
                       concept)))
         (id (getf properties :id))
         (individual (when concept
                       (get-individual ctype :id id
                                             :properties props)))
         (content individual))
    (make-referent content (when (typep concept 'concept) concept))))


(defmethod referent-p ((r referent))
  t)

(defmethod referent-p ((r t))
  nil)


(defgeneric conformity (concept-type referent))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  properties  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod setf-properties ((referent referent) &rest keys &key name measure set)
  (declare (ignore name measure set))
  (setf (properties referent) (apply #'setf-properties (properties referent) keys)))



(defmethod render-properties ((referent referent))
  (render-properties (properties referent)))







(defmethod name-property ((referent referent))
  (getf (properties referent) :name))

(defmethod measure-property ((referent referent))
  (getf (properties referent) :measure))

(defmethod set-property ((referent referent))
  (getf (properties referent) :set))


(defmethod format-referent ((referent referent) &key &allow-other-keys)
  ;;(format t "~&referent: ~s~%"  referent)
  ;;(format t "~&(content referent): ~s~%"  (princ-to-string (content referent)))
  (cond ((content referent)
         (format-object (content referent)))
        ;; generic
        (t "")))

(defmethod format-object ((referent referent) &rest keys &key &allow-other-keys)
  (declare (ignore keys))
  (format-referent referent))





(defmethod referent-contents-equal (ref1 ref2)
  "Check if two referents are equal"
  (cond
    ((and (null ref1) (null ref2)) t)
    ((not (eql (type-of (content ref1)) (type-of (content ref2)))) nil)
    ((objects-equal (content ref1) (content ref2)))
    ;; ((typep (content ref1) 'individual)
    ;;   (individuals-equal (content ref1) (content ref2)))
    ))

(defmethod referents-equal ((ref1 referent) (ref2 referent))
  (and (referent-contents-equal ref1 ref2)
       (properties-equal (properties ref1) (properties ref2))))

(defmethod referents-equal ((ref1 (eql nil)) (ref2 (eql nil))) t)
(defmethod referents-equal ((ref1 t) (ref2 t)) nil)


(defmethod objects-equal (object1 object2)
  (and (equal (type-of object1) (type-of object2))
       (typecase object1
         (individual (individuals-equal object1 object2))
         (set (sets-equal object1 object2))
         (graph (graphs-equal object1 object2))
         (concept (concepts-equal object1 object2))
         (relation (relations-equal object1 object2))
         (referent (referents-equal object1 object2)))))



;; (defmethod generic-p ((properties list))
;;   (not (null (find :gen properties :key #'car))))

;;;;;; (defmethod generic-p ((referent string))
;;;;;;   (let ((properties (parse-properties referent)))
;;;;;;     (generic-p properties)))

;; (defmethod generic-p ((referent referent))
;;   (let ((properties (properties referent)))
;;     (generic-p properties)))


;;;;;; (defmethod measure ((properties list))
;;;;;;   (cadr (assoc :measure properties)))

;;;;;; (defmethod measure ((referent referent))
;;;;;;   (let ((properties (parse-properties referent)))
;;;;;;     (measure properties)))

;;;;;; (defmethod measure-p ((properties list))
;;;;;;   (not (null (measure properties))))

;;;;;; (defmethod measure-p ((referent referent))
;;;;;;   (not (null (measure referent))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;; (defmethod expand-referent ((concept graph-node))
;;;;;;   (assert (typep concept 'concept))
;;;;;;   (let* ((referent (referent concept))
;;;;;;          (properties (properties referent)))
;;;;;;     (cond ((named-p referent)
;;;;;;            (let* ((name-relation (make-relation 'name))
;;;;;;                   ;;(word-ctype (label (get-word-concept-type (name referent))))
;;;;;;                   (word-ctype (label (get-concept-type (name referent))))
;;;;;;                   ;;(name-concept (make-instance 'concept :type word-ctype))
;;;;;;                   (name-concept (make-concept word-ctype))
;;;;;;                   (arc1 (make-arc "->"))
;;;;;;                   (arc2 (make-arc "->"))
;;;;;;                   (mod-properties (remove :name properties :key #'car))
;;;;;;                   )
;;;;;;              (setf (referent concept) (make-referent mod-properties concept))
;;;;;;              (linkup (list concept arc1 name-relation arc2 name-concept))))


;;;;;;           ((measure-p properties)
;;;;;;            (let* ((meas-relation (make-relation 'meas))
;;;;;;                   (meas-concept (make-concept 'measure))
;;;;;;                   (name-relation (make-relation 'name))
;;;;;;                   (meas-ctype (string-left-trim '(#\@) (label (get-concept-type (measure referent)))))
;;;;;;                   (meas-val-concept (make-concept meas-ctype))
;;;;;;                   (arc1 (make-arc "->"))
;;;;;;                   (arc2 (make-arc "->"))
;;;;;;                   (arc3 (make-arc "->"))
;;;;;;                   (arc4 (make-arc "->"))
;;;;;;                   (mod-properties (remove :measure properties :key #'car))
;;;;;;                   )
;;;;;;              (setf (referent concept) (make-referent mod-properties concept))
;;;;;;              (print (list concept arc1 meas-relation arc2 meas-concept arc3 name-relation arc4 meas-val-concept ))
;;;;;;              (linkup (list concept arc1 meas-relation arc2 meas-concept arc3 name-relation arc4 meas-val-concept )))))))


;;;;;; (defmethod compact-referent ((concept graph-node))
;;;;;;   (assert (typep concept 'concept))
;;;;;;   (let ((referent (referent concept)))
;;;;;;     (when referent
;;;;;;       (let* ((links (links concept)))

;;;;;;         (let ((name-link (find 'name links :key (lambda (x) (label (relation-type (rel x)))))))
;;;;;;           (when name-link
;;;;;;             (setf (arcs concept) (remove (rel name-link) (arcs concept) :test #'nodes-eq))
;;;;;;             (add-feature-to-referent referent :name (string-trim '(#\") (label (concept-type (con name-link)))))))

;;;;;;         (let ((measure-link (find 'meas links :key (lambda (x) (label (relation-type (rel x)))))))
;;;;;;           (when measure-link
;;;;;;             (setf (arcs concept) (remove (rel measure-link) (arcs concept) :test #'nodes-eq))
;;;;;;             (add-feature-to-referent referent :measure (string-trim '(#\") (label (concept-type (con measure-link)))))))))
;;;;;;     concept))

;;; (compact-referent (pcg "[person:#123]->(name)->[\"Judy\"]"))
;;; (compact-referent (pcg "[person:#123]->(meas)->[measure: ]"))


;;;;;; (defmethod add-feature-to-referent ((referent referent) (feature-name symbol) feature-value)
;;;;;;     (setf (properties referent) (remove :gen (properties referent)  :key #'car))
;;;;;;     (setf (properties referent) (push (list feature-name feature-value) (properties referent))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;  END  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#|
(format-cgraph (parse-cgraph "[DOG]."))
(format-cgraph (parse-cgraph "[DOG: *]."))
(format-cgraph (parse-cgraph "[DOG: #123]."))
(format-cgraph (parse-cgraph "[DOG: Fido]."))
(format-cgraph (parse-cgraph "[DOG: {*}]."))
(format-cgraph (parse-cgraph "[DOG: {}].")) ;; valid test??
(format-cgraph (parse-cgraph "[DOG: {*} @ 5]."))
(format-cgraph (parse-cgraph "[DOG: {Fido, #123}]."))
(format-cgraph (parse-cgraph "[DOG: {{Fido, Spot}, #123}]."))

(format-cgraph (parse-cgraph "[DOG: {Fido, Spot}]."))
(format-cgraph (parse-cgraph "[DOG: {Fido, *}]."))
(format-cgraph (parse-cgraph "[LENGTH: @ 5 ft.]."))
|#




;; (defmethod pick ((string string) (marker character) indicator)
;;   (let ((index (position marker string)))
;;     (when index
;;       (let ((word (subseq string (1+ index))))
;;         (list indicator word)))))


;; (defun parse-set-string (string)
;;   (let* ((item-list (split-string string))
;;          (result ()))
;;     (unless item-list (setf item-list (list "")))
;;     (dolist (item item-list)
;;       (let ((trimmed (string-right-trim '(#\,) item)))
;;         (cond ((find #\# trimmed) (push
;;                                    (let ((form (pick trimmed #\# :ind)))
;;                                      (setf (cadr form) (make-individual 't (cadr form)))
;;                                      form)
;;                                    result))
;;               ((find #\@ trimmed) (push (pick trimmed #\@ :measure) result))
;;               ((find #\* trimmed) (push (pick trimmed #\* :gen) result))
;;               ((equal trimmed "") (push '(:gen "") result))
;;               ((plusp (length trimmed)) (push (list :name trimmed) result)))))
;;     (reverse result)))



#|
(progn
  (isolate-properties "")
  (isolate-properties "*")
  (isolate-properties "#123")
  (isolate-properties "Fido")
  (isolate-properties "{*}")
  (isolate-properties "{*} @ 5")
  (isolate-properties "{#}")
  (isolate-properties "{#} @ 5")
  (isolate-properties "{#}@5")
  (isolate-properties "{Fido, #123}")
  (isolate-properties "{Fido, Spot}")
  (isolate-properties "{Fido, Spot, *} @5")
  (isolate-properties "{Fido,Spot,*}@5")
  (isolate-properties "{Fido, Spot, Rex, Butch}")
  (isolate-properties "{Fido, *}")
  (isolate-properties "{Fido, *} @3")
  (isolate-properties "@ 5 ft.")
  (isolate-properties "*x")
  )
(progn
  (parse-properties "")
  (parse-properties "*")
  (parse-properties "#123")
  (parse-properties "Fido")
  (parse-properties "{*}")
  (parse-properties "{*} @ 5")
  (parse-properties "{#}")
  (parse-properties "{#} @ 5")
  (parse-properties "{Fido, #123}")
  (parse-properties "{Fido, Spot}")
  (parse-properties "{Fido, Spot, *} @5")
  (parse-properties "{Fido, Spot, Rex, Butch}")
  (parse-properties "{Fido, *}")
  (parse-properties "{Fido, *} @3")
  (parse-properties "@ 5 ft.")
  (parse-properties "@5ft.")
  (parse-properties "*x")
  )

(progn
  (render-properties (parse-properties ""))
  (render-properties (parse-properties "*"))
  (render-properties (parse-properties "#123"))
  (render-properties (parse-properties "Fido"))
  (render-properties (parse-properties "{*}"))
  (render-properties (parse-properties "{*} @ 5"))
  (render-properties (parse-properties "{#}"))
  (render-properties (parse-properties "{#} @ 5"))
  (render-properties (parse-properties "{Fido, #123}"))
  (render-properties (parse-properties "{Fido, Spot}"))
  (render-properties (parse-properties "{Fido, Spot, *} @5"))
  (render-properties (parse-properties "{Fido, Spot, Rex, Butch}"))
  (render-properties (parse-properties "{Fido, *}"))
  (render-properties (parse-properties "{Fido, *} @3"))
  (render-properties (parse-properties "@ 5 ft."))
  (render-properties (parse-properties "@5ft."))
  (render-properties (parse-properties "*x"))
  )


(progn
  (format-referent (parse-properties ""))
  (format-referent (parse-properties "*"))
  (format-referent (parse-properties "#123"))
  (format-referent (parse-properties "Fido"))
  (format-referent (parse-properties "{*}"))
  (format-referent (parse-properties "{*} @ 5"))
  (format-referent (parse-properties "{#}"))
  (format-referent (parse-properties "{#} @ 5"))
  (format-referent (parse-properties "{Fido, #123}"))
  (format-referent (parse-properties "{Fido, Spot}"))
  (format-referent (parse-properties "{Fido, Spot, *} @5"))
  (format-referent (parse-properties "{Fido, Spot, Rex, Butch}"))
  (format-referent (parse-properties "{Fido, *}"))
  (format-referent (parse-properties "{Fido, *} @3"))
  (format-referent (parse-properties "@ 5 ft."))
  (format-referent (parse-properties "@5ft."))

  (multiple-value-bind (properties variable)
           (parse-properties "*x")
     (format-referent properties :variable variable))
  )
|#



#|
see page 89, 90, 116-120
(progn
  ;; no referent, generic concept
  (render-properties (parse-properties ""))
  ;; no referent, generic concept
  (render-properties (parse-properties "*"))
  ;; individual marker
  (render-properties (parse-properties "#123"))
  ;; specific, unidentified individual (the cat)
  (render-properties (parse-properties "#"))
  ;; name
  (render-properties (parse-properties "Fido"))
  ;; plural i.e. a set with unspecified members
  (render-properties (parse-properties "{*}"))
  ;; plural i.e. a set with 5 members
  (render-properties (parse-properties "{*} @ 5"))

  ;; ??
  (render-properties (parse-properties "{#}"))
  (render-properties (parse-properties "{#} @ 5"))

  ;; set with Fido and one specific individual
  (render-properties (parse-properties "{Fido, #123}"))
  ;; set with Fido and Spot
  (render-properties (parse-properties "{Fido, Spot}"))
  ;; set with Fido and one unidentified individual
  (render-properties (parse-properties "{Fido, *}"))
  ;; Fido, Spot, and 2 others
  (render-properties (parse-properties "{Fido, Spot, *}@4"))
  ;; measure of 5 feet
  (render-properties (parse-properties "@ 5 ft."))
  ;; generic individual, masked with a variable
  (render-properties (parse-properties "*x"))

  (render-properties '((:IND "#123") (:MEASURE "@5 in"))  NIL)
  ;;(multiple-value-call #'render-properties (parse-properties "*x"))
  )

   (multiple-value-call #'render-properties  (parse-properties "*x"))
|#



;; (defmethod generic-p ((referent string))
;;   (let* ((referent-info referent)
;;          (left-brace  (position #\{ referent-info))
;;          (right-brace (position #\} referent-info))
;;          (set-start (when left-brace (1+ left-brace)))
;;          (set-end   (when (and right-brace set-start (> right-brace left-brace)) right-brace))
;;          (set-text  (when (and set-start set-end) (subseq referent-info set-start set-end)))
;;          (set-p (not (null set-text)))
;;          (start (if set-p (1+ set-end) 0))
;;          (end (length referent-info))
;;          (text (when (and start end) (subseq referent-info start end)))
;;          (asterisk (position #\* text))
;;          )
;;     (or (zerop (length referent-info))
;;         (not (null (and (not set-p) asterisk))))))

;; (defmethod name ((properties list))
;;   (cadr (assoc :name properties)))

;; (defmethod name ((referent referent))
;;   (let ((properties (parse-properties referent)))
;;     (name properties)))


;; (defmethod named-p ((properties list))
;;   (not (null (find :name properties :key #'car))))

;; (defmethod named-p ((referent referent))
;;   (let ((properties (properties referent)))
;;     (named-p properties)))


;;; (expand-referent (pcg "[person: Judy]"))
;;; (fcg (expand-referent (pcg "[person: Judy]")))
;;; (expand-referent (pcg "[length: @ 5 ft.]"))
;;; (fcg (expand-referent (pcg "[length: @ 5 ft.]")))
;;; (expand-referent (pcg "[length:@25.4 cm]"))
;;; (fcg (expand-referent (pcg "[length: @ 5 ft.]")))
;;; (fcg (expand-referent (pcg "[length:@25.4 cm]")))
