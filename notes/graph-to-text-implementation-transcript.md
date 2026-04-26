# CGraph: Graph-to-Text Implementation Transcript

Source session: `e649fb12-f4ad-4ee3-9287-01385185c0b1.jsonl`

---

## User

<local-command-stdout>Set model to [1mOpus 4.7[22m</local-command-stdout>

## User

I would like to implement an algorithm to convert a conceptual graph to English text. Sowa describes an approach in his 1984 book. I have put the text of the six rules in athe file cgraph/notes/graph-to-text-rules.text.

I think implementing  it will be very involved and has some requirements. For instance it wants to have access to semantic information about words. It looks like it needs a dictionary, and I'm not sure if it will be possible to obtain one.

Will you do the following:
1. determine whether the references document is sufficient, given that requirements can be met
2. determine what resources will be required and whether it looks like they can be obtained

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/notes/graph-to-text-rules.text`

## Assistant

*[tool: Bash]* `List repo structure` — `ls /Users/bseely/repo/cgraph/ && echo "---" && ls /Users/bseely/repo/cgraph/system/`

## Assistant

*[tool: Bash]* `List core and operations folders` — `ls /Users/bseely/repo/cgraph/system/core/ /Users/bseely/repo/cgraph/system/operations/`

## Assistant

*[tool: Bash]* `Look for relation type definitions` — `grep -l "AGNT\|OBJ\|RCPT\|INST\|MANR\|LOC" /Users/bseely/repo/cgraph/default-types/* /Users/bseely/repo/cgraph/system/co`

## Assistant

*[tool: Bash]* `Look at default type files` — `ls /Users/bseely/repo/cgraph/default-types/ && echo "---" && grep -E "(AGNT|OBJ|RCPT|INST|MANR|LOC|relation)" /Users/bse`

## Assistant

*[tool: Bash]* `Check relation-types file` — `head -50 /Users/bseely/repo/cgraph/default-types/relation-types.text`

## Assistant

I read the rules document, looked at your relation-types and concept-types files. Here's my read.

## 1. Are the six rules sufficient?

**No, not on their own — but Sowa says so himself.** The closing paragraph: *"Since the universal rules for translating graphs to sentences allow many options, they must be supplemented with particular rules for any specific language."*

What the rules actually give you is a **traversal skeleton**: in what order to visit concept/relation nodes (Rule 1, 6), when to use anaphora vs. full noun phrase (Rule 5), how to handle nested graphs (Rule 4), and constraints on where constituents can land (Rule 3). They are control-flow, not realization. They tell you *when* a concept gets uttered, not *what word* comes out or how it's inflected.

To produce actual English you need four things the rules deliberately leave open:

| Need | What the rules say | What you must supply |
|---|---|---|
| Lexical realization (concept → word) | "syntactic rules determine when … uttered as a word" (Rule 2) | A concept-type → lexeme(s) mapping |
| Arc-choice at branches | "syntactic and stylistic rules determine which arc" (Rule 1) | An English-specific ordering: AGNT first, then OBJ, then PP-modifiers, etc. |
| Morphology & function words | not addressed | Verb tense, plural, articles, prepositions tied to relation types |
| Anaphora form | "pronoun or short noun phrase" (Rule 5) | Rules to pick *he/she/it/they/the X* |

So the document is sufficient as a **specification of the path-walking algorithm**. It is not sufficient as a generation algorithm.

## 2. Resources required and obtainability

The good news: you already have most of what's needed in this repo. The hard external dependency people usually fear (a big lexicon) is largely sidestepped because your concept types **already are** the lexicon.

**(a) Concept-type → word — mostly already present**
Your type labels (`LAY`, `MAKE`, `COLOR`, `EAT`) already carry the lexical root. You'd need a thin overlay table for: irregular forms, multi-word expressions ("verb-particle" cases Rule 2 mentions), and part-of-speech tagging (which types are verbs vs. nouns vs. adjectives — `act` subtypes are verbs, `attribute` subtypes are adjectives, `entity` subtypes are nouns). This is a few hundred entries, hand-built, and it grows with your ontology naturally. **Obtainable: yes, mostly free from existing data.**

**(b) Relation-type → syntactic role — small fixed table**
Your `relation-types.text` already has the semantics. The mapping is short and well-known from the CG literature:
- AGNT → subject
- OBJ / PTNT → direct object
- RCPT → "to X" / indirect object
- INST → "with X"
- LOC → "in/at X"
- MANR → adverb
- ATTR / CHRC → adjective
- POSS → "X's Y" or "Y of X"
- TIME / DUR → "when/for X"
- PART → "of X"

About 20–30 entries covers the standard set. **Obtainable: yes, hand-build it.**

**(c) Morphology — write a small library**
English inflection is regular enough that ~200 lines of Lisp covers verb conjugation (regulars + an irregulars table of ~150 verbs), pluralization, and a/an/the selection driven by the referent (`*` → indefinite, named individual → definite or bare, `∀`/`@every` → "every", etc.). A full lexical resource (WordNet, freely downloadable from Princeton; CL bindings exist via `wordnet` ASDF systems) is *available* but probably overkill at first — your ontology defines the vocabulary you care about. **Obtainable: yes, no external dependency strictly required.**

**(d) APSG / Heidorn's NLP — skip it**
Sowa cites Heidorn (1972, 1975) as the grammar formalism. That code was IBM-internal and not realistically obtainable. You don't need it — a templated phrase-structure grammar keyed off relation type is perfectly serviceable and is what most modern CG-to-text implementations actually use.

**(e) Anaphora — heuristic**
Track uttered concepts in a hash table during the walk. On revisit, emit a pronoun (gender/number from the type: PERSON+male → "he", inanimate → "it", PL referent → "they"); fall back to "the X" if pronoun would be ambiguous. Rule 5 is satisfiable without any external resource.

## Bottom line

- **The document is a sufficient specification of the traversal algorithm**, but you will be writing several hundred to ~1500 lines of English-specific realization code on top of it. Sowa is explicit that this layer is your responsibility.
- **All required resources are obtainable** without expensive external dependencies. A useful first version can be built entirely from data you already have (type hierarchy + relation types + their descriptions) plus hand-written tables.
- **Recommended scoping for a v1**: implement Rules 1, 3, 5, 6 fully on simple non-nested graphs; defer Rule 4 (raising) and the verb-particle case in Rule 2; produce active-voice present-tense English only. That gets you something that prints recognizable sentences from your demo graphs, and the harder cases can be added incrementally.

Want me to sketch a concrete phased implementation plan with file/module boundaries before writing any code?

## User

yes!

## Assistant

## Phased Implementation Plan

### Module layout (new directory: `system/generation/`)

```
system/generation/
  lexicon.lisp          ; concept-type → word(s), POS, irregulars
  syntax-roles.lisp     ; relation-type → syntactic role table
  morphology.lisp       ; conjugation, pluralization, articles, pronouns
  walker.lisp           ; utterance-path traversal (Rules 1,3,5,6)
  realizer.lisp         ; emits surface tokens during walk
  anaphora.lisp         ; visited-set + pronoun/short-NP selection
  generate.lisp         ; top-level entry: (graph-to-text graph) → string
  nested.lisp           ; Rule 4 nested-graph handling (phase 3)
test/
  generation-tests.lisp
```

Add `:cgraph/generation` system in `cgraph.asd` depending on `:cgraph/core`.

---

### Phase 1 — Walking skeleton (Rules 1, 6)

**Goal:** produce ordered token stream from a simple AGNT-rooted graph; no morphology yet.

- `walker.lisp`
  - `find-utterance-start (graph)` — locate AGNT (active) or OBJ/RCPT (passive) relation; fall back to first relation
  - `make-walk-state` — utterance-marks (concept→bool), traversal-marks (relation→bool), visit-counts
  - `walk-graph (graph state visitor)` — DFS that respects "don't return to caller until all relations of c traversed" (Rule 1) and ends at main predicate (Rule 6)
- `syntax-roles.lisp`
  - Static alist: `((agnt :subject) (obj :dobj) (rcpt :iobj "to") (inst :pp "with") (loc :pp "in") (manr :adv) (attr :adj) (chrc :adj) (poss :poss) (part :pp "of") (time :pp "at") (dur :pp "for") (dest :pp "to") ...)`
  - `relation-role (rel-type)` lookup
  - `arc-priority` ordering for branch selection (subject > dobj > iobj > pp-modifiers, manner-before-time per English convention)
- `realizer.lisp`
  - First cut: emit raw type label as word; print Subject Verb Object PP* in order
- `generate.lisp` — `(graph-to-text g)` returning a string

**Deliverable:** `[CAT] ← (AGNT) ← [SIT] → (LOC) → [MAT]` produces `"cat sit on mat"`.

### Phase 2 — Morphology and function words

- `morphology.lisp`
  - `pluralize (noun)` — regular rules + irregulars table (~50 entries)
  - `conjugate (verb tense person number)` — regular -s/-ed/-ing + irregulars table (~150 entries) loaded from data file
  - `article-for (concept)` — derive a/an/the/some/every from referent (`*` → indefinite, named → "the"+name or just name, `∀`/`@every` → "every", `{*}` set → plural, count-referent → numeric)
  - `inflect-verb-by-subject (verb subject-concept)`
- `lexicon.lisp`
  - `concept-type-pos (type)` — walks supertype chain: `act` → :verb, `attribute` → :adj, `entity`/`object`/`person` etc → :noun
  - `concept-type-lemma (type)` — default = downcased label; override table for multi-word and irregular cases
  - Data file: `default-types/lexicon-overrides.text` with `(:label wear-out :lemma "wear out" :pos :verb :past "wore out")`
- Update `realizer.lisp` to call lexicon + morphology; insert prepositions from `syntax-roles`

**Deliverable:** `"the cat sat on the mat"`, `"a dog bites the mailman"`.

### Phase 3 — Anaphora and cycles (Rule 5)

- `anaphora.lisp`
  - Pre-walk pass: count incoming reference paths per concept; mark cycle joins
  - On revisit during walk: select `:pronoun` (he/she/it/they from gender/animacy/number derivable from concept-type position in hierarchy: PERSON+MALE→he, ANIMATE→it, plural-referent→they) or `:short-np` ("the X") based on disambiguation need
  - Track recent-mention queue for pronoun ambiguity check
- Hook into `walker.lisp` so first visit emits full NP, subsequent visits emit anaphor

**Deliverable:** correct handling of graphs where two arcs converge on one concept.

### Phase 4 — Adjacency markers (Rule 3)

- When walker takes a non-adjacent arc (skips a concept it must come back to), `realizer.lisp` inserts: relative pronouns (`that`/`who`/`which`), commas, or coordinating conjunctions
- `realizer.lisp` gets a `branch-marker` op invoked by walker on branch entry/exit

### Phase 5 — Nested graphs (Rule 4, basic)

- `nested.lisp`
  - Detect concepts whose referent is a graph (PROPOSITION, SITUATION contexts)
  - Default: full nested expression at containing-node visit, wrapped with `that`/`to`-clause
  - Hook for raising left as TODO

### Phase 6 — Polish, voice selection, defer-list

- Heuristic active/passive choice (passive when AGNT absent or when topic is OBJ)
- Capitalize first word, terminal punctuation
- Tense from referent or `dur`/`time` relations; default present
- Document explicitly deferred: verb-particle splitting (Rule 2 second half), Rule 4 raising, Rule 6 graph decomposition by inference

---

### Testing plan

- `test/generation-tests.lisp` — round-trip-ish: hand-authored graphs → expected string (or string-set, since multiple realizations are valid)
- Start with the canonical-graph strings already in `default-types/concept-types.text` as the test corpus — they're labeled, simple, and exercise the common relation set
- One test per phase's deliverable

### Effort estimate

| Phase | Rough size | What unblocks |
|---|---|---|
| 1 | ~200 LOC | All later phases |
| 2 | ~400 LOC + data | Readable output |
| 3 | ~150 LOC | Multi-clause graphs |
| 4 | ~100 LOC | Relative clauses |
| 5 | ~150 LOC | Belief/proposition contexts |
| 6 | ~150 LOC | Production quality |

Total ~1100–1500 LOC + a couple of small data files. Phase 1+2 alone (~600 LOC) gets you a usable demo.

Want me to start on Phase 1?

## User

yes

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/cgraph.asd`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/core/concept.lisp`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/core/relation.lisp`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/core/graph.lisp`

## Assistant

Reviewing structure to ensure the generator API fits cleanly. Now writing Phase 1 code.

## Assistant

*[tool: Bash]* `Find label accessor` — `grep -E "(defmethod label|defun label|:accessor label)" /Users/bseely/repo/cgraph/system/core/types.lisp | head -10`

## Assistant

*[tool: Bash]* `Check node accessors` — `grep -n "defmethod label\|defmethod arcs\|outarc \|inarcs " /Users/bseely/repo/cgraph/system/core/node.lisp | head -20`

## Assistant

*[tool: Bash]* `Check node.lisp` — `grep -n "arcs\|label" /Users/bseely/repo/cgraph/system/core/node.lisp | head -20`

## Assistant

*[tool: Bash]* `Find type categories` — `grep -n "defclass\|act\b\|animate\|verb\|noun" /Users/bseely/repo/cgraph/default-types/concept-types.text | head -40`

## Assistant

*[tool: Bash]* `Find subtype predicate` — `grep -n "is-subtype\|subtype-p\|conforms-type\|type-conforms\|supertype-p" /Users/bseely/repo/cgraph/system/core/types.l`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/core/types.lisp` (offset 315, limit 60)

## Assistant

*[tool: Bash]* `Find parse-cgraph entry` — `grep -n "parse-cgraph" /Users/bseely/repo/cgraph/system/core/reader.lisp | head -5`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/core/reader.lisp` (offset 820, limit 30)

## Assistant

Writing Phase 1 files now.

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/syntax-roles.lisp` — write

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/walker.lisp` — write

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — write

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/generate.lisp` — write

## Assistant

Now wiring it into the asd and adding tests.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/cgraph.asd` — edit

## Assistant

*[tool: Bash]* `List tests dir` — `ls /Users/bseely/repo/cgraph/test/ | head -30`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/test/cgraph-tests.lisp` (offset 1, limit 60)

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/test/parse-test.lisp` (offset 1, limit 40)

## Assistant

*[tool: Bash]* `Look at parse-test tail` — `tail -40 /Users/bseely/repo/cgraph/test/parse-test.lisp`

## Assistant

*[tool: Bash]* `Find test entry points` — `grep -n "^(defun\|defparameter graph-string" /Users/bseely/repo/cgraph/test/parse-test.lisp | head -10`

## Assistant

*[tool: Bash]* `Find parse-test function` — `grep -n "^(defun parse-test\|defmethod parse-test" /Users/bseely/repo/cgraph/test/parse-test.lisp`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/test/parse-test.lisp` (offset 237, limit 25)

## Assistant

Now creating a generation test file following the same pattern.

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — write

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/cgraph.asd` — edit

## Assistant

Now let me try loading the system to catch any compile errors before claiming Phase 1 is done.

## Assistant

*[tool: Bash]* `Check for sbcl` — `which sbcl 2>/dev/null && echo OK || echo NO_SBCL`

## Assistant

*[tool: Bash]* `Load cgraph system` — `sbcl --non-interactive --no-userinit --eval "(require :asdf)" --eval "(push (truename \".\") asdf:*central-registry*)" -`

## Assistant

*[tool: Bash]* `Check for quicklisp / sbcl init` — `ls ~/quicklisp/setup.lisp 2>/dev/null && echo HAS_QL || echo NO_QL; ls ~/.sbclrc 2>/dev/null`

## Assistant

*[tool: Bash]* `Load cgraph with swank` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Look at swank usage` — `grep -n "swank\|SWANK" /Users/bseely/repo/cgraph/system/setup/initialize.lisp | head -20`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/setup/initialize.lisp` (offset 180, limit 25)

## Assistant

*[tool: Bash]* `Find setup-cgraph callers` — `grep -rn "setup-cgraph\b\|(setup-cgraph)" /Users/bseely/repo/cgraph/system/ /Users/bseely/repo/cgraph/cgraph.asd 2>/dev/`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/setup/initialize.lisp` (offset 200, limit 30)

## Assistant

*[tool: Bash]* `Find test call sites` — `grep -rn "start-cgraph\|setup-cgraph\|initialize-cgraph" /Users/bseely/repo/cgraph/test/ 2>/dev/null | head -10`

## Assistant

*[tool: Bash]* `Find initialize-cgraph definition` — `grep -n "initialize-cgraph\|(start-cgraph" /Users/bseely/repo/cgraph/system/setup/initialize.lisp`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/setup/initialize.lisp` (offset 75, limit 30)

## Assistant

*[tool: Bash]* `Find what's failing` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Backtrace on load fail` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Find swank top-level invocations` — `grep -rn "eval-in-emacs\|swank::\|swank:" /Users/bseely/repo/cgraph/system/ /Users/bseely/repo/cgraph/test/ 2>/dev/null `

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/graphing/concept-type-graph.lisp` (offset 115, limit 25)

## Assistant

*[tool: Read]* `/Users/bseely/.sbclrc`

## Assistant

*[tool: Bash]* `Filter compile output` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Tail compile output` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Find unhandled error context` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Find offending swank top-level form` — `grep -n "swank\|graph-types" /Users/bseely/repo/cgraph/system/graphing/concept-type-graph.lisp | head -10`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/graphing/concept-type-graph.lisp` (offset 170, limit 15)

## Assistant

All four generation files compile cleanly. The remaining load failure is a pre-existing issue unrelated to my changes — `system/graphing/concept-type-graph.lisp` lines 174-181 has an `eval-when (:load-toplevel :execute)` block that calls `swank:eval-in-emacs` to register an Emacs function. That only works when the system is loaded inside SLIME (the user's normal workflow), which is why batch loading fails. My code did not introduce this.

## Phase 1 — what landed

**New module `system/generation/`** (all 4 files compile cleanly):

- `syntax-roles.lisp` — table mapping CG relation labels (`agnt`, `obj`, `rcpt`, `inst`, `loc`, `manr`, `attr`, `chrc`, `poss`, `part`, `dest`, `dur`, `time`, plus the measurement family) to syntactic roles (`:subject`, `:dobj`, `:iobj`, `:pp`, `:adj`, `:adv`, `:poss`) and prepositions where applicable. Includes a PP-priority list so manner-before-time ordering is enforced.
- `walker.lisp` — `walk-state` struct (utterance + traversal marks), `find-main-predicate` (prefers act-side of an AGNT, falls back to act/event-typed concept, then most-connected), and `classify-relations` which buckets a concept's arcs by role.
- `realizer.lisp` — `realize-np` (head + ATTR/CHRC adjectives + POSS), `realize-pp`, `realize-adv` (crude `-ly` suffix), and `realize-clause` which composes tokens in subject–verb–dobj–iobj–PP–adv order. Uses referent name when present (so `[person: sue]` → "sue").
- `generate.lisp` — `(graph-to-text graph)` accepting a CG string, a `graph` object, or a node list. Capitalizes the first word and adds a period.

**Test file `test/generation-test.lisp`** with 5 cases:

| Input | Expected |
|---|---|
| `[girl]<-(agnt)<-[EAT]->(obj)->[PIE].` | "Girl eat pie." |
| `[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE].` | "Sue eat pie." |
| `[girl:sue]<-(agnt)<-[EAT]->(manr)->[FAST].` | "Sue eat fast-ly." |
| `[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD].` | "Dog eat food." |
| `[CAT]<-(agnt)<-[SIT]->(loc)->[MAT].` | "Cat sit in mat." |

**Wired into `cgraph.asd`** — added the `generation` module under `system` (depends on `setup` and `core`), and added `generation-test` to the test components.

## To run

In your SLIME session:
```
(asdf:load-system :cgraph :force t)
(generation-test t)
```

Or one-off:
```
(graph-to-text "[girl]<-(agnt)<-[EAT]->(obj)->[PIE].")
```

Output will be intentionally telegraphic ("Cat sit in mat") — Phase 2 adds articles, conjugation, and pluralization to clean it up. Want me to start Phase 2, or would you like to exercise Phase 1 in SLIME first and report back?

## User

I might have just messed things up. I quit Emacs and when  it asked, I told it to save all buffers. -- just a heaqds up in case something you save was changed. I'll restart Emacs and Lisp now

## Assistant

Acknowledged — heads up noted. The walker.lisp diff shown looks identical to what I wrote, so nothing seems lost on my end. Go ahead and restart; I'll wait.

## User

generation-test fails, here's the REPL output:
CG> (generation-test t)

generation-test
  FAIL  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Girl eat pie."
    actual:   "<error: There is no applicable method for the generic function
          #<STANDARD-GENERIC-FUNCTION CONCEPTUAL-GRAPHS::NAME-PROPERTY (1)>
        when called with arguments
          (NIL).
See also:
  The ANSI Standard, Section 7.6.6>"
  FAIL  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eat pie."
    actual:   "<error: There is no applicable method for the generic function
          #<STANDARD-GENERIC-FUNCTION CONCEPTUAL-GRAPHS::NAME-PROPERTY (1)>
        when called with arguments
          (NIL).
See also:
  The ANSI Standard, Section 7.6.6>"
  FAIL  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[FAST]."
    expected: "Sue eat fast-ly."
    actual:   "<error: Concept type FAST is not consistent with the MANR relation out-arc type, MANNER.
 FAST has supertypes (⊤ INDIVIDUAL ENTITY ABSTRACT QUALITY ATTRIBUTE
                      PHYSICAL-ATTRIBUTE SPEED FAST)
The out-arc should be one of (INDIVIDUAL ENTITY ABSTRACT QUALITY ATTRIBUTE ⊤
                              CHARACTERISTIC MANNER)
>"
  FAIL  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "Dog eat food."
    actual:   "<error: There is no applicable method for the generic function
          #<STANDARD-GENERIC-FUNCTION CONCEPTUAL-GRAPHS::NAME-PROPERTY (1)>
        when called with arguments
          (NIL).
See also:
  The ANSI Standard, Section 7.6.6>"
  FAIL  "[CAT]<-(agnt)<-[SIT]->(loc)->[MAT]."
    expected: "Cat sit in mat."
    actual:   "<error: There is no applicable method for the generic function
          #<STANDARD-GENERIC-FUNCTION CONCEPTUAL-GRAPHS::NAME-PROPERTY (1)>
        when called with arguments
          (NIL).
See also:
  The ANSI Standard, Section 7.6.6>"
NIL
CG>

## Assistant

Two bugs in Phase 1:

1. `lemma-for-concept` calls `referent-name` on concepts whose `referent` is nil, and `name-property` has no NIL method.
2. `[FAST]` is a `SPEED` subtype, not a `MANNER` subtype, so the parser rejects it.

Fixing both.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

Two changes:

- `system/generation/realizer.lisp` — `lemma-for-concept` now checks for a non-nil referent before calling `referent-name`, falling back to the type label.
- `test/generation-test.lisp` — replaced `[FAST]` with `[MANNER]` (which is the actual destination type for `manr`) and `[MAT]` with `[PLACE]` (destination type for `loc`). Also bound `*allow-dynamic-individual-creation*` to `t` to match the pattern in `test-all`.

Recompile the two changed files and rerun `(generation-test t)`. The expected strings are still telegraphic ("Sue eat manner-ly", "Cat sit in place") — that's the Phase 1 output; Phase 2 cleans up morphology and word choice.

## User

success:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Girl eat pie."
    actual:   "Girl eat pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eat pie."
    actual:   "Sue eat pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eat manner-ly."
    actual:   "Sue eat manner-ly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "Dog eat food."
    actual:   "Dog eat food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "Cat sit in place."
    actual:   "Cat sit in place."
  all 5 generation cases passed.
T
CG>

## Assistant

Phase 1 lands: walker locates the main predicate, classifies arcs by syntactic role, realizer composes subject–verb–dobj–PP–adv order. All 5 cases pass.

Ready for Phase 2 when you are. That brings:
- Articles (a/an/the/every/some) driven by the referent (`*` → indefinite, named individual → bare/definite, `∀` → "every", `{*}` → plural)
- Verb conjugation (regulars + irregulars table) and subject-verb agreement
- Noun pluralization
- A `lexicon-overrides` data file for irregulars and multi-word expressions

Want me to start Phase 2?

## User

Do it!

## Assistant

Starting Phase 2.

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/lexicon.lisp` — write

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/morphology.lisp` — write

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/morphology.lisp` — edit

## Assistant

Now updating the realizer to use lexicon + morphology.

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — write

## Assistant

Wiring the new files into the asd.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/cgraph.asd` — edit

## Assistant

Updating test expectations to match Phase 2 output.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Compile-check generation module` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

All six generation files compile cleanly. Phase 2 changes:

- **`system/generation/lexicon.lisp`** (new) — `*lexicon-overrides*` registry, POS classification by walking the type lattice (`act`/`event` → :verb, `manner` → :adv, `attribute` → :adj, else :noun), `base-lemma` (override → referent name → type label), `concept-number` / `concept-definiteness` / `proper-name-p` / `mass-noun-p`, plus irregular-verb (~50 entries) and irregular-plural (~14 entries) tables. `register-lexicon-entry` API for runtime overrides.
- **`system/generation/morphology.lisp`** (new) — `pluralize`, `present-3sg`, `past-tense`, `conjugate`, `article-for` (a/an/the/every/some, no article for proper / mass), `adverbify` (handles -y → -ily, -le → -ly, -ic → -ically, -ll → -lly, default -ly).
- **`system/generation/realizer.lisp`** (rewritten) — `noun-form` inflects head; `realize-np` chooses determiner from the leading orthographic word (so "an" works in front of an adjective starting with a vowel); proper nouns are capitalized and get no article; possessives suppress the indefinite article; `verb-for-clause` conjugates the main predicate using subject's number/person.
- **`cgraph.asd`** — added `lexicon` and `morphology` between `walker` and `realizer`.
- **`test/generation-test.lisp`** — updated expectations.

| Input | Phase 2 expected |
|---|---|
| `[girl]<-(agnt)<-[EAT]->(obj)->[PIE].` | "A girl eats a pie." |
| `[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE].` | "Sue eats a pie." |
| `[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER].` | "Sue eats mannerly." |
| `[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD].` | "A dog eats a food." |
| `[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE].` | "A cat sits in a place." |

Note "a food" — mass-noun handling exists (`(register-lexicon-entry 'food :mass-p t)`) but no overrides are wired up yet; that's a 1-line fix when you want it. Ready to run `(generation-test t)` in your SLIME session.

## User

I restarted everything. generation-test isn't happy:
CG> (generation-test t)

generation-test
  FAIL  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VERB>"
  FAIL  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VERB>"
  FAIL  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VERB>"
  FAIL  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VERB>"
  FAIL  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "<error: The value
          \"sit\"
        is not of type
          NUMBER
        when binding VERB>"
NIL
CG>

## Assistant

*[tool: Bash]* `Find conflicting VERB symbol` — `grep -rn "defun verb\|defmethod verb\|defgeneric verb\|defclass verb\|deftype verb\|(verb " /Users/bseely/repo/cgraph/sy`

## Assistant

*[tool: Bash]* `Check for type declarations` — `grep -rn "deftype number\|check-type.*number\|the (number\|declare.*type.*number.*verb\|the number verb" /Users/bseely/r`

## Assistant

*[tool: Bash]* `Find all verb usages` — `grep -rn "verb" /Users/bseely/repo/cgraph/system/ 2>/dev/null | head -20`

## Assistant

*[tool: Bash]* `Check for valence/arity methods` — `grep -rn "valence\|num-arcs\|defmethod number" /Users/bseely/repo/cgraph/system/core/relation.lisp /Users/bseely/repo/cg`

## Assistant

*[tool: Bash]* `Find conjugate definitions` — `grep -rn "defun conjugate\|defmethod conjugate\|defgeneric conjugate" /Users/bseely/repo/cgraph/ 2>/dev/null | head -10`

## Assistant

*[tool: Bash]* `Check external types for verb` — `grep -rn "verb\|VERB" ~/repo/cgraph-types/ 2>/dev/null | grep -v ":;;" | head -10`

## Assistant

*[tool: Bash]* `Search verb-as-type` — `grep -rn "deftype verb\|the verb\|the (verb\|defstruct.*:type\|verb.*number\|type.*number.*verb\|((verb " /Users/bseely/`

## Assistant

*[tool: Bash]* `Find prior conjugate definitions` — `grep -rn "conjugate\|cube\|present-3sg\|past-tense" ~/repo/cgraph-types/ ~/repo/cgraph/system/ 2>/dev/null | grep -v "sy`

## Assistant

*[tool: Bash]* `Find number-typed verb` — `grep -rn "the number.*verb\|declare.*number.*verb\|type number) verb\|fix.*verb\|integer.*verb" /Users/bseely/repo 2>/de`

## Assistant

*[tool: Bash]* `Check declaim in generation` — `grep -rn "declaim\|proclaim" /Users/bseely/repo/cgraph/system/generation/ 2>/dev/null`

## Assistant

*[tool: Bash]* `Force recompile, capture warnings` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Force recompile output` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `All declaim sites` — `grep -rn "declaim\|proclaim" /Users/bseely/repo/cgraph/system/ /Users/bseely/repo/cgraph/cgraph.asd 2>/dev/null | head -`

## Assistant

*[tool: Bash]* `Check label slot` — `grep -n "label\b" /Users/bseely/repo/cgraph/system/core/types.lisp | head -10`

## Assistant

*[tool: Bash]* `Find check-type number` — `grep -rn "check-type.*number\|the number" /Users/bseely/repo/cgraph/system/ 2>/dev/null | head -10`

## Assistant

*[tool: Bash]* `Find package-qualified verb refs` — `grep -rn "cg::verb\|cgraph::verb\|CGRAPH::VERB\|conceptual-graphs::verb\|symbol-plist.*verb\|setf.*get.*verb" /Users/bse`

## Assistant

*[tool: Bash]* `Check types.lisp for number-typed defs` — `grep -rn "(defmethod\|defun" ~/repo/cgraph/system/core/types.lisp 2>/dev/null | grep -i "verb\|count\|num\|number" | hea`

## Assistant

*[tool: Bash]* `Check :type declarations` — `grep -rn "type=\|:type " /Users/bseely/repo/cgraph/system/generation/ 2>/dev/null`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` (offset 75, limit 20)

## Assistant

*[tool: Bash]* `Check fasl cache` — `grep -rn "verb\|VERB" /Users/bseely/.cache/common-lisp/sbcl-2.6.2-macosx-arm64/Users/bseely/repo/cgraph/system/generatio`

## Assistant

*[tool: Bash]* `Check support/debug.lisp` — `grep -n "verb\|number" /Users/bseely/repo/cgraph/support/debug.lisp 2>/dev/null | head -10`

## Assistant

*[tool: Bash]* `Check for verb/number classes` — `grep -rn "defstruct\|defclass" /Users/bseely/repo/cgraph/system/ 2>/dev/null | grep -i "verb\|number"`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/setup/initialize.lisp` (offset 50, limit 40)

## Assistant

*[tool: Bash]* `Find initializations.lisp` — `find ~/repo/cgraph ~/.cgraph -name "initializations.lisp" 2>/dev/null | head -5`

## Assistant

*[tool: Read]* `/Users/bseely/.cgraph/initializations.lisp`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/support/debug.lisp` (offset 1, limit 50)

## Assistant

*[tool: Bash]* `Size of debug.lisp` — `wc -l /Users/bseely/repo/cgraph/support/debug.lisp`

## Assistant

*[tool: Bash]* `Check cgraph-types for code` — `grep -rn "verb\|defun\|defmethod\|deftype" ~/repo/cgraph-types/ 2>/dev/null | head -10`

## Assistant

Let me just sidestep the mystery by renaming parameters that might be colliding with something I can't find.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/morphology.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Bash]* `Recompile, check warnings` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Renamed `verb` → `vlemma` and `number` → `numbr` in `morphology.lisp` and the call site in `realizer.lisp`. Compiles cleanly.

The error was odd: SBCL was reporting `"eat"` failing a `NUMBER` type check during binding of `VERB`. Nothing in my code declares either as typed, so something in the loaded environment must be declaring `cg::verb` to be a `NUMBER`. Renaming sidesteps it. If you can recompile and rerun `(generation-test t)` we should see whether that was the whole issue or whether there's more.

## User

still unhappy:
CG> (generation-test t)

generation-test
  FAIL  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VLEMMA>"
  FAIL  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VLEMMA>"
  FAIL  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VLEMMA>"
  FAIL  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "<error: The value
          \"eat\"
        is not of type
          NUMBER
        when binding VLEMMA>"
  FAIL  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "<error: The value
          \"sit\"
        is not of type
          NUMBER
        when binding VLEMMA>"
NIL
CG>

## Assistant

*[tool: Bash]* `Check readtable mods` — `grep -n "readtable\|set-macro-char\|set-syntax-from-char\|with-readtable" /Users/bseely/repo/cgraph/system/setup/definit`

## Assistant

*[tool: Bash]* `Find readtable customization` — `grep -rn "with-readtable-mods\|set-macro-character\|set-syntax-from-char\|defmacro with-cg-readtable" /Users/bseely/repo`

## Assistant

*[tool: Bash]* `Search for conjugate type decls` — `grep -rn "ftype.*conjugate\|conjugate.*function\|declaim.*conjugate" ~/quicklisp ~/repo /usr/lib 2>/dev/null | head -5`

## Assistant

Found it: `cl:conjugate` is a **standard Common Lisp function** that takes a complex number and returns its conjugate. The CG package `(:use :cl)`, so my `(defun conjugate ...)` was redefining `cl:conjugate` — and the original `(number)` ftype declaration was sticking, type-checking my first argument as `NUMBER`. Renaming the parameter didn't help because the type was on the function, not the parameter.

Renaming the function.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/morphology.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

Renamed `conjugate` → `inflect-verb` in both `morphology.lisp` and `realizer.lisp`. The first call site is the one in `verb-for-clause`.

One housekeeping note: since the previous load redefined `cl:conjugate` (CL's built-in) inside your image, restart Lisp once more after recompiling so the original `cl:conjugate` is restored. Then `(generation-test t)`.

## User

Restarting Lisp is so easy, that I always restart it to ensure the code is properly loaded.
happy now:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "A dog eats a food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  all 5 generation cases passed.
T
CG>

## Assistant

All 5 cases pass — Phase 2 lands. Saving a quick memory note about the `cl:conjugate` collision pattern, since the silent-redefinition + persistent-ftype combination produced a confusing error and is a real trap for future naming choices in this package.

## Assistant

*[tool: Write]* `/Users/bseely/.claude/projects/-Users-bseely-repo-cgraph/memory/feedback_cl_builtin_collision.md` — write

## Assistant

*[tool: Read]* `/Users/bseely/.claude/projects/-Users-bseely-repo-cgraph/memory/MEMORY.md`

## Assistant

*[tool: Edit]* `/Users/bseely/.claude/projects/-Users-bseely-repo-cgraph/memory/MEMORY.md` — edit

## Assistant

Phase 2 complete. Memory note added so the next time we reach for a name like `count`, `position`, or `parse` in this package, we'll think twice.

Ready for Phase 3 (anaphora and cycles, Sowa Rule 5) when you are. That brings: tracking which concepts have been uttered during the walk, gender/animacy/number-aware pronoun selection (he/she/it/they) on revisit, fall-back to "the X" short noun phrase when a pronoun would be ambiguous, and proper handling of graphs where two arcs converge on the same concept.

## User

Let's do it

## Assistant

Starting Phase 3.

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/anaphora.lisp` — write

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

Wiring `anaphora.lisp` into the asd, then adding tests.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/cgraph.asd` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Recompile, check for warnings` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

All seven generation files compile cleanly.

Phase 3 changes:

- **`system/generation/anaphora.lisp`** (new) — `pronoun-for` looks up a pronoun via a `*pronoun-table*` keyed by `(gender number case)`. Three cases supported: `:nominative`, `:accusative`, `:possessive`. `gender-of` consults the lexicon first (lazy override), falls back to `:neuter` for non-humans and `:unknown` (→ singular "they") for humans without a registered gender. Ships with lexicon entries for `man`/`woman`/`boy`/`girl`.
- **`system/generation/realizer.lisp`** — `realize-np` now takes `:case`. First visit emits the full NP and calls `mark-uttered`; subsequent visits emit a pronoun (with a fallback to "the X" if pronoun lookup misses). `realize-pp` and the dobj/iobj branches in `realize-clause` request `:accusative`; the subject stays `:nominative`. Split the original NP body into a private `realize-full-np` helper.
- **`cgraph.asd`** — added `anaphora` between `morphology` and `realizer`.
- **`test/generation-test.lisp`** — three new cases:

| Input | Expected |
|---|---|
| `[CAT:*x]<-(agnt)<-[BITE]->(obj)->[CAT:*x].` | "A cat bites it." |
| `[BOY:*x]<-(agnt)<-[SEE]->(obj)->[BOY:*x].` | "A boy sees him." |
| `[GIRL:*x]<-(agnt)<-[SEE]->(obj)->[GIRL:*x].` | "A girl sees her." |

These exercise: (a) revisit detection via `uttered-p`, (b) case selection (subject = nominative, object = accusative), (c) gender lookup from lexicon overrides, (d) animate/neuter default for non-human subjects.

Restart Lisp and run `(generation-test t)`.

## User

generation-test results:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "A dog eats a food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  FAIL  "[CAT:*x]<-(agnt)<-[BITE]->(obj)->[CAT:*x]."
    expected: "A cat bites it."
    actual:   "<error: Unknown concept-type 'BITE' encountered while while parsing: [CAT:*x]<-(agnt)<-[BITE]->(obj)->[CAT:*x].>"
  FAIL  "[BOY:*x]<-(agnt)<-[SEE]->(obj)->[BOY:*x]."
    expected: "A boy sees him."
    actual:   "<error: Unknown concept-type 'SEE' encountered while while parsing: [BOY:*x]<-(agnt)<-[SEE]->(obj)->[BOY:*x].>"
  FAIL  "[GIRL:*x]<-(agnt)<-[SEE]->(obj)->[GIRL:*x]."
    expected: "A girl sees her."
    actual:   "<error: Unknown concept-type 'SEE' encountered while while parsing: [GIRL:*x]<-(agnt)<-[SEE]->(obj)->[GIRL:*x].>"
NIL
CG>

## Assistant

*[tool: Bash]* `Check defined verb concept types` — `grep -rE ":label (eat|sit|bite|see|love|own)" /Users/bseely/repo/cgraph-types/ /Users/bseely/repo/cgraph/default-types/ `

## Assistant

*[tool: Bash]* `Find defined verb-like types` — `grep -E "^\(:label" /Users/bseely/repo/cgraph-types/concept-types.lisp | grep -iE "(eat|sit|see|bite|run|own|wash|love|h`

## Assistant

*[tool: Bash]* `Find SIT definition` — `grep -rE ":label sit\b" /Users/bseely/repo/cgraph-types/ /Users/bseely/repo/cgraph/default-types/ /Users/bseely/.cgraph/`

## Assistant

*[tool: Bash]* `Confirm cat/dog defined` — `grep -E "^\(:label (sit|cat|dog|girl|boy|pie|food|place|mat|manner|eat)\b" /Users/bseely/repo/cgraph-types/concept-types`

## Assistant

*[tool: Bash]* `Check missing types` — `grep -E "^\(:label (cat|sit|see|bite|wash)\b" /Users/bseely/repo/cgraph-types/concept-types.lisp /Users/bseely/repo/cgra`

## Assistant

*[tool: Bash]* `Find sit in cgraph-types` — `grep -rE "sit" /Users/bseely/repo/cgraph-types/concept-types.lisp /Users/bseely/repo/cgraph-types/types.text 2>/dev/null`

## Assistant

*[tool: Bash]* `Any sit in cgraph-types` — `grep -E "sit" /Users/bseely/repo/cgraph-types/concept-types.lisp | head -10`

## Assistant

*[tool: Bash]* `Find sit type def anywhere` — `grep -rEn "\(:label sit" ~/.cgraph/ ~/repo/cgraph/ ~/repo/cgraph-types/ 2>/dev/null | head -5`

## Assistant

*[tool: Bash]* `List test-types` — `grep -E "^\(:label " /Users/bseely/repo/cgraph/test/test-types/concept-types.lisp | head -40`

## Assistant

*[tool: Bash]* `Find verb concept types` — `grep -E "^\(:label " /Users/bseely/repo/cgraph/test/test-types/concept-types.lisp | grep -iE "(sit|see|bite|run|wash|own`

## Assistant

*[tool: Bash]* `List action/event types` — `grep -E "supertypes \((act|event|state|move|communicate|ingest|give)" /Users/bseely/repo/cgraph/test/test-types/concept-`

## Assistant

*[tool: Bash]* `Verbs in user types` — `grep -E "^\(:label " /Users/bseely/repo/cgraph-types/concept-types.lisp | grep -iE "supertypes \((act|event|state|ingest`

## Assistant

*[tool: Bash]* `Check load-test-types signature` — `grep -n "defun load-test-types\|defun test-cgraph" /Users/bseely/repo/cgraph/test/cgraph-tests.lisp`

## Assistant

*[tool: Bash]* `Check coref var usage` — `grep -E "\\*x.*\\*x" /Users/bseely/repo/cgraph/test/parse-test.lisp /Users/bseely/repo/cgraph/test/coreference-test.lisp`

## Assistant

*[tool: Bash]* `Find coref variable tests` — `grep -E "graph-string.*\\*[a-z]" /Users/bseely/repo/cgraph/test/parse-test.lisp /Users/bseely/repo/cgraph/test/variable-`

## Assistant

*[tool: Bash]* `Examples of coref vars` — `grep -Erh "\\[.*: ?\\*[a-z]" /Users/bseely/repo/cgraph/test/*.lisp 2>/dev/null | head -10`

## Assistant

Re-checking which verbs are defined in the user's actual type set. EAT and GIVE are defined; BITE and SEE are not. Switching the anaphora tests to use GIVE with RCPT (reflexive give-to-self) to match types that exist in the user's `cgraph-types` directory.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Confirm compile` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

*[tool: Bash]* `Force recompile` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Replaced the BITE/SEE tests (those types aren't in your hierarchy) with three reflexive-GIVE patterns using the standard `[X: *z]<-(agnt)<-[GIVE]->(rcpt)->[X: *z]` shape — GIVE is defined in your `cgraph-types`, and `*z` coreference makes the parser produce a single shared concept node so the realizer revisits it for the `:rcpt` arc:

| Input | Expected |
|---|---|
| `[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z].` | "A boy gives to him." |
| `[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z].` | "A girl gives to her." |
| `[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z].` | "A person gives to them." |

Restart Lisp and run `(generation-test t)`.

## User

it's really close:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "A dog eats a food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  FAIL  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to (him)."
  FAIL  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to (her)."
  FAIL  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to (them)."
NIL
CG>

## Assistant

Found the bug: `lookup-pronoun` uses `(cdr (assoc ...))` but the table entries are `((key) value)` — two-element lists, not cons cells — so `cdr` returns a one-element list `("him")`, which `format ~a` prints as `(him)`. Fix is `cadr` (or `second`).

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/anaphora.lisp` — edit

## Assistant

Recompile `anaphora.lisp` and rerun.

## User

That got it...
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "A dog eats a food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  pass  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to him."
  pass  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to her."
  pass  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to them."
  all 8 generation cases passed.
T
CG>

## Assistant

Phase 3 lands. All 8 cases pass — including the three reflexive coreference patterns where the same node is realized first as a full NP and then as a case-appropriate pronoun (`him`, `her`, `them`).

What now exists:
- **Rules 1, 6** (Phase 1): traversal skeleton with main-predicate selection and arc classification.
- **Rule 2** (Phase 2): morphology — verb conjugation, pluralization, articles, adjective→adverb derivation.
- **Rule 5** (Phase 3): anaphora — `uttered-p` tracking, gender/animacy/number-aware pronoun selection in three cases, with a "the X" fallback.

Phases still on the original plan:
- **Phase 4** — adjacency markers (Rule 3): relative pronouns `that`/`who`/`which` and commas when the walker takes a non-adjacent branch. Lets the realizer handle multi-clause graphs like `[BOY]<-(agnt)<-[OWN]->(obj)->[DOG]<-(agnt)<-[BARK]` ("a boy owns a dog that barks").
- **Phase 5** — nesting (Rule 4): expand graph-referent concepts (PROPOSITION, SITUATION) into embedded clauses with `that`/`to`-clause complementizers.
- **Phase 6** — polish: heuristic active/passive selection, mass-noun overrides for common cases (food, water, etc.), terminal punctuation refinements, deferred items documented.

Want me to take Phase 4?

## User

yep

## Assistant

Phase 4: relative clauses for non-adjacent traversals.

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp`

## Assistant

You've hit your limit · resets 10:30pm (America/New_York)

## User

I'm back. Where are we?

## Assistant

Welcome back. Status:

**Phases 1–3 are landed and tested** — all 8 generation tests pass:
- Walking skeleton, morphology (articles + verb conjugation + pluralization), and anaphora (pronouns on revisit with case agreement).

**Phase 4 (relative clauses) is in progress** — I had just read `realizer.lisp` to plan the changes but hadn't written any code yet. The plan:

- Add `realize-predicate-body` (verb + complements, no subject NP) — extracted from `realize-clause` so it can be reused.
- Add `unrealized-predications` — finds AGNT relations on a non-main concept whose other end is an unrealized act.
- Add `realize-relative-clause` — emits `that <verb-phrase>` (or `who` for humans).
- Hook into `realize-full-np` so any NP head with an unrealized AGNT-to-act picks up a trailing relative clause.
- Mark all main-clause relations traversed at the start of `realize-clause` so subordinate NPs don't try to relativize the main predicate.

Two test cases planned:
- `[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE].` → "A boy gives a dog that eats a pie."
- `[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE].` → "A boy gives a girl who eats a pie."

Want me to proceed with Phase 4 implementation?

## User

yes

## Assistant

Implementing Phase 4 now.

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — write

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Force recompile` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Phase 4 changes:

- **`system/generation/realizer.lisp`** — restructured:
  - `realize-clause` now marks all of its bucket relations as traversed up front (via `mark-clause-relations-traversed`) so subordinate NPs don't try to relativize the main verb.
  - Extracted `realize-predicate-body` (verb + dobj + iobj + PPs + adverbs, no subject NP) — used by both the main clause (subject prepended) and relative clauses (head fills the subject slot).
  - Added `unrealized-predications` — finds AGNT relations on a non-main concept whose act hasn't been uttered.
  - Added `relative-pronoun-for` — `who` for humans, `that` otherwise.
  - Added `realize-relative-clause` — emits `who/that <predicate-body>`, marks the AGNT traversed, and recursively classifies the sub-act so its own arcs (dobj, etc.) are processed.
  - `realize-full-np` calls `relative-clauses-for` and appends the resulting clauses.

- **`test/generation-test.lisp`** — two new cases:

| Input | Expected |
|---|---|
| `[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE].` | "A boy gives a dog that eats a pie." |
| `[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE].` | "A boy gives a girl who eats a pie." |

Restart Lisp and run `(generation-test t)`.

## User

looking good!
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "A dog eats a food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  pass  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to him."
  pass  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to her."
  pass  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to them."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a dog that eats a pie."
    actual:   "A boy gives a dog that eats a pie."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a girl who eats a pie."
    actual:   "A boy gives a girl who eats a pie."
  all 10 generation cases passed.
T
CG>

## Assistant

Phase 4 lands clean — all 10 cases pass, including both relative-clause shapes with correct `who`/`that` selection by humanness.

Phases 1–4 done. Remaining on the original plan:

- **Phase 5 (nesting, Sowa Rule 4)** — for concepts whose referent is itself a graph (PROPOSITION, SITUATION, BELIEF), enter the nested graph at the containing-node visit and emit `that <embedded clause>` or `to <embedded clause>`. Example: `[PERSON: ivan]<-(expr)<-[BELIEVE]->(obj)->[PROPOSITION: [PERSON: ivan]→(loc)→[KITCHEN]]` → "Ivan believes that Ivan is in the kitchen." Raising (Sowa's "Ivan is believed to be in the kitchen") deferred.

- **Phase 6 (polish)** — heuristic active/passive selection (passive when AGNT is absent), mass-noun overrides for common foods/substances so "a food" becomes "food", BE-copula handling for ATTR/CHRC at the clause level (e.g., `[CAT]→(attr)→[BLACK]` → "A cat is black"), and explicit deferred-list documentation.

Phase 5 is the more interesting one — it brings the system to the point where it can express nested mental-attitude graphs, which is one of the things Sowa's framework is most distinctive for. Phase 6 is shorter and improves naturalness on the cases we already handle. Want me to do Phase 5 next?

## User

yes

## Assistant

*[tool: Bash]* `Look for nested-graph syntax examples` — `grep -rEn "PROPOSITION:|SITUATION:|BELIEF:" /Users/bseely/repo/cgraph/test/*.lisp 2>/dev/null | head -10`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/test/graph-referent-test.lisp` (offset 1, limit 60)

## Assistant

*[tool: Bash]* `Find nested-graph test patterns` — `grep -rEn "PROPOSITION:|SITUATION:|BELIEF:|\\[KNOW\\]" /Users/bseely/repo/cgraph/test/*.lisp 2>/dev/null | grep -v "^[^:`

## Assistant

*[tool: Read]* `/Users/bseely/repo/cgraph/test/normalize-test.lisp` (offset 110, limit 30)

## Assistant

Phase 5 implementation now. Adding `expr`/`stat` relations, generalizing the main-predicate finder, and adding nested-graph realization.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/syntax-roles.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/walker.lisp` — edit

## Assistant

Now adding `realize-argument` and `realize-nested-graph` to the realizer, and routing dobj/iobj/pp through it.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Recompile` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Phase 5 changes:

- **`syntax-roles.lisp`** — added `expr` → `:subject` (experiencer for state predicates like KNOW/BELIEVE), `stat` → `:dobj` (state-of-affairs propositional complement), `cont` → `:dobj` (content).
- **`walker.lisp`** — generalized `find-main-predicate`. Renamed `act-side-of-agnt` → `verb-side-of-subject-rel` and `find-agnt-relation` → `find-subject-relation`; the finder now uses `relation-role` so any subject-introducing relation (AGNT, EXPR, ...) is recognized.
- **`realizer.lisp`** — added:
  - `clausal-concept-p` — true when the concept's referent is a graph.
  - `realize-nested-graph` — finds the main predicate of an inner graph, classifies its arcs, and calls `realize-clause` on it. Walk-state is shared across the boundary so anaphora carries through.
  - `realize-argument` — wraps `realize-np` for noun phrases and emits `that <inner clause>` for graph-typed concepts. The preposition (e.g., "to" for iobj) is suppressed for clausal complements.
  - `realize-pp` and the dobj/iobj branches in `realize-predicate-body` now route through `realize-argument`.

Test added:
| Input | Expected |
|---|---|
| `[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]].` | "Ivan knows that a girl eats a pie." |

Restart Lisp and run `(generation-test t)`.

## User

you're doing great!
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "A dog eats a food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  pass  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to him."
  pass  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to her."
  pass  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to them."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a dog that eats a pie."
    actual:   "A boy gives a dog that eats a pie."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a girl who eats a pie."
    actual:   "A boy gives a girl who eats a pie."
  pass  "[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]."
    expected: "Ivan knows that a girl eats a pie."
    actual:   "Ivan knows that a girl eats a pie."
  all 11 generation cases passed.
T
CG>

## Assistant

Phase 5 lands. All 11 cases pass — Sowa's distinctive nested-graph mental-attitude pattern works end-to-end: outer subject + state verb + `that` + recursively-realized inner clause.

What we have now, in Sowa's terms:
- **Rule 1, 6** — utterance path traversal with main-predicate selection
- **Rule 2** — morphology and lexical realization
- **Rule 3** — relative clauses for non-adjacent traversals (`who`/`that`)
- **Rule 4** — nested-graph expansion (`that`-clauses)
- **Rule 5** — anaphora on revisit, with case and gender agreement

Phase 6 (polish) is what's left from the original plan. Concrete items I'd recommend tackling, in rough order of impact:

1. **BE-copula for stative attribute relations** — `[CAT]→(attr)→[BLACK]` should yield "A cat is black." rather than treating CAT as a verb. Would also fix `[PERSON:Ivan]→(loc)→[KITCHEN]` → "Ivan is in the kitchen." (which is closer to Sowa's example).
2. **Mass-noun lexicon overrides** — register `food`, `water`, `information`, etc. as `:mass-p t` so we get "food" instead of "a food".
3. **Active/passive heuristic** — when there's no AGNT but an OBJ exists with an act, render as passive ("The pie is eaten").
4. **Adverbify cleanup** — `[MANNER]` lemma "manner" becoming "mannerly" is an artifact of using the abstract type; if we register MANNER itself as a non-derivable adverb head we can emit "in some manner" or just skip it.

Want me to take Phase 6 and bundle these, or pick a subset?

## User

You're doing the work. If it's easier to take them one at a time, in order, then do that. If you have a better approach, then do that.

## Assistant

Starting with item 1 (BE-copula). First checking what attribute types are available.

## Assistant

*[tool: Bash]* `Find attribute types` — `grep -E "^\(:label .* :supertypes \(attribute" /Users/bseely/repo/cgraph-types/concept-types.lisp /Users/bseely/repo/cgr`

## Assistant

*[tool: Bash]* `Find common adjective types` — `grep -E "^\(:label (small|large|black|white|red|blue|fast|slow|hot|cold|noisy|hard|soft|young|old) :sup" /Users/bseely/r`

## Assistant

*[tool: Bash]* `Confirm attribute supertype chain` — `grep -E "^\(:label (speed|hardness|age|attribute) " /Users/bseely/repo/cgraph-types/concept-types.lisp 2>/dev/null | hea`

## Assistant

Implementing the BE-copula path.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/walker.lisp` — edit

## Assistant

Now the realizer side — copula clause builder, plus making `realize-full-np` skip relations already marked traversed (so they don't double-emit as both modifier and complement).

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

Now wiring `graph-to-text` to dispatch on copula vs verbal.

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/generate.lisp` — write

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Recompile, catch warnings` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Phase 6 item 1 (BE-copula) — changes:

- **`walker.lisp`** — added `copula-required-p` (true when no subject relation exists in the graph) and `find-copula-topic` (picks the entity side of an ATTR/CHRC/LOC relation, falling back to most-connected).
- **`realizer.lisp`** — added `realize-copula-clause`. It marks `:adj` and `:pp` relations as traversed before rendering the topic NP, so they don't double-emit as both pre-modifiers and predicate complements. Also updated `realize-full-np` to skip relations already marked traversed (so the copula path can suppress modifier folding cleanly).
- **`generate.lisp`** — `graph-to-text` now dispatches: copula clause when no subject relation exists, verbal clause otherwise. Extracted `finalize-sentence` helper.

Two new tests:
| Input | Expected |
|---|---|
| `[CAT]->(attr)->[FAST].` | "A cat is fast." |
| `[PERSON: ivan]->(loc)->[PLACE].` | "Ivan is in a place." |

Restart Lisp and run `(generation-test t)`.

## User

looks good:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats a food."
    actual:   "A dog eats a food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  pass  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to him."
  pass  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to her."
  pass  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to them."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a dog that eats a pie."
    actual:   "A boy gives a dog that eats a pie."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a girl who eats a pie."
    actual:   "A boy gives a girl who eats a pie."
  pass  "[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]."
    expected: "Ivan knows that a girl eats a pie."
    actual:   "Ivan knows that a girl eats a pie."
  pass  "[CAT]->(attr)->[FAST]."
    expected: "A cat is fast."
    actual:   "A cat is fast."
  pass  "[PERSON: ivan]->(loc)->[PLACE]."
    expected: "Ivan is in a place."
    actual:   "Ivan is in a place."
  all 13 generation cases passed.
T
CG>

## Assistant

Item 2 (mass-noun overrides). Registering common mass nouns and updating the FOOD test expectation.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/lexicon.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Recompile lexicon` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Item 2 done. Lexicon now ships with ~30 mass nouns registered with `:mass-p t`. The `article-for` function already returned `nil` for mass nouns, so this just plugs them in. The `[DOG]...[FOOD]` test now expects "A dog eats food." (no article).

Want to run `(generation-test t)` to verify before I continue with item 3 (active/passive heuristic)?

## User

still looks good:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats food."
    actual:   "A dog eats food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  pass  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to him."
  pass  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to her."
  pass  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to them."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a dog that eats a pie."
    actual:   "A boy gives a dog that eats a pie."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a girl who eats a pie."
    actual:   "A boy gives a girl who eats a pie."
  pass  "[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]."
    expected: "Ivan knows that a girl eats a pie."
    actual:   "Ivan knows that a girl eats a pie."
  pass  "[CAT]->(attr)->[FAST]."
    expected: "A cat is fast."
    actual:   "A cat is fast."
  pass  "[PERSON: ivan]->(loc)->[PLACE]."
    expected: "Ivan is in a place."
    actual:   "Ivan is in a place."
  all 13 generation cases passed.
T
CG>

## Assistant

Item 3: passive voice when AGNT is absent. Adding the `past-participle` morphology helper, the `realize-passive-clause`, and a 3-way dispatch in `graph-to-text`.

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/morphology.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Write]* `/Users/bseely/repo/cgraph/system/generation/generate.lisp` — write

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Recompile` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Item 3 done. Changes:

- **`morphology.lisp`** — added `past-participle` (irregular table for the irregulars, `past-tense` form for regulars).
- **`realizer.lisp`** — added `realize-passive-clause`. The OBJ's other end becomes the surface subject; verb gets `is/are <past-participle>` form; iobj/PP/adv complements follow as in active.
- **`generate.lisp`** — three-way dispatch: subject relation present → active; act/event present without subject → passive; otherwise → copula.

Three new tests:
| Input | Expected |
|---|---|
| `[PIE]<-(obj)<-[EAT].` | "A pie is eaten." |
| `[FOOD]<-(obj)<-[EAT].` | "Food is eaten." |
| `[PIE]<-(obj)<-[GIVE]->(rcpt)->[GIRL].` | "A pie is given to a girl." |

Restart Lisp and run `(generation-test t)`.

## User

it's good:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats mannerly."
    actual:   "Sue eats mannerly."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats food."
    actual:   "A dog eats food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  pass  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to him."
  pass  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to her."
  pass  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to them."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a dog that eats a pie."
    actual:   "A boy gives a dog that eats a pie."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a girl who eats a pie."
    actual:   "A boy gives a girl who eats a pie."
  pass  "[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]."
    expected: "Ivan knows that a girl eats a pie."
    actual:   "Ivan knows that a girl eats a pie."
  pass  "[CAT]->(attr)->[FAST]."
    expected: "A cat is fast."
    actual:   "A cat is fast."
  pass  "[PERSON: ivan]->(loc)->[PLACE]."
    expected: "Ivan is in a place."
    actual:   "Ivan is in a place."
  pass  "[PIE]<-(obj)<-[EAT]."
    expected: "A pie is eaten."
    actual:   "A pie is eaten."
  pass  "[FOOD]<-(obj)<-[EAT]."
    expected: "Food is eaten."
    actual:   "Food is eaten."
  pass  "[PIE]<-(obj)<-[GIVE]->(rcpt)->[GIRL]."
    expected: "A pie is given to a girl."
    actual:   "A pie is given to a girl."
  all 16 generation cases passed.
T
CG>

## Assistant

Item 4: adverbify cleanup for MANNER. Adding an `:adv-form` lexicon slot and registering MANNER → "somehow".

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/lexicon.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/system/generation/realizer.lisp` — edit

## Assistant

*[tool: Edit]* `/Users/bseely/repo/cgraph/test/generation-test.lisp` — edit

## Assistant

*[tool: Bash]* `Recompile changed files` — `sbcl --non-interactive --eval "(ql:quickload :swank)" --eval "(push (truename \".\") asdf:*central-registry*)" --eval "(`

## Assistant

Item 4 done. Adverb-form overrides registered for MANNER ("somehow"), TIME ("sometime"), and PLACE ("somewhere"). `realize-adv` consults `:adv-form` before falling through to suffix derivation, so abstract category labels get sensible adverbs instead of "mannerly".

The MANNER test now expects "Sue eats somehow." Restart Lisp and run `(generation-test t)`.

## User

it's good:
CG> (generation-test t)

generation-test
  pass  "[girl]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A girl eats a pie."
    actual:   "A girl eats a pie."
  pass  "[person: sue]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "Sue eats a pie."
    actual:   "Sue eats a pie."
  pass  "[girl:sue]<-(agnt)<-[EAT]->(manr)->[MANNER]."
    expected: "Sue eats somehow."
    actual:   "Sue eats somehow."
  pass  "[DOG]<-(agnt)<-[EAT]->(obj)->[FOOD]."
    expected: "A dog eats food."
    actual:   "A dog eats food."
  pass  "[CAT]<-(agnt)<-[SIT]->(loc)->[PLACE]."
    expected: "A cat sits in a place."
    actual:   "A cat sits in a place."
  pass  "[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z]."
    expected: "A boy gives to him."
    actual:   "A boy gives to him."
  pass  "[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z]."
    expected: "A girl gives to her."
    actual:   "A girl gives to her."
  pass  "[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z]."
    expected: "A person gives to them."
    actual:   "A person gives to them."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a dog that eats a pie."
    actual:   "A boy gives a dog that eats a pie."
  pass  "[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]."
    expected: "A boy gives a girl who eats a pie."
    actual:   "A boy gives a girl who eats a pie."
  pass  "[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]."
    expected: "Ivan knows that a girl eats a pie."
    actual:   "Ivan knows that a girl eats a pie."
  pass  "[CAT]->(attr)->[FAST]."
    expected: "A cat is fast."
    actual:   "A cat is fast."
  pass  "[PERSON: ivan]->(loc)->[PLACE]."
    expected: "Ivan is in a place."
    actual:   "Ivan is in a place."
  pass  "[PIE]<-(obj)<-[EAT]."
    expected: "A pie is eaten."
    actual:   "A pie is eaten."
  pass  "[FOOD]<-(obj)<-[EAT]."
    expected: "Food is eaten."
    actual:   "Food is eaten."
  pass  "[PIE]<-(obj)<-[GIVE]->(rcpt)->[GIRL]."
    expected: "A pie is given to a girl."
    actual:   "A pie is given to a girl."
  all 16 generation cases passed.
T
CG>

## Assistant

All 16 cases pass. All four polish items in Phase 6 are landed.

The full implementation now covers:

| Sowa rule | Implementation |
|---|---|
| Rule 1 | `walker.lisp` — `find-main-predicate`, `classify-relations` |
| Rule 2 | `lexicon.lisp` + `morphology.lisp` — POS, articles, conjugation, pluralization |
| Rule 3 | `realizer.lisp` — `realize-relative-clause` (`who`/`that`) |
| Rule 4 | `realizer.lisp` — `realize-nested-graph` (`that`-clauses) |
| Rule 5 | `anaphora.lisp` — pronoun selection with case + gender + number |
| Rule 6 | `realize-clause` returns to main predicate |
| Polish | copula, mass nouns, passive voice, abstract-category adverbs |

Six files, ~700 LOC total in `system/generation/`. 16 tests covering active, passive, copula, anaphora, relative clauses, and nested propositions.

What's explicitly **not** in the implementation, per the original Phase plan:
- **Verb-particle splitting** (Sowa Rule 2 second half — "carry out" with displaced particle)
- **Raising** (Sowa Rule 4 second half — "Ivan is believed to be in the kitchen")
- **Graph decomposition by inference** (Sowa Rule 6 second half — splitting a complex graph into multiple sentences)
- **Tense and aspect** beyond present (no past/future/perfect/progressive selection from referent or modifier cues)
- **Quantification** (`@every`, `@some`, count referents → "every X", "two X")
- **Coordination** (no AND/OR composition of clauses)
- **Active/passive choice when both AGNT and OBJ are present** (always picks active)

If you want any of those next, name it. Otherwise the system is ready to use — `(graph-to-text "...")` from the REPL, or `(generation-test t)` to confirm. Worth saving a project memory note about the module layout?

## User

Can you save the transcript of the entire process?

## Assistant

I don't have direct access to the raw conversation transcript — Claude Code keeps sessions in its own storage and doesn't expose a "dump transcript" tool to me. Let me check whether there's a session log on disk I can locate, otherwise I'll write a structured retrospective document instead.

## Assistant

*[tool: Bash]* `Check Claude session storage` — `ls ~/.claude/projects/-Users-bseely-repo-cgraph/ 2>/dev/null | head -20`

## Assistant

*[tool: Bash]* `Find current session file` — `ls -lt ~/.claude/projects/-Users-bseely-repo-cgraph/*.jsonl 2>/dev/null | head -5`

## Assistant

*[tool: Bash]* `Inspect JSONL structure` — `head -2 /Users/bseely/.claude/projects/-Users-bseely-repo-cgraph/e649fb12-f4ad-4ee3-9287-01385185c0b1.jsonl | python3 -c`

## Assistant

*[tool: Bash]* `Count message types` — `python3 -c "
import json
seen_types = {}
with open('/Users/bseely/.claude/projects/-Users-bseely-repo-cgraph/e649fb12-f4`

## Assistant

*[tool: Bash]* `Inspect message shapes` — `python3 -c "
import json
with open('/Users/bseely/.claude/projects/-Users-bseely-repo-cgraph/e649fb12-f4ad-4ee3-9287-013`

## Assistant

*[tool: Write]* `/tmp/extract_transcript.py` — write

