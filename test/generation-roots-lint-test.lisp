(in-package :conceptual-graphs)

;;; Tests for %LINT-MISSING-GENERATION-ROOTS and the
;;; *GENERATION-HIERARCHY-ROOTS* contract.
;;;
;;; Generation consults a few hard-coded type labels through SAFE-SUBTYPE-P:
;;; the POS roots (ACT/EVENT -> :verb, MANNER -> :adv, ATTRIBUTE -> :adj, else
;;; :noun), plus PERSON (HUMAN-P), ANIMATE (ANIMATE-CONCEPT-P) and SITUATION
;;; (CLAUSAL-SITUATION-P). A user-supplied catalog may omit any of them; the
;;; guarded lookup swallows the resulting error, so classification does not
;;; crash -- it silently degrades. %LINT-MISSING-GENERATION-ROOTS exists to
;;; surface exactly that gap. These tests pin down both halves: the silent
;;; degradation is real, and the lint check reports precisely the absent roots
;;; (and nothing when all present).

(defun %missing-generation-root-findings ()
  "The current findings from the :missing-generation-root check only."
  (remove-if-not (lambda (f) (eq (second f) :missing-generation-root))
                 (%lint-missing-generation-roots)))

(defun %missing-generation-root-contexts ()
  "Context symbols (the absent roots) of the current findings."
  (mapcar #'fourth (%missing-generation-root-findings)))

(defun %finding-severity (root)
  "Severity of the :missing-generation-root finding for ROOT, or NIL."
  (first (find root (%missing-generation-root-findings) :key #'fourth)))

(defun %without-catalog-types (roots thunk)
  "Call THUNK with each symbol in ROOTS removed from the concept-type catalog,
   restoring them afterward even on non-local exit. Only the catalog index is
   touched; the concept-type objects (and their supertype links) are left alone,
   which is what makes a removed root disappear from lookups the way a catalog
   that never defined it would."
  (let ((saved '()))
    (unwind-protect
         (progn
           (dolist (r roots)
             (multiple-value-bind (v p) (gethash r *concept-type-catalog*)
               (when p (push (cons r v) saved) (remhash r *concept-type-catalog*))))
           (funcall thunk))
      (dolist (pair saved)
        (setf (gethash (car pair) *concept-type-catalog*) (cdr pair))))))

(defun generation-roots-lint-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; 1. Baseline: the test catalog defines every root the generation
        ;;    subsystem consults, so there are no findings, and a known ACT
        ;;    subtype classifies as :verb.
        (check "no findings when all roots present"
               (null (%missing-generation-root-contexts)))
        (check "give -> :verb with roots present"
               (eq :verb (pos-from-hierarchy (get-concept-type 'give))))

        ;; 2. The table covers the POS roots and the three non-POS roots, and
        ;;    stays derived from *POS-HIERARCHY-ROOTS* rather than duplicating
        ;;    it -- so adding a POS root can't silently escape the check.
        (check "table covers every POS root"
               (null (set-difference (mapcar #'car *pos-hierarchy-roots*)
                                     (mapcar #'first *generation-hierarchy-roots*))))
        (check "table covers person, animate, situation"
               (null (set-difference '(person animate situation)
                                     (mapcar #'first *generation-hierarchy-roots*))))
        (check "every entry carries a severity, consequence and remedy"
               (every (lambda (e)
                        (destructuring-bind (root &key severity consequence
                                                       remedy also)
                            e
                          (declare (ignore root also))
                          (and (member severity '(:error :warn :info))
                               (stringp consequence)
                               (stringp remedy))))
                      *generation-hierarchy-roots*))

        ;; 3. Remove one root: exactly that root is reported, as a single :warn.
        (%without-catalog-types '(manner)
          (lambda ()
            (check "exactly MANNER reported when MANNER absent"
                   (equal '(manner) (%missing-generation-root-contexts)))
            (check "finding is a single :warn"
                   (and (= 1 (length (%missing-generation-root-findings)))
                        (eq :warn (first (first (%missing-generation-root-findings))))))))

        ;; 4. Remove BOTH verb roots: an ACT subtype silently degrades to :noun
        ;;    (the failure the check warns about), and both roots are reported --
        ;;    and only those (manner/attribute, still present, are not).
        (%without-catalog-types '(act event)
          (lambda ()
            (check "give -> :noun when ACT and EVENT both absent"
                   (eq :noun (pos-from-hierarchy (get-concept-type 'give))))
            (check "both verb roots reported"
                   (null (set-difference '(act event) (%missing-generation-root-contexts))))
            (check "only absent roots reported"
                   (null (set-difference (%missing-generation-root-contexts) '(act event))))
            (check "ACT finding mentions the clause-structure fallout"
                   (search "FIND-MAIN-PREDICATE"
                           (third (find 'act (%missing-generation-root-findings)
                                        :key #'fourth))))))

        ;; 5. The non-POS roots degrade silently in their own ways, and each is
        ;;    reported. SITUATION is :info rather than :warn -- its fallback
        ;;    ('that'-clause) is always grammatical, just sometimes stilted.
        (%without-catalog-types '(animate)
          (lambda ()
            (check "ANIMATE reported when absent"
                   (equal '(animate) (%missing-generation-root-contexts)))
            (check "ANIMATE finding is a :warn"
                   (eq :warn (%finding-severity 'animate)))))
        (%without-catalog-types '(situation)
          (lambda ()
            (check "SITUATION reported when absent"
                   (equal '(situation) (%missing-generation-root-contexts)))
            (check "SITUATION finding is :info, not :warn"
                   (eq :info (%finding-severity 'situation)))))

        ;; 6. PERSON absent: reported by the root check, AND the gender check
        ;;    says out loud that it could not run. Silence there would read as
        ;;    a clean bill of health in exactly the broken case.
        (%without-catalog-types '(person)
          (lambda ()
            (check "PERSON reported when absent"
                   (equal '(person) (%missing-generation-root-contexts)))
            (let ((gender-findings (%lint-person-subtypes-without-gender)))
              (check "gender check reports it was skipped"
                     (and (= 1 (length gender-findings))
                          (eq :person-check-skipped (second (first gender-findings)))))
              (check "skipped finding carries a message"
                     (plusp (length (third (first gender-findings))))))))
        (check "gender check runs normally with PERSON present"
               (notany (lambda (f) (eq (second f) :person-check-skipped))
                       (%lint-person-subtypes-without-gender)))

        ;; 7. Restored: clean again, and the check is reachable through the
        ;;    aggregate LEXICON-LINT entry point (not just the private function).
        (check "no findings after restore"
               (null (%missing-generation-root-contexts)))
        (%without-catalog-types '(manner)
          (lambda ()
            (check "lexicon-lint surfaces :missing-generation-root"
                   (member :missing-generation-root (lexicon-lint) :key #'second)))))

      (when verbose
        (format t "~&generation-roots-lint-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))
