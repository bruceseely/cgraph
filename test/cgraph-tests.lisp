
(in-package :conceptual-graphs)

(defun extract-test-names ()
  (let* ((cgraph-directory (asdf:system-source-directory "cgraph"))
         (test-directory (format nil "~atest/" cgraph-directory))
         (files (directory-files test-directory))
         (file-names (mapcar #'pathname-name files))
         (test-mames (remove-if-not (lambda (f) (string-suffix-p f "-test")) file-names)))
    test-mames))

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
           (initialize-types :external-types-directory test-types-directory)
           (when verbose
             (print-concept-types)))))
  t)

(defmacro with-test-types (&body body)
  "Evaluate BODY with the test type catalog loaded. On exit (including
   non-local exit) restore whichever catalog was loaded on entry, using
   *loaded-types-source* to identify it. NIL prior states stay as the
   test catalog (nothing meaningful to restore); :default re-establishes
   the copied example-types fallback; an external-directory string is
   re-linked and reloaded."
  (let ((prior (gensym "PRIOR-TYPES-SOURCE-")))
    `(let ((,prior *loaded-types-source*))
       (load-test-types)
       (unwind-protect (progn ,@body)
         (cond ((or (null ,prior)
                    (equal ,prior *loaded-types-source*))
                nil)
               ((eq ,prior :default)
                (delete-type-files)
                (clear-cgraph-type-catalogs)
                (initialize-types :external-types-directory nil))
               (t
                (initialize-types :external-types-directory ,prior)))))))



(defvar *max-test-name-len* 0)

;; (defmethod test-one ((name string) &optional verbose)
;;   (let* ((sep1 "-=-")
;;          (sep2 (if (oddp (length name)) "" "="))
;;          (sep3 (subseq "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" 0 *max-test-name-len*))
;;          (text (format nil "~a ~a ~a~a" sep1 name sep2 sep3))
;;          (pass (ignore-errors
;;                 (let ((*standard-output* sb-impl::*null-broadcast-stream*))
;;                   (funcall (intern (string-upcase name))))))
;;          )

;;     (when (or verbose (not pass))
;;       (format t "~&~a" (subseq text 0 (+ *max-test-name-len* 8)))
;;       (format t " ~:[failed <<<~;passed~]~%" pass))
;;     pass))

(defmethod test-one ((name string) &optional verbose)
  (let* ((sep1 "-=-")
         (sep2 (if (oddp (length name)) "" "="))
         (sep3 (subseq "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" 0 *max-test-name-len*))
         (text (format nil "~a ~a ~a~a" sep1 name sep2 sep3))
         (pass (ignore-errors
                (let ((*standard-output* sb-impl::*null-broadcast-stream*))
                  (funcall (intern (string-upcase name)))))))
    (when (or verbose (not pass))
      (format t "~&~a ~:[failed <<<~;passed~]~%"
              (subseq text 0 (+ *max-test-name-len* 8))
              pass))
    (finish-output)
    pass))

;; (defun test-one (name &optional verbose)
;;   (let* ((sep1 "-=-")
;;          (sep2 (if (oddp (length (princ-to-string name))) "" "="))
;;          (sep3 "-=-=-=-=-=-=-=-=-=-=-=-=-=-=")
;;          (text   (format nil "~a ~a ~a~a" sep1 name sep2 sep3))
;;          (prefix (subseq text 0 28))
;;          (sentinel (format nil "<<RUN-~A>>" name))) ; unique per test
;;     (format t "~&~A ~A" prefix sentinel)
;;     (finish-output)
;;     (let ((pass (ignore-errors
;;                  (let ((*standard-output* sb-impl::*null-broadcast-stream*))
;;                    (funcall name)))))
;;       (when (and (find-package :swank)
;;                  (fboundp (find-symbol "EVAL-IN-EMACS" :swank)))
;;         (funcall (find-symbol "EVAL-IN-EMACS" :swank)
;;                  `(with-current-buffer (slime-output-buffer)
;;                     (save-excursion
;;                      (goto-char (point-max))
;;                      (when (search-backward ,sentinel nil t)
;;                        (replace-match ,(if pass "passed" "failed <<<")
;;                                       t t))))))
;;       (terpri)
;;       pass)))





(defun test-all (&optional verbose)
  (let* ((results t)
         (*allow-dynamic-individual-creation* t)
         (test-name-strings (extract-test-names))
         (*max-test-name-len* (apply #'max (mapcar #'length test-name-strings))))
    (dolist (test-name test-name-strings)
      ;;(format t "~&test-name: ~s~%"  test-name)
      (let ((result (test-one test-name verbose)))
        (setf results (and results result))))
    results))

(defun test-cgraph (&optional verbose)
  (with-test-types
    (test-all verbose)))
