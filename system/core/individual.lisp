;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(declaim (sb-ext:disable-package-locks set))
(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  individual  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
               :accessor properties)
   ;;concepts referencing this individual
   (concepts :initform (list)
             :accessor concepts)))


(defmethod id ((thing (eql nil))) nil)
(defmethod properties ((thing (eql nil))) nil)

(defmethod concept-type ((individual individual))
  (individual-type individual))

(defmethod types-equal ((individual1 individual) (individual2 individual))
  (types-equal (individual-type individual1) (individual-type individual2)))


;; (defmethod print-object ((object individual) stream)
;;   (let ((props (properties object)))
;;     (print-unreadable-object (object stream :type nil :identity nil)
;;       (format stream "INDIV ~a" (label (individual-type object)))
;;       (dolist (prop props)
;;         (format stream " ~s" prop))
;;       (format stream ", ~a" (id object)))))


(defmethod print-object ((object individual) stream)
  (princ (format-individual object) stream))

(defmethod initialize-instance :after ((instance individual) &key &allow-other-keys)
  (record-individual instance))



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


(defgeneric individuals-equal (individual1 individual2 &key ignore-id))

(defmethod individuals-equal ((ind1 individual) (ind2 individual) &key (ignore-id t))
  (and
   (types-equal (individual-type ind1) (individual-type ind2))
   (properties-equal (properties ind1) (properties ind2) :ignore-id ignore-id)))

(defmethod individuals-equal ((ind1 individual) (ind2 (eql 'nil)) &key ignore-id) ignore-id nil)
(defmethod individuals-equal ((ind1 (eql 'nil)) (ind2 individual) &key ignore-id) ignore-id nil)
(defmethod individuals-equal ((ind1 (eql 'nil)) (ind2 (eql 'nil)) &key ignore-id) ignore-id t)


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
  (let* ((ctype (concept-type type))
         (props (sans-prop properties :id :vaariable))
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  formatting  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defmethod format-individual ((individual individual))
  (let* ((separator (if *concise* "" " "))
         (properties (slot-value individual 'properties))
         (id (slot-value individual 'id))
         (unique (unique-individual-p individual))
         (properties-string (format-properties properties))
         (id-string (cond ((numberp id) (format nil "#~d" id))
                          ((eql id 't) (format nil "#"))
                          ((null id) "")))
         (show-id (or *always-show-id* (null properties) (not unique))))
    (format nil "~a~:[~;~a~]" properties-string show-id id-string)))


(defmethod format-object ((object individual)  &rest keys &key &allow-other-keys)
  (let ((*concise* t))
    (format-individual object)))

(defmethod format-node ((node individual)  &rest keys &key &allow-other-keys)
  (apply #'format-individual node keys))


(defmethod format-node ((individual (eql nil))  &rest keys &key &allow-other-keys)
  nil)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  properties  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod name-property ((individual individual))
  (getf (properties individual) :name))

(defmethod measure-property ((individual individual))
  (getf (properties individual) :measure))



(defmethod set-property ((individual individual))
  (getf (properties individual) :set))


;;; recgonized properties
;;; :name - string
;;; :measure - a cons of (value (number) . units-string)
;;; :set


;;; a property is a tag-value pair on the properties plist
;;; for property '(:id arg ...)
;;; arg == number => a specific, identiified individual; (:id 244) => #244
;;; arg == t => a specific, identiified individual; (:id t) => #<next-number>
;;; arg == nil => a specific, unidentiified individual; (:id nil) => #
;;; no :id spec => no individual  (no properties)
;;;
;;; :variable is a string; "x"


;; ;; incllude a variable if necessary ----> concept
;; (when (and variable properties)
;;   (setf result (format nil "~a~:[ ~;~]*~(~a~)" result *concise* variable)))


(defun property-keys (property-list)
  (remove-if-not #'keywordp property-list))


;;; sans-prop is like remf, except:
;;; - the source place is not modified
;;; - a new plist, missing the requested omission(s), is returned
;;; - a second returned value indicates whether a change was made
;;; - multiple properties can be removed with one function call
(defun sans-prop (place &rest indicators)
  (let ((new-plist (copy-list place)))
    (dolist (indicator indicators)
      (remf new-plist indicator))
    (values new-plist (not (= (length new-plist) (length place))))))

(defvar *property-order* (list :name :set :measure :id :variable))

;;; put props list in a canonical order
(defun sort-properties (props)
  ;; reverse order
  (let ((keys *property-order*)
        (sorted (list)))
    (dolist (key keys)
      (let ((val (getf props key)))
        (when val
          (push (list key val) sorted))))
    (apply #'append sorted)))

(defun sort-property-keys (props)
  (let* ((keys *property-order*)
         (sorted (list)))
    (dolist (key keys)
      (when (find key props :test #'eq)
        (push key sorted)))
    (reverse sorted)))


;; :id shouldn't be in properties lists
(defmethod properties-equal ((props1 list) (props2 list) &key (ignore-id t))
  (when ignore-id
    (setf props1 (sans-prop props1 :id))
    (setf props2 (sans-prop props2 :id)))
  (let* ((a1 (sort-properties props1))
         (a2 (sort-properties props2)))
    (equalp a1 a2)))



;;; a property-list is a list of a tag-value pair on the properties plist
;;; like (:name "Fred" ...)
(defun format-property (property-list)
  ;;(format t "~&(format-property ~s)~%" property)

  (destructuring-bind (tag arg) property-list
    (case tag
      (:graph
       (format nil "~a" arg))
      (:name
       (format nil "~a" arg))

      (:set
       ;;(assert (listp arg))
       (let* (expanded)
         (do* ((list arg (cdr list)))
              ((null list))
           (let* ((term (car list))
                 (formatted (format-property term)))
           (push formatted expanded)))
         (let ((formatted (format nil "{~{~a~^, ~}}" expanded)))
           formatted)))

      (:measure
       (assert (listp arg))
       (let ((size (car arg))
             (units (cadr arg)))
         (cond ((null arg) "")
               ((null units) (format nil "@~a" size))
               (t (format nil "@~a~:[ ~;~]~a" size *concise* units)))))
      (:id
       (cond ((null arg) nil)
             ((eq arg 't) "#")
             (t (format nil "#~a" arg))))
      (:indiv
       (cond ((null arg) nil)
             ((eq arg 't) "#")
             (t (format nil "#~a" arg))))

      (t nil))))


(defmethod format-properties (properties)
  ;;(format t "~&(format-properties ~s)~%" properties)

  (let ((separator (if *concise* "" " "))
        (keys '(:name :set :measure :id))
        (result ""))

    (cond ((null properties) (setf result ""))
          ((eq properties 't) (setf result "*"))
          (properties
           (dolist (key keys)
             (let* ((presentp (find key properties :test #'eq))
                    (property-spec (list key (getf properties key)))
                    (term (when presentp (format-property property-spec))))
               (when term
                 (setf result (format nil "~a~a~a" result separator term)))))))

    (string-trim '(#\tab #\space #\comma) result)))



;;; return the properties list that describes the referent
;;; in graph-nodes.lisp
(defmethod parse-properties ((property-string string) &key variable)
  variable
  (with-input-from-string (stream property-string)
    (let* ((terms (read-features stream))
           (variable (getf terms :variable)))
      (remf terms :variable)
      (values terms variable))))



(defmethod setf-properties ((properties list) &key name measure set)
  (when name    (setf (getf properties :name) name))
  (when measure (setf (getf properties :measure) measure))
  (when set     (setf (getf properties :set) set))
  properties)

(defmethod setf-properties ((individual individual) &rest keys &key name measure set)
  (declare (ignore name measure set))
  (setf (properties individual) (apply #'setf-properties (properties individual) keys)))

(defun make-properties (&rest keys &key name measure set)
  (declare (ignore name measure set))
  (let ((properties (list)))
    (apply #'setf-properties properties keys)))


;;; when a key occurs in both plists, take the value
;;; from the first plist unless take-last is true
(defmethod combine-plists ((plist1 list) (plist2 list) &optional take-last)
  (let* ((keys1 (property-keys plist1))
         (keys2 (property-keys plist2))
         (keys (sort-property-keys (remove-duplicates (append keys1 keys2))))
         (combined (if take-last
                       (append plist2 plist1)
                       (append plist1 plist2)))
         (plist (list)))
    (dolist (key keys)
      (push key plist)
      (push (getf combined key) plist))
   (reverse  plist)))





;;; inverse of parse-properties
;;; properties do not contain variable info, but the string representation does
;;; return a string representation of properties
(defmethod render-properties ((properties list))
  ;;(print-backtrace)
  ;;(format t "~%>> (render-properties ~s)~%" properties)
  (let ((set-properties (getf properties :set))
        (graph (getf properties :graph))
        (other-properties (sans-prop properties :graph :set))
        )
    graph
    (let* ((set-str (if set-properties
                        (format-individual (list :set set-properties) :comma-p t)
                        ""))
           (other-str (if other-properties
                        (format-individual other-properties)
                        ""))
           (feature-string (strcat set-str other-str)))
      feature-string)))



(defmethod render-properties ((feature-string string))
  (values feature-string))

(defmethod render-properties ((individual individual))
  (render-properties (properties individual)))


;;; parse the display property-string representation
;;; create a referent-spec from the properties extracted from the supplied string
(defmethod parse-properties ((property-string string) &key variable)
  (let ((components (isolate-properties property-string))
        (properties (list))
        variable)

    (if (and (= (length components) 1) (equal (car components) ""))
        (setq properties '())
        (let ((measure    (find #\@ components :key (lambda (z) (elt z 0))))
              (individual (find #\# components :key (lambda (z) (elt z 0))))
              (generic    (find #\* components :key (lambda (z) (elt z 0))))
              (ref        (find #\+ components :key (lambda (z) (elt z 0))))
              (graph      (find #\[ components :key (lambda (z) (elt z 0))))
              (set        (find #\{ components :key (lambda (z) (elt z 0))))
              (name       (unless (find (elt (car components) 0) '(#\@ #\# #\* #\+ #\{ #\[))
                            (car components))))
          (when graph
            (push (list :graph graph) properties))
          (when measure
            (push (list :measure (remove #\space measure)) properties))
          (when individual
            (push (list :indiv individual) properties))
          (when generic
            (cond ((= (length generic) 1)
                   (push (list :gen generic) properties))
                  (t
                   (let ((var (subseq generic 1))
                         (ast (subseq generic 0 1)))
                     (setf variable var)
                     (push (list :gen ast) properties)))))
          (when ref
            (push (list :ref ref) properties))
          (when set
            (let* ((set-properties-string (string-trim "{}" set))
                   (set-properties (split-string set-properties-string :separator ",")))
              (push (list :set (mapcar (lambda (x) (string-trim " " x)) set-properties)) properties)))
          (when name
            (push (list :name name) properties))))
    (values (apply #'append properties) variable)))

(defmethod parse-properties ((individual individual)  &key variable)
  (properties individual))
