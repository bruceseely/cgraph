;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;  ;;  initialize  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; NOTE: *cgraph-types-directory* = directory that the code uses for types


(defun delete-type-files ()
  (let ((concept-path (format nil "~aconcept-types.lisp" *cgraph-types-directory*))
        (relation-path (format nil "~arelation-types.lisp" *cgraph-types-directory*)))
    (when (probe-file concept-path)
      (delete-file concept-path))
    (when (probe-file relation-path)
      (delete-file relation-path))))


(defun link-cgraph-types-to-external-directory (external-directory-path)
  ;; ensure a trailing "/" on directory-path
  (setf external-directory-path (strcat (string-right-trim "/" external-directory-path) "/"))

  ;; ensure the source directory exists
  (when (probe-file external-directory-path)
    (let* ((external-concept-type-path  (format nil "~aconcept-types.lisp"  external-directory-path))
          (external-relation-type-path (format nil "~arelation-types.lisp" external-directory-path))
          (concept-link-command  (format nil "ln -s ~a  ~a"  external-concept-type-path  *cgraph-types-directory*))
          (relation-link-command (format nil "ln -s ~a ~a" external-relation-type-path *cgraph-types-directory*)))

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


(defun initialize-types (&key (external-types-directory *external-types-directory* type-supplied) supress-warnings)
  (when type-supplied
    (setf *external-types-directory*  external-types-directory))

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

;;; Thhis allows dynamically adding types for testing
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
  (format t "~&web server logs:  ~a~50t*cgraph-log-directory*~%"   *cgraph-log-directory*)
  (format t "~&initializations:  ~ainitializations.lisp~%" *cgraph*)
  (values))


(defvar *home* (namestring (user-homedir-pathname)))


;;; This is the entry point
;;; should be called only on startup
;;; concept-types is the path to the concept-types file
;;; relation-types is the path to the relation-types file
;;;

(defun setup-cgraph (code-base &key external-types-directory)
  (let* ((cgraph-base (format nil "~a.cgraph/" (namestring (user-homedir-pathname))))
         (types-directory (format nil "~atypes/" cgraph-base))
         (data-directory (format nil "~adata/" cgraph-base))
         (log-directory (format nil "~alogs/" cgraph-base))
         (concept-types-path (format nil "~aconcept-types.lisp" cgraph-base))
         (relation-types-path (format nil "~arelation-types.lisp" cgraph-base)))
    (setf *cgraph* (ensure-directories-exist cgraph-base))
    (setf *cgraph-types-directory* (ensure-directories-exist types-directory))
    (setf *cgraph-data-directory*  (ensure-directories-exist data-directory))
    (setf *cgraph-log-directory*   (ensure-directories-exist log-directory))
    (setf *cgraph-examples-directory* (format nil "~adefault-types/" (asdf::system-source-directory :cgraph)))
    (setf *initial-types-directory* *cgraph-types-directory*)
    (initialize-types :external-types-directory external-types-directory))

  ;; REPL tools: SUP:RAPROPOS and friends.  A secondary system, so the main
  ;; one needn't depend on cl-ppcre.  They are a convenience, never a
  ;; prerequisite -- a missing dependency must not abort setup.
  (handler-case (asdf:load-system "cgraph/support")
    (error (condition)
      (format t "~&;; cgraph/support not loaded (SUP:RAPROPOS unavailable): ~a~%"
	      condition)))

  ;; Set default package for SLIME worker threads (when SLIME is loaded)
  (when (find-package :swank)
    (let ((bindings-var (find-symbol "*DEFAULT-WORKER-THREAD-BINDINGS*" :swank)))
      (when (and bindings-var (boundp bindings-var))
        (push (cons '*package* (find-package :conceptual-graphs))
              (symbol-value bindings-var)))))

  ;; Protect SWANK's readtable-for-package from the CG readtable.
  ;; The CG readtable makes ':' a terminating macro char, which breaks
  ;; (read-from-string "swank::guess-buffer-readtable") if an error is
  ;; signaled inside a with-readtable-mods/with-cg-readtable scope and
  ;; the user presses 'v' in SLDB (which runs in the suspended thread).
  (let* ((spp (find-package :swank/source-path-parser))
         (sym (and spp (find-symbol "READTABLE-FOR-PACKAGE" spp))))
    (when (and sym (fboundp sym))
      (let ((orig (symbol-function sym)))
        (setf (symbol-function sym)
              (lambda (package)
                (let ((*readtable* (copy-readtable nil)))
                  (funcall orig package)))))))

  (when (and (find-package :swank)
             ;; Only push to Emacs when there's an active SLIME connection.
             ;; Without this guard, headless sbcl runs (e.g. test scripts)
             ;; trip an ETYPECASE on a NIL connection inside swank.
             (let ((conn (find-symbol "*EMACS-CONNECTION*" :swank)))
               (and conn (boundp conn) (symbol-value conn))))
    (swank::eval-in-emacs
     '(progn
       (load "init-cgraph.el")
       (load (expand-file-name "~/repo/cgraph/cgraph-filesets.el"))
       (cgraph-read-options-from-cl))))

  (cleanup-files code-base))


(in-package :cl-user)

;;; This is the transition from the :cl-user package to the :cg package
(defun start-cgraph (code-path &key external-types-directory)
  (setf *package* (or (find-package :conceptual-graphs)
                      (make-package :conceptual-graphs
                                    :use '(:common-lisp :common-lisp-user :uiop)
                                    :nicknames '(:cg :cgraph))))

  (cg::setup-cgraph code-path :external-types-directory external-types-directory)

  (cg::report-directories)
  (terpri)

  ;; start web server
  (terpri)
  (asdf:load-system :cgraph-web)
  (cg::start-web-server :port 8060)
  (terpri)

  (when cg::*run-lexicon-lint-on-startup*
    (let ((min-sev (case cg::*run-lexicon-lint-on-startup*
                     (:errors-only     :error)
                     (:errors-warnings :warn)
                     (otherwise        :info))))
      (cg::report-lexicon-lint :min-severity min-sev))
    (terpri))

  (when cg::*run-tests-on-startup*
    (cg::test-cgraph t)))

(in-package #:conceptual-graphs)

;;; --- Opening the editor from the REPL --------------------------------------
;;;
;;; The editor is its own ASDF system, and START-CGRAPH does not load it -- it
;;; loads :cgraph-web and starts the acceptor, nothing more. So the first edit
;;; of a session otherwise needs the system loaded by hand before EDIT-CGRAPH
;;; is so much as a defined name.
;;;
;;; EDIT-GRAPH is that preamble, done once and correctly:
;;;
;;;   (edit-graph "[EAT]- (agnt)→[DOG] (obj)→[FOOD]")
;;;   (edit-graph some-graph)
;;;   (edit-graph)                        ; start from nothing
;;;
;;; Loading on demand rather than at startup keeps the editor optional, which
;;; is the reason it is a separate system at all. Same shape as START-CGRAPH
;;; pulling in :cgraph-web when it is actually wanted.

(defun %cg-symbol (name)
  "The symbol NAME in this package, or an error naming what is missing.
   Looked up rather than referenced so that this file, which is part of the
   main system, need not mention names the editor system defines."
  (or (find-symbol name '#:conceptual-graphs)
      (error "~a is undefined -- :cgraph-editor did not load as expected." name)))

(defun %sync-editor-port ()
  "Point the editor at whatever port the server is really listening on.

   *EDITOR-PORT* defaults to 8060 and the editor shares the type browser's
   acceptor, so the two agree until someone starts the server elsewhere --
   and then the printed URL is wrong in a way that looks like the editor is
   broken. Ask the acceptor instead of assuming."
  (let* ((sym (find-symbol "*WEB-ACCEPTOR*" '#:conceptual-graphs))
         (acceptor (and sym (boundp sym) (symbol-value sym))))
    (when acceptor
      (setf (symbol-value (%cg-symbol "*EDITOR-PORT*"))
            (uiop:symbol-call '#:hunchentoot '#:acceptor-port acceptor)))))

(defun edit-graph (&optional thing &rest keys)
  "Edit THING in the browser, loading the editor system if this image lacks it.

   THING is anything EDIT-CGRAPH takes -- a string of linear notation, a live
   GRAPH, a CONCEPT, or nothing at all for a fresh graph -- and KEYS pass
   straight through (:PARENT, :OPEN). Blocks until UPDATE or CANCEL and returns
   (VALUES RESULT COMMITTED-P), so a string in gives the edited string back and
   a graph in is edited in place.

   The system is loaded only when EDIT-CGRAPH is not already defined, so this
   costs nothing after the first call and never recompiles under you
   mid-session. To pick up edited editor sources, reload it yourself."
  (unless (find-symbol "EDIT-CGRAPH" '#:conceptual-graphs)
    ;; Derived from the loaded system rather than hard-coded: the editor's .asd
    ;; sits beside cgraph's, wherever the repository happens to live.
    (pushnew (asdf:system-source-directory '#:cgraph)
             asdf:*central-registry* :test #'equal)
    (asdf:load-system :cgraph-editor))
  (%sync-editor-port)
  (apply (%cg-symbol "EDIT-CGRAPH") thing keys))
