;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(declaim (sb-ext:disable-package-locks set))
(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  individual  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defvar *always-show-individual-id* nil)


(defun initialize-individuals ()
  (setf *current-individual-number* 1)
  (setf *individuals* (list)))


(defclass individual (basic-node)
  ((id :initarg :id
       :type number
       :accessor id)
   (type :initarg :type
         :type concept-type
         :accessor individual-type)
   (properties :initform (list)
               :initarg :properties
               ;;:accessor properties
               :accessor properties)
   ;; referent that wraps this individual (if any)
   ;; (referent :initform nil
   ;;           :initarg :referent
   ;;           :accessor individual-referent)
   ;;concepts referencing this individual
   (concepts :initform (list)
             :accessor concepts)))


(defmethod id ((thing (eql nil))) nil)

;; Properties accessor - delegates to referent if available, otherwise uses local slot
;; (defmethod properties ((individual individual))
;;   (let ((ref (individual-referent individual)))
;;     (if ref
;;         (properties ref)
;;         (properties individual))))

;; (defmethod (setf properties) (value (individual individual))
;;   (setf (properties individual) value))

(defmethod properties ((thing (eql nil))) nil)

(defmethod concept-type ((individual individual))
  (individual-type individual))

(defmethod types-equal ((individual1 individual) (individual2 individual))
  (types-equal (individual-type individual1) (individual-type individual2)))



(defmethod initialize-instance :after ((instance individual) &key &allow-other-keys)
  (record-individual instance))


(defmethod print-object ((object individual) stream)
  (let ((props (properties object)))
    (print-unreadable-object (object stream :type nil :identity nil)
      (format stream "INDIV ~a" (label (individual-type object)))
      (dolist (prop props)
        (format stream " ~s" prop))
      (format stream ", ~a" (id object))))

  ;;(princ (format-individual object) stream)
  )





;; (defmethod individuals-with-marker ((marker string))
;;   (when (and (char-equal (elt marker 0) #\#)
;;              (every #'digit-char-p (subseq marker 1)))
;;     (let ((id (parse-intrger (subseq marker 1)))
;;           (items (remove-if-not (lambda (indiv) (= (id indiv) id))  )))
;;       items)))

;; (defmethod individuals-with-marker-count ((marker string))
;;   (length (individuals-with-marker marker)))

(defmethod marker-p ((marker string))
  (not (null
        (and (char-equal (elt marker 0) #\#)
             (every #'digit-char-p (subseq marker 1))
             (in-table-p (parse-integer (subseq marker 1)) *individual-property-table* :key #'id)))))



(defmethod individual-p ((thing individual)) t)

(defmethod individual-p ((thing t)) nil)


(defmethod individuals-eq ((ind1 individual) (ind2 individual))
  (eq ind1 ind2))


(defgeneric individuals-equal (individual1 individual2))

(defmethod individuals-equal ((ind1 individual) (ind2 individual))
  (and
   (types-equal (individual-type ind1) (individual-type ind2))
   (properties-equal (properties ind1) (properties ind2))))

(defmethod individuals-equal ((ind1 individual) (ind2 (eql 'nil))) nil)
(defmethod individuals-equal ((ind1 (eql 'nil)) (ind2 individual)) nil)
(defmethod individuals-equal ((ind1 (eql 'nil)) (ind2 (eql 'nil))) t)


(defmethod nodes-equal ((ind1 individual) (ind2 individual))
  (individuals-equal ind1 ind2))


(defmethod same-individual-p ((ind1 individual) (ind2 individual))
  (and (eql (id ind1) (id ind2))
       (types-equal (individual-type ind1) (individual-type ind2))
       (properties-equal (properties ind1) (properties ind2))))



(defvar *id-cache* (make-hash-table :test #'equal))

(defun clear-id-cache ()
  (let ((size (hash-table-count *id-cache*)))
    (clrhash *id-cache*)
    size))




(defun next-individual-number ()
  ;;(uiop/image:print-backtrace :count 9)
  (setf *current-individual-number* (1+ *current-individual-number*)))


(defmethod remove-individual ((individual individual))
  (setf *individuals*
        ;;(remove individual *individuals* :key #'id)
        (remove individual *individuals*)))


;;; :properties may carry an :id property, so ignore it
(defmethod get-individuals (type (properties list))
  (let* ((ctype (get-concept-type type))
         (props (sans-prop properties :id :variable))
         (individuals (remove-if-not
                       (lambda (indiv)
                         (and
                          (types-equal (individual-type indiv) ctype)
                          (equalp (properties indiv) props)))
                       *individuals*)))
    individuals))

(defmethod find-individual-with-id (id)
  (find id *individuals* :key #'id :test #'eql))


;;; The info being parsed may not contain an id
(defmethod get-individual (individual-type &key id properties)
  (let* ((ctype (get-concept-type individual-type))
         (props (sans-prop properties :id :variable)))
    (cond ((null ctype)
           nil)
          ((not (or id properties))
           nil)
          (properties
           (find-if (lambda (indiv)
                      (and
                       (types-equal (individual-type indiv) ctype)
                       (equalp (properties indiv) props)))
                    *individuals*))
          ((eql id 't)
           (find-if (lambda (indiv) (eql (id indiv) 't))
                    *individuals*))
          ((numberp id)
           (find-individual-with-id id)))))



(defmethod make-individual (type &optional (properties (list)) &key id)
  (let ((id (or id (next-individual-number)))
        (ctype (get-concept-type type)))
    (make-instance 'individual :type ctype
                               :id id
                               :properties (sans-prop properties :id))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  ;;  modifying individual cache  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod record-individual ((individual individual))
  (setf *individuals* (cons individual *individuals*)))


(defmethod unique-individual-p ((individual individual))
  (let* ((properties (slot-value individual 'properties))
         (type (slot-value individual 'type))
         (matching-types (gethash type *individual-type-table*))
         (matches (count individual matching-types :test #'individuals-equal)))

    (or (null matches)
        (< matches 2))))

(defmethod unique-individual-p ((thing t))
  nil)



;;; generate the internal representation of a marker from displayedmarker
(defmethod parse-individual-marker ((marker-string string))
  (cond ((equal marker-string "") nil)
        ((equal marker-string "#") 't)
        (t (let* ((number-string (string-left-trim "#" marker-string)))
             (when (and (plusp (length number-string))
                        (every #'digit-char-p number-string))
               (parse-integer number-string))))))



;; (defmethod get-individual-marker ((id number))
;;   ;; verify the id is real
;;   (let ((individual-object (get-individual id)))
;;     (when (and individual-object
;;                (= id (id individual-object)))
;;       (format nil "#~d" id))))

(defmethod get-individual-marker ((text-string string))
  (let* ((hash-pos (position #\# text-string :test #'char-equal)))
    (when hash-pos
      (let ((marker-end (position-if-not #'digit-char-p text-string :start (1+ hash-pos))))
        (parse-individual-marker (subseq text-string hash-pos marker-end))))))



;;; generate the displayed marker from internal representation
;; (defun format-individual-marker (marker)
;;   (cond ((eql marker 't) "#")
;;         ((and (numberp marker) (get-individual marker))
;;          (format nil "#~d" marker))
;;         (t "")))





;; (defmethod setf-properties ((individual individual) &rest keys &key name measure set)
;;   (declare (ignore name measure set))
;;   (setf (properties individual) (apply #'setf-properties (properties individual) keys)))


(defmethod render-properties ((individual individual))
  (render-properties (properties individual)))


(defmethod parse-properties ((individual individual)  &key &allow-other-keys)
  (properties individual))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  restricting  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod restrict ((individual individual) (restrict-properties list))
  (let ((ind-properties (properties individual)))
    (when (subsetp ind-properties restrict-properties)
      (setf (properties individual) restrict-properties))))


(defmethod restrict ((individual individual) (restriction individual))
  (when (types-equal (individual-type individual) (individual-type restriction))
    (restrict individual (properties restriction))))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  formatting  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod format-individual ((individual individual))
  (let* ((separator (if *concise* "" " "))
         (properties (slot-value individual 'properties))
         (id (slot-value individual 'id))
         (unique (unique-individual-p individual))
         (properties-string (format-properties properties))
         (id-string (cond ((numberp id) (format nil " #~d" id))
                          ((eql id 't) (format nil " #"))
                          ((null id) "")))
         (show-id (or *always-show-individual-id* (null properties) (not unique))))
    (format nil "~a~:[~;~a~]" properties-string show-id id-string)))


(defmethod format-object ((object individual)  &rest keys &key &allow-other-keys)
  (let ((*concise* t))
    (format-individual object)))

(defmethod format-node ((node individual)  &rest keys &key &allow-other-keys)
  (apply #'format-individual node keys))


(defmethod format-node ((individual (eql nil))  &rest keys &key &allow-other-keys)
  nil)
