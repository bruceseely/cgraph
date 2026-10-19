;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;  ;;  initialize  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; --- Type sets ---------------------------------------------------------------
;;;
;;; A type set is a directory holding concept-types.lisp and relation-types.lisp,
;;; and optionally lexicon-overrides.lisp. *CGRAPH-TYPES-DIRECTORY* names the one
;;; the catalog is loaded from; the type editor saves into the same files. Sets
;;; are read where they are -- nothing is copied, deleted or symlinked -- and the
;;; shipped set, default-types/, is never written. To change types you make a
;;; set of your own with CREATE-TYPE-SET.
;;;
;;; This used to work by indirection: ~/.cgraph/types/ held either a copy of the
;;; defaults or symlinks into a chosen directory, rebuilt by setup with
;;; `ln -s' -- so every setup deleted and rewrote files in the user's home
;;; directory, and binding *CGRAPH-TYPES-DIRECTORY* to a set's own directory
;;; linked that directory into itself and destroyed its files.

(defun default-types-directory ()
  "The shipped, read-only type set: default-types/ in the cgraph source tree."
  (namestring (asdf:system-relative-pathname "cgraph" "default-types/")))

(defun named-type-sets-directory ()
  "Where named type sets live: ~/.cgraph/types/<name>/."
  (namestring (merge-pathnames ".cgraph/types/" (user-homedir-pathname))))

(defun type-set-directory (designator)
  "The directory namestring, with a trailing slash, of the type set DESIGNATOR
   names. A pathname, or a string containing a slash, is a directory (a leading
   ~/ is your home directory); any other string is a NAME, meaning
   ~/.cgraph/types/NAME/."
  (let ((string (if (pathnamep designator) (namestring designator) designator)))
    (check-type string string)
    (cond ((and (not (pathnamep designator)) (not (find #\/ string)))
           (format nil "~a~a/" (named-type-sets-directory) string))
          (t
           (when (and (>= (length string) 2) (string= "~/" string :end2 2))
             (setf string (namestring (merge-pathnames (subseq string 2)
                                                       (user-homedir-pathname)))))
           (namestring (uiop:ensure-directory-pathname string))))))

(defun type-set-files-exist-p (directory)
  (and (probe-file (format nil "~aconcept-types.lisp" directory))
       (probe-file (format nil "~arelation-types.lisp" directory))
       t))

(defun default-types-p (&optional (directory *cgraph-types-directory*))
  "True when DIRECTORY is the shipped type set."
  (and directory
       (equal (ignore-errors (truename directory))
              (ignore-errors (truename (default-types-directory))))))

(define-condition types-read-only (error)
  ()
  (:report (lambda (condition stream)
             (declare (ignore condition))
             (format stream "The default types are read-only. To edit types, make a ~
                             type set of your own: (cg:create-type-set \"name\") copies ~
                             the current types to ~a<name>/ and switches to it."
                     (named-type-sets-directory))))
  (:documentation "Signalled on an attempt to write the shipped default types.
   A condition of its own so the web UI can tell it from other refusals and
   offer to create a type set instead."))

(defun ensure-types-writable (&optional (directory *cgraph-types-directory*))
  "Signal TYPES-READ-ONLY unless the type set in DIRECTORY may be written. Only
   the shipped defaults are refused; any set the user chose is theirs to edit."
  (when (or (null directory) (default-types-p directory))
    (error 'types-read-only)))

(defun create-type-set (designator &key from (switch t))
  "Copy a type set into a new one named by DESIGNATOR (see TYPE-SET-DIRECTORY:
   a name for ~/.cgraph/types/NAME/, or a directory path), and return its
   directory. FROM names the set to copy, by default the one now loaded --
   which is the shipped defaults until you choose another. Every file in its
   directory is copied, not only the type files -- a set may carry a lexicon,
   notes, a README -- except hidden ones. With SWITCH (the default) the new set becomes the current
   one, so the type editor saves into it; the catalog in memory already holds
   the same types and is not reloaded. Refuses to overwrite an existing set."
  (let ((source (type-set-directory (or from *cgraph-types-directory*
                                        (default-types-directory))))
        (target (type-set-directory designator)))
    (unless (type-set-files-exist-p source)
      (error "No type set at ~a: it needs concept-types.lisp and relation-types.lisp."
             source))
    (when (or (type-set-files-exist-p target)
              (uiop:directory-files target))
      (error "~a already exists and isn't empty; choose another name." target))
    (ensure-directories-exist target)
    ;; Hidden files (.DS_Store, editor locks) are the directory's, not the set's.
    (dolist (file (uiop:directory-files source))
      (unless (char= #\. (char (file-namestring file) 0))
        (uiop:copy-file file (merge-pathnames (file-namestring file) target))))
    (when switch
      (setf *external-types-directory* target
            *cgraph-types-directory*   target
            *loaded-types-source*      target))
    target))


(defun domain-types-directory ()
  "The directory this session's type files really live in -- the domain.
   *CGRAPH-TYPES-DIRECTORY* names it directly; TRUENAME still follows a
   symlinked concept-types.lisp, so a set whose files are links into another
   directory is found where the files are. Falls back to
   *CGRAPH-TYPES-DIRECTORY* itself when there is no such file."
  (let* ((dir  (uiop:ensure-directory-pathname (or *cgraph-types-directory*
                                                   (default-types-directory))))
         (link (ignore-errors (truename (merge-pathnames "concept-types.lisp" dir)))))
    (if link (uiop:pathname-directory-pathname link) dir)))


(defun initialize-types (&key directory external-types-directory supress-warnings)
  "Load the type catalog from a type set: DIRECTORY (or its older name
   EXTERNAL-TYPES-DIRECTORY) when given, which also makes it current;
   otherwise *CGRAPH-TYPES-DIRECTORY*; otherwise the shipped defaults. Reads
   only: nothing is copied, linked or deleted."
  (let ((given (or directory external-types-directory)))
    (when given
      (setf *cgraph-types-directory* (type-set-directory given))))
  (unless *cgraph-types-directory*
    (setf *cgraph-types-directory* (default-types-directory)))

  (cond ((type-set-files-exist-p *cgraph-types-directory*)
         (clear-cgraph-type-catalogs)
         (load-cgraph-types supress-warnings)
         ;; ... and the English that goes with them. A domain may ship
         ;; lexicon-overrides.lisp beside its type files to say how its types are
         ;; worded; absence is legal and silent (see *DOMAIN-LEXICON-LOADER*).
         ;; After the catalog, so the lint that reads these entries has types to
         ;; check them against.
         (when *domain-lexicon-loader*
           (funcall *domain-lexicon-loader* (domain-types-directory))))
        (t
         (warn "No type set at ~a: it needs concept-types.lisp and relation-types.lisp."
               *cgraph-types-directory*))))


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
  (format t "~&______________________________________________________________  ~%")
  (format t "~&CGraph directory: ~a~50t*cgraph*~%"       *cgraph*)
  (format t "~&type definitions: ~a~50t*cgraph-types-directory*~%" *cgraph-types-directory*)
  (format t "~&generated plots   ~a~50t*cgraph-data-directory*~%"  *cgraph-data-directory*)
  (format t "~&web server logs:  ~a~50t*cgraph-log-directory*~%"   *cgraph-log-directory*)
  (format t "~&initializations:  ~ainitializations.lisp~%" *cgraph*)
  (values))


(defvar *home* (namestring (user-homedir-pathname)))


;;; --- Starting a session --------------------------------------------------
;;;
;;; INIT is the one entry point a user needs. SETUP-CGRAPH, RESET-CGRAPH and
;;; INITIALIZE-CGRAPH stay as the pieces it is made of, for callers that want
;;; only one of them (the tests, the web UI's reinitialize button).

(defparameter *default-web-port* 8060
  "The port INIT starts the web server on when given :WEB T.")

(defun set-cgraph-directories (type-set)
  "Point cgraph's directory variables at ~/.cgraph/ and at TYPE-SET, a type-set
   directory, or NIL for the shipped defaults. Creates nothing."
  (let ((cgraph-base (format nil "~a.cgraph/" (namestring (user-homedir-pathname)))))
    (setf *cgraph*                    cgraph-base
          *cgraph-data-directory*     (format nil "~adata/" cgraph-base)
          *cgraph-log-directory*      (format nil "~alogs/" cgraph-base)
          *cgraph-examples-directory* (default-types-directory)
          *external-types-directory*  type-set
          *cgraph-types-directory*    (or type-set (default-types-directory)))))

(defun chosen-type-set (designator)
  "The type-set directory DESIGNATOR names (see TYPE-SET-DIRECTORY), or NIL
   when DESIGNATOR is NIL. Signals an error if it holds no type set."
  (let ((type-set (and designator (type-set-directory designator))))
    (when (and type-set (not (type-set-files-exist-p type-set)))
      (error "No type set at ~a: it needs concept-types.lisp and relation-types.lisp. ~
              (cg:create-type-set ~s) makes one from the current types."
             type-set designator))
    type-set))

(defun load-support-tools ()
  "Load cgraph/support -- SUP:RAPROPOS and friends. A secondary system, so the
   main one needn't depend on cl-ppcre. They are a convenience, never a
   prerequisite -- a missing dependency must not abort setup."
  (handler-case (asdf:load-system "cgraph/support")
    (error (condition)
      (format t "~&;; cgraph/support not loaded (SUP:RAPROPOS unavailable): ~a~%"
	      condition))))

(defvar *swank-readtable-patched* nil
  "True once SWANK's READTABLE-FOR-PACKAGE has been wrapped, so a second setup
   doesn't wrap the wrapper.")

(defun install-slime-integration ()
  "When SWANK is loaded: make :CG the package of SLIME's worker threads, and
   protect SWANK from the CG readtable. Safe to call any number of times."
  (when (find-package :swank)
    (let ((bindings-var (find-symbol "*DEFAULT-WORKER-THREAD-BINDINGS*" :swank))
          (package (find-package :conceptual-graphs)))
      (when (and bindings-var (boundp bindings-var))
        (unless (member (cons '*package* package) (symbol-value bindings-var)
                        :test #'equal)
          (push (cons '*package* package) (symbol-value bindings-var))))))

  ;; Protect SWANK's readtable-for-package from the CG readtable.
  ;; The CG readtable makes ':' a terminating macro char, which breaks
  ;; (read-from-string "swank::guess-buffer-readtable") if an error is
  ;; signaled inside a with-readtable-mods/with-cg-readtable scope and
  ;; the user presses 'v' in SLDB (which runs in the suspended thread).
  (let* ((spp (find-package :swank/source-path-parser))
         (sym (and spp (find-symbol "READTABLE-FOR-PACKAGE" spp))))
    (when (and sym (fboundp sym) (not *swank-readtable-patched*))
      (let ((orig (symbol-function sym)))
        (setf (symbol-function sym)
              (lambda (package)
                (let ((*readtable* (copy-readtable nil)))
                  (funcall orig package))))
        (setf *swank-readtable-patched* t)))))

(defun init (&key types web)
  "Start, or start over, a cgraph session, and return the type-set directory
   in use. This is the one call a session needs after loading cgraph.

   TYPES names the type set to load: a name for ~/.cgraph/types/NAME/, or a
   directory path. Without it, INIT keeps the set already in use, so calling
   (cg:init) again starts fresh with the same types; the first time, that is
   the shipped default types, read-only.

   INIT loads the types and their lexicon, then ~/.cgraph/initializations.lisp
   if there is one, and makes a fresh, empty *CONTEXT*, forgetting every
   individual, variable and coreference. It writes nothing.

   WEB, when T or a port number, also loads the web type browser and graph
   editor and starts their server (on port 8060 for T)."
  (let ((type-set (cond (types (chosen-type-set types))
                        ((default-types-p) nil)
                        (t *cgraph-types-directory*)))
        ;; The type files and initializations.lisp are read and evaluated as
        ;; cgraph code, whatever package the caller is in.
        (*package* (find-package :conceptual-graphs)))
    (set-cgraph-directories type-set)
    (reset-cgraph)
    (load-support-tools)
    (install-slime-integration)
    (when web
      (asdf:load-system :cgraph-web)
      ;; The editor registers its handlers on the server's acceptor.
      (asdf:load-system :cgraph-editor)
      (uiop:symbol-call :conceptual-graphs :start-web-server
                        :port (if (integerp web) web *default-web-port*)))
    *cgraph-types-directory*))

(defun setup-cgraph (code-base &key types external-types-directory)
  "Set cgraph up for a session and load a type catalog -- the first half of
   INIT, which most callers should use instead. TYPES names the type set to
   use -- a name for ~/.cgraph/types/NAME/, or a directory path (see
   TYPE-SET-DIRECTORY); EXTERNAL-TYPES-DIRECTORY is its older spelling. With
   neither, the shipped default types are used, read-only. Setup writes
   nothing: ~/.cgraph/data/ and ~/.cgraph/logs/ are created only when a plot
   or a web-server log is first written there."
  ;; CODE-BASE is no longer used. Setup used to finish with
  ;; (CLEANUP-FILES CODE-BASE), deleting every *.fasl, *.lisp~ and *.lisp#
  ;; under it recursively -- harmless given the cgraph source directory, but a
  ;; setup function has no business deleting files, and "~/" would have wiped
  ;; a home tree. The parameter stays so existing callers keep working;
  ;; CLEANUP-FILES is still there to call by hand.
  (declare (ignore code-base))
  (set-cgraph-directories (chosen-type-set (or types external-types-directory)))
  (initialize-types)
  (load-support-tools)
  (install-slime-integration))



(in-package :cl-user)

;;; This is the transition from the :cl-user package to the :cg package
;;; This machine's launcher (~/.sbclrc's CGRAPH): CG:INIT with the web server,
;;; plus what belongs to this setup rather than to cgraph -- the Emacs side,
;;; the lexicon lint and the test suites.
(defun start-cgraph (code-path &key external-types-directory)
  (declare (ignore code-path))
  (setf *package* (find-package :conceptual-graphs))

  (cg:init :types external-types-directory :web 8060)
  (terpri)

  ;; Load the Emacs side: cg-mode, the C-c t / C-c b keybindings, Customize
  ;; sync. This used to be the end of SETUP-CGRAPH, which made it everyone's:
  ;; init-cgraph.el is a file from this machine's emacs-init, so under anyone
  ;; else's SLIME the load failed in Emacs and took setup down with it.
  ;; START-CGRAPH is this machine's launcher, so it lives here. A failure is
  ;; reported, not fatal: the Lisp side works without it.
  (handler-case
      (cg::eval-in-emacs-if-connected
       '(progn
         (load "init-cgraph.el")
         (load (expand-file-name "~/repo/cgraph/cgraph-filesets.el"))
         (cgraph-read-options-from-cl)))
    (error (condition)
      (format t "~&;; Emacs setup failed (Lisp side unaffected): ~a~%" condition)))

  (cg::report-directories)
  (terpri)

  (when cg::*run-lexicon-lint-on-startup*
    (let ((min-sev (case cg::*run-lexicon-lint-on-startup*
                     (:errors-only     :error)
                     (:errors-warnings :warn)
                     (otherwise        :info))))
      (cg::report-lexicon-lint :min-severity min-sev))
    (terpri))

  ;; The suites are their own system now (cgraph/tests), so loading cgraph
  ;; doesn't compile them; load them here so (cg::test-all t) is at hand.
  (asdf:load-system "cgraph/tests")
  (when cg::*run-tests-on-startup*
    (cg::test-cgraph t)))

