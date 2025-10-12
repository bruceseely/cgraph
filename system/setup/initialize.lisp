;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;  ;;  initialize  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



(defun initialize-concept-types (&optional supress-warnings)
  (let* ((concept-type-path (format nil "~aconcept-types.lisp" *cgraph-types*))
         (cgraph-code-path (asdf:system-source-directory "cgraph"))
         (concept-type-source (format nil "~adefault-types/concept-types.text" cgraph-code-path)))

    ;;; ensure that type definitions are available
    (unless (probe-file concept-type-path)
      (ensure-directories-exist concept-type-path)
      (copy-file concept-type-source concept-type-path))

    ;; create type objects
    (clear-concept-types)
    (make-top-concept-type)
    (make-bottom-concept-type)
    (load-concept-types concept-type-path supress-warnings)))


;;; *cgraph-types* value is set in setup-cgraph
(defun initialize-relation-types (&optional supress-warnings)
  (let* ((relation-type-path (format nil "~arelation-types.lisp" *cgraph-types*))
         (cgraph-code-path (asdf:system-source-directory "cgraph"))
         (relation-type-source (format nil "~adefault-types/relation-types.text" cgraph-code-path)))

    ;;; ensure that type definitions are available
    (unless (probe-file relation-type-path)
      (ensure-directories-exist relation-type-path)
      (copy-file relation-type-source relation-type-path))

    ;;; create type objects
    (clear-relation-types)
    (load-relation-types relation-type-path supress-warnings)))

(defun initialize-types (&optional supress-warnings)
  ;; using type definitions in ~a~%" *cgraph-types*)
  (list
   (initialize-concept-types supress-warnings)
   (initialize-relation-types supress-warnings)))


(defun initialize-parameters ()
  (let ((filepath (format nil "~ainitializations.lisp" *cgraph*)))
    ;;using parameter definitions in ~a~%" filepath)
    (when (probe-file filepath)
      (with-open-file (stream filepath :direction :input)
        (loop
          (let ((init (read stream nil nil nil)))
            (if init
                (eval init)
                (return-from initialize-parameters))))

        ))))

(defun initialize-cgraph ()
  (initialize-variables)
  (initialize-individuals)
  (initialize-types)
  (initialize-parameters)
  )

(defun reset-cgraph ()
  (setf *context* (make-context nil))
  (setf *gensym-counter* 1)
  (setf *node-ref-counter* 1)
  (setf *concepts-in-graph* (list))
  (setf *dynamically-create-individuals* t)

  (setf *always-show-id* nil)
  (initialize-context *context*)
  (initialize-cgraph)
  (clear-id-cache))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;  ;;  setup  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod delete-files (directory (pattern string) )
  (let ((files (directory-files directory pattern))
        (subdirectories (subdirectories (pathname directory))))
    (dolist (file files)
      (delete-file file))
    (dolist (subdir subdirectories)
      (delete-files subdir pattern))))

(defun cleanup-files (&optional (directory "~/repo/cgraph/"))
  (delete-files directory "*.lisp~")
  (delete-files directory "*.lisp#")
  (delete-files directory "*.fasl" ))

(defun report-directories ()
  (reset-cgraph)
  (format t "~&______________________________________________________________  ~%")
  (format t "~&CGraph directory: ~a~50t*cgraph*~%"       *cgraph*)
  (format t "~&type definitions: ~a~50t*cgraph-types*~%" *cgraph-types*)
  (format t "~&generated plots   ~a~50t*cgraph-data*~%"  *cgraph-data*)
  (format t "~&initializations:  ~ainitializations.lisp~%" *cgraph*)
  (values))


;;; This is the entry point
;;; should be called only on startup
(defun setup-cgraph ()
  ;;  (ql:quickload "serapeum")
  (in-package :conceptual-graphs)

  (setf *cgraph* (ensure-directories-exist
                  (format nil "~a.cgraph/"
                          (namestring (user-homedir-pathname)))))
  (setf *cgraph-data* (ensure-directories-exist (format nil "~adata/"  *cgraph*)))
  (setf *cgraph-types* (ensure-directories-exist (format nil "~atypes/" *cgraph*)))

  ;; cleanup fasls previously created during debugging
  ;;(cleanup-files "~/repo/cgraph")
  (cleanup-files user::*cg-init-path*)
  (cg::report-directories)
  (terpri)
  (cg::test-all t)
  )
