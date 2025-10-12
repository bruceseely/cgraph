;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;; include NAME, MEASURE, ...  etc in concept
;;;    instead of explicit graph of concept objects
;;; (defvar *abbreviated-concepts* t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  context  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; NOTE *context* is declared in definitions.lisp

(defclass context ()
  ((concepts :initform (make-concept-cache)   ; cache of concepts local to this context
             :initarg :concepts
             )
   (id-concepts :initform (make-concept-cache)   ; cache of concepts by id
                :initarg :id-concepts
                )
   (contexts  :initform (list)    ; contexts contained by this context
              :initarg :contexts
              :accessor child-contexts
              )
   (parent-context :initform nil
                   :initarg :parent
                   :accessor parent
                   )))


;;;; string -> concept
(defun make-concept-cache ()
  (make-hash-table :test 'equal))


(defmethod clear-concepts ((context context))
  (setf (concepts context) (make-concept-cache)))


(defmethod make-context (&optional (parent-context nil))
  (let ((new-context (make-instance 'context
                                    :parent parent-context
                                    )))
    (when parent-context
      (pushnew new-context (child-contexts parent-context)))
    new-context))

(defmethod initialize-context ((context context))
  (with-slots (concepts contexts parent-context)
      context
    (setf concepts (make-concept-cache))
    (setf contexts nil)
    (unless (boundp parent-context)
      (setf parent-context nil))))


(defmethod initialize-context ((context (eql nil))))


(defmethod get-cached-concepts ((context context))
  (let ((concept-table (slot-value context 'concepts))
        (collected (list)))
    (maphash (lambda (key con) (push con collected)) concept-table)
    collected))


(defmethod concepts ((context context))
  (get-cached-concepts context))

(defmethod concepts ((context (eql nil)))
  nil)

(define-condition cached-concept-lookup-failed (error)
  ((ctype :initarg :ctype :reader ctype)
   (msg :initarg :msg :reader msg)))


;;; do not cache generic nodes
;;; cache by id and type/properties
;;; the type could change
;;; save regardless of whether it is already ccached
(defmethod cache-concept ((concept concept)  &key (context *context*))
  (unless (generic-p concept)
    (setf (context concept) context)
    (let ((id-concept-cache (slot-value context 'id-concepts))
          (concept-cache    (slot-value context 'concepts))
          (key (concept-cache-key-for-concept concept)))
      (setf (gethash (id concept) id-concept-cache) concept)
      (setf (gethash key concept-cache) concept))))


(defmethod add-concept ((concept concept) (context context))
  (cache-concept concept context))


(defmethod decache-concept ((concept concept))
  ;;(assert (typep concept 'concept))
  (let* ((context (or (context concept) *context*))
         (id-concept-cache (slot-value context 'id-concepts))
         (concept-cache (slot-value context 'concepts))
         (key (concept-cache-key-for-concept concept)))
    (remhash (id concept) id-concept-cache)
    (remhash key concept-cache)))


(defmethod retrieve-concept-by-id (id &key (context *context*))
  (when id
    (let ((id-concept-cache (slot-value context 'id-concepts)))
      (gethash id id-concept-cache))))







;;; called by get-concept; returns nil if there is no concept to
;;; retrieve
(defmethod retrieve-concept (concept-type (properties list) &key id (context *context*))
  (or
   (retrieve-concept-by-id id)
   (when properties                  ; generic concepts are not cached
     (let* ((concept-cache (slot-value context 'concepts))
            (ctype (get-concept-type concept-type))
            (key (concept-cache-key ctype id properties)))
       (cond ((null ctype)
              (error 'cached-concept-lookup-failed
                     :ctype ctype
                     :msg (format nil "cannot find concept-type ~s" ctype)))

             ((null context)
              (error 'cached-concept-lookup-failed :ctype ctype :msg "cannot find context"))

             ((null concept-cache)
              (error 'cached-concept-lookup-failed :ctype ctype :msg "cannot find concept-cache"))

             (key
              (gethash key concept-cache nil)))))))


(defmethod retrieve-concept (concept-type (referent-string string) &key id (context *context*))
  (let* ((properties (parse-properties referent-string)))
    (when properties
      (retrieve-concept concept-type properties :id id))))


(defmethod retrieve-concept (concept-type (individual individual) &key (context *context*) &allow-other-keys)
  (let ((concept-cache (slot-value context 'concepts)))
    (describe concept-cache)
    (cond ((null context)
           (error 'cached-concept-lookup-failed :ctype concept-type :msg "cannot find context"))
          ((null concept-cache)
           (error 'cached-concept-lookup-failed :ctype concept-type :msg "cannot find concept-cache")))

    (let* ((ctype (get-concept-type concept-type))
           (props (properties individual))
           (id (id individual))
           (key (concept-cache-key ctype id props)))
      (when key
        (gethash key concept-cache nil)))))




(defmethod clear-concept-cache (&optional (context *context*))
  (assert (typep context 'context))
  (clrhash (concepts context)))


(defun cached-concepts-report (&optional (context *context*) (stream *standard-output*))
  (when context
    (let ((cache (concepts context))
          (concepts (list)))
      (maphash (lambda (key val)
                 (push (list key val) concepts))
               cache)

      (when concepts
        (let* ((col1-width (apply #'max (mapcar (lambda (x) (length (princ-to-string (cadr x)))) concepts)))
               (col2-width (apply #'max (mapcar (lambda (x) (length (princ-to-string (car x)))) concepts)))
               (col2-tab (+ col1-width 1))
               (col3-tab (+ col2-tab col2-width 1))
               (sorted-concepts (sort concepts #'alpha-lessp :key #'car)))
          (format stream "~&Concept~vtKey~vtVar~%" col2-tab col3-tab )
          (dolist (con sorted-concepts)
            (destructuring-bind (key val) con
              (let ((variable nil #+nil(concept-variable val)))
                (format stream "~&~a~vt~a~vt~@[~(~a~)~]~%" val col2-tab key col3-tab variable))))))
      t)))
