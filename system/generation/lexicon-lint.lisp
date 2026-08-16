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
  "Each relation type must have a syntax entry the realizer can find -- a
   registration or a built-in; an unmapped relation is silently dropped during
   generation.

   This is the check a user-authored ontology hits first, so the message names
   REGISTER-RELATION-SYNTAX: editing *relation-syntax-table* means editing the
   repo, which is the thing the hook exists to avoid."
  (let ((findings nil))
    (dolist (label (all-relation-types))
      (unless (relation-role-entry label)
        (push (list :error
                    :relation-not-mapped
                    (format nil "Relation ~A has no syntax entry — it will be ~
                                 silently dropped during generation. To fix: ~
                                 (register-relation-syntax '~(~A~) :dobj) with ~
                                 whichever role fits, or add it to ~
                                 *relation-syntax-table*."
                            label label)
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
  "Effective syntax entries whose relation is actually in the catalog. An entry
   for a relation you never defined provides no coverage -- and a registration
   counts here exactly as a built-in does, which is the point: an ontology that
   registers its own :SUBJECT relation has covered the role."
  (remove-if-not (lambda (e) (%relation-type-exists-p (first e)))
                 (relation-syntax-entries)))

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
  "Syntax entries assigning a role no realizer reads: either
   an unrecognized keyword (a typo -- :POS for :POSS) or one declared in
   *GENERATION-SYNTAX-ROLES* as not implemented. The consequence is identical
   in both cases and identical to having no entry at all: every consumer
   compares the role against the keywords it handles, no comparison matches,
   and the relation falls out of the output silently."
  (let ((findings nil))
    (dolist (entry (relation-syntax-entries))
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
  ;; The first is named in prose rather than by variable, because it is now the
  ;; MERGE of *relation-syntax-table* and the registrations -- a stale entry may
  ;; have come from either, and naming one of them would send you to the wrong
  ;; place half the time. The other three are single variables and say so.
  (list (list "The relation syntax mapping"  (relation-syntax-entries)    nil)
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
                                         syntax role is ~S, ~
                                         not :PP. The table is only consulted ~
                                         for :PP relations, so this entry can ~
                                         never fire."
                                    name label role)
                            label)
                      findings)))))))
    (nreverse findings)))

(defun %lint-stale-lexicon-overrides ()
  "Lexicon override keys that don't correspond to any concept type in
   the current catalog — usually a type was renamed or removed.

   :INFO, matching :STALE-RELATION-ENTRY on the relation side, and for the
   same reason: an override for a type you never defined is dead weight that
   can never fire, whereas the reverse direction loses output. The shipped
   registrations at the bottom of lexicon.lisp cover far more vocabulary than
   most catalogs define, so these are the normal case rather than a defect —
   at :WARN they buried everything else in the report."
  (let ((findings nil))
    (loop for key being the hash-keys of *lexicon-overrides*
          for sym = (ignore-errors (intern key :conceptual-graphs))
          unless (and sym (ignore-errors (get-concept-type sym)))
            do (push (list :info
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

   :UNGENDERED T settles that question in the lexicon and silences the
   finding. Only the absence of BOTH keys is reportable -- a type nobody
   has ruled on either way. Singular-they is the right output for CHILD or
   ADULT, so without a way to say so the check would report correct
   behaviour forever, and a warning that is always wrong teaches you to
   stop reading the ones that are not.

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
                         (lexicon-prop label :gender)
                         (lexicon-prop label :ungendered))
               (push (list :info
                           :person-without-gender
                           (format nil "Person subtype ~A has no :gender ~
                                        override; pronouns will use ~
                                        singular-they. Add ~
                                        (register-lexicon-entry '~(~A~) ~
                                        :gender :masc/:fem :human-p t) ~
                                        if the type is inherently gendered, ~
                                        or :ungendered t to record that it ~
                                        is not."
                                   label label)
                           label)
                     findings))))
         person-type))
    (nreverse findings)))

;;; --- Lexicon-override and string-keyed-table checks ------------------------
;;;
;;; There was once a check here that flagged a concept type whose label appears
;;; in *IRREGULAR-VERBS* but whose POS isn't :VERB, on the theory that the
;;; irregular forms could never be reached. That premise is false. The
;;; morphology functions are called with a bare LEMMA STRING by the clause
;;; realizer for whatever concept FIND-MAIN-PREDICATE selects, and that choice
;;; is structural (it follows the subject relation), not POS-driven. KNOW is
;;; POS :NOUN and still generates "Ivan is known to eat a pie" -- "known" comes
;;; from the table, since the rule would give "knowed". The check fired on every
;;; state-noun predicate (KNOW, BELIEF, THOUGHT), which is the intended design,
;;; and its advice -- move the type under ACT/EVENT, or force :pos :verb --
;;; would have turned a noun like SET into a verb. Removed rather than repaired:
;;; there is no POS-based premise that is both sound and useful here.
;;;
;;; What IS checkable about these tables is internal consistency, below.

(defun %lint-lexicon-override-keys ()
  "REGISTER-LEXICON-ENTRY takes an unchecked &REST plist, so a key that is
   misspelled -- or one that is documented but that no code reads -- is stored
   and then ignored without complaint. Both cases mean the user asked for
   something and silently didn't get it, so both are errors."
  (let ((findings nil))
    (loop for type-key being the hash-keys of *lexicon-overrides*
            using (hash-value plist)
          do (loop for key in plist by #'cddr
                   do (let ((entry (assoc key *lexicon-override-keys*)))
                        (cond
                          ((null entry)
                           (push (list :error
                                       :unknown-lexicon-key
                                       (format nil "~A has a lexicon override ~
                                                    for ~S, which is not a key ~
                                                    any code reads, so it is ~
                                                    silently ignored. Known ~
                                                    keys: ~{~S~^ ~}."
                                               type-key key
                                               (mapcar #'first
                                                       *lexicon-override-keys*))
                                       type-key)
                                 findings))
                          ((not (getf (rest entry) :implemented t))
                           (push (list :error
                                       :unimplemented-lexicon-key
                                       (format nil "~A has a lexicon override ~
                                                    for ~S. The key is ~
                                                    documented but nothing ~
                                                    reads it, so the override ~
                                                    is silently ignored. ~
                                                    Instead: ~A."
                                               type-key key
                                               (format nil
                                                       (getf (rest entry)
                                                             :alternative)))
                                       type-key)
                                 findings))))))
    (nreverse findings)))

(defun %string-table-rows (spec)
  "(SYMBOL ARITY COLUMNS CONSULTED-BY) -> the table's current rows."
  (symbol-value (first spec)))

(defun %lint-malformed-string-table-rows ()
  "A row of the wrong arity fails silently in the worst way: the accessor for
   the missing column returns NIL, the caller's (OR irregular regular) falls
   through to the rule, and you get 'bes' for a BE row that forgot its
   present-3sg. Non-string cells are worse -- they reach CONCATENATE and
   signal, far from the table that caused it."
  (let ((findings nil))
    (dolist (spec *string-keyed-generation-tables*)
      (destructuring-bind (symbol arity columns consulted-by) spec
        (dolist (row (%string-table-rows spec))
          (cond
            ((not (listp row))
             (push (list :error :malformed-table-row
                         (format nil "~A contains ~S, which is not a row."
                                 symbol row)
                         symbol)
                   findings))
            ((/= (length row) arity)
             (push (list :error :malformed-table-row
                         (format nil "~A row ~S has ~D element~:P, not ~D ~
                                      (~{~A~^, ~}). The missing column reads ~
                                      as NIL and ~A silently falls back to the ~
                                      regular rule."
                                 symbol row (length row) arity columns
                                 consulted-by)
                         (first row))
                   findings))
            ((notevery #'stringp row)
             (push (list :error :malformed-table-row
                         (format nil "~A row ~S has a non-string cell. Lookup ~
                                      is by STRING-EQUAL so it may still match, ~
                                      but the value is passed to CONCATENATE ~
                                      and will signal there instead of here."
                                 symbol row)
                         (first row))
                   findings))))))
    (nreverse findings)))

(defun %lint-duplicate-string-table-keys ()
  "Lookup is by ASSOC, which returns the first match, so a second row for the
   same lemma is unreachable. Silent, and easy to create by adding a word that
   is already present far up a long alphabetical-ish list."
  (let ((findings nil))
    (dolist (spec *string-keyed-generation-tables*)
      (let ((symbol (first spec))
            (seen (make-hash-table :test 'equalp)))
        (dolist (row (%string-table-rows spec))
          (when (and (consp row) (stringp (first row)))
            (let* ((key (first row))
                   (previous (gethash key seen)))
              (cond (previous
                     (push (list :warn
                                 :duplicate-table-key
                                 (format nil "~A has more than one row for ~
                                              ~S. ASSOC returns the first ~
                                              (~S), so ~S is unreachable."
                                         symbol key previous row)
                                 key)
                           findings))
                    (t (setf (gethash key seen) row))))))))
    (nreverse findings)))

(defun %regular-forms-for (symbol row)
  "What the rule-driven morphology would produce for ROW's lemma, with the
   irregular tables rebound to NIL so the rules can't consult themselves.
   Deriving this rather than restating the rules keeps the check from drifting
   away from the morphology it is checking. NIL for tables with no rule-driven
   counterpart."
  (let ((lemma (first row)))
    (case symbol
      (*irregular-verbs*
       (let ((*irregular-verbs* nil))
         (list (past-tense lemma) (past-participle lemma) (present-3sg lemma))))
      (*irregular-plurals*
       (let ((*irregular-plurals* nil))
         (list (pluralize lemma))))
      (t nil))))

(defun %lint-redundant-irregular-rows ()
  "A row whose forms are exactly what the regular rules already derive costs a
   lookup and implies an irregularity that isn't there. Harmless, so :info --
   but worth knowing before you trust the table as a list of English
   irregulars."
  (let ((findings nil))
    (dolist (spec *string-keyed-generation-tables*)
      (let ((symbol (first spec))
            (arity (second spec)))
        (dolist (row (%string-table-rows spec))
          (when (and (consp row)
                     (= (length row) arity)
                     (every #'stringp row))
            (let ((regular (%regular-forms-for symbol row)))
              (when (and regular
                         (every #'string-equal regular (rest row))
                         (= (length regular) (length (rest row))))
                (push (list :info
                            :redundant-irregular-row
                            (format nil "~A row ~S restates what the regular ~
                                         rules already derive, so it never ~
                                         changes any output. Safe to remove."
                                    symbol row)
                            (first row))
                      findings)))))))
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
          (%lint-lexicon-override-keys)
          (%lint-person-subtypes-without-gender)
          (%lint-malformed-string-table-rows)
          (%lint-duplicate-string-table-keys)
          (%lint-redundant-irregular-rows)))

(defparameter *lint-severities* '(:error :warn :info)
  "Lint severities, most severe first. Position in this list is the rank.")

(defun %severity-rank (sev)
  "Rank of SEV within *LINT-SEVERITIES*, signalling on anything else.

   Strict on purpose. This used to fall through to a (t 3) catch-all, which
   meant a caller passing an unrecognized keyword got a filter that silently
   matched everything -- the report looked like it had run and filtered, and
   had not. Easy to hit, because the *RUN-LEXICON-LINT-ON-STARTUP* option
   names read like severities but are a different vocabulary."
  (or (position sev *lint-severities*)
      (error "~S is not a lint severity. Expected one of ~{~S~^, ~}.~%~
              (The *RUN-LEXICON-LINT-ON-STARTUP* option names -- :ERRORS-ONLY, ~
              :ERRORS-WARNINGS, :ALL -- are a different vocabulary; ~
              INITIALIZE-CGRAPH maps those to these.)"
             sev *lint-severities*)))

(defun %finding-rank (finding)
  "Sort and filter key for a finding. Lenient where %SEVERITY-RANK is strict,
   and in the direction that keeps the fault visible: finding severities come
   from user-editable tables, so a typo there should not take down the whole
   report, and should not quietly hide the finding either. An unrecognized
   severity ranks above :ERROR -- it sorts first and survives every filter,
   printing under a header naming the bogus keyword."
  (or (position (first finding) *lint-severities*) -1))

(defun %cheat-sheet-pathname ()
  "Absolute path to the generation-tables cheat sheet shipped with cgraph,
   or NIL if the cgraph system source directory can't be resolved."
  (let ((sysdir (ignore-errors (asdf:system-source-directory :cgraph))))
    (when sysdir
      (let ((path (merge-pathnames "notes/generation-tables.md" sysdir)))
        (and (probe-file path) path)))))

(defun report-lexicon-lint (&key (stream *standard-output*) (min-severity :info))
  "Run lexicon-lint and pretty-print findings grouped by severity.
   MIN-SEVERITY filters by level and must be one of :ERROR, :WARN or :INFO --
   anything else signals rather than quietly disabling the filter. :INFO
   (the default) shows all findings; :WARN shows errors and warnings; :ERROR
   shows only errors. Note these are not the *RUN-LEXICON-LINT-ON-STARTUP*
   option names; INITIALIZE-CGRAPH translates those into these.
   When the filter hides every finding, the report stays silent (no
   'no findings' header), so it can be used in startup contexts where
   silence-means-OK is desired. Without a filter (:INFO), an empty
   result still prints the 'no findings' line for interactive feedback.
   When findings exist, appends a clickable file:// link to the cheat
   sheet. Returns the raw (unfiltered) findings list."
  (let* ((all-findings (lexicon-lint))
         ;; Validate the caller's argument before doing any work, so a bad
         ;; MIN-SEVERITY fails at the call rather than half-way through a report.
         (max-rank (%severity-rank min-severity))
         (findings (remove-if (lambda (f) (> (%finding-rank f) max-rank))
                              all-findings))
         (sorted (stable-sort (copy-list findings) #'< :key #'%finding-rank))
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
