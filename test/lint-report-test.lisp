(in-package :conceptual-graphs)

;;; Tests for REPORT-LEXICON-LINT's severity handling.
;;;
;;; Two ranking functions, deliberately different:
;;;
;;;   %SEVERITY-RANK  strict -- ranks a caller-supplied MIN-SEVERITY, and
;;;                   signals on anything that isn't a real severity. It used
;;;                   to fall through to a (t 3) catch-all, so passing an
;;;                   unrecognized keyword produced a filter that matched
;;;                   everything while looking like it had filtered.
;;;
;;;   %FINDING-RANK   lenient -- ranks a finding whose severity came from a
;;;                   user-editable table. A typo there should not take down
;;;                   the report, and should not hide the finding either, so
;;;                   an unrecognized severity ranks above :ERROR: it sorts
;;;                   first and survives every filter.

(defun %report-to-string (&rest args)
  "REPORT-LEXICON-LINT's printed output, as a string."
  (let ((out (make-string-output-stream)))
    (apply #'report-lexicon-lint :stream out args)
    (get-output-stream-string out)))

(defun %signals-p (thunk)
  "T if calling THUNK signals an ERROR, plus the report text."
  (handler-case (progn (funcall thunk) (values nil nil))
    (error (e) (values t (princ-to-string e)))))

(defun lint-report-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; --- %SEVERITY-RANK is strict ---------------------------------------

        (check "the three severities rank in order"
               (equal '(0 1 2) (mapcar #'%severity-rank '(:error :warn :info))))
        (check "*lint-severities* and the ranks agree"
               (equal *lint-severities*
                      (sort (copy-list *lint-severities*) #'< :key #'%severity-rank)))

        ;; The exact mistake this fixes: a startup-option name is not a
        ;; severity, and used to disable the filter instead of complaining.
        (multiple-value-bind (signalled text) (%signals-p
                                               (lambda () (%severity-rank :errors-warnings)))
          (check "a startup-option name signals rather than ranking"
                 signalled)
          (check "the error names the valid severities"
                 (and text (search ":ERROR" text) (search ":INFO" text)))
          (check "the error points at the option vocabulary"
                 (and text (search ":ERRORS-WARNINGS" text))))

        (check "nil signals"
               (%signals-p (lambda () (%severity-rank nil))))
        (check "an arbitrary keyword signals"
               (%signals-p (lambda () (%severity-rank :loud))))
        (check "a non-keyword signals"
               (%signals-p (lambda () (%severity-rank "error"))))

        ;; --- %FINDING-RANK is lenient, in the visible direction -------------

        (check "known finding severities rank like %severity-rank"
               (equal '(0 1 2)
                      (mapcar (lambda (s) (%finding-rank (list s :check "msg" nil)))
                              '(:error :warn :info))))
        (check "an unknown finding severity outranks :error"
               (< (%finding-rank '(:bogus :check "msg" nil))
                  (%finding-rank '(:error  :check "msg" nil))))
        (check "an unknown finding severity survives the strictest filter"
               (<= (%finding-rank '(:bogus :check "msg" nil))
                   (%severity-rank :error)))
        (check "ranking a malformed finding doesn't signal"
               (not (%signals-p (lambda () (%finding-rank '(nil nil nil nil))))))

        ;; --- REPORT-LEXICON-LINT -------------------------------------------

        (multiple-value-bind (signalled text)
            (%signals-p (lambda () (%report-to-string :min-severity :errors-warnings)))
          (check "report signals on a bad min-severity"
                 signalled)
          (check "report's error is the severity error"
                 (and text (search ":ERRORS-WARNINGS" text))))

        (check "report accepts each real severity"
               (every (lambda (s)
                        (not (%signals-p (lambda () (%report-to-string :min-severity s)))))
                      '(:error :warn :info)))

        ;; Filtering still works, which is what the old catch-all defeated.
        (let ((at-info (%report-to-string :min-severity :info))
              (at-error (%report-to-string :min-severity :error)))
          (check "the :info report is at least as long as the :error report"
                 (>= (length at-info) (length at-error)))
          (check ":error filtering drops the info tier"
                 (not (search "INFO" at-error)))
          (check "the default is :info"
                 (string= at-info (%report-to-string))))

        ;; The startup path must keep passing real severities -- that mapping
        ;; is what stands between the option names and the strict rank.
        (check "every startup option maps to a rankable severity"
               (every (lambda (option)
                        (let ((sev (case option
                                     (:errors-only     :error)
                                     (:errors-warnings :warn)
                                     (otherwise        :info))))
                          (integerp (%severity-rank sev))))
                      '(:errors-only :errors-warnings :all t nil))))

      (when verbose
        (format t "~&lint-report-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))
