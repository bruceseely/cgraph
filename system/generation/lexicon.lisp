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

(defparameter *lexicon-overrides* (make-hash-table :test 'equal)
  "Per-concept-type overrides on the derivational defaults. Key: upcased label
   string. Value: a plist. See notes/lexicon-overrides.md for the full reference.
   Canonical keys:
     Word form:  :lemma :plural :past :past-participle :present-3sg :gerund
                 :particle
     Noun class: :pos :mass-p :proper-p :gender (:masc/:fem) :ungendered
                 :human-p :animate-p
     Verb frame: :raising :rcpt-direct :obj-prep :adv-form")

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
    (:human-p     :reader "HUMAN-P")
    (:animate-p   :reader "ANIMATE-CONCEPT-P")
    (:raising     :reader "GRAPH-TO-TEXT dispatch")
    (:rcpt-direct :reader "REALIZE-CLAUSE")
    (:obj-prep    :reader "REALIZE-CLAUSE")
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
  "Add or replace a lexicon override for TYPE-LABEL. Keys are not validated
   here -- see *LEXICON-OVERRIDE-KEYS* and the lint check that reads it."
  (let ((key (string-upcase (string type-label))))
    (setf (gethash key *lexicon-overrides*) plist)))

(defun lexicon-entry (type-or-label)
  (let ((key (cond ((symbolp type-or-label) (string-upcase (string type-or-label)))
                   ((stringp type-or-label) (string-upcase type-or-label))
                   ((typep type-or-label 'concept-type)
                    (string-upcase (string (label type-or-label))))
                   (t nil))))
    (and key (gethash key *lexicon-overrides*))))

(defun lexicon-prop (type-or-label key &optional default)
  (getf (lexicon-entry type-or-label) key default))

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
  "Lower-case lemma for CONCEPT: explicit override > referent name > type label."
  (let* ((ctype  (concept-type concept))
         (override (lexicon-prop ctype :lemma))
         (ref (referent concept))
         (name (and ref (referent-name concept))))
    (cond (override override)
          ((and name (stringp name) (plusp (length name))) name)
          (t (string-downcase (label ctype))))))

(defun proper-name-p (concept)
  "True if the lemma should be treated as a proper noun (no article, capitalized)."
  (or (lexicon-prop (concept-type concept) :proper-p)
      (let* ((ref (referent concept))
             (name (and ref (referent-name concept))))
        (and name (stringp name) (plusp (length name))))))

(defun mass-noun-p (concept)
  (lexicon-prop (concept-type concept) :mass-p))

;;; --- Number, person, definiteness from referent -----------------------------

(defun concept-number (concept)
  "Return :plural if the concept's referent denotes a set, else :singular."
  (cond ((set-spec concept) :plural)
        ;; Set-typed referent (e.g. parsed from '[DOG: {*}]') means plural.
        ((let ((ref (referent concept)))
           (and ref (set-p ref)))
         :plural)
        (t :singular)))

(defun concept-person (concept)
  ;; Phase 2: no first/second-person referents in the schema; default 3rd.
  (declare (ignore concept))
  3)

(defun concept-definiteness (concept)
  "Return :definite / :indefinite / :proper / :universal / :existential.
   '@every' -> :universal, '@some' -> :existential, named individual ->
   :proper, bare or numbered individual marker ([T: #] / [T: #4]) ->
   :definite, otherwise :indefinite."
  (let ((quant (and (typep concept 'concept) (concept-quantifier concept))))
    (cond ((eq quant :universal)   :universal)
          ((eq quant :existential) :existential)
          ((proper-name-p concept) :proper)
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
  (register-lexicon-entry m :mass-p t))

;;; Teach the reader which types are mass nouns. Core declares *MASS-TYPE-P*
;;; and leaves it NIL; filling it here keeps the dependency pointing the way
;;; the systems already do, generation onto core.
(setf *mass-type-p* (lambda (ctype) (lexicon-prop ctype :mass-p)))

;;; --- Adverb-form overrides -------------------------------------------------
;;; Some types are abstract category labels rather than specific adjectives,
;;; so suffix-derivation produces nonsense (MANNER -> "mannerly"). Provide
;;; an :adv-form override that realize-adv consults first.

(register-lexicon-entry 'manner :adv-form "somehow")
;; keyed on the TIME-PERIOD concept, not the `time' relation (which is not a
;; concept type) -- completes the somehow/sometime/somewhere trio.
(register-lexicon-entry 'time-period :adv-form "sometime")
(register-lexicon-entry 'place  :adv-form "somewhere")

;;; --- Verb-form overrides for state-noun types ------------------------------
;;; When a state-noun type is used as the main predicate of a clause, we need
;;; the corresponding verb form. BELIEF -> "believe", INTENTION -> "intend",
;;; THOUGHT -> "think", etc.

;;; --- Particle (phrasal-verb) overrides -------------------------------------
;;; '[PICK-UP]' surfaces as 'pick up'; the inflectable verb is the lemma and
;;; the particle is appended after the main verb form. Register particle
;;; verbs here (or via register-lexicon-entry from user code).

(register-lexicon-entry 'pick-up   :lemma "pick"  :particle "up")
(register-lexicon-entry 'carry-out :lemma "carry" :particle "out")
(register-lexicon-entry 'turn-off  :lemma "turn"  :particle "off")
(register-lexicon-entry 'turn-on   :lemma "turn"  :particle "on")

(register-lexicon-entry 'belief    :lemma "believe" :raising t)
(register-lexicon-entry 'intention :lemma "intend")
(register-lexicon-entry 'thought   :lemma "think")
(register-lexicon-entry 'hope      :lemma "hope")
(register-lexicon-entry 'fear      :lemma "fear")
(register-lexicon-entry 'wish      :lemma "wish")

;;; --- Raising verbs (Sowa Rule 4 second half) ------------------------------
;;; Cognitive verbs that, when their AGNT/EXPR is absent (passive use),
;;; render with the inner subject lifted to the outer surface subject:
;;; '[KNOW]->(stat)->[PROPOSITION: [Ivan]->(loc)->[PLACE]]' becomes
;;; 'Ivan is known to be in a place' rather than 'A know.' or
;;; 'It is known that Ivan is in a place'.

(register-lexicon-entry 'know :raising t)

;;; --- Argument-frame overrides for communication verbs ---------------------
;;; By default the CG :dobj surfaces as direct object and :rcpt as 'to X'.
;;; Communication verbs flip this: the recipient is unmarked, the info is a
;;; PP. ':rcpt-direct t' triggers the swap; ':obj-prep' picks the preposition.

(register-lexicon-entry 'inform :rcpt-direct t :obj-prep "about")
(register-lexicon-entry 'notify :rcpt-direct t :obj-prep "about")
(register-lexicon-entry 'advise :rcpt-direct t :obj-prep "about")
(register-lexicon-entry 'remind :rcpt-direct t :obj-prep "of")
(register-lexicon-entry 'warn   :rcpt-direct t :obj-prep "about")
(register-lexicon-entry 'ask    :rcpt-direct t :obj-prep "about")
;; Double-object verbs: the info NP follows the recipient with no preposition
;; ("tell her the news", "teach the kids math").
(register-lexicon-entry 'tell   :rcpt-direct t :obj-prep nil)
(register-lexicon-entry 'teach  :rcpt-direct t :obj-prep nil)
(register-lexicon-entry 'show   :rcpt-direct t :obj-prep nil)
