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
  (let ((*print-pretty* nil)
        (*concise* nil)
        (*include-node-ref* nil)
        (result t)
        (num-tests 10))


    (load-test-types)

    (when verbose
      (format t "~%VARIABLE-TEST~%"))

    (dotimes (test-num num-tests)
      (let ((pass (vartest test-num verbose)))
        (setf result (and result pass))))

    result))
