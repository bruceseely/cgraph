;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;  ;;  initialize  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; NOTE: *cgraph-types-directory* = directory that the code uses for types

;; (delete-type-files)
;; (copy-example-type-definitions)
;; (link-cgraph-types-to-external-directory "~/repo/cgraph-types/")

;; (load-cgraph-types "~/.cgraph/types/")




(defun delete-type-files ()
  (let ((concept-path (format nil "~aconcept-types.lisp" *cgraph-types-directory*))
        (relation-path (format nil "~arelation-types.lisp" *cgraph-types-directory*)))
    ;; (format t "~&concept-path: ~s~%"  concept-path)
    ;; (format t "~&relation-path: ~s~%"  relation-path)
    (when (probe-file concept-path)
      (delete-file concept-path))
    (when (probe-file relation-path)
      (delete-file relation-path)))
  )

   "ln -s /Users/bseely/repo/cgraph-types/concept-types.lispconcept-types.lisp  /Users/bseely/.cgraph/types/concept-types.lisp"
;;; ln -s /Users/bseely/repo/cgraph-types/concept-types.lisp /Users/bseely/.cgraph/types/concept-types.lisp
;; "ln -s /Users/bseely/repo/cgraph-types/concept-types.lispconcept-types.lisp  /Users/bseely/.cgraph/types/concept-types.lispconcept-types.lisp"

;;; (uiop:run-program "ln -s /Users/bseely/repo/cgraph-types/concept-types.lisp  /Users/bseely/.cgraph/types/concept-types.lisp")
;;; (uiop:run-program (format nil "ln -s ~a ~a"   "/Users/bseely/repo/cgraph-types/concept-types.lisp"  "/Users/bseely/.cgraph/types/concept-types.lisp"))

;; (let ((external-concept-type-path "/Users/bseely/repo/cgraph-types/concept-types.lisp")
;;       (*cgraph-types-directory* "/Users/bseely/.cgraph/types/concept-types.lisp"))
;;   (uiop:run-program (format nil "ln -s ~a ~a"   external-concept-type-path  *cgraph-types-directory*)))

;; (let ((external-concept-type-path "/Users/bseely/repo/cgraph-types/concept-types.lisp")
;;       (*cgraph-types-directory* "/Users/bseely/.cgraph/types/concept-types.lisp")
;;       (concept-link-command  (format nil "ln -s ~a ~a"  external-concept-type-path  *cgraph-types-directory*))
;;       )
;;   (uiop:run-program concept-link-command))


(defun link-cgraph-types-to-external-directory (external-directory-path)
  ;; ensure a trailing "/" on directory-path
  (setf external-directory-path (strcat (string-right-trim "/" external-directory-path) "/"))

  ;; ensure the source directory exists
  (when (probe-file external-directory-path)
    (let* ((external-concept-type-path  (format nil "~aconcept-types.lisp"  external-directory-path))
          (external-relation-type-path (format nil "~arelation-types.lisp" external-directory-path))
          (concept-link-command  (format nil "ln -s ~a  ~a"  external-concept-type-path  *cgraph-types-directory*))
          (relation-link-command (format nil "ln -s ~a ~a" external-relation-type-path *cgraph-types-directory*)))

      ;;(format t "~&concept-link-command: ~s~%"  concept-link-command)
      (delete-type-files)

      ;; link the files
      (uiop:run-program concept-link-command)
      (uiop:run-program relation-link-command)

      ;; verify access to type files
      (not (null
            (and (probe-file (format nil "~aconcept-types.lisp" *cgraph-types-directory*))
                 (probe-file (format nil "~arelation-types.lisp" *cgraph-types-directory*))))))))


(defun copy-example-type-definitions ()
  (delete-type-files)
  (copy-file (format nil "~aconcept-types.text" *cgraph-examples-directory*)
             (format nil "~aconcept-types.lisp" *cgraph-types-directory*))
  (copy-file (format nil "~arelation-types.text" *cgraph-examples-directory*)
             (format nil "~arelation-types.lisp" *cgraph-types-directory*)))


(defun initialize-types (&key external-types-directory supress-warnings)
  ;; ensure files are setup
  (cond (external-types-directory
         (link-cgraph-types-to-external-directory external-types-directory))
        ((not (and
               (probe-file (format nil "~aconcept-types.lisp" *cgraph-types-directory*))
               (probe-file (format nil "~arelation-types.lisp" *cgraph-types-directory*))))
         (copy-example-type-definitions)))

  ;; load the types
  (when (and (probe-file (format nil "~aconcept-types.lisp" *cgraph-types-directory*))
             (probe-file (format nil "~arelation-types.lisp" *cgraph-types-directory*)))
    (clear-cgraph-type-catalogs)
    (load-cgraph-types supress-warnings)))


(defun initialize-parameters ()
  (let ((filepath (format nil "~ainitializations.lisp" *cgraph*)))
    ;;using parameter definitions in ~a~%" filepath)
    (when (probe-file filepath)
      (with-open-file (stream filepath :direction :input)
        (loop
          (let ((init (read stream nil nil nil)))
            (if init
                (eval init)
                (return-from initialize-parameters))))))))

(defun initialize-cgraph ()
  (initialize-variables)
  (initialize-coreferences)
  (initialize-individuals)
  (initialize-types)
  (initialize-parameters)
  )

(defun reset-cgraph ()
  (setf *context* (make-context nil))
  (setf *gensym-counter* 1)
  (setf *node-ref-counter* 1)
  (setf *concepts-in-graph* (list))
  (setf *dynamically-create-individuals* nil)
  (setf *always-show-node-ref* nil)
  (setf *always-show-individual-id* nil)
  (setf *always-format-nodes* nil)

  (initialize-context *context*)
  (initialize-cgraph)
  (clear-id-cache))


(defun ensure-concept-types-exist (definitions)
  (dolist (def definitions)
    (parse-concept-type-def def)))

(defun ensure-relation-types-exist (definitions)
  (dolist (def definitions)
    (parse-relation-type-def def)))


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
  (format t "~&type definitions: ~a~50t*cgraph-types-directory*~%" *cgraph-types-directory*)
  (format t "~&generated plots   ~a~50t*cgraph-data-directory*~%"  *cgraph-data-directory*)
  (format t "~&initializations:  ~ainitializations.lisp~%" *cgraph*)
  (values))


(defvar *home* (namestring (user-homedir-pathname)))
(defvar *cgraph*)
(defvar *cgraph-types-directory*)
(defvar *cgraph-examples-directory*)
(defvar *cgraph-data-directory*)


;;; This is the entry point
;;; should be called only on startup
;;; concept-types is the path to the concept-types file
;;; relation-types is the path to the relation-types file
;;;
(defun setup-cgraph (code-base &key external-types-directory)
  (in-package :conceptual-graphs)

  (let* ((cgraph-base (format nil "~a.cgraph/" (namestring (user-homedir-pathname))))
         (types-directory (format nil "~atypes/" cgraph-base))
         (data-directory (format nil "~adata/" cgraph-base))
         (concept-types-path (format nil "~aconcept-types.lisp" cgraph-base))
         (relation-types-path (format nil "~arelation-types.lisp" cgraph-base)))

    (setf *cgraph* (ensure-directories-exist cgraph-base))
    (setf *cgraph-types-directory* (ensure-directories-exist types-directory))
    (setf *cgraph-data-directory*  (ensure-directories-exist data-directory))
    (setf *cgraph-examples-directory* (format nil "~adefault-types/" (asdf::system-source-directory :cgraph)))

    (initialize-types :external-types-directory external-types-directory)
    )

  ;; Set default package for SLIME worker threads (when SLIME is loaded)
  (when (find-package :swank)
    (let ((bindings-var (find-symbol "*DEFAULT-WORKER-THREAD-BINDINGS*" :swank)))
      (when (and bindings-var (boundp bindings-var))
        (push (cons '*package* (find-package :conceptual-graphs))
              (symbol-value bindings-var)))))

  (cleanup-files code-base)
  (cg::report-directories)
  (terpri)
  (cg::test-all t))
