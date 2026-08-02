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
    (remhash variable (nodes *variables*))
    ;; Give the letter back. Allocation removes from the pool permanently, so
    ;; without this a name freed by an edit is still gone and the alphabet
    ;; drains monotonically however much churn the session sees. Only
    ;; single characters from the original alphabet go back -- a generated
    ;; `v12' was never in the pool and does not belong in it.
    (let ((s (string-downcase (string variable))))
      (when (and (= 1 (length s))
                 (find (char s 0) *variable-names*)
                 (not (find (char s 0) (names *variables*))))
        (setf (names *variables*)
              (concatenate 'string (names *variables*) s))))))

(defmethod unset-variable ((node graph-node))
  (unset-variable (node-variable node)))

(defmethod unset-variable ((variable string))
  (unset-variable (intern (string-upcase variable) :keyword)))

(defmethod variable-setep (node)
  (gethash node (variables *variables*)))

(defun next-variable-name ()
  "A free variable name: the next letter of the pool, or a generated one once
   the alphabet is spent.

   The pool holds 21 single characters and every allocation REMOVEs one for
   good, so a long-lived session eventually empties it -- and the old code then
   took (SUBSEQ \"\" 0 1) and signalled `The bounding indices 0 and 1 are bad
   for a sequence of length 0'. In the graph editor that is fatal rather than
   cosmetic: SESSION-RENDER runs on every request, so once the pool is dry
   every request fails, including the ones the page uses to recover. The error
   then cannot be cleared by anything the user does, because it is true again
   the moment they try.

   Falling off the end of the alphabet is not an error, so it no longer behaves
   like one -- the names simply stop being single letters."
  (let ((pool (names *variables*)))
    (if (plusp (length pool))
        (subseq pool 0 1)
        (loop for i from 1
              for candidate = (format nil "v~d" i)
              unless (gethash (intern (string-upcase candidate) :keyword)
                              (nodes *variables*))
                return candidate))))

(defmethod set-variable ((node basic-node) &optional new-name)
  (assert (or (null new-name) (typep new-name 'symbol) (typep new-name 'string)))
  (assert (typep node 'concept))
  ;;(format t "~2&(set-variable ~s ~s)" node new-name)
  (unless (variable-setep node)
    (let ((var-name (typecase new-name
                      (symbol  (or new-name
                                   (intern (string-upcase (next-variable-name)) :keyword)))
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
