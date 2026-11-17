;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ;;  variables  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; length of variable names is restricted to one character

;;; string of characters that are used as default variable names
(defvar *variable-names* "xyzpqrstabcdefghjklmn")
;;; *VARIABLES* (a VARIABLE-CACHE) lives in the environment (environment.lisp).


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


;;; Formatting works on a copy.
;;;
;;; Printing a graph decides which concepts need a label to show where the
;;; graph meets itself, and the segment code records those decisions with
;;; SET-VARIABLE and UNSET-VARIABLE -- in the same table that holds the *x
;;; labels a graph was read with. So printing changed the graph: a concept
;;; that didn't need a label for display had its *x unset, and its ?x
;;; partners were left pointing at nothing, while one that did need one kept
;;; a made-up label afterwards. A query pattern printed before it was run lost
;;; the variables it was meant to return.
;;;
;;; CGRAPH-TEXT now binds *VARIABLE-OVERLAY* to a copy of the table, and every
;;; function here reads and writes (VARIABLE-CACHE), which is the copy while
;;; one is bound. What the formatter does to labels stays in the copy. It is a
;;; special variable bound with LET, so per thread: two requests printing at
;;; once each have their own.

(defvar *variable-overlay* nil
  "A VARIABLE-CACHE standing in for the environment's *VARIABLES* while
   bound -- by CGRAPH-TEXT, for the length of one printing.")

(defun variable-cache ()
  "The variable table in force: the overlay while one is bound, else the
   environment's."
  (or *variable-overlay* *variables*))

(defun copy-variable-cache (cache)
  "A VARIABLE-CACHE holding what CACHE holds, sharing none of its tables."
  (let ((copy (make-instance 'variable-cache :names (copy-seq (names cache)))))
    (maphash (lambda (k v) (setf (gethash k (variables copy)) v)) (variables cache))
    (maphash (lambda (k v) (setf (gethash k (nodes copy)) v)) (nodes cache))
    copy))

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



;;; Into :CG, and NIL for no variable -- interning (STRING NIL) in the caller's
;;; package only gave back CL:NIL where that package happened to use CL.
(defmethod node-variable ((node graph-node))
  (let ((variable (gethash node (variables (variable-cache)))))
    (when variable
      (intern (string variable) :cg))))

(defmethod variable-node ((variable symbol))
  (gethash (intern (string variable) :keyword) (nodes (variable-cache))))

(defmethod variable-node ((variable string))
  (variable-node (intern (string-upcase variable) :keyword)))

(defmethod variable-node ((variable character))
  (variable-node (intern (string (char-upcase variable)) :keyword)))


(defmethod unset-variable ((variable symbol))
  (let ((node (variable-node variable)))
    (remhash node (variables (variable-cache)))
    (remhash variable (nodes (variable-cache)))
    ;; Give the letter back. Allocation removes from the pool permanently, so
    ;; without this a name freed by an edit is still gone and the alphabet
    ;; drains monotonically however much churn the session sees. Only
    ;; single characters from the original alphabet go back -- a generated
    ;; `v12' was never in the pool and does not belong in it.
    (let ((s (string-downcase (string variable))))
      (when (and (= 1 (length s))
                 (find (char s 0) *variable-names*)
                 (not (find (char s 0) (names (variable-cache)))))
        (setf (names (variable-cache))
              (concatenate 'string (names (variable-cache)) s))))))

(defmethod unset-variable ((node graph-node))
  (unset-variable (node-variable node)))

(defmethod unset-variable ((variable string))
  (unset-variable (intern (string-upcase variable) :keyword)))

(defmethod variable-setep (node)
  (gethash node (variables (variable-cache))))

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
  (let ((pool (names (variable-cache))))
    (if (plusp (length pool))
        (subseq pool 0 1)
        (loop for i from 1
              for candidate = (format nil "v~d" i)
              unless (gethash (intern (string-upcase candidate) :keyword)
                              (nodes (variable-cache)))
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

      (setf (names (variable-cache)) (remove (string var-name) (names (variable-cache)) :test #'string-equal))
      (setf (gethash node (variables (variable-cache))) var-name)
      (setf (gethash (intern (string-upcase var-name) :keyword) (nodes (variable-cache))) node)))
  node)

;; (defmethod set-variable ((node (eql nil)) &optional new-name)
;;   (declare (ignore new-name)))

(defun variable-count ()
  (hash-table-count (variables (variable-cache))))



(defun variables-status ()
  (let ((defs (list)))
    (maphash (lambda (key val)
               (pushnew  (list key val) defs
                         :key #'cadr
                         :test #'eql))
             (variables (variable-cache)))
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
