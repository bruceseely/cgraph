;;;; problem:
;;; (path :from SHORT-SOGS-DATE-TO-TJD) shows a lot functions it shouldn't
;;;
;;; info
;;; https://franz.com/support/documentation/current/doc/cross-reference.htm
;;; https://franz.com/support/documentation/current/doc/operators/xref/get-relation.htm
;;; https://franz.com/support/documentation/current/doc/operators/excl/def-function-spec-handler.htm
;;; https://franz.com/support/documentation/current/doc/implementation.htm#function-specs-1
;;; https://franz.com/support/documentation/current/doc/operators/excl/function-name-p.htm

#||
(let ((fns '(parse-spec parse-fspec callees fspec-name dref parse-name	expand found  find-path	 call-paths call-path treeout)))
  (dolist (fn fns)
    (fmakunbound fn)))
||#



;;; fspec - internal file spec ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;

(defun parse-fspec (fspec)
  (case (excl:fspec-first fspec)
    (:anonymous-lambda
     ;; (:anonymous-lambda index)
     )
    (:discriminator
     ;; (:discriminator type)
     )
    (:effective-method
     ;; (:effective-method num-req restp kwdcheck aroundp next-method-p)
     ;;
     ;; num-req - the number of required arguments to the effective method
     ;; restp - whether there is a &rest arg after the required args
     ;; kwdcheck - whether the method will check for valid keywords
     ;; aroundp - whether the effective method has around methods
     ;; next-method-p - whether any of the methods in the effective method do either
     ;;	   (next-method-p) or (call-next-method)
     )
    (:internal
     ;; (:internal outer-name index)
     ;; outer-name -  name of the function which houses the internal function
     ;;		       can be any fspec, including an :internal fspec,
     ;; index - numbered in the order these functions are encountered within the compiler
     (list (excl:fspec-first fspec) :outer-name (excl:fspec-second fspec) :index (excl:fspec-third fspec))
     )
    (:property
     ;; (:property symbol indicator)
     ;; way to define functions which reside on property lists.
     ;; function object becomes the value of the indicator property on the symbol's plist
     )
    (:top-level-form
     ;; (:top-level-form filename file-character-position)
     )
    (prof:closure
     ;; (prof:closure index)
     )
    (compiler-macro
     ;; (compiler-macro function-spec)
     )
    (flet
        ;; (flet outer-name inner-name)
        (list (excl:fspec-first fspec) :outer-name (excl:fspec-second fspec) :inner-name (excl:fspec-third fspec))
      )
    (labels
        ;; (labels outer-name inner-name)
        (list (excl:fspec-first fspec) :outer-name (excl:fspec-second fspec) :inner-name (excl:fspec-third fspec))
      )
    (method
     ;; (method name [qualifiers] specializers)
     (let ((fourth (excl::fspec-fourth fspec)))
       (if fourth
           (list (excl:fspec-first fspec) :name (excl:fspec-second fspec)
                                          :qualifiers (excl:fspec-third fspec) :specializers (excl::fspec-fourth fspec))
           (list (excl:fspec-first fspec) :name (excl:fspec-second fspec) :specializers (excl:fspec-third fspec)))))
    (setf
     ;; (setf reader)
     (list (excl:fspec-first fspec) :reader (excl:fspec-second fspec)))))



(defun format-fspec (fspec &optional (stream *standard-output*))
  (let ((fspec-plist (parse-fspec fspec)))
    (format stream "#<~a ~a ~a>" (getf fspec-plist :name) (getf fspec-plist :qualifiers)(getf fspec-plist :specializers))))


(defun fspec-name (fspec)
  (case (excl:fspec-first fspec)
    ;; add exceptions here ;;;;;;
    (t
     ;; (method name [qualifiers] specializers)
     (excl:fspec-second fspec))))

(defun dref (fspec)
  (cond ((consp fspec)
         (fspec-name fspec))
        (t fspec)))



(defun parse-name (spec)
  ;; (when (eql spec 'setf) (break))
  (cond ((atom spec) spec)
        ((and (eql (car spec) 'method) (listp (cadr spec)) (eql (caadr spec) 'setf))
         (cadr spec))
        ((find (car spec) '(method flet labels))
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

;;;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;
;;;;;;; re methods & gfs
;;;;;
;;;;; (who-calls method-spec) -> not meaningful
;;;;; (xref:get-relation :calls	 :wild '(METHOD SAVE-PLAN (LRP)))
;;;;; NIL
;;;;;
;;;;; (who-calls  generic-function) --> method-specs
;;;;; (xref:get-relation :calls	 :wild 'save-plan)
;;;;; ((METHOD SAVE-PLAN (STRING)) (METHOD WRITE-LONG-RANGE-PLAN (T))
;;;;;  (METHOD GUI-SAVE-PLAN (STRING)))
;;;;; (who-calls 'READ-OBSERVATION-BLOCK-DATA-FROM-MEDIUM)
;;;;; -> ((METHOD POPULATE-PROPOSAL (PROPOSAL)))
;;;;;
;;;;; (calls-who method-spec) -> generic-functions & functions
;;;;; (xref:get-relation :calls '(METHOD SAVE-PLAN (LRP)) :wild)
;;;;; (LIST SETQ LRP-NAME-VALID-P NOT DIAGNOSTIC CONS WRITE-PLAN-TO-MEDIUM
;;;;;	    GET-SCHEDULER SAVE-PLAN-ERROR-HANDLER PLAN-IN-CATALOG-P
;;;;;	    PLAN-WINDOW-DESCRIPTIONS CAR NULL SET-STATUS CDR)
;;;;;
;;;;; (calls-who generic-function) -> methods of the generic-function
;;;;; (xref:get-relation :calls 'SAVE-PLAN :wild)
;;;;; ((METHOD SAVE-PLAN (LRP)) (METHOD SAVE-PLAN (STRING))
;;;;;  (METHOD SAVE-PLAN :AFTER (T)))
;;;;;
;;;;; VPS> (calls-who 'load-proposals)
;;;;; ((METHOD LOAD-PROPOSALS (CONS)) (METHOD LOAD-PROPOSALS (NUMBER))
;;;;;  (METHOD LOAD-PROPOSALS ((EQL :ALL)))
;;;;;  (METHOD LOAD-PROPOSALS ((EQL :RANDOM)))
;;;;;  (METHOD LOAD-PROPOSALS :AROUND (T)) (METHOD LOAD-PROPOSALS (STRING))
;;;;;  (METHOD LOAD-PROPOSALS :BEFORE (T)))
;;;;; VPS> (calls-who ' (METHOD LOAD-PROPOSALS ((EQL :RANDOM))))
;;;;;	   (ATOM SETF CDDR < LIST - + NOT CONSP CDR EXCL::.PROGRAM-ERROR EQ CAR
;;;;;	    RPLACD EXCL::ERROR-FROM-CODE SYSTEM::INV-MEMREF MAKE-RANDOM-STATE
;;;;;	    COPY-LIST AVAILABLE-PROGRAM-IDS EXCL::<_2OP LENGTH EXCL::ASSERT-1
;;;;;	    RANDOM EXCL::-_2OP EXCL::+_2OP APPLY SYMBOL-FUNCTION SUBSEQ
;;;;;	    ALEXANDRIA.0.DEV:SHUFFLE LOAD-PROPOSALS)
;;;;; VPS>
;;;;; (calls-who function) -> functions called by the function
;;;;; (xref:get-relation :calls 'calc-path :wild)
;;;;; (NOT NULL WHOCALLS-TREE CALLSWHO-TREE CALL-PATH)
;;;;;
;;;;;
;;;;;;; re functions
;;;;;
;;;;; (who-calls 'treeout)
;;;;; (xref:get-relation :calls :wild 'treeout)
;;;;; (TREEOUT)
;;;;;
;;;;; (who-calls 'find-path)
;;;;; (xref:get-relation :calls :wild 'find-path)
;;;;; (CALL-PATHS)
;;;;;
;;;;; (who-calls 'found)
;;;;; (xref:get-relation :calls :wild 'found)
;;;;; ((:INTERNAL FIND-PATH 0) CALL-PATHS)
;;;;;
;;;;; (calls-who 'call-paths)
;;;;; (xref:get-relation :calls 'call-paths :wild)
;;;;; (LOOP EXCL::WITH-LOOP-LIST-COLLECTION-HEAD LIST
;;;;;	    EXCL::LOOP-REALLY-DESETQ MAPCAR 1+ + EXCL::LOOP-COLLECT-RPLACD
;;;;;	    SETF WHEN > PUSH SETQ CONS EXPAND NULL NREVERSE CDR CAR
;;;;;	    EXCL::+_2OP FOUND RPLACD NOT CONSP EXCL::ERROR-FROM-CODE
;;;;;	    SYSTEM::INV-MEMREF EXCL::>_2OP FIND-PATH)


;;; https://franz.com/support/documentation/current/doc/operators/xref/get-relation.htm
(defmacro who-calls (called-form)
  `(xref:get-relation :calls :wild ,called-form))

(defmacro calls-who (calling-form)
  `(xref:get-relation :calls ,calling-form :wild))




(defun calls-whox (generic-function)
  (let ((gfuns (calls-who generic-function))
        (methods (list)))
    (dolist (fun gfuns)
      (push (calls-who fun) methods))
    (filter (sort (remove-duplicates (apply #'append methods)) #'alpha-lessp))))








;;; an expansion is a list of paths, where each path is a function-spec
;;; followed by the specs of functions already visited to get to the fumction
;;;
;;; The horizon of an expansion is the leaves of the tree.
;;; Normally, those are atoms.
;;; We are carrying the entire path with up, so we need the car of the path.

;;; (expand-path '(save-plan))
;; path: a list of function-names
;;; returns
;;; (list (list <a-function-called-by-headof-path> path)
;;;	  (list <another-function-called-by-headof-path> path)
;;;	  ...)
;;; i.e. returns a list of paths, one for each function called by head
(defmethod expand-path ((path list))
  (let* ((head (parse-name (car path)))
         (callers (who-calls head))
         (expanded (mapcar #'(lambda (caller)
                               (cons caller path))
                           callers)))
    ;; what is this trying to do?
    ;;(remove head temp :key #'(lambda (x) (parse-name x)))
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
    ;; what is this trying to do?
    ;;(remove head temp :key #'(lambda (x) (parse-name x)))
    expanded))



;;; (expand '((save-plan)))
(defun expand2 (paths)
  ;; combine the lists of paths into a single list of all paths
  (apply #'append (mapcar #'expand-path2 paths)))













#||
(expand '((load-proposals)))
(expand (expand '((load-proposals))))
(expand (expand (expand '((load-proposals)))))

(expand '((save-plan)))
(expand (expand '((save-plan))))
(expand (expand (expand '((save-plan)))))

(expand `((read-observation-block-data-from-medium)))
(expand (expand '((read-observation-block-data-from-medium))))
(expand (expand (expand '((read-observation-block-data-from-medium)))))
(expand (expand (expand (expand '((read-observation-block-data-from-medium))))))

(expand `((preprocess-proposal-id-list)))
(expand (expand `((preprocess-proposal-id-list))))
(expand (expand (expand `((preprocess-proposal-id-list)))))
||#

(defun horizon-contains (horizon fn-spec)
  (find (parse-name fn-spec) horizon :key #'parse-name))


;;; not used
(defun find-path (fn-spec expansion)
  (find-if #'(lambda (path)
               (horizon-contains path fn-spec))
           expansion))



#||



(expand `((read-observation-block-data-from-medium)))
(expand (expand '((read-observation-block-data-from-medium))))
(expand (expand (expand '((read-observation-block-data-from-medium)))))
(expand (expand (expand (expand '((read-observation-block-data-from-medium))))))

||#


;;; work from end to start because who-calls returns methods,
;;;    and calls-who returns generic functions
(defun call-paths (from to &optional limit)
  "call paths from from to to"
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
        ;;(format t "~&path-list: ~s" path-list)
        (dolist (path path-list)
          ;;(format t "~&path: ~s" path)
          (when (equal (parse-name (car path)) from)
            (push path paths)))))
    paths))



(defun call-paths2 (from to &optional limit)
  "call paths from from to to"
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
        ;;(format t "~&path-list: ~s" path-list)
        (dolist (path path-list)
          ;;(format t "~&path: ~s" path)
          (when (equal (parse-name (car path)) from)
            (push path paths)))))
    paths))




#||
(path :from load-proposals :to read-observation-block-data-from-medium :limit 3)


(path :from load-proposals :to (method read-observation-block-data-from-medium (jwst-proposal)
(path :from load-proposals :to (method read-observation-block-data-from-medium (t)))))
(path :from load-proposals :to (method read-observation-block-data-from-medium (t)) :limit 3)


;;starts early
(path :from load-proposals :to (method read-observation-block-data-from-medium (t)) :limit 4)


||#


(defun call-path (from-fn to-fn &optional limit)
  (let ((paths (call-paths from-fn to-fn limit)))
    paths))

(defun call-path2 (from-fn to-fn &optional limit)
  (let ((paths (call-paths2 from-fn to-fn limit)))
    paths))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defparameter *ignored-fns* '(get-exclude-executions lookup-stored-query program-ids-from-query store-query process-diagnostic insert-format-arguments diagnostic get-diagnostic-class))

(defparameter *ignored-packages* '(excl multiprocessing system common-lisp sql dbi database))


(defmethod use ((x t))
  (let ((name (parse-name x)))
    (when (not (or (find name *ignored-fns*)
             (and (consp x) (eq (car x) 'setf))
             (find (intern (uiop/package:symbol-package-name name))
                   *ignored-packages*)))
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
       (eql (type-of (symbol-function sym)) 'standard-generic-function))


;;; generic-function name --> the generic-function's method fspecs
(defmethod method-specs (function)
  (format t "~%>> (method-specs '~s)~%" function)
  ;;(break)
  (let* ((function-name (parse-name function))
         (function (symbol-function function-name)))
    (if (eql (type-of function) 'standard-generic-function)
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
        #+nil
        (remove-duplicates
         (remove nil (apply #'append
                            (mapcar #'(lambda (m)
                                        (calls-who m))
                                    callee-function-names))))
        callee-function-names
        ))))

;;;; (CALLS-WHO '(SETF GET-PARAMETER-FILENAME))



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

(defun calc-path (&key to from limit)
  (cond ((and (null from) (null to)) nil)
        ((null from)
         (whocalls-tree to limit))
        ((null to)
         (callswho-tree from limit))
        ((and to from)
         (call-path from to limit))))

(defun calc-path2 (&key to from limit)
  (cond ((and (null from) (null to)) nil)
        ((null from)
         (whocalls-tree to limit))
        ((null to)
         (callswho-tree from limit))
        ((and to from)
         (call-path2 from to limit))))




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
                     (treeout x (1+ level)))1
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

(compile 'foo)
(compile 'bar)
(compile 'baz)

(path :from baz :to foo)
|#

#|
(path :from assign-best-window :to find-all-schedulable-orient-combos)
(path :from run-scheduling-step :to find-all-schedulable-orient-combos)
(path :from run-auto-lrp :to extract-plan)
|#



;;; takes a list of linear paths
;;; returns a list of trees
#+boo
(defun combine-paths (paths)
  (format t "~2&(combine-paths ~a)" paths)
  (when paths
    (let ( (starts (list))
           ;;(new (list))
           (start))

      (dolist (path paths)
        (unless (find :after (car path))
          (let ((start (car path))
                (start-paths (remove nil
                                     (mapcar (lambda (p)
                                               (when  (equalp (car p) start)
                                                 (cdr p)))
                                             paths))))
            (push start starts)
            (setf (cdr start) start-paths))
          ;;(push (cons start start-paths) new)
          ))
      starts)))

#+ft
(defun combine-paths (paths)
  (format t "~2&(combine-paths ~a)" paths)
  (when paths
    (let ((starts (list))
          (new (list)))


      (dolist (path paths)
        (unless (find :after (car path))
          (pushnew (car path) starts :test #'equalp)))
      ;;(format t "~&starts: ~s" starts)

      (dolist (start starts)
        ;;(format t "~&start: ~s" start)

        (let ((start-paths (remove nil
                                   (mapcar (lambda (p)
                                             (when  (equalp (car p) start)
                                               (cdr p)))
                                           paths))))
          ;;(format t "~&start-paths: ~s" start-paths)
          (push (cons start start-paths) new)


          ;;(format t "~&new: ~s" new)
          ))
      new)))
