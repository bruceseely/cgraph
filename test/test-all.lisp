
(in-package :conceptual-graphs)

;;; not tested
;;; cg-processing formation-rules graph-every operations process

(defun test-one (name &optional verbose)
  (let* ((sep1 "-=-")
         (sep2 (if (oddp (length (princ-to-string name))) "" "="))
         (sep3 "-=-=-=-=-=-=-=-=-=-=-=-=-=-=")
         (text (format nil "~a ~a ~a~a" sep1 name sep2 sep3))
         (pass (ignore-errors
                (let ((*standard-output* sb-impl::*null-broadcast-stream*))
                  (funcall name)))))

    (when (or verbose (not pass))
      (format t "~&~a" (subseq text 0 28))
      (format t " ~:[failed <<<~;passed~]~%" pass))
    pass))

(defun test-all (&optional verbose)
  ;;(untrace)
  (let ((results t)
        (test-names '(type-test
                      segment-test
                      variable-test
                      individual-test
                      referent-test
                      concept-test
                      format-test
                      cache-test
                      linkup-test
                      parse-test
                      formation-rules-test
                      combine-test
                      graph-every-test)))
    (dolist (test-name test-names)
      (let ((result (test-one test-name verbose)))
        (setf results (and results result))))
    results))
