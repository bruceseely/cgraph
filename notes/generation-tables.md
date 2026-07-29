# Generation Tables — Cheat Sheet

**Scope:** this document covers the **graph-to-text generation** subsystem
only (`system/generation/`). The rest of cgraph — type lattice, projection,
query, the web UI — does not consult these tables. If you are not generating
English from a CG, nothing here applies.

A reference for which tables in `system/generation/` may need attention when
you add a new concept type, relation type, or notice a wrong-output bug.

The generation system is **exception-driven**: most types need no table edits
because POS, number, definiteness, and pronoun choice are derived by walking
the type lattice. Tables exist to record cases where the default is wrong.

The big asymmetry: **relations always need a table entry; concept types
usually don't.**

---

## When you add a new RELATION type

A relation that is not in `*relation-syntax-table*` is silently dropped during
generation. This is the one hard rule.

Everything about relations fails the same way — the relation vanishes from the
output and nothing is signalled — so it is worth knowing the four distinct ways
it can happen. `lexicon-lint` checks all four; see "Relation table failures"
near the end of this document.

**Required:**

- `*relation-syntax-table*` (`syntax-roles.lisp`)
  Add `(label role &optional preposition)`. 
  Roles: `:subject :dobj :iobj :pp :adj :adv :poss :nmod`.
  (`:pred-cmp` is declared but no realizer reads it — mapping a relation to
  it silently drops the relation. Use `:dobj` for clausal complements.)

  **Pick the role by asking what role the relation's argument plays in English:**
  
  | Role         | Example use                          | Surface form                       |
  |--------------|--------------------------------------|------------------------------------|
  | `:subject`   | AGNT, EXPR — who does the action     | "**Bob** eats a pie"               |
  | `:dobj`      | OBJ, PTNT — what the action acts on  | "Bob eats **a pie**"               |
  | `:iobj`      | RCPT — to whom (uses preposition)    | "Bob gives a pie **to Mary**"      |
  | `:pp`        | LOC, INST, DUR — where/with/how-long | "Bob eats a pie **in the kitchen**" |
  | `:adj`       | ATTR, CHRC — descriptive property    | "the **red** pie"                  |
  | `:adv`       | MANR — manner of action              | "Bob eats a pie **quickly**"       |
  | `:poss`      | POSS — ownership                     | "**Bob's** pie" / "Bob has a pie"  |
  
  Examples:
  ```lisp
  (cause :pp "because of")  ; [EAT]->(cause)->[HUNGER] => "...because of hunger"
  (orig  :pp "from")        ; [LETTER]->(orig)->[BOB] => "...from Bob"
  (recip :iobj "to")        ; [GIFT]->(recip)->[MARY] => "...to Mary"
  ```
  
  If you don't know which role, render a sample graph with
  `(graph-to-text g)` and see what's missing — the symptom usually picks the
  role for you.

**Recommended (most spatial / temporal / partitive relations):**

- `*pp-relation-priority*` (`syntax-roles.lisp`)
  Position in this list controls ordering of PPs within a clause. Earlier = emitted first.
  
  Example: `loc` comes before `time` so we generate "Bob eats **in the
  kitchen at noon**" rather than "Bob eats at noon in the kitchen." If your
  new relation is spatial, put it near `loc`; if temporal, near `time`.
  
- `*np-pp-prepositions*` (`syntax-roles.lisp`)
  Only needed when the relation can attach to an NP head (post-modifier).
  Source-side and dest-side prepositions are usually different.

  Example for `cntns` (containment): the source side ("the bottle") uses
  "containing" — "**the bottle containing milk**". The dest side ("the milk")
  uses "in" — "**the milk in the bottle**". Same relation, two different
  English prepositions depending on which concept the NP is built around.

---

## When you add a new CONCEPT type

In most cases: **do nothing.** The lattice walk handles it.

POS is decided by `pos-from-hierarchy` (`lexicon.lisp`):

| Supertype reached | POS  |
|-------------------|------|
| ACT or EVENT      | verb |
| MANNER            | adv  |
| ATTRIBUTE         | adj  |
| (anything else)   | noun |

Animacy / humanness uses `safe-subtype-p label 'animate'` and `'person'`.

So if your new type sits under the right supertype, generation works. The
tables below only matter for exceptions.

### Concept-type override checklist

Walk this list when defining a new type. Most rows will be "skip."

| If the type is...                                  | Register             | Example call                                        |
|----------------------------------------------------|----------------------|-----------------------------------------------------|
| A state-noun used as a verb (BELIEF→"believe")     | `:lemma`             | `(register-lexicon-entry 'belief :lemma "believe")` |
| A mass noun (FOOD, RICE, WATER)                    | `:mass-p t`          | `(register-lexicon-entry 'rice  :mass-p t)`         |
| Has irregular plural (CHILD→"children")            | row in `*irregular-plurals*` (keyed on lemma string) | `("child" "children")` in `*irregular-plurals*` |
| Is an irregular verb (EAT→ate/eaten)               | row in `*irregular-verbs*` (keyed on lemma string)   | `("eat" "ate" "eaten" "eats")` in `*irregular-verbs*` |
| A gendered common noun (MAN, WOMAN, BOY, GIRL)     | `:gender :masc/:fem :human-p t` | `(register-lexicon-entry 'woman :gender :fem :human-p t)` |
| Should always be human even without :gender        | `:human-p t`         | `(register-lexicon-entry 'doctor :human-p t)`       |
| Should always be animate                           | `:animate-p t`       | `(register-lexicon-entry 'cat    :animate-p t)`     |
| An abstract category whose adverb form is special  | `:adv-form "..."`    | `(register-lexicon-entry 'manner :adv-form "somehow")` |
| A communication verb taking recipient as DObj      | `:rcpt-direct t :obj-prep "..."` | `(register-lexicon-entry 'inform :rcpt-direct t :obj-prep "about")` |
| Always treated as a proper noun                    | `:proper-p t`        | `(register-lexicon-entry 'manhattan :proper-p t)`   |
| Has a non-default POS the hierarchy can't tell     | `:pos :verb/:noun/...` | `(register-lexicon-entry 'paint :pos :verb)`      |

All of these go through `register-lexicon-entry 'TYPE-LABEL :key value ...`
except the irregular-verb and irregular-plural tables, which are direct list
entries keyed on the **lemma string** (not the type label).

### Hierarchy-level supertypes referenced by code

These labels are queried by `safe-subtype-p` during generation. Renaming or
removing one breaks defaults across the lattice:

- `act`, `event`        → drive `:verb` POS classification
- `manner`              → drives `:adv` POS classification
- `attribute`           → drives `:adj` POS classification
- `animate`             → drives `animate-concept-p`
- `person`              → drives `human-p` and pronoun gender defaults
- `situation`           → drives infinitive vs. `that`-clause complements

(There is no `entity` root: anything matching none of the above falls through
to `:noun` unconditionally.)

If you reorganize the upper lattice, audit `lexicon.lisp`, `anaphora.lisp`,
`walker.lisp`, and `realize-pp.lisp` for these symbols — and see
"Types the generation code expects" below for what breaks if one is absent.

---

## Tables that DON'T depend on types

These are structural / English-grammatical and rarely need editing:

- `*pronoun-table*` (`anaphora.lisp`) — pronoun by gender/number/case
- `*role-emission-order*` (`syntax-roles.lisp`) — clause linearization order
- `*vowels*` (`morphology.lisp`)

---

## Tables keyed on STRINGS, not types

These are independent of the concept-type lattice — they look up the surface
lemma or name regardless of which type produced it:

- `*irregular-verbs*`        — keyed on verb lemma
- `*irregular-plurals*`      — keyed on noun lemma
- `*unit-words*`             — keyed on unit abbreviation
- `*given-name-genders*`     — keyed on downcased given-name string

You can extend `*given-name-genders*` at runtime with
`(register-name-gender 'priya :fem)`.

Because they're general English data rather than bindings to your ontology,
**a row for a word your catalog never mentions is normal, not a defect** —
there is deliberately no staleness check for them. What the lint does check is
internal consistency; see "String-keyed table failures" below.

---

## Where to put user additions

`~/.cgraph/initializations.lisp` is evaluated at startup. It is the natural
place for:

```lisp
(register-lexicon-entry 'cat   :animate-p t)
(register-lexicon-entry 'sugar :mass-p t)
(register-name-gender   'priya :fem)
```

System defaults (the lists shipped with cgraph) live in
`system/generation/lexicon.lisp` and `system/generation/anaphora.lisp`.
If a default is universally wrong, fix it there; if it's a personal addition,
keep it in `initializations.lisp`.

---

## Diagnosing wrong output

When a generated sentence is wrong, the question to ask is which table — if
any — would have prevented it:

| Symptom                                          | Likely fix                              |
|--------------------------------------------------|------------------------------------------|
| Relation completely missing from output          | run `(report-lexicon-lint)` — four different table faults produce this, see below |
| Every sentence comes out as "X is Y"             | nothing maps to `:subject`              |
| Relation in the wrong position in the clause     | `*pp-relation-priority*` ordering       |
| Wrong preposition on an NP modifier              | `*np-pp-prepositions*` entry            |
| "a food" instead of "food"                       | `:mass-p t` on the type                 |
| "childs" instead of "children"                   | `*irregular-plurals*` row               |
| "eated" instead of "ate"                         | `*irregular-verbs*` row                 |
| a `:past`/`:gerund` override has no effect       | those keys are inert — add an `*irregular-verbs*` row |
| "bes"/"gos" despite an `*irregular-verbs*` row   | the row is short — `(fourth row)` is `NIL` |
| Wrong pronoun gender on a name                   | `register-name-gender`                  |
| "it" for a person of unknown gender              | `:human-p t` on the type (→ "they")     |
| "believing" as the main verb of a BELIEF clause  | `:lemma "believe"` on BELIEF            |
| "inform Bob about the news" rendered as "inform the news to Bob" | `:rcpt-direct t :obj-prep "about"` |
| "mannerly" instead of "somehow"                  | `:adv-form` on the type                 |

If none of these apply, the bug is in dispatch (`graph-to-text` in
`generate.lisp`) or the realizer, not a table.

---

## Types the generation code expects

Everything above assumes the shipped upper ontology. You are free to supply
your own type definitions, and cgraph will not stop you — but the generation
subsystem hard-codes a small number of type labels, and a catalog that omits
one of them produces **silently wrong English rather than an error.**

Note this is *only* about the generation subsystem. A missing type is not a
problem for the lattice, projection, query, or the web UI. And a type used
*inside a graph* that isn't defined is a different, non-silent case: the
reader rejects it at parse time (`reader.lisp`), long before generation.

### Why it degrades instead of failing

`subtype-p` signals an error for an unknown label, but every generation call
site wraps the call:

- `safe-subtype-p` (`lexicon.lisp`) — `handler-case ... (error () nil)`
- `act-or-event-concept-p` (`walker.lisp`) — `handler-case` per root
- `clausal-situation-p` (`realize-pp.lisp`) — `ignore-errors`

So a missing root makes its predicate return NIL, and the caller takes its
default branch. Nothing crashes. `test/generation-roots-lint-test.lisp` pins
this down: with `ACT` and `EVENT` removed from the catalog,
`pos-from-hierarchy` classifies `GIVE` as `:noun` and signals nothing.

This is deliberate — a partial ontology should still generate *something* —
but it means **the absence of an error is not evidence that generation is
working.**

### The expected labels

The authoritative list is `*generation-hierarchy-roots*` (`lexicon.lisp`),
which pairs each root with what breaks when it's absent and how to work
around it. The lint check reads that table, so this list and the check
cannot drift apart:

| Label       | Consulted by                                      | If absent, generation…                                                                   | Lint    |
|-------------|---------------------------------------------------|------------------------------------------------------------------------------------------|---------|
| `act`       | `*pos-hierarchy-roots*`; `act-or-event-concept-p` | classifies every verb as `:noun`, **and** loses a main-predicate fallback — see below     | `:warn` |
| `event`     | same as `act`                                      | same as `act`                                                                              | `:warn` |
| `manner`    | `*pos-hierarchy-roots*`                            | renders adverbs as nouns                                                                   | `:warn` |
| `attribute` | `*pos-hierarchy-roots*`                            | renders adjectives as nouns                                                                | `:warn` |
| `person`    | `human-p` (`anaphora.lisp`)                        | never says "he"/"she"/"they" for a person — falls back to "it"                              | `:warn` |
| `animate`   | `animate-concept-p` (`anaphora.lisp`)              | treats every referent as inanimate for pronoun and POSS purposes                            | `:warn` |
| `situation` | `clausal-situation-p` (`realize-pp.lisp`)          | renders every clausal complement as a `that`-clause, never an infinitive ("wants to go")   | `:info` |

`SITUATION` is `:info` rather than `:warn` because its fallback is always
grammatical — just sometimes stilted. The rest change whether the output is
*correct*.

`ACT` / `EVENT` are the most damaging, because they are load-bearing twice
over. Beyond POS, `act-or-event-concept-p` feeds `find-main-predicate`,
`copula-required-p`, and `have-clause-p` in `walker.lisp` — so their absence
degrades *sentence structure*, not just word class. A graph that should render
as a verbal clause may come out as a copular or possessive one.

`SITUATION`'s fallback is the mildest: the `that`-clause form is always
grammatical, just sometimes stilted. That fallback is intentional and
documented in `clausal-situation-p`'s docstring.

### What the startup lint catches

`report-lexicon-lint` runs at startup under `*run-lexicon-lint-on-startup*`
(`definitions.lisp`; called from `initialize.lisp`). Run it by hand any time
with `(report-lexicon-lint)`.

It catches:

- **any absent root from the table above** (`:missing-generation-root`) — the
  finding names the consequence and the remedy for that specific root
- **all four relation-table failure directions** — see "Relation table
  failures" below, plus `:pp-table-role-mismatch` and
  `:missing-generation-relation`
- stale lexicon overrides naming types that no longer exist, and override
  **keys** that are misspelled or inert (see "Override keys" below)
- **malformed, duplicated or redundant rows** in the string-keyed tables
- `PERSON` subtypes lacking a `:gender` override — or, when `PERSON` itself is
  absent, a `:person-check-skipped` note saying the check could not run. That
  distinction matters: this check walks down from `PERSON`, so without it the
  check has nothing to look at, and quiet output would otherwise read as a
  clean bill of health in precisely the case where pronouns are most broken

Startup output is filtered by `*run-lexicon-lint-on-startup*`; the default
`:all` shows everything, `:errors-warnings` hides the `:info` tier (including
`SITUATION` and the skipped-check note), and `:errors-only` shows just
unmapped relations. If you are debugging an ontology, run `(report-lexicon-lint)`
by hand — it always reports at `:info`.

### If you're bringing your own ontology

To generate English you want, at minimum, the seven labels above present and
positioned so that the intended types actually fall under them — a defined
`ACT` that nothing is a subtype of is no better than a missing one.

If you can't or don't want to adopt those labels, the escape hatch is explicit
per-type overrides, which bypass the lattice walk entirely:

```lisp
(register-lexicon-entry 'run    :pos :verb)     ; instead of relying on ACT
(register-lexicon-entry 'doctor :human-p t)     ; instead of relying on PERSON
(register-lexicon-entry 'cat    :animate-p t)   ; instead of relying on ANIMATE
```

That is viable for a small catalog and unpleasant for a large one — the
override has to be repeated for every affected type, whereas one correctly
placed root covers the whole subtree. Prefer fixing the lattice; reach for
overrides when a type genuinely doesn't fit under any root. (`SITUATION` has
no override escape hatch — either define it or accept `that`-clauses.)

Nothing else in `system/generation/` requires a particular type to exist. The
shipped `register-lexicon-entry` calls at the bottom of `lexicon.lisp` (mass
nouns, particle verbs, communication verbs, `BELIEF`→"believe", …) are keyed
on label *strings* and register harmlessly whether or not the type is defined;
the ones that don't match your catalog surface as `:stale-lexicon-override`
warnings, which are informational, not breakage.

---

## Relation table failures

The concept side degrades because a *type* is missing. The relation side
degrades because the *table* between the catalog and the realizer is wrong,
and there are four independent ways for that to happen. All four produce the
same symptom — the relation is absent from the generated text, with nothing
signalled — which is why they need separate checks to tell apart.

Think of it as a square with the catalog, the syntax table, the set of roles,
and the realizer at its corners:

| Direction            | Failure                                                    | Check                              | Severity |
|----------------------|------------------------------------------------------------|------------------------------------|----------|
| catalog → table      | you defined a relation nothing maps                         | `:relation-not-mapped`             | `:error` |
| role → table         | no relation in *your* catalog maps to a role                | `:syntax-role-uncovered`           | varies   |
| table → realizer     | the mapped role is one no realizer reads                    | `:unknown-syntax-role`             | `:error` |
| table → catalog      | the entry names a relation you never defined                | `:stale-relation-entry`            | `:info`  |

The asymmetry in severity is deliberate. A relation you defined with no entry
loses output, so it's an error. An entry for a relation you never defined is
dead weight that can never fire, so it's informational — the shipped tables
cover more relations than most catalogs define, and a handful of these is
normal.

### Role coverage

A role is only reachable if some relation **in your catalog** maps to it. An
entry for a relation you never defined provides no coverage — the check tests
liveness, not mere presence in the table.

`*generation-syntax-roles*` (`syntax-roles.lisp`) records what each role's
absence costs. `:subject` is the severe one, and it's an `:error`: with nothing
mapped to it, `find-subject-relation` never fires, `copula-required-p` is
always true, and **every** graph renders as a copular clause. `:dobj` is a
`:warn` (transitive verbs lose their objects). The rest are `:info` — a
catalog with no manner relation legitimately has no adverbs.

### Roles the realizer doesn't read

Two ways to map a relation to a role that does nothing:

- **A typo.** `:pos` instead of `:poss` looks plausible and is silently inert:
  every consumer compares the role against the keywords it handles, nothing
  matches, and the relation drops out.
- **A declared-but-unimplemented role.** `:pred-cmp` appears in the documented
  role list and in `*role-emission-order*`, but no realizer consumes it. Map a
  relation to it and the relation disappears. Use `:dobj` for clausal
  complements — that's what `prop` does.

Both are `:error`, because the consequence is identical to having no entry.

### PP support-table consistency

`*pp-relation-priority*`, `*np-pp-prepositions*` and
`*clause-level-pp-relations*` are all consulted behind a `:pp` role test. An
entry naming a relation whose role is something else can never fire —
`:pp-table-role-mismatch`, `:warn`. Relations that are absent from the catalog
or unmapped are skipped here, since the checks above already report them.

### Relation labels hard-coded in the realizer

Almost all relation handling is table-driven, so there is only one:
`*generation-relation-labels*` records `time`, which `realize-pp.lisp` names
literally for the deictic-adverb path ("yesterday" as a bare adverb rather than
"at yesterday"). Without a `TIME` relation the `string-equal` never matches and
that path goes quietly dead — `:missing-generation-relation`, `:info`, since
the prepositional form is still grammatical.

---

## String-keyed table failures

`*irregular-verbs*`, `*irregular-plurals*` and `*unit-words*` are looked up by
surface string, so none of the catalog-facing checks apply to them. Their
failure modes are internal, and all four are silent:

| Failure | What happens | Check | Severity |
|---|---|---|---|
| wrong arity | the missing column reads as `NIL`, and the caller's `(or irregular regular)` falls through to the rule | `:malformed-table-row` | `:error` |
| non-string cell | `string-equal` may still match, then the value reaches `concatenate` and signals *there* | `:malformed-table-row` | `:error` |
| duplicate lemma | `assoc` returns the first row; later ones are unreachable | `:duplicate-table-key` | `:warn` |
| redundant row | restates what the regular rules already derive | `:redundant-irregular-row` | `:info` |

The arity case is the nasty one. Drop the `"is"` from the `be` row and nothing
complains — you just start generating "bes", because `present-3sg` gets `NIL`
from `(fourth row)` and falls back to the regular `-s` rule.

The redundancy check derives the comparison by calling the real morphology with
the tables rebound to `NIL`, rather than restating the `-y`/`-ied` rules, so it
can't drift from the rules it's checking. Three shipped rows are redundant
today — `believe`, `own`, `love` — harmless, but worth knowing before you read
the table as a list of English irregulars.

`*string-keyed-generation-tables*` (`lexicon.lisp`) is the spec these checks
read: table symbol, arity, column names, and what consults it.

### Override keys

`register-lexicon-entry` takes an unchecked `&rest` plist, so a misspelled key
is stored and ignored in silence:

```lisp
(register-lexicon-entry 'rice :massp t)   ; typo — does nothing, says nothing
```

`*lexicon-override-keys*` (`lexicon.lisp`) lists every key and what reads it;
`:unknown-lexicon-key` is an `:error`.

Four documented keys are **declared but inert** — `:past`,
`:past-participle`, `:present-3sg`, and `:gerund`. The morphology functions
take a bare lemma string rather than a concept, so they have no way to reach a
per-type override; they consult `*irregular-verbs*` instead. Setting one of
these does nothing at all. They lint as `:unimplemented-lexicon-key`, `:error`,
with the alternative named in the message. To give a type irregular verb forms,
add a row to `*irregular-verbs*`. There is no override path for `:gerund` —
`present-participle` is purely rule-driven.

### A check that used to be here

An earlier check flagged concept types whose label appears in
`*irregular-verbs*` but whose POS isn't `:verb`, on the theory that the
irregular forms could never be reached. **That premise is false**, and the
check has been removed rather than repaired.

The morphology is reached by *lemma string* from the clause realizer, for
whatever concept `find-main-predicate` selects — and that selection is
structural (it follows the subject relation), not POS-driven. `KNOW` is
classified `:noun` and still generates "Ivan is known to eat a pie"; "known"
can only have come from the table, since the rule would give "knowed". So the
check fired on every state-noun predicate — `KNOW`, `BELIEF`, `THOUGHT` — which
is exactly the intended design, and its advice (move the type under `ACT`, or
force `:pos :verb`) would have turned a noun like `SET` into a verb.

Worth remembering when reading the rest of this document: **`concept-pos`
governs how a concept is realized as an NP, adjective or adverb — not whether
the main predicate gets conjugated.**
