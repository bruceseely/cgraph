;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;; Tests for a DOMAIN's own generation overrides -- the lexicon-overrides.lisp
;;; a catalog may ship beside its type files (LOAD-DOMAIN-LEXICON-OVERRIDES,
;;; called by INITIALIZE-TYPES through *DOMAIN-LEXICON-LOADER*).
;;;
;;; The point of the file is that a domain that defines BALTIMORE as a subtype
;;; of CITY is also the thing that knows BALTIMORE is a proper noun -- said
;;; without an article -- and cgraph's own lexicon.lisp is the wrong place to
;;; write that down. These tests pin the four properties that make the file
;;; safe to rely on:
;;;
;;;   1. absence is legal -- a domain with no such file loads silently;
;;;   2. an entry reaches GENERATION, not just the registry: [CITY] with
;;;      :proper-p stops being "A city.";
;;;   3. mounting another domain REWINDS -- one domain's English cannot leak
;;;      into the next, and an entry that displaced one of cgraph's shipped
;;;      registrations gives it back rather than deleting it;
;;;   4. a malformed form costs only itself -- warned, skipped, rest of the
;;;      file still loaded.

(defun %temp-domain-directory (&optional text)
  "A fresh empty directory, holding a lexicon-overrides.lisp of TEXT when TEXT
   is supplied. The caller deletes it."
  (let ((dir (ensure-directories-exist
              (merge-pathnames (format nil "cgraph-domain-lexicon-~a/" (gensym))
                               (uiop:temporary-directory)))))
    (when text
      (with-open-file (stream (merge-pathnames *domain-lexicon-file-name* dir)
                              :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create)
        (write-string text stream)))
    dir))

(defun %count-warnings (thunk)
  "Call THUNK, muffling warnings; return (values result warning-count)."
  (let ((n 0))
    (let ((result (handler-bind ((warning (lambda (c) (incf n) (muffle-warning c))))
                    (funcall thunk))))
      (values result n))))

(defun domain-lexicon-test (&optional verbose)
  (with-test-types
    ;; a context to build the sample graphs in (GRAPH-TO-TEXT reads real graphs)
    (reset-cgraph)
    (let ((ok t)
          (dirs '()))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label)))
             (temp-dir (&optional text)
               (let ((d (%temp-domain-directory text)))
                 (push d dirs)
                 d)))
        (unwind-protect
             (progn
               ;; Baseline: CITY is an ordinary count noun in the test catalog.
               (clear-domain-lexicon-overrides)
               (check "baseline [CITY] -> \"A city.\""
                      (string= "A city." (graph-to-text (make-cgraph "[CITY]"))))

               ;; 1. A domain that ships no override file.
               (let ((none (temp-dir)))
                 (check "no file -> NIL, and nothing recorded"
                        (and (null (load-domain-lexicon-overrides none))
                             (null *domain-lexicon-file*)))
                 (check "no file -> catalog English unchanged"
                        (string= "A city." (graph-to-text (make-cgraph "[CITY]")))))

               ;; 2. An entry reaches the generator.
               (let ((one (temp-dir "(:label city :proper-p t)")))
                 (check "file loaded -> path returned and recorded"
                        (and (load-domain-lexicon-overrides one)
                             *domain-lexicon-file*))
                 (check ":proper-p registered"
                        (eq t (lexicon-prop 'city :proper-p)))
                 (check "[CITY] -> \"City.\" (no article, capitalized)"
                        (string= "City." (graph-to-text (make-cgraph "[CITY]")))))

               ;; 3. Mounting another domain rewinds this one -- including a
               ;;    shipped registration this domain had displaced. FRIDAY is
               ;;    cgraph's own (:proper-p t :time-prep "on").
               (let ((two   (temp-dir "(:label city :proper-p t)
                                       (:label friday :lemma \"FRI\")"))
                     (empty (temp-dir)))
                 (load-domain-lexicon-overrides two)
                 (check "domain entry displaces a shipped one"
                        (and (string= "FRI" (lexicon-prop 'friday :lemma))
                             (null (lexicon-prop 'friday :time-prep))))
                 (load-domain-lexicon-overrides empty)
                 (check "rewind drops the domain's own entry"
                        (null (lexicon-prop 'city :proper-p)))
                 (check "rewind restores the shipped entry whole"
                        (and (null (lexicon-prop 'friday :lemma))
                             (eq t (lexicon-prop 'friday :proper-p))
                             (string= "on" (lexicon-prop 'friday :time-prep))))
                 (check "rewind restores the English too"
                        (string= "A city." (graph-to-text (make-cgraph "[CITY]")))))

               ;; 4. One bad form costs only itself.
               (let ((mixed (temp-dir "(:proper-p t)
                                       (:label city :proper-p t)")))
                 (multiple-value-bind (result warnings)
                     (%count-warnings (lambda () (load-domain-lexicon-overrides mixed)))
                   (check "malformed form warns" (= 1 warnings))
                   (check "file still loads" (and result t))
                   (check "the good entry still registered"
                          (eq t (lexicon-prop 'city :proper-p)))))

               (clear-domain-lexicon-overrides)
               (check "cleared at the end"
                      (and (null (lexicon-prop 'city :proper-p))
                           (null *domain-lexicon-file*))))

          (clear-domain-lexicon-overrides)
          (dolist (d dirs)
            (ignore-errors (uiop:delete-directory-tree d :validate t)))))
      (format t "~&domain-lexicon-test: ~:[FAILED <<<~;passed~]~%" ok)
      ok)))
