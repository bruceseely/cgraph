;;; -*- Mode: LISP; Syntax: Common-lisp; Base: 10; Lowercase: Yes -*-

(in-package :conceptual-graphs)

;;; Tests for the environment (system/setup/environment.lisp): ENV-LET, and the
;;; lexicon's layers -- cgraph's built-in entries, then the domain file, then
;;; REPL registrations, rebuilt per environment whenever its types load.

(defun environment-test (&optional verbose)
  (with-test-types
    (let ((ok t)
          ;; test/ holds no lexicon-overrides.lisp: a domain that ships none
          (no-domain-file (asdf:system-relative-pathname "cgraph" "test/")))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; --- ENV-LET ------------------------------------------------------
        (let ((outer *coref-labels*)
              (temp  (make-hash-table :test 'equal)))
          (env-let ((*coref-labels* temp))
            (check "env-let sets the slot inside its body"
                   (eq temp (env-coref-labels *environment*))))
          (check "and puts it back after"
                 (eq outer *coref-labels*))
          (catch 'out
            (env-let ((*coref-labels* temp))
              (throw 'out nil)))
          (check "and after a non-local exit"
                 (eq outer *coref-labels*))
          (let ((before *node-ref-counter*))
            (env-let ((*coref-labels* temp))
              (get-node-ref))
            (check "other changes made inside are kept (the node counter)"
                   (= (1+ before) *node-ref-counter*)))
          (check "a plain variable is LET-bound beside an environment slot"
                 (equal '(1 t)
                        (env-let ((x 1) (*coref-labels* temp))
                          (list x (eq temp *coref-labels*)))))
          (check "values are computed before any slot is set"
                 (eq outer (env-let ((*coref-labels* temp)
                                     (seen *coref-labels*))
                             seen))))

        ;; --- lexicon layers -----------------------------------------------
        (unwind-protect
             (progn
               (register-lexicon-entry 'test-env-word :lemma "zz")
               (check "a REPL registration applies at once"
                      (equal "zz" (lexicon-prop 'test-env-word :lemma)))
               (mount-domain-lexicon no-domain-file)
               (check "and lasts until the types are next loaded"
                      (null (lexicon-prop 'test-env-word :lemma)))
               (check "which keeps cgraph's built-in entries"
                      (equal "on" (lexicon-prop 'friday :time-prep))))
          (mount-domain-lexicon (domain-types-directory)))

        ;; --- a second environment -----------------------------------------
        (let ((outer-cache *node-cache*)
              (outer-lexicon *lexicon-overrides*))
          (let ((*environment* (make-environment)))
            (check "a fresh environment has its own node cache"
                   (not (eq outer-cache *node-cache*)))
            (check "and an empty lexicon until its types load"
                   (null (lexicon-prop 'friday :time-prep)))
            (mount-domain-lexicon no-domain-file)
            (check "loading gives it the built-in entries"
                   (equal "on" (lexicon-prop 'friday :time-prep)))
            (register-lexicon-entry 'friday :lemma "FRI")
            (check "a registration there applies there"
                   (equal "FRI" (lexicon-prop 'friday :lemma))))
          (check "and the first environment's lexicon is untouched"
                 (and (eq outer-lexicon *lexicon-overrides*)
                      (null (lexicon-prop 'friday :lemma)))))

        ;; --- two knowledge bases ------------------------------------------
        ;; ANGEL is only in the test catalog, CHEVY only in the shipped one.
        (let* ((test-dir      (asdf:system-relative-pathname "cgraph" "test/test-types/"))
               (outer-source  *loaded-types-source*)
               (outer-context *context*)
               (a (make-environment :types test-dir))
               (b (make-environment :types :default)))
          (flet ((in-a (thunk) (with-environment (a) (funcall thunk)))
                 (in-b (thunk) (with-environment (b) (funcall thunk))))
            (check "make-environment :types loads that type set"
                   (in-a (lambda () (concept-type-defined-p 'angel))))
            (check "and the other environment has its own"
                   (in-b (lambda () (and (concept-type-defined-p 'chevy)
                                         (not (concept-type-defined-p 'angel))))))
            (check "neither sees the other's types"
                   (not (in-a (lambda () (concept-type-defined-p 'chevy)))))
            (check "even a type both have is two objects"
                   (not (eq (in-a (lambda () (get-concept-type 'entity)))
                            (in-b (lambda () (get-concept-type 'entity))))))
            (check "each has its own root context, bound by with-environment"
                   (let ((ca (in-a (lambda () *context*)))
                         (cb (in-b (lambda () *context*))))
                     (and ca cb (not (eq ca cb))
                          (not (eq ca outer-context)) (not (eq cb outer-context)))))
            (let ((b-nodes (in-b (lambda () (hash-table-count *node-cache*)))))
              (in-a (lambda () (make-cgraph "[ANGEL]")))
              (check "a graph made in one is kept in its context"
                     (= 1 (in-a (lambda () (length (graphs *context*))))))
              (check "and not in the other's"
                     (zerop (in-b (lambda () (length (graphs *context*))))))
              (check "nor are its nodes in the other's cache"
                     (= b-nodes (in-b (lambda () (hash-table-count *node-cache*))))))
            (check "a type the environment lacks is refused there"
                   (in-b (lambda ()
                           (handler-case (progn (parse-cgraph "[ANGEL]") nil)
                             (error () t)))))
            (check "each remembers its own type set"
                   (and (equal (namestring test-dir)
                               (namestring (in-a (lambda () *cgraph-types-directory*))))
                        (equal (namestring (default-types-directory))
                               (namestring (in-b (lambda () *cgraph-types-directory*))))))
            (check "so reloading one after loading the other reloads its own"
                   (in-a (lambda ()
                           (let ((*package* (find-package :conceptual-graphs)))
                             (initialize-types))
                           (and (concept-type-defined-p 'angel)
                                (not (concept-type-defined-p 'chevy))))))
            (check "and the environment the test began in is untouched"
                   (and (equal outer-source *loaded-types-source*)
                        (eq outer-context *context*))))))
      (format t "~&environment-test: ~:[FAILED <<<~;passed~]~%" ok)
      ok)))
