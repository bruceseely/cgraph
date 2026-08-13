
(in-package :conceptual-graphs)

;;; not tested
;;; cg-processing formation-rules graph-every operations process

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
         (text (format nil "~a ~a ~a~a" sep1 name sep2 sep3))
         (missing (not (fboundp name)))
         (pass (and (not missing)
                    (ignore-errors
                     (let ((*standard-output* sb-impl::*null-broadcast-stream*))
                       (funcall name))))))

    (when (or verbose (not pass))
      (format t "~&~a ~a~%" (subseq text 0 28)
              (cond (missing "UNDEFINED <<<")
                    (pass    "passed")
                    (t       "failed <<<"))))
    pass))

(defun test-all (&optional verbose)
  ;;(untrace)
  (let ((results t)
        (*allow-dynamic-individual-creation* t)
        (test-names '(type-test
                      segment-test
                      variable-test
                      individual-test
                      referent-test
                      graph-referent-test
                      concept-test
                      format-test
                      cache-test
                      linkup-test
                      parse-test
                      formation-rules-test
                      combine-test
                      projection-test
                      maximal-join-test
                      coreference-test
                      negative-context-test
                      graph-every-test
                      type-definition-test
                      query-test
                      ;; The lint suites. All four are built by cgraph.asd and
                      ;; none of them were run: the list named
                      ;; POS-ROOTS-LINT-TEST, which does not exist, and nothing
                      ;; else. GENERATION-ROOTS-LINT-TEST is the one that name
                      ;; was reaching for.
                      generation-roots-lint-test
                      relation-tables-lint-test
                      morphology-tables-lint-test
                      lint-report-test)))
    (dolist (test-name test-names)
      ;;(format t "~&test-name: ~s~%"  test-name)
      (let ((result (test-one test-name verbose)))
        (setf results (and results result))))
    results))
