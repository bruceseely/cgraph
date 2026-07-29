(in-package :conceptual-graphs)

;;; Tests for the lexicon-override-key and string-keyed-table lint checks.
;;;
;;; These tables differ in kind from the type- and relation-keyed ones: they
;;; are looked up by surface lemma, independently of the lattice, so they hold
;;; general English data rather than bindings to an ontology. That is why there
;;; is no staleness check for them -- a row for a word your catalog never
;;; mentions is normal. What can go wrong is internal:
;;;
;;;   wrong arity      missing column reads NIL, caller falls back to the rule
;;;   non-string cell  matches via STRING-EQUAL, then signals in CONCATENATE
;;;   duplicate lemma  ASSOC returns the first row, later ones are unreachable
;;;   redundant row    restates the regular rule; dead weight, not a defect
;;;
;;; *LEXICON-OVERRIDES* is the opposite case -- it IS keyed to the ontology,
;;; and REGISTER-LEXICON-ENTRY validates nothing, so a misspelled key or one
;;; nothing reads is accepted and ignored in silence.
;;;
;;; Fixtures rebind the tables rather than mutating them.

(defun morphology-tables-lint-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; --- Override keys -------------------------------------------------

        (check "shipped overrides use only valid keys"
               (null (%lint-lexicon-override-keys)))
        (check "every override-key entry is well-formed"
               (every (lambda (e)
                        (destructuring-bind (key &key reader implemented
                                                      alternative)
                            e
                          (declare (ignore reader))
                          (and (keywordp key)
                               ;; An unimplemented key must say what to do
                               ;; instead; an implemented one needn't.
                               (or (not (null (getf (rest e) :implemented t)))
                                   (and (null implemented)
                                        (stringp alternative))))))
                      *lexicon-override-keys*))

        (let ((*lexicon-overrides* (make-hash-table :test 'equal)))
          (register-lexicon-entry 'dog :massp t)   ; typo for :mass-p
          (let ((findings (%lint-lexicon-override-keys)))
            (check "misspelled override key is reported"
                   (equal '(:unknown-lexicon-key) (mapcar #'second findings)))
            (check "misspelled key is an :error"
                   (eq :error (first (first findings))))
            (check "unknown-key message lists the valid keys"
                   (search ":MASS-P" (third (first findings))))))

        (let ((*lexicon-overrides* (make-hash-table :test 'equal)))
          (register-lexicon-entry 'eat :past "ate")
          (let ((findings (%lint-lexicon-override-keys)))
            (check "documented-but-unread key is reported separately"
                   (equal '(:unimplemented-lexicon-key)
                          (mapcar #'second findings)))
            (check "unimplemented key is an :error"
                   (eq :error (first (first findings))))
            (check "unimplemented-key message names the alternative"
                   (search "*IRREGULAR-VERBS*" (third (first findings))))))

        (let ((*lexicon-overrides* (make-hash-table :test 'equal)))
          (register-lexicon-entry 'dog :mass-p t :lemma "dog" :gender :masc)
          (check "valid keys yield no findings"
                 (null (%lint-lexicon-override-keys))))

        ;; --- Malformed rows ------------------------------------------------

        (check "shipped string-keyed tables are well-formed"
               (null (%lint-malformed-string-table-rows)))

        (let ((*irregular-verbs* '(("be" "was" "been"))))   ; missing present-3sg
          (let ((findings (%lint-malformed-string-table-rows)))
            (check "short row is reported"
                   (equal '(:malformed-table-row) (mapcar #'second findings)))
            (check "short row is an :error"
                   (eq :error (first (first findings))))
            (check "short-row message names the missing column"
                   (search "present-3sg" (third (first findings))))))

        (let ((*irregular-plurals* '(("man" "men" "extra"))))
          (check "long row is reported"
                 (equal '(:malformed-table-row)
                        (mapcar #'second (%lint-malformed-string-table-rows)))))

        (let ((*irregular-plurals* '(("man" men))))
          (let ((findings (%lint-malformed-string-table-rows)))
            (check "non-string cell is reported"
                   (equal '(:malformed-table-row) (mapcar #'second findings)))
            (check "non-string message explains the deferred failure"
                   (search "CONCATENATE" (third (first findings))))))

        (let ((*irregular-plurals* '("not-a-row")))
          (check "non-list row is reported"
                 (equal '(:malformed-table-row)
                        (mapcar #'second (%lint-malformed-string-table-rows)))))

        ;; --- Duplicates ----------------------------------------------------

        (check "shipped tables have no duplicate lemmas"
               (null (%lint-duplicate-string-table-keys)))

        (let ((*irregular-verbs* '(("eat" "ate" "eaten" "eats")
                                   ("go"  "went" "gone" "goes")
                                   ("eat" "et"  "eaten" "eats"))))
          (let ((findings (%lint-duplicate-string-table-keys)))
            (check "duplicate lemma is reported once"
                   (equal '("eat") (mapcar #'fourth findings)))
            (check "duplicate is a :warn"
                   (eq :warn (first (first findings))))
            (check "duplicate message shows the row that wins"
                   (search "\"ate\"" (third (first findings))))))

        ;; --- Redundant rows ------------------------------------------------

        (let ((*irregular-verbs* '(("eat" "ate" "eaten" "eats")
                                   ("own" "owned" "owned" "owns"))))
          (let ((findings (%lint-redundant-irregular-rows)))
            (check "redundant verb row is reported"
                   (equal '("own") (mapcar #'fourth findings)))
            (check "redundant row is :info"
                   (eq :info (first (first findings))))))

        ;; The check derives the regular forms by calling the morphology with
        ;; the tables rebound to NIL, rather than restating the rules -- so it
        ;; tracks the real -y/-ied and -y/-ies rules, not an approximation.
        (let ((*irregular-verbs* '(("try" "tried" "tried" "tries")
                                   ("fly" "flew"  "flown" "flies"))))
          (let ((findings (%lint-redundant-irregular-rows)))
            (check "rule-derived row (try) counts as redundant"
                   (member "try" (mapcar #'fourth findings) :test #'string=))
            (check "genuinely irregular row (fly) does not"
                   (not (member "fly" (mapcar #'fourth findings)
                                :test #'string=)))))

        ;; The redundancy check spans every table in
        ;; *STRING-KEYED-GENERATION-TABLES*, so a fixture that pins down one
        ;; table's findings has to silence the others.
        (let ((*irregular-verbs* nil)
              (*irregular-plurals* '(("cat" "cats") ("child" "children"))))
          (let ((findings (%lint-redundant-irregular-rows)))
            (check "redundant plural row is reported"
                   (equal '("cat") (mapcar #'fourth findings)))
            (check "genuine irregular plural is not reported"
                   (not (member "child" (mapcar #'fourth findings)
                                :test #'string=)))))

        ;; A malformed row must not also be judged for redundancy -- the
        ;; arity guard keeps the two checks from double-reporting.
        (let ((*irregular-verbs* nil)
              (*irregular-plurals* '(("cat"))))
          (check "malformed rows are skipped by the redundancy check"
                 (null (%lint-redundant-irregular-rows))))

        ;; --- Aggregate and removal ------------------------------------------

        (let ((*irregular-verbs* '(("eat" "ate" "eaten" "eats") ("eat" "et" "eaten" "eats"))))
          (check "lexicon-lint surfaces :duplicate-table-key"
                 (member :duplicate-table-key (lexicon-lint) :key #'second)))
        (let ((*lexicon-overrides* (make-hash-table :test 'equal)))
          (register-lexicon-entry 'eat :gerund "eating")
          (check "lexicon-lint surfaces :unimplemented-lexicon-key"
                 (member :unimplemented-lexicon-key (lexicon-lint) :key #'second)))

        ;; The POS-based irregular-verb check was removed as unsound: the
        ;; morphology is reached by lemma string from the clause realizer, so
        ;; a :NOUN-classified state noun (KNOW) still gets its irregular forms.
        (check "the unsound POS-based irregular check is gone"
               (not (member :irregular-verb-misclassified (lexicon-lint)
                            :key #'second)))
        (check "KNOW really does reach its irregular past participle"
               (and (not (eq :verb (pos-from-hierarchy (get-concept-type 'know))))
                    (string= "known" (past-participle "know"))
                    (string= "knowed" (let ((*irregular-verbs* nil))
                                        (past-participle "know"))))))

      (when verbose
        (format t "~&morphology-tables-lint-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))
