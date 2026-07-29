;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Lexicon-lint: scan the type lattice and generation tables for
;;  suspicious gaps. Run after CGraph is fully initialized — the type
;;  catalogs must be populated before checks against them are meaningful.
;;
;;  Findings are (severity check-name message context):
;;    severity   - :error :warn :info
;;    check-name - keyword identifying which check fired
;;    message    - human-readable string
;;    context    - the offending label / object (or NIL)
;;
;;  (lexicon-lint)         => list of findings
;;  (report-lexicon-lint)  => prints grouped by severity, returns the list
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun %lint-missing-generation-roots ()
  "Generation consults a handful of type labels through SAFE-SUBTYPE-P --
   the POS roots (ACT, EVENT, MANNER, ATTRIBUTE) plus PERSON, ANIMATE and
   SITUATION. A user catalog may omit any of them, and the guarded lookup
   swallows the resulting error -- so a missing root doesn't crash, it
   silently degrades. Report once per absent root, using the consequence
   and remedy recorded alongside it in *GENERATION-HIERARCHY-ROOTS*."
  (let ((findings nil))
    (dolist (entry *generation-hierarchy-roots*)
      (destructuring-bind (root &key severity consequence remedy also) entry
        (unless (ignore-errors (get-concept-type root))
          ;; The three texts are FORMAT control strings carrying ~ line folds;
          ;; resolve each on its own before splicing, so an absent :also can't
          ;; shift the argument list under the remaining directives.
          (let ((consequence-text (format nil consequence))
                (also-text        (and also (format nil also)))
                (remedy-text      (format nil remedy)))
            (push (list severity
                        :missing-generation-root
                        (format nil "Concept type ~:@(~A~) is absent from the ~
                                     catalog, but generation consults it: ~A.~
                                     ~@[ ~A.~] To fix: ~A."
                                root consequence-text also-text remedy-text)
                        root)
                  findings)))))
    (nreverse findings)))

(defun %lint-relation-syntax-coverage ()
  "Each relation type must have an entry in *relation-syntax-table*; an
   unmapped relation is silently dropped during generation."
  (let ((findings nil))
    (dolist (label (all-relation-types))
      (unless (assoc label *relation-syntax-table* :test #'string-equal)
        (push (list :error
                    :relation-not-mapped
                    (format nil "Relation ~A has no entry in ~
                                 *relation-syntax-table* — it will be ~
                                 silently dropped during generation."
                            label)
                    label)
              findings)))
    (nreverse findings)))

(defun %lint-stale-lexicon-overrides ()
  "Lexicon override keys that don't correspond to any concept type in
   the current catalog — usually a type was renamed or removed."
  (let ((findings nil))
    (loop for key being the hash-keys of *lexicon-overrides*
          for sym = (ignore-errors (intern key :conceptual-graphs))
          unless (and sym (ignore-errors (get-concept-type sym)))
            do (push (list :warn
                           :stale-lexicon-override
                           (format nil "Lexicon override registered for ~A, ~
                                        but no concept type with that label ~
                                        exists. Remove the override or ~
                                        define the type."
                                   key)
                           key)
                     findings))
    (nreverse findings)))

(defun %lint-person-subtypes-without-gender ()
  "Subtypes of PERSON without a :gender override fall through to
   :unknown gender and singular-they pronouns. May be intentional
   (gender-neutral role) or an oversight (FATHER, KING, ...).

   The walk is rooted at PERSON, so a catalog without PERSON gives this
   check nothing to look at. Report that explicitly rather than returning
   quietly: the case where the check can't run is exactly the case where
   pronoun generation is most broken, and silence there would read as a
   clean bill of health."
  (let ((findings nil)
        (person-type (ignore-errors (get-concept-type 'person))))
    (if (null person-type)
        (push (list :info
                    :person-check-skipped
                    (format nil "Concept type PERSON is absent, so the ~
                                 person-subtype gender check could not run -- ~
                                 the absence of gender findings below means ~
                                 'could not look', not 'nothing to report'. ~
                                 See the :missing-generation-root finding ~
                                 for PERSON.")
                    'person)
              findings)
        (walk-concept-types-down
         (lambda (node)
           (let ((label (label node)))
             (unless (or (eq node person-type)
                         (lexicon-prop label :gender))
               (push (list :info
                           :person-without-gender
                           (format nil "Person subtype ~A has no :gender ~
                                        override; pronouns will use ~
                                        singular-they. Add ~
                                        (register-lexicon-entry '~(~A~) ~
                                        :gender :masc/:fem :human-p t) ~
                                        if the type is inherently gendered."
                                   label label)
                           label)
                     findings))))
         person-type))
    (nreverse findings)))

(defun %lint-irregular-verb-not-classified-as-verb ()
  "A concept type whose label appears in *irregular-verbs* but whose
   POS-from-hierarchy isn't :verb means the type is misplaced in the
   lattice — the irregular forms will never be looked up because the
   generator won't treat it as a verb."
  (let ((findings nil))
    (dolist (label (all-concept-types))
      (let* ((type (ignore-errors (get-concept-type label)))
             (lemma (and type (string-downcase (string label))))
             (irregular (and lemma (assoc lemma *irregular-verbs*
                                          :test #'string-equal)))
             (pos (and type
                       (or (lexicon-prop type :pos)
                           (pos-from-hierarchy type)))))
        (when (and irregular (not (eq pos :verb)))
          (push (list :info
                      :irregular-verb-misclassified
                      (format nil "Type ~A is listed in ~
                                   *irregular-verbs* but its POS is ~A. ~
                                   Either move the type under ACT/EVENT, ~
                                   or add (register-lexicon-entry '~(~A~) ~
                                   :pos :verb)."
                              label pos label)
                      label)
                findings))))
    (nreverse findings)))

(defun lexicon-lint ()
  "Run all lexicon/generation lint checks. Returns a list of findings
   of the form (severity check-name message context)."
  (append (%lint-missing-generation-roots)
          (%lint-relation-syntax-coverage)
          (%lint-stale-lexicon-overrides)
          (%lint-person-subtypes-without-gender)
          (%lint-irregular-verb-not-classified-as-verb)))

(defun %severity-rank (sev)
  (case sev (:error 0) (:warn 1) (:info 2) (t 3)))

(defun %cheat-sheet-pathname ()
  "Absolute path to the generation-tables cheat sheet shipped with cgraph,
   or NIL if the cgraph system source directory can't be resolved."
  (let ((sysdir (ignore-errors (asdf:system-source-directory :cgraph))))
    (when sysdir
      (let ((path (merge-pathnames "notes/generation-tables.md" sysdir)))
        (and (probe-file path) path)))))

(defun report-lexicon-lint (&key (stream *standard-output*) (min-severity :info))
  "Run lexicon-lint and pretty-print findings grouped by severity.
   MIN-SEVERITY filters by level: :INFO (default) shows all findings;
   :WARN shows errors and warnings; :ERROR shows only errors.
   When the filter hides every finding, the report stays silent (no
   'no findings' header), so it can be used in startup contexts where
   silence-means-OK is desired. Without a filter (:INFO), an empty
   result still prints the 'no findings' line for interactive feedback.
   When findings exist, appends a clickable file:// link to the cheat
   sheet. Returns the raw (unfiltered) findings list."
  (let* ((all-findings (lexicon-lint))
         (max-rank (%severity-rank min-severity))
         (findings (remove-if (lambda (f) (> (%severity-rank (first f)) max-rank))
                              all-findings))
         (sorted (stable-sort (copy-list findings) #'<
                              :key (lambda (f) (%severity-rank (first f)))))
         (errors (count :error findings :key #'first))
         (warns  (count :warn  findings :key #'first))
         (infos  (count :info  findings :key #'first)))
    (cond ((and (null findings) (eq min-severity :info))
           (format stream "~&lexicon-lint: no findings.~%"))
          ((null findings)
           ;; Filtered down to nothing — stay silent.
           nil)
          (t
           (format stream "~&lexicon-lint: ~D error~:P, ~D warning~:P, ~
                           ~D info note~:P.~2%"
                   errors warns infos)
           (let ((current-sev nil))
             (dolist (f sorted)
               (destructuring-bind (sev check msg context) f
                 (declare (ignore context))
                 (unless (eq sev current-sev)
                   (setf current-sev sev)
                   (format stream "~&--- ~A ---~%" sev))
                 (format stream "  [~A] ~A~%" check msg))))
           (let ((cheat-sheet (%cheat-sheet-pathname)))
             (when cheat-sheet
               (format stream "~%See the cheat sheet for help fixing ~
                               these findings:~%  file://~A~%"
                       (namestring cheat-sheet))))))
    all-findings))
