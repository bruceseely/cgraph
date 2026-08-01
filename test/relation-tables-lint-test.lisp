(in-package :conceptual-graphs)

;;; Tests for the relation-side generation lint checks.
;;;
;;; *RELATION-SYNTAX-TABLE* and the three PP support tables sit between the
;;; relation catalog and the realizer, and every way they can be wrong fails
;;; silently -- the relation is simply absent from the output. The four checks
;;; here walk the four edges of that square:
;;;
;;;   catalog -> table    %LINT-RELATION-SYNTAX-COVERAGE (pre-existing)
;;;   role    -> table    %LINT-UNCOVERED-SYNTAX-ROLES
;;;   table   -> realizer %LINT-UNREALIZABLE-SYNTAX-ROLES
;;;   table   -> catalog  %LINT-STALE-RELATION-ENTRIES
;;;
;;; plus %LINT-PP-TABLE-CONSISTENCY for support-table entries that can never
;;; fire, and %LINT-MISSING-GENERATION-RELATIONS for labels the realizer names
;;; literally.
;;;
;;; Fixtures rebind the tables rather than mutating them, so a failing
;;; assertion can't leak state into the rest of the suite.

(defun %findings-named (check findings)
  (remove-if-not (lambda (f) (eq (second f) check)) findings))

(defun %contexts-named (check findings)
  (mapcar #'fourth (%findings-named check findings)))

(defun %without-relation-types (labels thunk)
  "Call THUNK with each symbol in LABELS removed from the relation-type
   catalog, restoring them afterward even on non-local exit. Mirrors
   %WITHOUT-CATALOG-TYPES on the concept side."
  (let ((saved '()))
    (unwind-protect
         (progn
           (dolist (r labels)
             (multiple-value-bind (v p) (gethash r *relation-type-catalog*)
               (when p (push (cons r v) saved) (remhash r *relation-type-catalog*))))
           (funcall thunk))
      (dolist (pair saved)
        (setf (gethash (car pair) *relation-type-catalog*) (cdr pair))))))

(defun relation-tables-lint-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; --- Role coverage: role -> table ---------------------------------
        ;; A role is reachable only if some relation IN THE CATALOG maps to it.

        (check "shipped tables leave no role uncovered"
               (null (%lint-uncovered-syntax-roles)))

        (let ((*relation-syntax-table* '((obj :dobj) (loc :pp "in"))))
          (let ((uncovered (%contexts-named :syntax-role-uncovered
                                            (%lint-uncovered-syntax-roles))))
            (check "uncovered :subject is reported"
                   (member :subject uncovered))
            (check "uncovered :subject is an :error"
                   (eq :error (first (find :subject (%lint-uncovered-syntax-roles)
                                           :key #'fourth))))
            (check "covered roles are not reported"
                   (null (intersection '(:dobj :pp) uncovered)))
            (check "unimplemented roles are skipped by the coverage check"
                   (not (member :pred-cmp uncovered)))))

        ;; An entry whose relation isn't in the catalog provides no coverage --
        ;; this is the case a naive (assoc role table) check would get wrong.
        (let ((*relation-syntax-table* '((no-such-relation :subject) (obj :dobj))))
          (check "entry for an absent relation doesn't count as coverage"
                 (member :subject (%contexts-named :syntax-role-uncovered
                                                   (%lint-uncovered-syntax-roles)))))
        (let ((*relation-syntax-table* '((agnt :subject) (obj :dobj))))
          (check "entry for a present relation does count as coverage"
                 (not (member :subject (%contexts-named :syntax-role-uncovered
                                                        (%lint-uncovered-syntax-roles))))))

        ;; --- Role realizability: table -> realizer -------------------------
        ;; A role no realizer reads drops the relation exactly as if it were
        ;; unmapped. Two flavors: a typo, and a declared-but-unimplemented role.

        (let ((*relation-syntax-table* '((agnt :subject) (obj :dobj) (poss :pos))))
          (let ((findings (%lint-unrealizable-syntax-roles)))
            (check "unknown role keyword is reported"
                   (equal '(poss) (%contexts-named :unknown-syntax-role findings)))
            (check "unknown role is an :error"
                   (eq :error (first (first (%findings-named :unknown-syntax-role
                                                             findings)))))
            (check "unknown-role message names the known roles"
                   (search ":SUBJECT"
                           (third (first (%findings-named :unknown-syntax-role
                                                          findings)))))))

        (let ((*relation-syntax-table* '((agnt :subject) (obj :dobj) (thme :pred-cmp))))
          (let ((findings (%lint-unrealizable-syntax-roles)))
            (check "unimplemented role is reported separately"
                   (equal '(thme) (%contexts-named :unimplemented-syntax-role
                                                   findings)))
            (check "unimplemented role is an :error"
                   (eq :error (first (first (%findings-named
                                             :unimplemented-syntax-role findings)))))
            (check "unimplemented role is not also reported as unknown"
                   (null (%findings-named :unknown-syntax-role findings)))))

        (let ((*relation-syntax-table* '((agnt :subject) (obj :dobj) (loc :pp "in"))))
          (check "well-formed table yields no realizability findings"
                 (null (%lint-unrealizable-syntax-roles))))

        ;; The invariant that matters in practice: the table cgraph ships must
        ;; itself be clean. This is what caught (part :pos) -- a one-letter
        ;; typo for :poss that dropped every part arc from generated text,
        ;; invisibly, because an unrecognized role and an absent entry fail
        ;; identically.
        (check "the shipped syntax table assigns only realizable roles"
               (null (%lint-unrealizable-syntax-roles)))

        ;; --- Staleness: table -> catalog -----------------------------------
        ;; Harmless (the entry never fires), so :info rather than :error.

        (let ((*relation-syntax-table* '((agnt :subject) (ghost-rel :dobj)))
              (*pp-relation-priority* '(loc phantom-rel))
              (*np-pp-prepositions* '((loc "in" "of")))
              (*clause-level-pp-relations* '(loc)))
          (let ((stale (%contexts-named :stale-relation-entry
                                        (%lint-stale-relation-entries))))
            (check "stale syntax-table entry is reported"
                   (member 'ghost-rel stale))
            (check "stale priority-table entry is reported"
                   (member 'phantom-rel stale))
            (check "live entries are not reported as stale"
                   (null (intersection '(agnt loc) stale)))
            (check "stale entries are :info, not :error"
                   (every (lambda (f) (eq :info (first f)))
                          (%lint-stale-relation-entries)))
            (check "stale message names the offending table"
                   (search "*pp-relation-priority*"
                           (third (find 'phantom-rel
                                        (%findings-named :stale-relation-entry
                                                         (%lint-stale-relation-entries))
                                        :key #'fourth))))))

        ;; --- PP support-table consistency ----------------------------------
        ;; The three support tables are read behind a :pp role test, so an
        ;; entry for a non-:pp relation can never fire.

        (check "shipped PP support tables are consistent"
               (null (%lint-pp-table-consistency)))

        (let ((*relation-syntax-table* '((agnt :subject) (obj :dobj) (loc :pp "in")))
              (*pp-relation-priority* '(loc obj))
              (*np-pp-prepositions* '((loc "in" "of")))
              (*clause-level-pp-relations* '(loc)))
          (let ((findings (%lint-pp-table-consistency)))
            (check "non-:pp relation in a PP table is reported"
                   (equal '(obj) (%contexts-named :pp-table-role-mismatch findings)))
            (check "PP-table mismatch is a :warn"
                   (eq :warn (first (first findings))))
            (check "mismatch message names the actual role"
                   (search ":DOBJ" (third (first findings))))))

        ;; Already covered by other checks -- don't say it twice.
        (let ((*relation-syntax-table* '((agnt :subject) (obj :dobj)))
              (*pp-relation-priority* '(absent-rel))
              (*np-pp-prepositions* '())
              (*clause-level-pp-relations* '()))
          (check "absent relation in a PP table isn't double-reported"
                 (null (%lint-pp-table-consistency))))
        (let ((*relation-syntax-table* '((agnt :subject) (obj :dobj)))
              (*pp-relation-priority* '(loc))
              (*np-pp-prepositions* '())
              (*clause-level-pp-relations* '()))
          (check "unmapped relation in a PP table isn't double-reported"
                 (null (%lint-pp-table-consistency))))

        ;; --- Literally-named relation labels -------------------------------

        (check "no missing-relation findings with the full catalog"
               (null (%lint-missing-generation-relations)))
        (check "every *generation-relation-labels* entry is well-formed"
               (every (lambda (e)
                        (destructuring-bind (label &key severity consequence
                                                        remedy also)
                            e
                          (declare (ignore label also))
                          (and (member severity '(:error :warn :info))
                               (stringp consequence)
                               (stringp remedy))))
                      *generation-relation-labels*))
        (%without-relation-types '(time)
          (lambda ()
            (check "absent TIME relation is reported"
                   (equal '(time) (%contexts-named
                                   :missing-generation-relation
                                   (%lint-missing-generation-relations))))
            (check "TIME finding is :info"
                   (eq :info (first (first (%lint-missing-generation-relations)))))))

        ;; --- Reachable through the aggregate entry point --------------------

        (let ((*relation-syntax-table* '((obj :dobj) (poss :pos))))
          (let ((all (lexicon-lint)))
            (check "lexicon-lint surfaces :syntax-role-uncovered"
                   (member :syntax-role-uncovered all :key #'second))
            (check "lexicon-lint surfaces :unknown-syntax-role"
                   (member :unknown-syntax-role all :key #'second))))
        (check "role table and syntax-table roles agree on shape"
               (every (lambda (e) (keywordp (first e))) *generation-syntax-roles*)))

      (when verbose
        (format t "~&relation-tables-lint-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))
