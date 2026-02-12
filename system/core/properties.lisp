;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)



;;; a property is a tag-value pair on the properties plist
;;; for property '(:id arg ...)
;;; arg == number => a specific, identiified individual; (:id 244) => #244
;;; arg == t => a specific, identiified individual; (:id t) => #<next-number>
;;; arg == nil => a specific, unidentiified individual; (:id nil) => #
;;; no :id spec => no individual  (no properties)
;;;
;;; :variable is a string; "x"


;;; recgonized properties
;;; :name - string
;;; :measure - a cons of (value (number) . units-string)
;;; :set




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  properties  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; :id shouldn't be in properties lists
(defmethod properties-equal ((props1 list) (props2 list))
  (setf props1 (sans-prop props1 :id))
  (setf props2 (sans-prop props2 :id))
  (let* ((a1 (sort-properties props1))
         (a2 (sort-properties props2)))
    (equalp a1 a2)))


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






(defmethod setf-properties ((properties list) &key name measure set)
  (when name    (setf (getf properties :name) name))
  (when measure (setf (getf properties :measure) measure))
  (when set     (setf (getf properties :set) set))
  properties)

(defun make-properties (&rest keys &key name measure set)
  (declare (ignore name measure set))
  (let ((properties (list)))
    (apply #'setf-properties properties keys)))

(defmethod render-properties ((properties list))
  (let ((set-properties (getf properties :set))
        (graph (getf properties :graph))
        (other-properties (sans-prop properties :graph :set)))
    graph
    (let* ((set-str (if set-properties
                        (format-properties (list :set set-properties))
                        ""))
           (other-str (if other-properties
                        (format-properties other-properties)
                        ""))
           (feature-string (strcat set-str other-str)))
      feature-string)))

(defmethod render-properties ((feature-string string))
  (values feature-string))



;;; identify all referent properties, i.e. handle embedded whitespace
;;; used by parse-properties
(defmethod isolate-properties ((referent-spec string))
  (let* ((left-brace   (position #\{ referent-spec))
         (right-brace  (when left-brace (position #\} referent-spec :start left-brace)))
         (spec-start   (if right-brace  (1+ right-brace) 0))
         (left-bracket (position #\[ referent-spec :start spec-start))
         (asterisk     (position #\* referent-spec :start spec-start))
         (at-sign      (position #\@ referent-spec :start spec-start))
         (hash         (position #\# referent-spec :start spec-start))
         (bang         (position #\+ referent-spec :start spec-start))
         (starts       (sort (remove nil (list asterisk at-sign hash bang left-brace left-bracket)) #'<))
         (collection (list)))

    ;; the :name feature is untagged
    (cond ((null starts)
           (setq starts '(0)))
          ((not (zerop (car starts)))
           (push 0 starts)))
    (let ((specs (when starts
                   (do ((start-list starts (cdr start-list)))
                       ((null start-list) (reverse collection))
                     (let* ((start (car start-list))
                            (next (cadr start-list))
                            (end (or next (length referent-spec)))
                            (spec (string-trim '(#\space) (subseq referent-spec start end))))
                       (push spec collection))))))
      specs)))



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






;; setf-properties moved to referent.lisp
;; (defmethod setf-properties ((properties list) &key name measure set)
;;   (when name    (setf (getf properties :name) name))
;;   (when measure (setf (getf properties :measure) measure))
;;   (when set     (setf (getf properties :set) set))
;;   properties)

;; make-properties moved to referent.lisp
;; (defun make-properties (&rest keys &key name measure set)
;;   (declare (ignore name measure set))
;;   (let ((properties (list)))
;;     (apply #'setf-properties properties keys)))


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



;;; render-properties moved to referent.lisp
;; (defmethod render-properties ((properties list))
;;   (let ((set-properties (getf properties :set))
;;         (graph (getf properties :graph))
;;         (other-properties (sans-prop properties :graph :set)))
;;     graph
;;     (let* ((set-str (if set-properties
;;                         (format-individual (list :set set-properties) :comma-p t)
;;                         ""))
;;            (other-str (if other-properties
;;                         (format-individual other-properties)
;;                         ""))
;;            (feature-string (strcat set-str other-str)))
;;       feature-string)))

;; (defmethod render-properties ((feature-string string))
;;   (values feature-string))


;;; return the properties list that describes the referent
;;; in graph-nodes.lisp
;; (defmethod parse-properties ((property-string string) &key variable)
;;   variable
;;   (with-input-from-string (stream property-string)
;;     (let* ((terms (read-features stream))
;;            (variable (getf terms :variable)))
;;       (remf terms :variable)
;;       (values terms variable))))

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
