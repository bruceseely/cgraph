(in-package :conceptual-graphs)

;;; Tests for %LINT-MISSING-POS-ROOTS and the *POS-HIERARCHY-ROOTS* contract.
;;;
;;; POS-FROM-HIERARCHY classifies a concept's part of speech by asking whether
;;; it is a subtype of one of a few hard-coded roots (ACT/EVENT -> :verb,
;;; MANNER -> :adv, ATTRIBUTE -> :adj, else :noun). A user-supplied catalog may
;;; omit any of those roots; SAFE-SUBTYPE-P swallows the resulting lookup error,
;;; so classification does not crash -- it silently degrades that whole POS
;;; class to :noun. %LINT-MISSING-POS-ROOTS exists to surface exactly that gap.
;;; These tests pin down both halves: the silent degradation is real, and the
;;; lint check reports precisely the absent roots (and nothing when all present).

(defun %missing-pos-root-findings ()
  "The current findings from the :missing-pos-root check only."
  (remove-if-not (lambda (f) (eq (second f) :missing-pos-root))
                 (%lint-missing-pos-roots)))

(defun %missing-pos-root-contexts ()
  "Context symbols (the absent roots) of the current :missing-pos-root findings."
  (mapcar #'fourth (%missing-pos-root-findings)))

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

(defun pos-roots-lint-test (&optional verbose)
  (with-test-types
    (let ((ok t))
      (flet ((check (label pass)
               (setf ok (and ok (and pass t)))
               (when (or verbose (not pass))
                 (format t "~&  ~:[FAIL <<<~;pass~] ~a~%" pass label))))

        ;; 1. Baseline: the test catalog defines all four roots, so there are no
        ;;    findings and a known ACT subtype classifies as :verb.
        (check "no findings when all roots present"
               (null (%missing-pos-root-contexts)))
        (check "give -> :verb with roots present"
               (eq :verb (pos-from-hierarchy (get-concept-type 'give))))

        ;; 2. Remove one root: exactly that root is reported, as a single :warn.
        (%without-catalog-types '(manner)
          (lambda ()
            (check "exactly MANNER reported when MANNER absent"
                   (equal '(manner) (%missing-pos-root-contexts)))
            (check "finding is a single :warn"
                   (and (= 1 (length (%missing-pos-root-findings)))
                        (eq :warn (first (first (%missing-pos-root-findings))))))))

        ;; 3. Remove BOTH verb roots: an ACT subtype silently degrades to :noun
        ;;    (the failure the check warns about), and both roots are reported --
        ;;    and only those (manner/attribute, still present, are not).
        (%without-catalog-types '(act event)
          (lambda ()
            (check "give -> :noun when ACT and EVENT both absent"
                   (eq :noun (pos-from-hierarchy (get-concept-type 'give))))
            (check "both verb roots reported"
                   (null (set-difference '(act event) (%missing-pos-root-contexts))))
            (check "only absent roots reported"
                   (null (set-difference (%missing-pos-root-contexts) '(act event))))))

        ;; 4. Restored: clean again, and the check is reachable through the
        ;;    aggregate LEXICON-LINT entry point (not just the private function).
        (check "no findings after restore"
               (null (%missing-pos-root-contexts)))
        (%without-catalog-types '(manner)
          (lambda ()
            (check "lexicon-lint surfaces :missing-pos-root"
                   (member :missing-pos-root (lexicon-lint) :key #'second)))))

      (when verbose
        (format t "~&pos-roots-lint-test: ~:[FAILED <<<~;passed~]~%" ok))
      ok)))
