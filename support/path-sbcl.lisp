;;;; path-sbcl.lisp - SBCL port of path.lisp
;;;; Execution path tracing between functions using sb-introspect
;;;;
;;;; Original code written for Allegro CL, ported to SBCL
;;;;
;;;; Note: SBCL's introspection is more limited than ACL's xref system.
;;;; - sb-introspect:who-calls requires functions to be compiled with debug info
;;;; - You may need to compile with (optimize (debug 3)) for full information

;;; Ensure sb-introspect is available
(require :sb-introspect)

;;; SBCL fspec handling ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; SBCL uses simpler function specs than ACL:
;;; - Regular functions: symbol
;;; - Setf functions: (setf symbol)
;;; - Methods: represented differently, use MOP
;;;
;;; We'll create compatibility functions for the fspec accessors

;;; ⏺ Glad it's working. You now have:

;;;   - (path :from fn) - shows call tree of what fn calls (depth 5 by default)
;;;   - (path :to fn) - shows who calls fn (depth 5 by default)
;;;   - (path :from fn :to fn2) - shows paths between two functions
;;;   - (path :from fn :limit 10) - override depth

;;;   You can tune *default-tree-depth* if 5 is too shallow or too deep.


;;;   New parameter:
;;;   *session-ignored-fns*   ; hash table of ignored functions

;;;   New functions:
;;;   (ignore-fn 'some-noisy-fn)      ; add to ignore list
;;;   (unignore-fn 'some-fn)          ; remove from ignore list
;;;   (clear-ignored-fns)             ; clear all session ignores
;;;   (show-ignored-fns)              ; list what's currently ignored
;;;   (session-ignored-p name)        ; predicate for checking

;;;   Usage:
;;;   (load "support/path-sbcl.lisp")

;;;   (path :from parse-cgraph)
;;;   ;; See some noisy function you don't care about...

;;;   (ignore-fn 'noisy-utility)
;;;   (ignore-fn 'another-one)

;;;   ;; Now they won't appear
;;;   (path :from parse-cgraph)

;;;   ;; See what you've ignored
;;;   (show-ignored-fns)

;;;   ;; Bring one back
;;;   (unignore-fn 'another-one)

;;;   ;; Start fresh
;;;   (clear-ignored-fns)

;;;   Uses a hash table for O(1) lookups, and the ignore list persists for your session but resets when you reload the file.

;;; ❯ I think that's all for now

;;; ⏺ Sounds good. Here's a summary of what's in support/path-sbcl.lisp:
;;;   ┌──────────────────────┬────────────────────────────────────────────────────┐
;;;   │       Feature        │                      Control                       │
;;;   ├──────────────────────┼────────────────────────────────────────────────────┤
;;;   │ Tree depth           │ *default-tree-depth* (default 5) or :limit param   │
;;;   ├──────────────────────┼────────────────────────────────────────────────────┤
;;;   │ Package blacklist    │ *ignored-packages*                                 │
;;;   ├──────────────────────┼────────────────────────────────────────────────────┤
;;;   │ Package whitelist    │ *interesting-packages* (takes precedence when set) │
;;;   ├──────────────────────┼────────────────────────────────────────────────────┤
;;;   │ Accessor filtering   │ *filter-accessors* (default t)                     │
;;;   ├──────────────────────┼────────────────────────────────────────────────────┤
;;;   │ Specific functions   │ *ignored-fns*                                      │
;;;   ├──────────────────────┼────────────────────────────────────────────────────┤
;;;   │ Interactive ignoring │ (ignore-fn ...), (unignore-fn ...), etc.           │
;;;   └──────────────────────┴────────────────────────────────────────────────────┘
;;;   Main entry points:
;;;   (path :from fn)              ; call tree from fn
;;;   (path :to fn)                ; who calls fn
;;;   (path :from fn :to fn2)      ; paths between functions
;;;   (path :from fn :limit 10)    ; custom depth

;;;   Let me know if you run into issues or want to add more features later.











(defun fspec-first (fspec)
  "Get the first element of a function spec (the type indicator)"
  (if (consp fspec)
      (car fspec)
      fspec))

(defun fspec-second (fspec)
  "Get the second element of a function spec"
  (when (consp fspec)
    (cadr fspec)))

(defun fspec-third (fspec)
  "Get the third element of a function spec"
  (when (consp fspec)
    (caddr fspec)))

(defun fspec-fourth (fspec)
  "Get the fourth element of a function spec"
  (when (consp fspec)
    (cadddr fspec)))


(defun parse-fspec (fspec)
  "Parse a function spec into a property list describing it"
  (cond
    ((symbolp fspec)
     (list 'function :name fspec))
    ((not (consp fspec))
     nil)
    (t
     (case (fspec-first fspec)
       (:internal
        ;; (:internal outer-name index)
        (list (fspec-first fspec) :outer-name (fspec-second fspec) :index (fspec-third fspec)))
       (flet
           ;; (flet outer-name inner-name)
           (list (fspec-first fspec) :outer-name (fspec-second fspec) :inner-name (fspec-third fspec)))
       (labels
           ;; (labels outer-name inner-name)
           (list (fspec-first fspec) :outer-name (fspec-second fspec) :inner-name (fspec-third fspec)))
       (sb-pcl::method
        ;; SBCL method specs: (sb-pcl::method name qualifiers specializers)
        (let ((fourth (fspec-fourth fspec)))
          (if fourth
              (list 'method :name (fspec-second fspec)
                    :qualifiers (fspec-third fspec) :specializers (fspec-fourth fspec))
              (list 'method :name (fspec-second fspec) :specializers (fspec-third fspec)))))
       (method
        ;; (method name [qualifiers] specializers)
        (let ((fourth (fspec-fourth fspec)))
          (if fourth
              (list (fspec-first fspec) :name (fspec-second fspec)
                    :qualifiers (fspec-third fspec) :specializers (fspec-fourth fspec))
              (list (fspec-first fspec) :name (fspec-second fspec) :specializers (fspec-third fspec)))))
       (setf
        ;; (setf reader)
        (list (fspec-first fspec) :reader (fspec-second fspec)))
       (t
        ;; Unknown spec type
        (list :unknown :spec fspec))))))



(defun format-fspec (fspec &optional (stream *standard-output*))
  (let ((fspec-plist (parse-fspec fspec)))
    (format stream "#<~a ~a ~a>" (getf fspec-plist :name) (getf fspec-plist :qualifiers)(getf fspec-plist :specializers))))


(defun fspec-name (fspec)
  "Extract the function name from a function spec"
  (cond
    ((symbolp fspec) fspec)
    ((not (consp fspec)) nil)
    (t
     (case (fspec-first fspec)
       ((setf) fspec)  ; (setf foo) is the name
       ((method sb-pcl::method)
        (fspec-second fspec))
       ((:internal flet labels)
        (fspec-second fspec))
       (t
        (fspec-second fspec))))))

(defun dref (fspec)
  (cond ((consp fspec)
         (fspec-name fspec))
        (t fspec)))



(defun parse-name (spec)
  "Extract a simple function name from various spec formats"
  (cond ((atom spec) spec)
        ((and (eql (car spec) 'method) (listp (cadr spec)) (eql (caadr spec) 'setf))
         (cadr spec))
        ((and (eql (car spec) 'sb-pcl::method) (listp (cadr spec)) (eql (caadr spec) 'setf))
         (cadr spec))
        ((find (car spec) '(method sb-pcl::method flet labels))
         (parse-name (cadr spec)))
        ((eql (car spec) 'setf)
         spec)
        ((eq (car spec) :internal)
         (parse-name (cadr spec)))
        ((eq (car spec) :discriminator)
         (car (cadr spec)))
        ((eq (car spec) :anonymous-lambda)
         'anonymous)
        ((eq (car spec) :property)
         spec)
        ((eq (car spec) :top-level-form)
         nil)
        ((eq (car spec) 'compiler-macro)
         (parse-name (cdr spec)))
        ;; for paths
        (t (parse-name (car spec)))))

;;;;; Cross-reference functions using sb-introspect ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;
;;; SBCL equivalents:
;;; - ACL's (xref:get-relation :calls :wild fn) = "who calls fn" -> sb-introspect:who-calls
;;; - ACL's (xref:get-relation :calls fn :wild) = "fn calls who" -> sb-introspect:find-function-callees
;;;
;;; Note: sb-introspect:who-calls returns a list of (dspec . source-location) pairs
;;;       where dspec is a "definition specifier" like (defun foo) or (defmethod bar (t))

(defun who-calls (called-form)
  "Return list of function specs that call CALLED-FORM.
In SBCL, this uses sb-introspect:who-calls which returns definition specifiers."
  (let ((name (parse-name called-form)))
    (when (and name (symbolp name))
      ;; sb-introspect:who-calls returns ((dspec . location) ...)
      ;; We extract just the dspecs and convert to a format similar to ACL
      (let ((callers (sb-introspect:who-calls name)))
        (mapcar #'(lambda (entry)
                    (let ((dspec (car entry)))
                      ;; Convert SBCL dspec to something like ACL fspec
                      ;; dspec is like (DEFUN FOO) or (DEFMETHOD BAR (T))
                      (cond
                        ((and (consp dspec) (eq (car dspec) 'defun))
                         (cadr dspec))
                        ((and (consp dspec) (eq (car dspec) 'defmethod))
                         ;; Convert (defmethod name specializers) to (method name specializers)
                         (cons 'method (cdr dspec)))
                        ((and (consp dspec) (eq (car dspec) 'defmacro))
                         (cadr dspec))
                        ((and (consp dspec) (eq (car dspec) 'sb-pcl::defmethod))
                         (cons 'method (cdr dspec)))
                        (t
                         ;; Return as-is for other types
                         (if (consp dspec) (cadr dspec) dspec)))))
                callers)))))


(defun specializer-name (specializer)
  "Get a printable name for a method specializer.
Handles both class specializers and EQL specializers."
  (typecase specializer
    (sb-mop:eql-specializer
     ;; EQL specializer like (eql :foo) or (eql nil)
     (list 'eql (sb-mop:eql-specializer-object specializer)))
    (class
     (class-name specializer))
    (t
     ;; Fallback - just return it
     specializer)))

(defun calls-who (calling-form)
  "Return list of functions called by CALLING-FORM.
In SBCL, this uses sb-introspect:find-function-callees."
  (let ((name (parse-name calling-form)))
    (when (and name (symbolp name) (fboundp name))
      (let ((fn (fdefinition name)))
        ;; For generic functions, we need to handle differently
        (if (typep fn 'generic-function)
            ;; Return method specs for generic functions
            (mapcar #'(lambda (method)
                        (list 'method name (method-qualifiers method)
                              (mapcar #'specializer-name (sb-mop:method-specializers method))))
                    (sb-mop:generic-function-methods fn))
            ;; For regular functions, get callees
            (let ((callees (sb-introspect:find-function-callees fn)))
              (remove-duplicates
               (mapcar #'(lambda (callee)
                           (cond
                             ((symbolp callee) callee)
                             ((and (consp callee) (eq (car callee) 'setf))
                              callee)
                             ((sb-kernel:fdefn-p callee)
                              (sb-kernel:fdefn-name callee))
                             ((functionp callee)
                              ;; Try to get the name
                              (let ((name (sb-kernel:%fun-name callee)))
                                (if (and name (not (eq name 'nil)))
                                    (parse-name name)
                                    callee)))
                             (t callee)))
                       callees)
               :test #'equal)))))))


(defun calls-whox (generic-function)
  "Get all functions called by all methods of a generic function"
  (let ((gfuns (calls-who generic-function))
        (methods (list)))
    (dolist (fun gfuns)
      (push (calls-who fun) methods))
    (filter (sort (remove-duplicates (apply #'append methods)) #'alpha-lessp))))


;;; Helper for sorting by symbol name
(defun alpha-lessp (a b)
  "Compare two items alphabetically by their printed representation"
  (string< (princ-to-string (parse-name a))
           (princ-to-string (parse-name b))))


;;; an expansion is a list of paths, where each path is a function-spec
;;; followed by the specs of functions already visited to get to the function
;;;
;;; The horizon of an expansion is the leaves of the tree.
;;; Normally, those are atoms.
;;; We are carrying the entire path with us, so we need the car of the path.

;;; (expand-path '(save-plan))
;; path: a list of function-names
;;; returns
;;; (list (list <a-function-called-by-headof-path> path)
;;;       (list <another-function-called-by-headof-path> path)
;;;       ...)
;;; i.e. returns a list of paths, one for each function called by head
(defmethod expand-path ((path list))
  (let* ((head (parse-name (car path)))
         (callers (who-calls head))
         (expanded (mapcar #'(lambda (caller)
                               (cons caller path))
                           callers)))
    expanded))



;;; (expand '((save-plan)))
(defun expand (paths)
  ;; combine the lists of paths into a single list of all paths
  (apply #'append (mapcar #'expand-path paths)))



(defmethod expand-path2 ((path list))
  (let* ((head (parse-name (car path)))
         (callers (calls-whox head))
         (expanded (mapcar #'(lambda (caller)
                               (cons caller path))
                           callers)))
    expanded))



;;; (expand '((save-plan)))
(defun expand2 (paths)
  ;; combine the lists of paths into a single list of all paths
  (apply #'append (mapcar #'expand-path2 paths)))




(defun horizon-contains (horizon fn-spec)
  (find (parse-name fn-spec) horizon :key #'parse-name))


;;; not used
(defun find-path (fn-spec expansion)
  (find-if #'(lambda (path)
               (horizon-contains path fn-spec))
           expansion))




;;; work from end to start because who-calls returns methods,
;;;    and calls-who returns generic functions
(defun call-paths (from to &optional limit)
  "Find call paths from FROM to TO"
  (let ((expansion-list
          (loop for depth = 0 then (1+ depth)
                for expansion = (list (list to)) then (expand expansion)
                for horizon = (mapcar #'car expansion)
                for found = (horizon-contains horizon from)
                if found collect expansion into expansions
                  until (or (null horizon)
                            (null (car horizon))
                            (and (null limit) found)
                            (and limit (numberp limit) (> depth limit)))
                finally (return expansions)))
        (paths (list)))

    ;; expansion-list - list of paths whose that end with the to function
    ;; collect the paths that start with the from function
    (when expansion-list
      (dolist (path-list expansion-list)
        (dolist (path path-list)
          (when (equal (parse-name (car path)) from)
            (push path paths)))))
    paths))



(defun call-paths2 (from to &optional limit)
  "Find call paths from FROM to TO (variant using calls-whox)"
  (let ((expansion-list
          (loop for depth = 0 then (1+ depth)
                for expansion = (list (list to)) then (expand2 expansion)
                for horizon = (mapcar #'car expansion)
                for found = (horizon-contains horizon from)
                if found collect expansion into expansions
                  until (or (null horizon)
                            (null (car horizon))
                            (and (null limit) found)
                            (and limit (numberp limit) (> depth limit)))
                finally (return expansions)))
        (paths (list)))

    ;; expansion-list - list of paths whose that end with the to function
    ;; collect the paths that start with the from function
    (when expansion-list
      (dolist (path-list expansion-list)
        (dolist (path path-list)
          (when (equal (parse-name (car path)) from)
            (push path paths)))))
    paths))




(defun call-path (from-fn to-fn &optional limit)
  (let ((paths (call-paths from-fn to-fn limit)))
    paths))

(defun call-path2 (from-fn to-fn &optional limit)
  (let ((paths (call-paths2 from-fn to-fn limit)))
    paths))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defparameter *ignored-fns* '(get-exclude-executions lookup-stored-query program-ids-from-query store-query process-diagnostic insert-format-arguments diagnostic get-diagnostic-class))

;;; Updated for SBCL - using SBCL package names
(defparameter *ignored-packages* '(sb-ext sb-impl sb-kernel sb-int sb-sys sb-pcl
                                   common-lisp cl cl-user))

;;; Package whitelist - when non-nil, ONLY show functions from these packages
;;; This takes precedence over *ignored-packages*
(defparameter *interesting-packages* nil
  "When non-nil, only include functions from these packages.
Takes precedence over *ignored-packages*.
Example: (setf *interesting-packages* '(:cg :my-app))")

(defun package-matches-p (pkg package-list)
  "Check if PKG matches any package in PACKAGE-LIST.
Handles both keyword and string package names."
  (let ((pkg-name (if (packagep pkg) (package-name pkg) (string pkg))))
    (find pkg-name package-list
          :test #'string-equal
          :key #'string)))

(defun package-interesting-p (name)
  "Check if NAME's package passes the package filter.
If *interesting-packages* is set, the package must be in that list.
Otherwise, the package must not be in *ignored-packages*."
  (let ((pkg (and (symbolp name) (symbol-package name))))
    (cond
      ;; No package - uninterned symbol, let it through
      ((null pkg) t)
      ;; Whitelist mode: package must be in *interesting-packages*
      (*interesting-packages*
       (package-matches-p pkg *interesting-packages*))
      ;; Blacklist mode: package must NOT be in *ignored-packages*
      (t
       (not (package-matches-p pkg *ignored-packages*))))))

;;; Accessor filtering via MOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *filter-accessors* t
  "When non-nil, filter out slot accessor functions (readers and writers)")

(defun accessor-method-p (method)
  "Check if METHOD is a slot accessor method (reader or writer)"
  (or (typep method 'sb-mop:standard-reader-method)
      (typep method 'sb-mop:standard-writer-method)))

(defun reader-method-p (method)
  "Check if METHOD is a slot reader method"
  (typep method 'sb-mop:standard-reader-method))

(defun writer-method-p (method)
  "Check if METHOD is a slot writer method"
  (typep method 'sb-mop:standard-writer-method))

(defun accessor-gf-p (fn-name)
  "Check if FN-NAME is a generic function where all methods are accessors"
  (when (and (symbolp fn-name)
             (fboundp fn-name)
             (typep (fdefinition fn-name) 'generic-function))
    (let ((methods (sb-mop:generic-function-methods (fdefinition fn-name))))
      (and methods
           (every #'accessor-method-p methods)))))

(defun reader-gf-p (fn-name)
  "Check if FN-NAME is a generic function where all methods are slot readers"
  (when (and (symbolp fn-name)
             (fboundp fn-name)
             (typep (fdefinition fn-name) 'generic-function))
    (let ((methods (sb-mop:generic-function-methods (fdefinition fn-name))))
      (and methods
           (every #'reader-method-p methods)))))

(defun writer-gf-p (fn-name)
  "Check if FN-NAME is a generic function where all methods are slot writers"
  (when (and (symbolp fn-name)
             (fboundp fn-name)
             (typep (fdefinition fn-name) 'generic-function))
    (let ((methods (sb-mop:generic-function-methods (fdefinition fn-name))))
      (and methods
           (every #'writer-method-p methods)))))

;;; Interactive filtering - ignore functions during a session ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *session-ignored-fns* (make-hash-table :test #'equal)
  "Functions ignored during the current session. Use IGNORE-FN and UNIGNORE-FN to modify.")

(defun ignore-fn (fn-name)
  "Add FN-NAME to the session ignore list. Can be a symbol or a fspec like (setf foo)."
  (let ((name (parse-name fn-name)))
    (setf (gethash name *session-ignored-fns*) t)
    (format t "~&Ignoring ~S~%" name)
    name))

(defun unignore-fn (fn-name)
  "Remove FN-NAME from the session ignore list."
  (let ((name (parse-name fn-name)))
    (remhash name *session-ignored-fns*)
    (format t "~&No longer ignoring ~S~%" name)
    name))

(defun clear-ignored-fns ()
  "Clear all session-ignored functions."
  (clrhash *session-ignored-fns*)
  (format t "~&Session ignore list cleared.~%")
  t)

(defun show-ignored-fns ()
  "Show all functions currently ignored in this session."
  (let ((fns nil))
    (maphash (lambda (k v) (declare (ignore v)) (push k fns)) *session-ignored-fns*)
    (if fns
        (format t "~&Session-ignored functions:~%~{  ~S~%~}" (sort fns #'string< :key #'princ-to-string))
        (format t "~&No session-ignored functions.~%"))
    fns))

(defun session-ignored-p (name)
  "Check if NAME is in the session ignore list."
  (gethash name *session-ignored-fns*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod use ((x t))
  (let ((name (parse-name x)))
    (when (and name
               (symbolp name)
               (package-interesting-p name)
               (not (or (find name *ignored-fns*)
                        (session-ignored-p name)
                        (and (consp x) (eq (car x) 'setf))
                        (and *filter-accessors* (accessor-gf-p name)))))
      x)))





(defmethod filter ((fns list))
  (cond ((eql (car fns) 'method)
         (when (filter (parse-name fns))
           fns))
        (t
         (remove-if-not #'use fns))))

(defmethod filter ((fn symbol))
  (when (use fn) fn))






(defun called-functions (fspec)
  (calls-who fspec))

;;; generic-function name --> method specs
(defmethod caller-fspecs ((function-name symbol))
  (when (use function-name)
    (who-calls function-name)))


(defmethod gf-p ((sym symbol))
  (and (fboundp sym)
       (typep (fdefinition sym) 'generic-function)))


;;; generic-function name --> the generic-function's method fspecs
(defmethod method-specs (function)
  (format t "~%>> (method-specs '~s)~%" function)
  (let* ((function-name (parse-name function))
         (fn (when (and function-name (symbolp function-name) (fboundp function-name))
               (fdefinition function-name))))
    (if (typep fn 'generic-function)
        (filter (calls-who function-name))
        (filter (list function-name)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; symbol or fspec => list of fspecs
(defmethod callees (spec)
  (format t "~%>> (callees '~s)~%" spec)
  (let ((function-name (dref spec)))
    (when (use function-name)
      (let* ((method-specs (method-specs function-name))
             (callee-function-names (filter
                                     (apply #'append
                                            (mapcar (lambda (method-spec)
                                                      (let* ((all-callees (calls-who method-spec))
                                                             (used-callees
                                                               (remove-duplicates
                                                                (remove nil (mapcar #'use all-callees)))))
                                                        used-callees))
                                                    method-specs)))))
        (format t "~&function-name: ~s" function-name)
        (format t "~&method-specs: ~s" method-specs)
        (format t "~&callee-function-names: ~s" callee-function-names)
        callee-function-names))))




;;; generic-function name or fspec --> method fspecs
(defmethod callers (spec)
  (let ((function-name (dref spec)))
    (when (use function-name)
      (caller-fspecs function-name))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defmethod callswho-tree ((fn-name symbol) &optional (limit 3) (depth 0))
  (format t "~2%>> (callswho-tree '~s ~s ~s)~%" fn-name limit depth)
  (cons fn-name
        (when (< depth limit)
          (let ((fspecs (callees fn-name)))
            (format t "~&fspecs: ~s" fspecs)
            (filter
             (remove-duplicates
              (mapcar #'(lambda (fspec)
                          (format t "~2&fspec: ~s" fspec)
                          (when (eql fspec 'setf) fspec (break))
                          (let ((f (parse-name fspec)))
                            (cond ((not (eq fn-name f))
                                   (callswho-tree f limit (1+ depth)))
                                  (t (list f)))))
                      fspecs)
              :test #'equalp))))))

(defmethod callswho-tree ((fspec list) &optional (limit 3) (depth 0))
  (callswho-tree (fspec-name fspec) limit depth))


;;;;;;;;;;;;;;;;;;;;;;;

(defmethod whocalls-tree ((fn-name symbol) &optional (limit 3) (depth 0))
  (cons fn-name
        (when (< depth limit)
          (let ((fns (callers fn-name)))
            (filter
             (remove-duplicates
              (mapcar #'(lambda (n)
                          (let ((f (parse-name n)))
                            (cond ((not (eq fn-name f))
                                   (filter (whocalls-tree f limit (1+ depth))))
                                  (t (list f)))))
                      fns)
              :test #'equalp))))))

(defmethod whocalls-tree ((fspec list) &optional (limit 3) (depth 0))
  (whocalls-tree (fspec-name fspec) limit depth))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defparameter *default-tree-depth* 5
  "Default depth limit for tree traversals when no limit is specified")

(defun calc-path (&key to from limit)
  (let ((effective-limit (or limit *default-tree-depth*)))
    (cond ((and (null from) (null to)) nil)
          ((null from)
           (whocalls-tree to effective-limit))
          ((null to)
           (callswho-tree from effective-limit))
          ((and to from)
           (call-path from to limit)))))  ; pass original limit for path search

(defun calc-path2 (&key to from limit)
  (let ((effective-limit (or limit *default-tree-depth*)))
    (cond ((and (null from) (null to)) nil)
          ((null from)
           (whocalls-tree to effective-limit))
          ((null to)
           (callswho-tree from effective-limit))
          ((and to from)
           (call-path2 from to limit)))))  ; pass original limit for path search




(defun leafp (tree)
  (or (symbolp tree)
      (eql (car tree) 'method)))


(defun treeout (tree &optional (level 0) &key (stream *standard-output*))
  (when tree
    (let ((indent-str (make-string (* level 3) :initial-element #\space))
          (*print-pretty* nil))
      (when (= level 1) (format t "~2%"))
      (cond ((leafp tree)
             (format stream "~&~:a~:a" indent-str tree))
            ((not (leafp (car tree)))
             (dolist (subtree tree)
               (treeout subtree (1+ level))))
            (t
             (mapc (lambda (x)
                     (treeout x (1+ level)))
                   tree))))))


(defmacro path (&key to from limit)
  `(let ((result (calc-path :from ',from :to ',to :limit ,limit)))
     (values result (length result))))


(defmacro path2 (&key to from limit)
  `(let ((result (calc-path2 :from ',from :to ',to :limit ,limit)))
     (values result (length result))))




(defmacro print-path (&key to from limit (tree nil) (stream *standard-output*))
  `(let ((path (or ,tree (path :to ,to :from ,from :limit ,limit))))
     (treeout path 0 :stream ,stream)
     t))


;;; Test functions for verifying the port works
#|
(defun foo (x)
  (format t "~&foo: ~a" x))

(defun bar (x)
  (format t "~&bar: ~a" x)
  (foo (* 2 x)))

(defun baz (x)
  (format t "~&baz: ~a" x)
  (foo (* 3 x))
  (bar (* 3 x)))

;; Compile with debug info for best results
(compile 'foo)
(compile 'bar)
(compile 'baz)

;; Test
(who-calls 'foo)
(calls-who 'baz)
(path :from baz :to foo)
|#


;;; Notes on SBCL differences from ACL:
;;;
;;; 1. sb-introspect:who-calls requires functions to be compiled with debug info.
;;;    For best results, compile with: (declaim (optimize (debug 3)))
;;;
;;; 2. sb-introspect returns definition specifiers (dspecs) like (DEFUN FOO)
;;;    instead of ACL's fspecs. The conversion is handled in who-calls.
;;;
;;; 3. find-function-callees works on the function object, not the symbol.
;;;
;;; 4. Generic function handling is different - SBCL uses sb-mop (MetaObject Protocol)
;;;    to access method information.
;;;
;;; 5. Some internal SBCL functions may not have complete call information.
