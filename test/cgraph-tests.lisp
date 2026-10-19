
(in-package :conceptual-graphs)

(defun load-test-types (&optional verbose)
  "Load the test type hierarchy from test/test-types/. Idempotent: returns
   immediately when the catalog is already the test catalog, so individual
   test files can call this at the top without churning a previously loaded
   user catalog or paying the unload/reload cost on every call."
  (let* ((cgraph-directory (asdf:system-source-directory "cgraph"))
         (test-directory (format nil "~atest/" cgraph-directory))
         (test-types-directory (format nil "~atest-types/" test-directory)))
    (cond ((equal *loaded-types-source* test-types-directory)
           (when verbose
             (format t "~&Test types already loaded from ~a~%"
                     test-types-directory)))
          (t
           (unload-cgraph-types)
           (initialize-types :directory test-types-directory)
           (when verbose
             (print-concept-types)))))
  t)

(defmacro with-test-types (&body body)
  "Evaluate BODY with the test type catalog loaded. On exit (including
   non-local exit) restore whichever catalog was loaded on entry, using
   *loaded-types-source* to identify it. A NIL prior state stays as the
   test catalog (nothing meaningful to restore); otherwise the prior type set
   is made current and reloaded. Both are reads: nothing on disk changes."
  (let ((prior (gensym "PRIOR-TYPES-SOURCE-")))
    `(let ((,prior *loaded-types-source*))
       (load-test-types)
       (unwind-protect (progn ,@body)
         (unless (or (null ,prior)
                     (equal ,prior *loaded-types-source*))
           (initialize-types :directory ,prior))))))



;;; --- Running the suites ------------------------------------------------------
;;;
;;; (asdf:test-system :cgraph) runs TEST-ALL through the cgraph/tests system;
;;; (cg::test-all t) does the same in a loaded image, from any package.

(defparameter *test-suites*
  '(set-operations-test
    type-test
    segment-test
    variable-test
    individual-test
    referent-test
    graph-referent-test
    concept-test
    make-concept-plist-test
    package-independence-test
    format-test
    normalize-test
    cache-test
    concept-cache-index-test
    linkup-test
    parse-test
    parse-error-test
    formation-rules-test
    combine-test
    projection-test
    maximal-join-test
    coreference-test
    negative-context-test
    graph-every-test
    type-definition-test
    query-test
    graph-equality-test
    decomposition-test
    relation-hierarchy-test
    relation-join-test
    ;; A domain's own generation overrides (the lexicon-overrides.lisp beside
    ;; its type files).
    domain-lexicon-test
    ;; Graph -> English.
    generation-test
    ;; The lint suites.
    generation-roots-lint-test
    relation-tables-lint-test
    morphology-tables-lint-test
    lint-report-test)
  "The suites TEST-ALL runs, in order. Some files hold more than one suite, so
   this is a list rather than a directory listing -- but a list can be left
   behind when a file is added, so TEST-ALL also fails when a test/*-test.lisp
   file's own suite is missing from it (see UNLISTED-TEST-SUITES).")

(defun unlisted-test-suites ()
  "Names of test/*-test.lisp files whose same-named suite isn't in *TEST-SUITES*."
  (let ((test-directory (merge-pathnames "test/" (asdf:system-source-directory "cgraph"))))
    (loop for file in (directory-files test-directory "*-test.lisp")
          for name = (intern (string-upcase (pathname-name file)) :cg)
          unless (member name *test-suites*)
            collect name)))

(defun test-one (name &optional verbose)
  "Run the test function NAME, reporting pass, failure, or that it does not
   exist.

   A name nothing defines is reported as UNDEFINED rather than as a failure.
   The IGNORE-ERRORS below turns any error into NIL, which made a misspelled
   or renamed test indistinguishable from one that ran and failed -- and that
   is exactly what happened: the list carried POS-ROOTS-LINT-TEST, which was
   never a function, and the suite reported it as a failing test for as long
   as it was there."
  (let* ((sep1 "-=-")
         (sep2 (if (oddp (length (princ-to-string name))) "" "="))
         (sep3 "-=-=-=-=-=-=-=-=-=-=-=-=-=-=")
         (text (format nil "~a ~(~a~) ~a~a" sep1 name sep2 sep3))
         (missing (not (fboundp name)))
         (pass (and (not missing)
                    (ignore-errors
                     (let ((*standard-output* (make-broadcast-stream)))
                       ;; Each test starts from a clean individual registry.
                       ;; Ids come from one counter for the whole image, so a
                       ;; test that mints individuals moves every id the next
                       ;; test would be given -- and several tests name
                       ;; individuals by id. Without this the suite passes
                       ;; because of the order it happens to be written in.
                       (initialize-individuals)
                       (funcall name))))))
    (when (or verbose (not pass))
      (format t "~&~a ~a~%" (subseq text 0 30)
              (cond (missing "UNDEFINED <<<")
                    (pass    "passed")
                    (t       "failed <<<"))))
    (finish-output)
    pass))

(defun test-all (&optional verbose)
  "Run every suite in *TEST-SUITES*; true iff all pass and none is unlisted."
  (let ((results t)
        (*allow-dynamic-individual-creation* t))
    (dolist (name *test-suites*)
      (setf results (and (test-one name verbose) results)))
    (dolist (name (unlisted-test-suites))
      (format t "~&-=- ~(~a~) is in test/ but not in *TEST-SUITES* <<<~%" name)
      (setf results nil))
    results))

(defun test-cgraph (&optional verbose)
  (with-test-types
    (test-all verbose)))
