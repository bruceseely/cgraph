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

(defun %degradation-message (kind label consequence also remedy)
  "Assemble the 'X is absent, here is what silently breaks' message shared by
   the concept-root and relation-label checks. CONSEQUENCE, ALSO and REMEDY are
   FORMAT control strings carrying ~ line folds; each is resolved on its own
   before splicing, so an absent ALSO cannot shift the argument list under the
   remaining directives."
  (let ((consequence-text (format nil consequence))
        (also-text        (and also (format nil also)))
        (remedy-text      (format nil remedy)))
    (format nil "~A ~:@(~A~) is absent from the catalog, but generation ~
                 consults it: ~A.~@[ ~A.~] To fix: ~A."
            kind label consequence-text also-text remedy-text)))

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
          (push (list severity
                      :missing-generation-root
                      (%degradation-message "Concept type" root
                                            consequence also remedy)
                      root)
                findings))))
    (nreverse findings)))

(defun %relation-type-exists-p (label)
  (and (ignore-errors (get-relation-type label)) t))

(defun %lint-missing-generation-relations ()
  "The relation-label counterpart of %LINT-MISSING-GENERATION-ROOTS: labels the
   realizer names literally rather than reaching through *RELATION-SYNTAX-TABLE*
   (see *GENERATION-RELATION-LABELS*). The comparison is a STRING-EQUAL that
   simply never matches when the relation is absent, so the special-case path
   goes dead with no error."
  (let ((findings nil))
    (dolist (entry *generation-relation-labels*)
      (destructuring-bind (label &key severity consequence remedy also) entry
        (unless (%relation-type-exists-p label)
          (push (list severity
                      :missing-generation-relation
                      (%degradation-message "Relation" label
                                            consequence also remedy)
                      label)
                findings))))
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

;;; --- Relation-table checks -------------------------------------------------
;;; %LINT-RELATION-SYNTAX-COVERAGE above walks catalog -> table: a relation you
;;; defined that nothing maps. The checks below walk the other three edges of
;;; the same square -- role -> table (is the role reachable at all?), table ->
;;; realizer (is the assigned role one anybody reads?), and table -> catalog
;;; (does the entry name a relation that exists?).

(defun %live-relation-syntax-entries ()
  "*RELATION-SYNTAX-TABLE* entries whose relation is actually in the catalog.
   An entry for a relation you never defined provides no coverage."
  (remove-if-not (lambda (e) (%relation-type-exists-p (first e)))
                 *relation-syntax-table*))

(defun %lint-uncovered-syntax-roles ()
  "A syntactic role is reachable only if some relation in the catalog maps to
   it. When none does, the realizer branch keyed on that role is dead code for
   this ontology -- silently, since the branch simply never runs. :SUBJECT is
   the severe case: without it every graph renders as a copular clause."
  (let ((findings nil)
        (live (%live-relation-syntax-entries)))
    (dolist (entry *generation-syntax-roles*)
      (destructuring-bind (role &key severity consequence remedy (implemented t))
          entry
        (when (and implemented
                   severity
                   (notany (lambda (e) (eq (second e) role)) live))
          (push (list severity
                      :syntax-role-uncovered
                      (format nil "No relation in the catalog maps to ~S: ~A. ~
                                   To fix: ~A."
                              role (format nil consequence) (format nil remedy))
                      role)
                findings))))
    (nreverse findings)))

(defun %lint-unrealizable-syntax-roles ()
  "*RELATION-SYNTAX-TABLE* entries assigning a role no realizer reads: either
   an unrecognized keyword (a typo -- :POS for :POSS) or one declared in
   *GENERATION-SYNTAX-ROLES* as not implemented. The consequence is identical
   in both cases and identical to having no entry at all: every consumer
   compares the role against the keywords it handles, no comparison matches,
   and the relation falls out of the output silently."
  (let ((findings nil))
    (dolist (entry *relation-syntax-table*)
      (let ((label (first entry))
            (role  (second entry)))
        (cond ((not (known-syntax-role-p role))
               (push (list :error
                           :unknown-syntax-role
                           (format nil "Relation ~:@(~A~) is mapped to ~S, ~
                                        which is not a role any realizer ~
                                        reads, so the relation is silently ~
                                        dropped -- exactly as if it had no ~
                                        entry at all. Known roles: ~{~S~^ ~}. ~
                                        To fix: correct the role, or add it to ~
                                        *GENERATION-SYNTAX-ROLES* and ~
                                        implement it in the realizer."
                                   label role
                                   (mapcar #'first *generation-syntax-roles*))
                           label)
                     findings))
              ((not (implemented-syntax-role-p role))
               (let ((props (rest (syntax-role-entry role))))
                 (push (list :error
                             :unimplemented-syntax-role
                             (format nil "Relation ~:@(~A~) is mapped to ~S: ~
                                          ~A. To fix: ~A."
                                     label role
                                     (format nil (getf props :consequence))
                                     (format nil (getf props :remedy)))
                             label)
                       findings))))))
    (nreverse findings)))

(defun %relation-tables ()
  "The generation tables keyed on relation labels, as (NAME TABLE PP-ONLY-P).
   PP-ONLY-P marks the three whose entries are consulted only for relations
   whose role is :PP."
  (list (list "*relation-syntax-table*"      *relation-syntax-table*      nil)
        (list "*pp-relation-priority*"       *pp-relation-priority*       t)
        (list "*np-pp-prepositions*"         *np-pp-prepositions*         t)
        (list "*clause-level-pp-relations*"  *clause-level-pp-relations*  t)))

(defun %relation-table-labels (table)
  "Labels named by TABLE, which holds either bare symbols or entries whose
   first element is the label."
  (mapcar (lambda (e) (if (consp e) (first e) e)) table))

(defun %lint-stale-relation-entries ()
  "Table entries naming a relation absent from the catalog. Harmless -- the
   entry simply never fires -- so this is :INFO, unlike the reverse direction
   (a relation you defined with no entry), which loses output and is :ERROR.
   Shipped tables cover more relations than most catalogs define, so a handful
   of these is normal."
  (let ((findings nil))
    (dolist (spec (%relation-tables))
      (destructuring-bind (name table pp-only-p) spec
        (declare (ignore pp-only-p))
        (dolist (label (%relation-table-labels table))
          (unless (%relation-type-exists-p label)
            (push (list :info
                        :stale-relation-entry
                        (format nil "~A names relation ~:@(~A~), which is not ~
                                     in the catalog, so the entry can never ~
                                     fire. Remove it, or define the relation."
                                name label)
                        label)
                  findings)))))
    (nreverse findings)))

(defun %lint-pp-table-consistency ()
  "*PP-RELATION-PRIORITY*, *NP-PP-PREPOSITIONS* and *CLAUSE-LEVEL-PP-RELATIONS*
   are all consulted behind a :PP role test, so an entry for a relation whose
   role is something else can never fire. Skips relations absent from the
   catalog and relations with no syntax entry -- those are already reported by
   %LINT-STALE-RELATION-ENTRIES and %LINT-RELATION-SYNTAX-COVERAGE, and saying
   it twice helps nobody."
  (let ((findings nil))
    (dolist (spec (%relation-tables))
      (destructuring-bind (name table pp-only-p) spec
        (when pp-only-p
          (dolist (label (%relation-table-labels table))
            (let ((role (and (%relation-type-exists-p label)
                             (relation-role label))))
              (when (and role (not (eq role :pp)))
                (push (list :warn
                            :pp-table-role-mismatch
                            (format nil "~A names relation ~:@(~A~), but its ~
                                         role in *RELATION-SYNTAX-TABLE* is ~S, ~
                                         not :PP. The table is only consulted ~
                                         for :PP relations, so this entry can ~
                                         never fire."
                                    name label role)
                            label)
                      findings)))))))
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
          (%lint-missing-generation-relations)
          (%lint-relation-syntax-coverage)
          (%lint-uncovered-syntax-roles)
          (%lint-unrealizable-syntax-roles)
          (%lint-pp-table-consistency)
          (%lint-stale-relation-entries)
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
