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
  ((nodes :initform (list)           ; list containing graphs as lists
          :initarg :nodes
          :accessor nodes
          )
   (graphs :initform (list) ; list containing nodes that are head nodes
           :initarg :graphs
           :accessor graphs
           )
   (child-contexts  :initform (list) ; contexts contained by this context
                    :initarg :contexts
                    :accessor child-contexts
                    )
   (parent-context :initform nil
                   :initarg :parent
                   :accessor parent-context
                   )))



(defmethod make-context (&optional (parent nil))
  (let ((new-context (make-instance 'context)))
    (when parent
      (setf (parent-context new-context) parent)
      (pushnew new-context (child-contexts parent)))
    new-context))

(defmethod initialize-context ((context context) &optional (parent nil parent-supplied))
  ;; (setf (child-contexts context) (list))
  ;; (when parent-supplied
  ;;   (setf (parent-context context) parent))
  (setf (nodes context) (list)))

(defmethod initialize-context ((context (eql nil)) &optional (parent nil)))


(defmethod initialize-instance :after ((context context) &key &allow-other-keys)
  (initialize-context context))


;; (defmethod all-concepts ((context context))
;;   (let ((graph-concepts (list)))
;;     (dolist (graph (graphs context))
;;       (push (collect-concepts (car graph)) graph-concepts))
;;     (let ((concepts (apply #'append graph-concepts)))
;;       (remove-duplicates concepts))))


;; (defmethod all-concepts ((context (eql nil)))
;;   nil)

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
    (pushnew concept (nodes context) :test #'concepts-equal)
    )
  ;;(format t "~&(nodes context):e ~s~%"  (nodes context))
  concept)


(defmethod add-concept ((concept concept) &optional (context *context*))
  (cache-concept concept :context context))


(defmethod decache-concept ((concept concept))
  ;;(assert (typep concept 'concept))
  (let* ((context (or (context concept) *context*))
         (concept-cache (concepts context))
         (key (concept-cache-key-for-concept concept)))
    (remove concept concept-cache :test #'concepts-equal)
    ;;(remhash key concept-cache)
    ))


(defmethod retrieve-concepts-having-properties (properties &optional (context *context*))
  (remove-if-not (lambda (concept)
                   (let* ((referent (referent concept))
                          (props (properties referent)))
                     (properties-equal props properties)))
                 (nodes context)))

(defmethod retrieve-concepts-having-individual (individual &optional (context *context*))
  (remove-if-not (lambda (concept)
                   (let* ((referent (referent concept))
                          (object (when referent
                                    (content referent))))
                     (and (individual-p object)
                          (individuals-equal object individual))))
                 (nodes context)))

(defmethod retrieve-concepts-having-id (individual-id &optional (context *context*))
  (let ((individual (find-individual-with-id individual-id)))
    (retrieve-concepts-having-individual individual context)))



(defmethod retrieve-concept (concept-type (individual individual) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-individual individual context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))

(defmethod retrieve-concept (concept-type (id number) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-id id context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))

(defmethod retrieve-concept (concept-type (properties list) &key (context *context*))
  (let ((candidates (retrieve-concepts-having-properties properties context))
        (ctype (get-concept-type concept-type)))
    ;; (remove-if-not (lambda (concept)
    ;;                  (types-equal (concept-type concept) ctype))
    ;;                candidates)
    (find ctype candidates :key #'concept-type)))




;; (defmethod retrieve-concept (concept-type (individual individual) &key (context *context*) &allow-other-keys)
;;   (let ((concept-cache (all-concepts context)))
;;     (describe concept-cache)
;;     (cond ((null context)
;;            (error 'cached-concept-lookup-failed :ctype concept-type :msg "cannot find context"))
;;           ((null concept-cache)
;;            (error 'cached-concept-lookup-failed :ctype concept-type :msg "cannot find concept-cache")))
;;     (let* ((ctype (get-concept-type concept-type))
;;            (id (id individual)))
;;       (retrieve-concept-by-id id context))))



(defmethod remove-concept ((concept concept) &optional (context *context*))
  (decache-concept concept))

;;; concept-type is added to the propertis list
(defmethod remove-concept ((properties list) &optional (context *context*))
  (let* ((ctype (cadr (assoc :type properties)))
         (concept (retrieve-concept ctype properties)))
    (when concept
      (remove-concept concept context))))








;;; *include-node-ref*

(defun graph-node-key (node)
  (string-trim " "
               (cond ((eq (type-of node) 'concept)
                      (format nil "concept-~a-~a" (node-type node)  (format-referent node)))
                     ((eq (type-of node) 'relation)
                      (format nil "relation-~a" (node-type node))))))


(defmethod graph-present-p ((graph-list list) &optional (context *context*))
  (let* ((sorted-graph (sort (copy-list graph-list) #'alpha-lessp :key #'graph-node-key))
         (found (find (mapcar #'graph-node-key sorted-graph) (graphs context)
                      :key (lambda (list) (mapcar #'graph-node-key list))
                      :test #'equalp)))
    (not (null found))))

(defmethod graph-present-p ((concept concept) &optional (context *context*))
  (graph-present-p (collect-nodes concept) context))

(defmethod graph-present-p ((graph string) &optional (context *context*))
  (graph-present-p (pcg graph) context))


(defmethod add-graph ((graph-list list) &optional (context *context*))
  (let* ((sorted-graph-list (sort (copy-list graph-list) #'alpha-lessp :key #'graph-node-key))
         (present (graph-present-p sorted-graph-list context)))
    (unless present (push sorted-graph-list (graphs context)))
    ;;(format t "~&(graphs context): ~s~%"  (graphs context))
    (not present)))

(defmethod add-graph ((concept concept) &optional (context *context*))
  (add-graph (collect-nodes concept) context))

(defmethod add-graph ((graph string) &optional (context *context*))
  (add-graph (pcg graph) context))


(defmethod clear-concept-cache (&optional (context *context*))
  (assert (typep context 'context))
  (clrhash (concepts context)))


(defun cached-concepts-report (&optional (context *context*) (stream *standard-output*))
  (when context
    (let ((cache (concepts context))
          (concepts (list)))
      (when cache
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
                  (format stream "~&~a~vt~a~vt~@[~(~a~)~]~%" val col2-tab key col3-tab variable)))))))
      t)))
