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
                      (null (lexicon-prop 'friday :lemma))))))
      (format t "~&environment-test: ~:[FAILED <<<~;passed~]~%" ok)
      ok)))
