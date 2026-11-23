;;; -*- Mode: LISP; Syntax: Common-lisp; Base 10; Lowercase: Yes -*-

(in-package #:conceptual-graphs)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  Lexicon (Phase 2):
;;  - Part-of-speech classification by walking the type lattice
;;  - Lemma resolution (per-type overrides; default = downcased label)
;;  - Irregular-form lookup (verbs and nouns)
;;  - Number / definiteness derived from a concept's referent
;;
;;  Overrides are stored in *lexicon-overrides* keyed by type-label symbol;
;;  callers may extend them via REGISTER-LEXICON-ENTRY at runtime.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Two tables. *BUILTIN-LEXICON-OVERRIDES* holds the entries in cgraph's own
;;; source (REGISTER-BUILTIN-LEXICON-ENTRY, below and in anaphora.lisp).
;;; *LEXICON-OVERRIDES* is the one every reader consults; it belongs to the
;;; current environment (setup/environment.lisp), and INITIALIZE-TYPES refills
;;; it from the built-ins and then the domain's lexicon-overrides.lisp. So
;;; after editing a built-in entry: reload the file, then reinitialize -- the
;;; same as before environments, since reloading always dropped the domain's
;;; entries until the next initialize.

(defparameter *builtin-lexicon-overrides* (make-hash-table :test 'equal)
  "cgraph's own per-concept-type overrides on the derivational defaults, copied
   into each environment's *LEXICON-OVERRIDES* when its types are loaded. Key:
   upcased label string. Value: a plist. See docs/lexicon-overrides.md for the
   full reference.
   Canonical keys:
     Word form:  :lemma :plural :past :past-participle :present-3sg :gerund
                 :particle
     Noun class: :pos :mass-p :proper-p :gender (:masc/:fem) :ungendered
                 :human-p :animate-p
     Verb frame: :raising :rcpt-direct :obj-prep :inst-direct :adv-form
     Arc prep:   :inst-prep :time-prep :thme-prep
     Lint only:  :synonym-ok")

(defparameter *lexicon-override-keys*
  '((:lemma       :reader "BASE-LEMMA")
    (:plural      :reader "REALIZE-NP")
    (:particle    :reader "REALIZE-CLAUSE")
    (:pos         :reader "CONCEPT-POS")
    (:mass-p      :reader "MASS-NOUN-P")
    (:proper-p    :reader "PROPER-NAME-P")
    (:gender      :reader "PRONOUN-FOR (anaphora.lisp)")
    ;; Read by the lint, deliberately NOT by GENDER-OF. It records that a type
    ;; carries no inherent gender and that this was decided rather than
    ;; overlooked. It must not be spelled (:gender :unknown), because GENDER-OF
    ;; consults the lexicon before the given-name registry -- so any gender
    ;; value here, even :unknown, would shadow the name and turn
    ;; [CHILD: Mary] from "she" into "they".
    (:ungendered  :reader "%LINT-PERSON-SUBTYPES-WITHOUT-GENDER (lexicon-lint.lisp)")
    ;; Read by the lint, like :UNGENDERED and for the same reason: it records
    ;; that two types saying the same English word was decided rather than
    ;; overlooked. GEOGRAPHICAL-STATE and GEOPOLITICAL-STATE are both "state"
    ;; on purpose.
    (:synonym-ok  :reader "%LINT-ENGLISH-COLLISIONS (lexicon-lint.lisp)")
    (:human-p     :reader "HUMAN-P")
    (:animate-p   :reader "ANIMATE-CONCEPT-P")
    (:raising     :reader "GRAPH-TO-TEXT dispatch")
    (:rcpt-direct :reader "REALIZE-CLAUSE")
    (:obj-prep    :reader "REALIZE-CLAUSE")
    (:inst-direct :reader "PROMOTE-DIRECT-INSTRUMENT (walker.lisp)")
    (:inst-prep   :reader "REALIZE-PP")
    (:time-prep   :reader "REALIZE-PP")
    (:thme-prep   :reader "THEME-MODIFIER (realize-clause.lisp)")
    (:adv-form    :reader "REALIZE-ADV (realize-pp.lisp)")
    ;; Declared but inert. The morphology functions take a bare lemma string
    ;; rather than a concept, so they have no way to reach a per-type override;
    ;; they consult *IRREGULAR-VERBS* instead. Registering one of these keys
    ;; does nothing at all, silently.
    (:past
     :implemented nil
     :alternative "add a row to *IRREGULAR-VERBS*, which PAST-TENSE consults")
    (:past-participle
     :implemented nil
     :alternative "add a row to *IRREGULAR-VERBS*, which PAST-PARTICIPLE consults")
    (:present-3sg
     :implemented nil
     :alternative "add a row to *IRREGULAR-VERBS*, which PRESENT-3SG consults")
    (:gerund
     :implemented nil
     :alternative "none -- PRESENT-PARTICIPLE is purely rule-driven, with no ~
                   table to override it"))
  "Every key REGISTER-LEXICON-ENTRY accepts, as (KEY &key READER IMPLEMENTED
   ALTERNATIVE). READER names what consumes the key, for the reader's benefit.
   IMPLEMENTED defaults to T; NIL marks a key that nothing reads, so setting it
   is silently ignored -- ALTERNATIVE then says what to do instead.

   REGISTER-LEXICON-ENTRY takes an unchecked &REST plist, so a misspelled key
   is accepted and ignored just as quietly. %LINT-LEXICON-OVERRIDE-KEYS exists
   to catch both cases; keep this the single source of truth so it and the
   readers can't drift.")

(defun register-lexicon-entry (type-label &rest plist)
  "Add or replace a lexicon override for TYPE-LABEL in the current environment.
   Keys are not validated here -- see *LEXICON-OVERRIDE-KEYS* and the lint
   check that reads it. Lasts until the environment's types are next loaded;
   an entry meant to stay belongs in the domain's lexicon-overrides.lisp."
  (let ((key (string-upcase (string type-label))))
    (setf (gethash key *lexicon-overrides*) plist)))

(defun register-builtin-lexicon-entry (type-label &rest plist)
  "Add or replace one of cgraph's own lexicon entries: in
   *BUILTIN-LEXICON-OVERRIDES*, for every environment loaded from now on, and
   in the current environment, so it applies at once. For cgraph's source
   files; anything else wants REGISTER-LEXICON-ENTRY or a domain file."
  (setf (gethash (string-upcase (string type-label)) *builtin-lexicon-overrides*)
        plist)
  (apply #'register-lexicon-entry type-label plist))

(defun lexicon-entry (type-or-label)
  (let ((key (cond ((symbolp type-or-label) (string-upcase (string type-or-label)))
                   ((stringp type-or-label) (string-upcase type-or-label))
                   ((typep type-or-label 'concept-type)
                    (string-upcase (string (label type-or-label))))
                   (t nil))))
    (and key (gethash key *lexicon-overrides*))))

(defun lexicon-prop (type-or-label key &optional default)
  (getf (lexicon-entry type-or-label) key default))

;;; --- A domain's own overrides -----------------------------------------------
;;; Everything registered further down this file is cgraph's own vocabulary --
;;; the weekdays, the mass nouns, the compound labels. A DOMAIN has vocabulary
;;; too, and no business being written into this file: the catalog that defines
;;; BALTIMORE as a subtype of CITY is the thing that knows BALTIMORE is a proper
;;; noun, said without an article. So a domain may ship LEXICON-OVERRIDES.LISP
;;; beside its concept-types.lisp, one form per entry, in the same shape the type
;;; files use:
;;;
;;;   (:label baltimore :proper-p t)
;;;   (:label rice      :mass-p t)
;;;   (:label belief    :lemma "believe")
;;;
;;; Each form is a REGISTER-LEXICON-ENTRY call with :LABEL naming the type, so
;;; every key that function takes works here -- see *LEXICON-OVERRIDE-KEYS* for
;;; the list and REPORT-LEXICON-LINT for the checks (a misspelled key, or one
;;; nothing reads, is a lint ERROR, and a label no concept type has is :INFO).
;;; ABSENCE IS LEGAL: a domain that needs no overrides ships no file, and that is
;;; the normal case rather than a gap.

(defparameter *domain-lexicon-file-name* "lexicon-overrides.lisp"
  "Filename a domain uses for its generation overrides, alongside its
   concept-types.lisp and relation-types.lisp.")

;;; *DOMAIN-LEXICON-FILE* and *DOMAIN-LEXICON-UNDO* live in the environment
;;; (setup/environment.lisp), beside the *LEXICON-OVERRIDES* they describe.

(defun clear-domain-lexicon-overrides ()
  "Undo every override the last domain file registered, restoring what stood
   before it. Returns nothing useful."
  (dolist (pair *domain-lexicon-undo*)
    (if (eq (cdr pair) :none)
        (remhash (car pair) *lexicon-overrides*)
        (setf (gethash (car pair) *lexicon-overrides*) (cdr pair))))
  (setf *domain-lexicon-undo* nil
        *domain-lexicon-file* nil)
  (values))

(defun register-domain-lexicon-entry (def)
  "Register one (:LABEL name :key value ...) form from a domain override file,
   remembering what it displaced so CLEAR-DOMAIN-LEXICON-OVERRIDES can put it
   back. Returns the label, or NIL for a form that is not a plist with a :LABEL
   -- which is warned about and skipped, so one bad entry costs only itself."
  (let ((label (and (listp def) (evenp (length def)) (getf def :label))))
    (cond
      ((null label)
       (warn "cgraph: ignoring malformed lexicon override ~s in ~a ~
              (want (:label NAME :key value ...))"
             def (or *domain-lexicon-file* *domain-lexicon-file-name*))
       nil)
      (t
       (let ((key   (string-upcase (string label)))
             (plist (copy-list def)))
         (remf plist :label)
         (multiple-value-bind (previous present) (gethash key *lexicon-overrides*)
           (push (cons key (if present previous :none)) *domain-lexicon-undo*))
         (apply #'register-lexicon-entry label plist)
         label)))))

(defun load-domain-lexicon-overrides (&optional (directory (domain-types-directory)))
  "Load DIRECTORY's generation overrides, replacing any previous domain's.
   Returns the file loaded, or NIL when the domain ships none.

   Called by INITIALIZE-TYPES through *DOMAIN-LEXICON-LOADER* once the type
   catalog is in place, and safe to call again by hand after editing the file."
  (let* ((dir  (uiop:ensure-directory-pathname directory))
         (path (probe-file (merge-pathnames *domain-lexicon-file-name* dir))))
    (clear-domain-lexicon-overrides)
    (when path
      ;; Plain READ, like the type loaders, and in :CG for the same reason --
      ;; a label read here is a symbol in whatever package is current.
      (let ((*package* (find-package :conceptual-graphs)))
        (with-open-file (stream path :direction :input)
          (loop for def = (read stream nil 'eof)
                until (eq def 'eof)
                do (register-domain-lexicon-entry def))))
      (setf *domain-lexicon-file* path))))

;;; Setup declares the hole (*DOMAIN-LEXICON-LOADER*) and generation fills it,
;;; the way *MASS-TYPE-P* is filled below -- generation depends on setup, never
;;; the other way about.
(defun reset-lexicon-overrides ()
  "Put the current environment's lexicon back to cgraph's built-in entries
   alone, forgetting any domain file and any REGISTER-LEXICON-ENTRY call."
  (let ((table (make-hash-table :test 'equal)))
    (maphash (lambda (key plist) (setf (gethash key table) plist))
             *builtin-lexicon-overrides*)
    (setf *lexicon-overrides*   table
          *domain-lexicon-undo* nil
          *domain-lexicon-file* nil))
  (values))

(defun mount-domain-lexicon (directory)
  "The built-in entries, then DIRECTORY's lexicon-overrides.lisp, as the current
   environment's lexicon. What INITIALIZE-TYPES calls, so that loading a type
   set always yields the same English whatever was registered before."
  (reset-lexicon-overrides)
  (load-domain-lexicon-overrides directory))

(setf *domain-lexicon-loader* #'mount-domain-lexicon)

;;; --- Part-of-speech classification ------------------------------------------

(defun safe-subtype-p (label-symbol root-symbol)
  (handler-case (subtype-p label-symbol root-symbol)
    (error () nil)))

(defparameter *pos-hierarchy-roots*
  '((act . :verb) (event . :verb) (manner . :adv) (attribute . :adj))
  "The concept-type roots POS-FROM-HIERARCHY keys on, in precedence order,
   each paired with the part of speech it implies: a concept type that is a
   subtype of the root is classified as that POS; the first match wins, and
   anything matching none falls through to :noun.

   These roots are ASSUMED to exist in the catalog. When one is absent, its
   whole POS class silently degrades to :noun (SAFE-SUBTYPE-P swallows the
   lookup error) -- %LINT-MISSING-GENERATION-ROOTS warns about exactly that.
   Keep this the single source of truth so the check and the classifier
   can't drift.")

(defun pos-from-hierarchy (concept-type)
  "Crude POS classification by walking the supertype lattice, per
   *POS-HIERARCHY-ROOTS*: subtypes of ACT/EVENT -> :verb, MANNER -> :adv,
   ATTRIBUTE -> :adj, everything else -> :noun. Falls back to :noun (also when
   a root type is missing from the catalog -- see the parameter's docstring)."
  (let ((label (label concept-type)))
    (or (loop for (root . pos) in *pos-hierarchy-roots*
              when (safe-subtype-p label root) return pos)
        :noun)))

(defparameter *generation-hierarchy-roots*
  (append
   ;; The POS roots, derived from *POS-HIERARCHY-ROOTS* so the two lists
   ;; cannot drift: adding a POS root automatically gets it linted.
   (loop for (root . pos) in *pos-hierarchy-roots*
         collect (list* root
                        :severity :warn
                        :consequence
                        (format nil "concepts that should be ~(~A~)s are ~
                                     silently classified :NOUN instead" pos)
                        :remedy
                        (format nil "define ~:@(~A~), or give the affected ~
                                     types explicit ~
                                     (register-lexicon-entry '<label> :pos ~S) ~
                                     overrides"
                                root pos)
                        (when (member root '(act event))
                          (list :also
                                "ACT-OR-EVENT-CONCEPT-P also feeds ~
                                 FIND-MAIN-PREDICATE, COPULA-REQUIRED-P and ~
                                 HAVE-CLAUSE-P, so clause structure degrades ~
                                 too -- a graph that should render as a verbal ~
                                 clause may come out copular or possessive"))))
   ;; Roots consulted outside the POS classifier. Same failure shape: the
   ;; SAFE-SUBTYPE-P call returns NIL and the caller takes its default branch.
   '((person
      :severity :warn
      :consequence "HUMAN-P is never true from the lattice, so people take ~
                    'it' rather than he/she/they"
      :remedy "define PERSON, or mark the affected types ~
               (register-lexicon-entry '<label> :human-p t)")
     (animate
      :severity :warn
      :consequence "ANIMATE-CONCEPT-P is never true from the lattice, so every ~
                    referent is treated as inanimate for pronoun and POSS choice"
      :remedy "define ANIMATE, or mark the affected types ~
               (register-lexicon-entry '<label> :animate-p t)")
     (situation
      :severity :info
      :consequence "CLAUSAL-SITUATION-P is never true, so every clausal ~
                    complement surfaces as a 'that'-clause and never as an ~
                    infinitive ('wants that he goes', not 'wants to go')"
      :remedy "define SITUATION -- there is no per-type override for this one")))
  "Every concept-type label the generation subsystem consults through
   SAFE-SUBTYPE-P, paired with what breaks when the catalog omits it.

   Entries are (ROOT &key SEVERITY CONSEQUENCE REMEDY ALSO). CONSEQUENCE,
   REMEDY and ALSO are FORMAT control strings (so they may use ~ line folds);
   they are consumed by %LINT-MISSING-GENERATION-ROOTS.

   A user is free to supply any type definitions they like, and none of these
   roots is required for the lattice, projection, query or the web UI -- they
   matter only when generating English. Because every call site guards the
   lookup, an absent root never signals: it silently degrades. That is what
   this table, and the lint check driven by it, exist to make visible.")

(defun concept-pos (concept)
  "Determine part-of-speech for CONCEPT, honoring lexicon overrides."
  (let ((ctype (concept-type concept)))
    (or (lexicon-prop ctype :pos)
        (pos-from-hierarchy ctype))))

;;; --- Lemma ------------------------------------------------------------------

(defun base-lemma (concept)
  "Lower-case lemma for CONCEPT: the dimension it is the bare filler of
   (DIMENSION-NOUN) > referent name > explicit override > type label.

   The name comes before the override: a :LEMMA says what to call one of the
   type's members that has no name -- US-STATE's \"state\", in \"drives to a
   state\" -- and a name is what to call this one. With the two the other way
   round, [US-STATE: Maryland] said \"drives to State\"."
  (let* ((ctype  (concept-type concept))
         ;; [CAR] says "car" even though its type is AUTOMOBILE: the name it
         ;; was written with wins, and an alias may have a :LEMMA of its own.
         ;; It takes the place of the type's label, and of the type's :LEMMA;
         ;; a referent's name still comes first.
         (spelling (concept-type-name concept))
         (alias-p  (and spelling ctype (not (eq spelling (label ctype)))))
         (override (lexicon-prop (if alias-p spelling ctype) :lemma))
         (ref (referent concept))
         (name (and ref (referent-name concept)))
         (dimension (dimension-noun concept)))
    (cond (dimension dimension)
          ((and name (stringp name) (plusp (length name))) name)
          (override override)
          (t (string-downcase (string (or spelling (label ctype))))))))

(defun proper-name-p (concept)
  "True if the lemma should be treated as a proper noun (no article, capitalized)."
  (or (lexicon-prop (concept-type concept) :proper-p)
      (let* ((ref (referent concept))
             (name (and ref (referent-name concept))))
        (and name (stringp name) (plusp (length name))))))

(defun mass-noun-p (concept)
  (lexicon-prop (concept-type concept) :mass-p))

;;; --- Indexical pronouns -----------------------------------------------------
;;; A pronoun with no antecedent to resolve to is an INDEXICAL: it names its
;;; referent by pointing, and the graph records that as an individual whose name
;;; IS the pronoun -- [PERSON: You] for an imperative's implicit subject,
;;; [PERSON: She] for a `her' nothing bound. Realized as an ordinary name, those
;;; come out "The woman sees She." and "You sees the dog.": English inflects a
;;; pronoun for CASE, which a name never has, and agrees a verb with its PERSON,
;;; which a name always settles as third.
;;;
;;; So the generator reads such a name back as the pronoun it is. Every form is
;;; a key, since a graph may well say [PERSON: Him] where the extractor writes
;;; the root.

(defparameter *personal-pronoun-forms*
  '(("i"    1 :singular "I"    "me"   "my")
    ("we"   1 :plural   "we"   "us"   "our")
    ("you"  2 :singular "you"  "you"  "your")
    ("he"   3 :singular "he"   "him"  "his")
    ("she"  3 :singular "she"  "her"  "her")
    ("it"   3 :singular "it"   "it"   "its")
    ("they" 3 :plural   "they" "them" "their"))
  "(KEY PERSON NUMBER NOMINATIVE ACCUSATIVE POSSESSIVE) for each personal
   pronoun. The case columns are the surface forms; PERSON and NUMBER are what
   a verb agrees with. \"I\" is capitalized because English capitalizes it
   everywhere, not because anything here is sentence-initial.")

(defun personal-pronoun-row (name)
  "The *PERSONAL-PRONOUN-FORMS* row NAME is any form of, or NIL. Case-blind,
   and every column is a key: `her', `she' and `hers'-less as it is, all find
   the same row."
  (and (stringp name)
       (find-if (lambda (row)
                  (or (string-equal name (first row))
                      (member name (cdddr row) :test #'string-equal)))
               *personal-pronoun-forms*)))

(defun indexical-pronoun-row (concept)
  "CONCEPT's pronoun row when it is an indexical pronoun individual -- a
   referent whose NAME is a pronoun -- else NIL."
  (let* ((ref  (and (typep concept 'concept) (referent concept)))
         (name (and ref (referent-name concept))))
    (personal-pronoun-row name)))

(defun indexical-pronoun-form (concept &optional (case :nominative))
  "The surface form CONCEPT takes in CASE when it is an indexical pronoun
   ([PERSON: She] + :accusative -> \"her\"), else NIL."
  (let ((row (indexical-pronoun-row concept)))
    (and row (ecase case
               (:nominative (fourth row))
               (:accusative (fifth  row))
               (:possessive (sixth  row))))))

;;; --- Number, person, definiteness from referent -----------------------------

(defun concept-number (concept)
  "Return :plural if the concept's referent denotes a set, else :singular.
   An indexical pronoun answers for itself: [PERSON: They] is one referent and
   plural all the same, and the verb has to agree with it."
  (cond ((let ((row (indexical-pronoun-row concept)))
           (and row (third row))))
        ((set-spec concept) :plural)
        ;; Set-typed referent (e.g. parsed from '[DOG: {*}]') means plural.
        ((let ((ref (referent concept)))
           (and ref (set-p ref)))
         :plural)
        (t :singular)))

(defun concept-person (concept)
  "Grammatical person for verb agreement: 1 or 2 for an indexical pronoun that
   is one ([PERSON: I], [PERSON: You]), else 3.

   Everything else in a graph IS third person -- a concept names something
   spoken about. A pronoun is the exception, because it names a role in the
   speech situation instead, and \"I sees the dog\" is what came of ignoring
   that."
  (or (second (indexical-pronoun-row concept)) 3))

(defun concept-definiteness (concept)
  "Return :definite / :indefinite / :proper / :universal / :existential.
   '@every' -> :universal, '@some' -> :existential, named individual ->
   :proper, an individual introduced with \"a\" (CONCEPT-INTRODUCED
   :indefinite) -> :indefinite, bare or numbered individual marker ([T: #] /
   [T: #4]) -> :definite, otherwise :indefinite."
  (let ((quant (and (typep concept 'concept) (concept-quantifier concept))))
    (cond ((eq quant :universal)   :universal)
          ((eq quant :existential) :existential)
          ((proper-name-p concept) :proper)
          ((and (typep concept 'concept)
                (eq (concept-introduced concept) :indefinite))
           :indefinite)
          ((let ((ref (referent concept)))
             (and ref (individual-p (content ref))))
           :definite)
          (t :indefinite))))

;;; --- Irregular tables (small starters; extend as needed) --------------------

(defparameter *irregular-verbs*
  ;; (lemma past past-participle present-3sg)
  '(("be"    "was"   "been"   "is")
    ("have"  "had"   "had"    "has")
    ("do"    "did"   "done"   "does")
    ("eat"   "ate"   "eaten"  "eats")
    ("go"    "went"  "gone"   "goes")
    ("give"  "gave"  "given"  "gives")
    ("take"  "took"  "taken"  "takes")
    ("make"  "made"  "made"   "makes")
    ("see"   "saw"   "seen"   "sees")
    ("come"  "came"  "come"   "comes")
    ("get"   "got"   "gotten" "gets")
    ("know"  "knew"  "known"  "knows")
    ("think" "thought" "thought" "thinks")
    ("say"   "said"  "said"   "says")
    ("find"  "found" "found"  "finds")
    ("tell"  "told"  "told"   "tells")
    ("become" "became" "become" "becomes")
    ("leave" "left"  "left"   "leaves")
    ("feel"  "felt"  "felt"   "feels")
    ("bring" "brought" "brought" "brings")
    ("begin" "began" "begun"  "begins")
    ("keep"  "kept"  "kept"   "keeps")
    ("hold"  "held"  "held"   "holds")
    ("write" "wrote" "written" "writes")
    ("stand" "stood" "stood"  "stands")
    ("sit"   "sat"   "sat"    "sits")
    ("lie"   "lay"   "lain"   "lies")
    ("lay"   "laid"  "laid"   "lays")
    ("run"   "ran"   "run"    "runs")
    ("ride"  "rode"  "ridden" "rides")
    ("drive" "drove" "driven" "drives")
    ("fly"   "flew"  "flown"  "flies")
    ("buy"   "bought" "bought" "buys")
    ("send"  "sent"  "sent"   "sends")
    ("build" "built" "built"  "builds")
    ("teach" "taught" "taught" "teaches")
    ("catch" "caught" "caught" "catches")
    ("read"  "read"  "read"   "reads")
    ("hear"  "heard" "heard"  "hears")
    ("speak" "spoke" "spoken" "speaks")
    ("pay"   "paid"  "paid"   "pays")
    ("meet"  "met"   "met"    "meets")
    ("set"   "set"   "set"    "sets")
    ("hit"   "hit"   "hit"    "hits")
    ("put"   "put"   "put"    "puts")
    ("cut"   "cut"   "cut"    "cuts")
    ("bite"  "bit"   "bitten" "bites")
    ("drink" "drank" "drunk"  "drinks")
    ("sing"  "sang"  "sung"   "sings")
    ("ring"  "rang"  "rung"   "rings")
    ("swim"  "swam"  "swum"   "swims")
    ("fall"  "fell"  "fallen" "falls")
    ("rise"  "rose"  "risen"  "rises")
    ("grow"  "grew"  "grown"  "grows")
    ("throw" "threw" "thrown" "throws")
    ("blow"  "blew"  "blown"  "blows")
    ("draw"  "drew"  "drawn"  "draws")
    ("wear"  "wore"  "worn"   "wears")
    ("tear"  "tore"  "torn"   "tears")
    ("break" "broke" "broken" "breaks")
    ("choose" "chose" "chosen" "chooses")
    ("steal" "stole" "stolen" "steals")
    ("sleep" "slept" "slept"  "sleeps")
    ("lose"  "lost"  "lost"   "loses")
    ("spend" "spent" "spent"  "spends")
    ("lend"  "lent"  "lent"   "lends")
    ("sell"  "sold"  "sold"   "sells")))

(defparameter *irregular-plurals*
  '(("man"   "men")
    ("woman" "women")
    ("child" "children")
    ("person" "people")
    ("foot"  "feet")
    ("tooth" "teeth")
    ("goose" "geese")
    ("mouse" "mice")
    ("ox"    "oxen")
    ("sheep" "sheep")
    ("fish"  "fish")
    ("deer"  "deer")
    ("series" "series")
    ("species" "species")))

(defparameter *string-keyed-generation-tables*
  ;; (SYMBOL ARITY COLUMN-NAMES CONSULTED-BY). *UNIT-WORDS* lives in
  ;; morphology.lisp, which loads after this file -- the symbol is quoted and
  ;; only dereferenced at lint time, so load order doesn't matter.
  '((*irregular-verbs* 4
     ("lemma" "past" "past participle" "present-3sg")
     "PAST-TENSE, PAST-PARTICIPLE and PRESENT-3SG")
    (*irregular-plurals* 2
     ("lemma" "plural")
     "PLURALIZE")
    (*unit-words* 3
     ("abbreviation" "singular" "plural")
     "EXPAND-UNITS"))
  "The generation tables keyed on surface strings rather than on type labels.

   These are looked up by lemma, independently of the type lattice, which is
   what makes them different in kind from *LEXICON-OVERRIDES*: they are general
   English data, not bindings to your ontology. So there is deliberately NO
   staleness check for them -- a row for a word your catalog never mentions is
   the normal case, not a defect, and reporting those would bury the report.

   What can go wrong is internal: a row of the wrong arity silently yields NIL
   for the missing column and the caller falls back to the regular rule, a
   duplicate lemma is shadowed by the earlier row because lookup is by ASSOC,
   and a row that merely restates what the rules already derive is dead weight.
   Those are what the lint checks.")

(defun verb-lemma-of-form (word)
  "The lemma an inflected verb form belongs to, or NIL.

   IRREGULAR-VERB-FORM read backwards. The table is written lemma-first
   because generation asks \"what is EAT's past?\", but a consumer coming the
   other way -- a parser handing over the surface word `ate' to a catalog that
   only knows EAT -- needs the same rows read in reverse, and the data should
   not be written twice to answer the same question from two sides."
  (let ((w (string-downcase (string word))))
    (loop for (lemma past participle present-3sg) in *irregular-verbs*
          when (or (string-equal w past)
                   (string-equal w participle)
                   (string-equal w present-3sg))
            return lemma)))

(defun irregular-verb-form (lemma form)
  "FORM is one of :past :past-participle :present-3sg. Returns NIL if not irregular."
  (let ((row (assoc lemma *irregular-verbs* :test #'string-equal)))
    (when row
      (ecase form
        (:past            (second row))
        (:past-participle (third row))
        (:present-3sg     (fourth row))))))

(defun irregular-plural (lemma)
  (let ((row (assoc lemma *irregular-plurals* :test #'string-equal)))
    (and row (second row))))

;;; --- Mass-noun registrations -----------------------------------------------
;;; Mass nouns take no indefinite article ("food", not "a food"). Register a
;;; common starter set; users can extend with REGISTER-LEXICON-ENTRY.

(dolist (m '(food water milk coffee tea juice beer wine bread rice
             salt sugar butter cheese meat soup
             information music news advice knowledge evidence
             money gold silver oil gas air
             furniture equipment luggage clothing software
             substance))
  (register-builtin-lexicon-entry m :mass-p t))

;;; Teach the reader which types are mass nouns. Core declares *MASS-TYPE-P*
;;; and leaves it NIL; filling it here keeps the dependency pointing the way
;;; the systems already do, generation onto core.
(setf *mass-type-p* (lambda (ctype) (lexicon-prop ctype :mass-p)))

;;; --- What is NOT here ------------------------------------------------------
;;; Entries that exist because of how an ontology names or places a type --
;;; a label qualified to disambiguate (CHEVY-VEHICLE -> "Chevy",
;;; GEOPOLITICAL-STATE -> "state"), a compound label whose hyphen shouldn't
;;; reach the reader (BODY-PART), a noun filed under EVENT (PARTY) -- belong in
;;; that type set's lexicon-overrides.lisp, not here: another ontology may name
;;; the same thing differently. This file holds facts about English words.
;;; cgraph-types, default-types/ and test/test-types/ each carry their own.

;;; --- Days of the week ------------------------------------------------------
;;; Proper nouns, so no article and a capital: "on Friday", not "at a friday".
;;; And "on" rather than :time's own "at", which is right for a clock time and
;;; wrong for a day. The deictic days -- TODAY, TOMORROW, YESTERDAY -- are NOT
;;; here: TEMPORAL-ADVERB-FORM drops their preposition entirely and says "a girl
;;; ate a pie yesterday", which is what English does with them.

(dolist (day '(monday tuesday wednesday thursday friday saturday sunday))
  (register-builtin-lexicon-entry day :proper-p t :time-prep "on"))

;;; --- Communication media ---------------------------------------------------
;;; A medium is mass ("she told him by email"); the countable thing is the
;;; message that travels on it (a letter, an email message). On an instrument
;;; arc it wants "by" rather than :inst's default "with" -- you reach someone
;;; BY post but WITH a pen.

(register-builtin-lexicon-entry 'email     :mass-p t :inst-prep "by")
(register-builtin-lexicon-entry 'post      :mass-p t :inst-prep "by")

;;; --- Adverb-form overrides -------------------------------------------------
;;; Some types are abstract category labels rather than specific adjectives,
;;; so suffix-derivation produces nonsense (MANNER -> "mannerly"). Provide
;;; an :adv-form override that realize-adv consults first.

(register-builtin-lexicon-entry 'manner :adv-form "somehow")
;; keyed on the TIME-PERIOD concept, not the `time' relation (which is not a
;; concept type) -- completes the somehow/sometime/somewhere trio.
;; NO :lemma here, though "a time-period" reads as badly as the rest. BASE-LEMMA
;; ranks an override ABOVE a referent name, and this type's instances carry
;; their meaning in the referent -- [TIME-PERIOD: yesterday]. An override
;; shadows that, TEMPORAL-ADVERB-FORM stops recognising the deictic, and
;; "A girl ate a pie yesterday" becomes "A girl eats a pie at Time period".
;; Four generation-test cases catch it; this comment is so it is not re-added.
(register-builtin-lexicon-entry 'time-period :adv-form "sometime")
(register-builtin-lexicon-entry 'place  :adv-form "somewhere")

;;; --- Verb-form overrides for state-noun types ------------------------------
;;; When a state-noun type is used as the main predicate of a clause, we need
;;; the corresponding verb form. BELIEF -> "believe", INTENTION -> "intend",
;;; THOUGHT -> "think", etc.

;;; --- Particle (phrasal-verb) overrides -------------------------------------
;;; '[PICK-UP]' surfaces as 'pick up'; the inflectable verb is the lemma and
;;; the particle is appended after the main verb form. Register particle
;;; verbs here (or via register-lexicon-entry from user code).

(register-builtin-lexicon-entry 'pick-up   :lemma "pick"  :particle "up")
(register-builtin-lexicon-entry 'carry-out :lemma "carry" :particle "out")
(register-builtin-lexicon-entry 'turn-off  :lemma "turn"  :particle "off")
(register-builtin-lexicon-entry 'turn-on   :lemma "turn"  :particle "on")

(register-builtin-lexicon-entry 'belief    :lemma "believe" :raising t)
(register-builtin-lexicon-entry 'intention :lemma "intend")
(register-builtin-lexicon-entry 'thought   :lemma "think")
(register-builtin-lexicon-entry 'hope      :lemma "hope")
(register-builtin-lexicon-entry 'fear      :lemma "fear")
(register-builtin-lexicon-entry 'wish      :lemma "wish")

;;; --- Raising verbs (Sowa Rule 4 second half) ------------------------------
;;; Cognitive verbs that, when their AGNT/EXPR is absent (passive use),
;;; render with the inner subject lifted to the outer surface subject:
;;; '[KNOW]->(stat)->[PROPOSITION: [Ivan]->(loc)->[PLACE]]' becomes
;;; 'Ivan is known to be in a place' rather than 'A know.' or
;;; 'It is known that Ivan is in a place'.

(register-builtin-lexicon-entry 'know :raising t)

;;; --- Argument-frame overrides for communication verbs ---------------------
;;; By default the CG :dobj surfaces as direct object and :rcpt as 'to X'.
;;; Communication verbs flip this: the recipient is unmarked, the info is a
;;; PP. ':rcpt-direct t' triggers the swap; ':obj-prep' picks the preposition.

(register-builtin-lexicon-entry 'inform :rcpt-direct t :obj-prep "about")
(register-builtin-lexicon-entry 'notify :rcpt-direct t :obj-prep "about")
(register-builtin-lexicon-entry 'advise :rcpt-direct t :obj-prep "about")
(register-builtin-lexicon-entry 'remind :rcpt-direct t :obj-prep "of")
(register-builtin-lexicon-entry 'warn   :rcpt-direct t :obj-prep "about")
(register-builtin-lexicon-entry 'ask    :rcpt-direct t :obj-prep "about")
;; Double-object verbs: the info NP follows the recipient with no preposition
;; ("tell her the news", "teach the kids math").
(register-builtin-lexicon-entry 'tell   :rcpt-direct t :obj-prep nil)
(register-builtin-lexicon-entry 'teach  :rcpt-direct t :obj-prep nil)
(register-builtin-lexicon-entry 'show   :rcpt-direct t :obj-prep nil)

;;; --- Verbs whose instrument is their object --------------------------------
;;; You drive a car, not "drive with a car": with no OBJ, the INST arc is the
;;; direct object (and the passive subject, "the car was driven"). An English
;;; fact about the verb, like :rcpt-direct above. With an OBJ present the
;;; instrument stays a PP -- "drive Sue with the van".

(register-builtin-lexicon-entry 'drive :inst-direct t)
