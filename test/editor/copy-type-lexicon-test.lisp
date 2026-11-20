(in-package :conceptual-graphs)

;;; The type browser's Copy offers to teach the parser the new word, as one
;;; like the original's: (jlike banana apple), appended to the lexicon.dict
;;; beside the type set. cgraph does not depend on the parser, so the file is
;;; text to it, and the parser is asked about a word only when it is loaded.
;;;
;;; Runs in a fresh environment on a temporary copy of the test types, so no
;;; real type set's files are touched.

(defun copy-type-lexicon-test (&optional verbose)
  (let* ((ok t)
         (dir (uiop:ensure-directory-pathname
               (merge-pathnames (format nil "cgraph-copy-lexicon-~d/" (get-universal-time))
                                (uiop:temporary-directory)))))
    (flet ((check (label pass)
             (setf ok (and ok (and pass t)))
             (when (or verbose (not pass))
               (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))
      (ensure-directories-exist dir)
      (unwind-protect
           (progn
             (dolist (name '("concept-types.lisp" "relation-types.lisp"))
               (uiop:copy-file (merge-pathnames name (asdf:system-relative-pathname
                                                      :cgraph "test/test-types/"))
                               (merge-pathnames name dir)))
             (with-environment ((make-environment :types (namestring dir)))
               (let ((file (type-set-lexicon-file)))
                 (check "the lexicon is the file beside the type set"
                        ;; truenames: macOS's temporary directory is a symlink
                        (equal (namestring (merge-pathnames "lexicon.dict" (truename dir)))
                               (namestring file)))
                 (check "a word the file does not define is not known from it"
                        (not (lexicon-file-defines-p "apple" file)))

                 (check "the first entry creates the file and returns its line"
                        (equal "(jlike banana apple)" (append-lexicon-like 'banana 'apple)))
                 (check "the file now defines the word"
                        (lexicon-file-defines-p "banana" file))
                 (check "and the line says where it came from"
                        (search "(jlike banana apple)   ; like apple"
                                (uiop:read-file-string file)))
                 (check "a later entry is appended, not replacing it"
                        (and (append-lexicon-like 'bag 'box)
                             (lexicon-file-defines-p "banana" file)
                             (lexicon-file-defines-p "bag" file)))
                 (check "a word already in the file is refused"
                        (handler-case (progn (append-lexicon-like 'banana 'pear) nil)
                          (error () t)))
                 (check "a word the file defines is known"
                        (eq :known (lexicon-word-status "banana")))
                 ;; With no parser loaded nothing can say a word is missing;
                 ;; with one loaded it answers for itself.
                 (check "a word nothing here can check is :unknown, or the parser's answer"
                        (member (lexicon-word-status "qwzx")
                                (if (find-package :parsifal) '(:missing) '(:unknown)))))))
        (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore)))
    (when verbose
      (format t "~&copy-type-lexicon-test: ~:[FAILED <<<~;passed~]~%" ok))
    ok))
