(in-package :conceptual-graphs)



(defmethod vartest ((graph-string string) &optional verbose)
  ;; (reset-cgraph)
  (initialize-variables)
  (clear-id-cache)
  (setf *include-node-ref* nil)

  (let* ((graph (parse-cgraph graph-string))
         (var-specs (variables-status))
         ;; (zz (mapcar (lambda (spec)
         ;;               (format t "~&~s:  ~a" (car spec) (node-ref (car spec))))
         ;;             var-specs))
         (canonicalized-graph-string (canonicalize-graph-string graph-string))
         (formated-graph (canonicalize-graph-string (format-cgraph graph)))
         (match (graph-strings-equal graph-string formated-graph)))
    ;;(setq *gs graph-string *fg formated-graph)

    (when verbose
      (format t "~&_______")
      (format t "~&source:~&~s" (canonicalize-graph-string graph-string))
      (format t "~%formatted:~&~s~%" formated-graph)
      ;;(format t "~&match: ~s~%"  match)
      ;; (when var-specs
      ;;   (print (variables-report)))
      ;;(print var-specs
      (format t "variables: ~a" var-specs)
      (format t "~&~:[*** fail *****~;>>> pass~]~%" match))
    match))

(defmethod vartest ((test-number number) &optional verbose)
  (destructuring-bind (graph graph-string)
      (make-test-graph test-number)
    (when verbose
      (format t "~3%>>> Test ~d~&" test-number)
      (format t "~%~a~2%" graph-string))
    (vartest graph-string verbose)))


(defun variable-test (&optional verbose)
  (with-test-types
    (let ((*print-pretty* nil)
          (*concise* nil)
          (*include-node-ref* nil)
          (result t)
          (num-tests 10))
      (when verbose
        (format t "~%VARIABLE-TEST~%"))
      (dotimes (test-num num-tests)
        (let ((pass (vartest test-num verbose)))
          (setf result (and result pass))))
      (and (printing-keeps-variables-test verbose) result))))

;;; Printing a graph leaves its labels alone. The formatter used to record the
;;; labels it decides to show in the table that holds the ones a graph was read
;;; with, unsetting a *x it didn't need for display -- see *VARIABLE-OVERLAY*
;;; in variable.lisp and notes/known-issues.md.
(defun printing-keeps-variables-test (&optional verbose)
  (let ((ok t)
        (*allow-dynamic-individual-creation* t))
    (flet ((check (name result)
             (setf ok (and ok (and result t)))
             (when (or verbose (not result))
               (format t "~&  ~:[fail~;pass~] ~a~%" result name)))
           (person-variables (nodes)
             (mapcar #'node-variable
                     (remove-if-not (lambda (n)
                                      (and (concept-p n)
                                           (string-equal (label (concept-type n)) "PERSON")))
                                    nodes))))
      (let ((nodes (parse-cgraph
                    "[EAT]- (agnt)→[PERSON: *x] (obj)→[FOOD] (rcpt)→[PERSON: ?x].")))
        (format-cgraph nodes)
        (check "a *x is still there after the graph is printed"
               (equal (person-variables nodes) '(x nil))))
      (let ((nodes (parse-cgraph "[GIVE: *z]- (agnt)→[BOY] (rcpt)→[GIRL].")))
        (format-cgraph nodes)
        (check "printing doesn't leave labels of its own behind"
               (equal (mapcar #'node-variable (remove-if-not #'concept-p nodes))
                      '(z nil nil))))
      ;; The query that takes a pattern already parsed reads the variables
      ;; from the table as it finds it. A pattern shown to someone before it
      ;; is run must still bind them.
      (let ((*context* (make-context nil)))
        (make-cgraph "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
        (let ((pattern (car (parse-cgraph "[EAT]→(agnt)→[ANIMAL: *a]"))))
          (format-cgraph pattern)
          (let ((results (query pattern *context*)))
            (check "a pattern printed before it is run still binds its variables"
                   (and results
                        (assoc 'a (getf (first results) :bindings)
                               :test #'string-equal)))))))
    ok))
