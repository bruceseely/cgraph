;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

(defvar *cg-env* nil)

(defclass conceptual-graphs-environment ()
  ((top-level-context :initform nil
		      :initarg :top-level-context ; necessary?
		      :accessor top-level-context)
   (current-context :initform nil
		    :initarg :current-context
		    :accessor current-context)
   (last-read :initform nil
	      :accessor last-read)
   (last-out :initform nil
	     :accessor last-out)
   (graphs :initform (list)
	   :accessor graphs)
   (history  :initform (list)
	     :accessor history)))

(defun make-conceptual-graphs-environment ()
  (let* ((context (make-context))
         (env (make-instance 'conceptual-graphs-environment
		             :top-level-context context
		             :current-context context)))
    (setf *cg-env* env)))

(defmethod initialize-env ((env conceptual-graphs-environment))
  (with-slots (top-level-context current-context last-read last-out graphs history)
      env
    (initialize-cgraph)
    (setf top-level-context nil)
    (setf last-read nil)
    (setf last-out nil)
    (setf graphs (list))
    (setf history (list))))

(defun clear-history (&optional (env *cg-env*))
  (setf (history env) (list)))

(defun get-history (&optional (index 0) (env *cg-env*))
  (nth index (history env)))



(defun prompt-read (prompt)
  (format *query-io* "~a " prompt)
  (force-output *query-io*)
  (read-line *query-io*))

(defun command-read (prompt &optional (env *cg-env*))
  (let ((input-string (prompt-read prompt)))
    (when env
      (push input-string (history env))
      (setf (last-read env) input-string))

    (with-input-from-string (stream input-string)
      (let* ((command (read stream nil nil))
	    (arg (read-line stream nil nil)))
	(values command arg)))))


(defun ensure-period (string)
  (format nil "~a." (string-right-trim "." string)))

(defun parse (graph-string)
  (let ((*package* (find-package :cg))
        (string (strcat (string-right-trim "." graph-string) ".")))
    (cg::parse-cgraph string)))


(defun command-help ()
  (let ((lines (list "~&:ex - exit the cg environment~%"
                     "~&:g      - add a cgraph~%"
                     "~&:i      - initialize~%"
                     "~&:p      - parse a cg-string ???~%"
                     "~&:s      - show graphs~%"
                     "~&:c      - show concepts~%"
                     )))
    (apply #'concatenate 'string lines)))


(defun cg ()
  (let* ((env (make-conceptual-graphs-environment))
	 (*context* (current-context env))
         (concept-table (concepts *context*))
	 (out nil))
    (initialize-cgraph)
    (format t (command-help))
    (block loop
      (loop
	(multiple-value-bind (command arg)
	    (command-read ">>" env)

          (case command
            (:q (return-from loop t))
            (:ex (return-from loop t))
            (:i (initialize-env env))
            (:g (let* ((arg (prompt-read "[graph text]:"))
                       (target (if arg
				   (parse arg)
				   (last-out env)))
                       (graph (format-cgraph target)))
                  (push arg (history env))
                  (setf (last-read env) arg)
                  (push (list target (format nil "\"~a\"" graph)) (graphs env))
		  (setf out (format nil "~a~%" graph))))
            (:s (let ((graphs (graphs env)))
                  (dolist (graph (reverse graphs))
                    (format t "~&~a~10t~a~%" (car graph) (cadr graph)))))
            (:c (maphash (lambda (k v)
                           (format t "~a~20t~a~%" k v))
                         concept-table))
            (:p (let ((target (or arg (last-out env))))
		  (setf out (parse target))))
            ;;(:h (setf out (format nil (command-help))))
            (:h (format t (command-help)) nil)
            (:assert)
            (:query)
            (t))
          )

        (format t "~@[~a~]" out)
        (setf (last-out env) out)
        (setf out nil)))))
