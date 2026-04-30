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

**Required:**

- `*relation-syntax-table*` (`syntax-roles.lisp`)
  Add `(label role &optional preposition)`. Roles: `:subject :dobj :iobj :pp
  :adj :adv :poss :nmod :pred-cmp`.

  **Pick the role by asking what role the relation's argument plays in
  English:**

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
  (cause :pp "because of")        ; [EAT]->(cause)->[HUNGER] => "...because of hunger"
  (orig  :pp "from")              ; [LETTER]->(orig)->[BOB] => "...from Bob"
  (recip :iobj "to")              ; [GIFT]->(recip)->[MARY] => "...to Mary"
  ```

  If you don't know which role, render a sample graph with
  `(graph-to-text g)` and see what's missing — the symptom usually picks the
  role for you.

**Recommended (most spatial / temporal / partitive relations):**

- `*pp-relation-priority*` (`syntax-roles.lisp`)
  Position in this list controls ordering of PPs within a clause. Earlier =
  emitted first.

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
- `entity`              → fallback `:noun`
- `animate`             → drives `animate-concept-p`
- `person`              → drives `human-p` and pronoun gender defaults

If you reorganize the upper lattice, audit `lexicon.lisp` and `anaphora.lisp`
for these symbols.

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
- `*given-name-genders*`     — keyed on downcased given-name string

You can extend `*given-name-genders*` at runtime with
`(register-name-gender 'priya :fem)`.

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
| Relation completely missing from output          | `*relation-syntax-table*` entry         |
| Relation in the wrong position in the clause     | `*pp-relation-priority*` ordering       |
| Wrong preposition on an NP modifier              | `*np-pp-prepositions*` entry            |
| "a food" instead of "food"                       | `:mass-p t` on the type                 |
| "childs" instead of "children"                   | `*irregular-plurals*` row               |
| "eated" instead of "ate"                         | `*irregular-verbs*` row                 |
| Wrong pronoun gender on a name                   | `register-name-gender`                  |
| "it" for a person of unknown gender              | `:human-p t` on the type (→ "they")     |
| "believing" as the main verb of a BELIEF clause  | `:lemma "believe"` on BELIEF            |
| "inform Bob about the news" rendered as "inform the news to Bob" | `:rcpt-direct t :obj-prep "about"` |
| "mannerly" instead of "somehow"                  | `:adv-form` on the type                 |

If none of these apply, the bug is in dispatch (`graph-to-text` in
`generate.lisp`) or the realizer, not a table.
