;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  variables  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; length of variable names is restricted to one character

;;; string of characters that are used as default variable names
(defvar *variable-names* "xyzpqrstabcdefghjklmn")
(defvar *variables* nil)


(defclass variable-cache ()
  ;; string of characters that are used as default variable names
  ;; initialized from *variable-names*
  ((names :initform (list)
          :initarg :names
          :accessor names)
   ;; map for node --> variable
   (variables :initform
              ;;(make-hash-table :weak-keys t :test 'string-equal)
              (make-hash-table :test 'eql)
              :accessor variables)
   ;; map for variable --> node
   (nodes :initform
          ;;(make-hash-table :weak-keys t :test 'equal)
          (make-hash-table :test 'equal)
          :accessor nodes)))


;;;; *variables* is a variable-cache instance
(defun initialize-variables (&optional (names *variable-names*))
  (setf *variables*
        (make-instance 'variable-cache
                       :names names))
  (setf (names *variables*) names)
  )


(defmethod extract-variable ((referent-string string))
  (let* ((ast-pos (position #\* referent-string :test #'char-equal))
         (space-pos (position #\space referent-string :start ast-pos :test #'char-equal))
         (end-pos (when ast-pos
                    (or
                     space-pos
                     (length referent-string))))
         (text (when end-pos
                 (subseq referent-string (1+ ast-pos) space-pos))))
    (string-trim '(#\space) text)))



(defmethod node-variable ((node graph-node))
  (intern (string (gethash node (variables *variables*)))))

(defmethod variable-node ((variable symbol))
  (gethash (intern (string variable) :keyword) (nodes *variables*)))

(defmethod variable-node ((variable string))
  (variable-node (intern (string-upcase variable) :keyword)))

(defmethod variable-node ((variable character))
  (variable-node (intern (string (char-upcase variable)) :keyword)))


(defmethod unset-variable ((variable symbol))
  (let ((node (variable-node variable)))
    (remhash node (variables *variables*))
    (remhash variable (nodes *variables*))))

(defmethod unset-variable ((node graph-node))
  (unset-variable (node-variable node)))

(defmethod unset-variable ((variable string))
  (unset-variable (intern (string-upcase variable) :keyword)))

(defmethod variable-setep (node)
  (gethash node (variables *variables*)))

(defmethod set-variable ((node basic-node) &optional new-name)
  (assert (or (null new-name) (typep new-name 'symbol) (typep new-name 'string)))
  (assert (typep node 'concept))
  ;;(format t "~2&(set-variable ~s ~s)" node new-name)
  (unless (variable-setep node)
    (let ((var-name (typecase new-name
                      (symbol  (or new-name
                                   (intern (string-upcase (subseq (names *variables*) 0 1)) :keyword)))
                      (string  (intern (string-upcase new-name) :keyword)))))

      (setf (names *variables*) (remove (string var-name) (names *variables*) :test #'string-equal))
      (setf (gethash node (variables *variables*)) var-name)
      (setf (gethash (intern (string-upcase var-name) :keyword) (nodes *variables*)) node)))
  node)

;; (defmethod set-variable ((node (eql nil)) &optional new-name)
;;   (declare (ignore new-name)))

(defun variable-count ()
  (hash-table-count (variables *variables*)))



(defun variables-status ()
  (let ((defs (list)))
    (maphash (lambda (key val)
               (pushnew  (list key val) defs
                         :key #'cadr
                         :test #'eql))
             (variables *variables*))
    defs))

(defun variables-report (&optional (stream *standard-output*))
  (let ((defs (variables-status)))
    (format stream "~&_______________________________~%")
    (format stream "~&|_Var__Concept________________|~%")
    ;; (dolist (def defs)
    ;;   (destructuring-bind (node var) def
    ;;     (format stream "~&|  ~a~6t~a~30t|~%" var node)))
    (format stream "~&|-----------------------------|~%")
    defs))
