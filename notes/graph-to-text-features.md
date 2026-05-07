# Graph-to-text — feature catalogue

A tour of what the realizer in `system/generation/` produces, with a
worked example for every feature. Examples are taken from
`test/generation-test.lisp`, so each line is a regression-tested
input/output pair.

The basic call is `(graph-to-text (make-cgraph "<CGIF string>"))`. The
graph carries its head (the bracketed concept the parser entered first),
which matters for the head-driven passive transformation in §5.

For internals — dispatch order, file split, lexicon-override slot list,
where to extend — see `memory/project_generation_architecture.md`. For
deferred work, see `notes/graph-to-text-todo.md`.

## 1. Noun phrases

### 1.1 Article selection

| Input                    | Output       |
|--------------------------|--------------|
| `[girl]`                 | A girl.      |
| `[girl: #]`              | The girl.    |
| `[girl: #9999]`          | The girl.    |
| `[girl: Sally]`          | Sally.       |

A bare concept is indefinite. A `#` referent (with or without an id)
makes it definite. A name referent surfaces as a proper noun.

### 1.2 Plurals and sets

| Input                          | Output                      |
|--------------------------------|-----------------------------|
| `[dog: {}]`                    | Dogs.                       |
| `[dog: {*}]`                   | Dogs.                       |
| `[dog: {*}@3]`                 | Three dogs.                 |
| `[dog: {Spot, Fido}]`          | The dogs Spot and Fido.     |
| `[dog: {Butch, Spot, Fido}]`   | The dogs Butch, Spot, and Fido. |
| `[DOG: {Fido, *} @3]`          | Fido and two other dogs.    |
| `[DOG: {Fido, #123}]`          | Fido and another dog.       |

Empty / generic / cardinal-only sets produce a plain plural. Mixed
named-and-unnamed sets render the named members and summarise the rest.

### 1.3 Measures

| Input                                  | Output                          |
|----------------------------------------|---------------------------------|
| `[length: @5 ft.]`                     | The length five feet.           |
| `[rock]→(chrc)→[LENGTH: @25.4 cm].`    | A rock of the length 25.4 centimeters. |

`@<number> <unit>` is a measure annotation; the unit is expanded to its
long form ("ft" → "feet").

## 2. Quantifiers

`@every` / `@all` / `@any` are universal; `@some` is existential. The
quantifier slot is on the concept and lives across every realization
position.

| Input                                          | Output                  |
|------------------------------------------------|-------------------------|
| `[CAT: @every]`                                | Every cat.              |
| `[CAT: @some]`                                 | A cat.                  |
| `[DOG: {*}@every]`                             | All dogs.               |
| `[DOG: {*}@some]`                              | Some dogs.              |
| `[DOG: @every]<-(agnt)<-[BARK].`               | Every dog barks.        |
| `[DOG: {*}@every]<-(agnt)<-[BARK].`            | All dogs bark.          |
| `[CAT: {*}@every]->(attr)->[FAST].`            | All cats are fast.      |
| `[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE: @every].` | A girl eats every pie.  |

Quantifiers nested inside a `[PROPOSITION: ...]` referent flow through
unchanged:

```
[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [DOG: @every]<-(agnt)<-[BARK]].
  →  Ivan knows that every dog barks.
```

## 3. Tense

Annotated on the verb concept.

| Annotation         | Example output                     |
|--------------------|-------------------------------------|
| `@past`            | A girl ate a pie.                   |
| `@future`          | A girl will eat a pie.              |
| `@present` (default) | A girl eats a pie.                |

Tense propagates through passive voice — `[PIE]<-(obj)<-[EAT: @past].`
→ "A pie was eaten."

### 3.1 Tense inference from TIME relation

When no explicit tense annotation is given, a TIME arc with a deictic
lemma sets the tense and surfaces as a bare adverb:

| Input                                                                | Output                          |
|----------------------------------------------------------------------|---------------------------------|
| `[GIRL]<-(agnt)<-[EAT]-(obj)→[PIE](time)→[time-period: yesterday].`  | A girl ate a pie yesterday.     |
| `[GIRL]<-(agnt)<-[EAT]-(obj)→[PIE](time)→[time-period: tomorrow].`   | A girl will eat a pie tomorrow. |
| `[GIRL]<-(agnt)<-[EAT]-(obj)→[PIE](time)→[time-period: now].`        | A girl eats a pie now.          |

Explicit annotation wins over inference:
`[EAT: @past]...[time-period: tomorrow]` → "A girl ate a pie tomorrow."

## 4. Aspect

| Annotation              | Output                                 |
|-------------------------|----------------------------------------|
| `@progressive`          | A girl is eating a pie.                |
| `@perfect`              | A girl has eaten a pie.                |
| `@past-progressive`     | A girl was eating a pie.               |
| `@past-perfect`         | A girl had eaten a pie.                |
| `@future-perfect`       | A girl will have eaten a pie.          |
| `@future-progressive`   | A girl will be eating a pie.           |
| `@perfect-progressive`  | A girl has been eating a pie.          |

All twelve tense × aspect cells render in both voices. Compound forms
are hyphenated single annotations — `@past-progressive` sets tense
`:past` and aspect `:progressive` in one go.

Passive aspect:
- `[PIE]<-(obj)<-[EAT: @perfect].` → "A pie has been eaten."
- `[PIE]<-(obj)<-[EAT: @progressive].` → "A pie is being eaten."

## 5. Voice

The realizer picks voice in this order: `@passive` annotation → `@active`
annotation → head-driven Sowa transformation (head on the patient flips
to passive) → active default.

| Input                                                | Output                           |
|------------------------------------------------------|----------------------------------|
| `[GIRL]<-(agnt)<-[EAT: @passive]->(obj)->[PIE].`     | A pie is eaten by a girl.        |
| `[GIRL]<-(agnt)<-[EAT: @passive @past]->(obj)->[PIE].` | A pie was eaten by a girl.    |
| `[PIE]<-(obj)<-[EAT]->(agnt)->[GIRL].`               | A pie is eaten by a girl.        |
| `[PIE]<-(obj)<-[EAT: @active]->(agnt)->[GIRL].`      | A girl eats a pie.               |

## 6. Coordination

### 6.1 Binary AND / OR on PROPOSITIONs

```
[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]]
  ->(and)->[PROPOSITION: [BOY]<-(agnt)<-[DRINK]].
  →  A girl eats a pie and a boy drinks.

[PROPOSITION: [DOG]<-(agnt)<-[BARK]]
  ->(or)->[PROPOSITION: [CAT]<-(agnt)<-[SIT]].
  →  A dog barks or a cat sits.
```

Per-conjunct tense, voice, quantifier flow independently.

### 6.2 N-ary chains (Oxford comma)

Chain via shared-node trick — `[P1]->(and)->[P2]->(and)->[P3]`:

```
[PROPOSITION: [GIRL]<-(agnt)<-[EAT]]
  ->(and)->[PROPOSITION: [BOY]<-(agnt)<-[DRINK]]
  ->(and)->[PROPOSITION: [DOG]<-(agnt)<-[BARK]].
  →  A girl eats, a boy drinks, and a dog barks.
```

OR works the same way. Mixed and/or chains are deliberately rejected
(use parenthesized nested PROPOSITIONs instead).

### 6.3 Shared-subject collapse

When every conjunct is an active clause whose subject refers to the
same individual (instance equality, shared coref label, or matching
referent id), the output collapses to one subject NP plus a coordinated
VP:

```
[PROPOSITION: [GIRL: Sue]<-(agnt)<-[EAT]]
  ->(and)->[PROPOSITION: [GIRL: Sue]<-(agnt)<-[DRINK]].
  →  Sue eats and drinks.

[PROPOSITION: [GIRL: Sue]<-(agnt)<-[EAT]]
  ->(and)->[PROPOSITION: [GIRL: Sue]<-(agnt)<-[DRINK]]
  ->(and)->[PROPOSITION: [GIRL: Sue]<-(agnt)<-[SIT]].
  →  Sue eats, drinks, and sits.
```

Per-conjunct tense still flows independently — `[EAT: @past]` + `[DRINK]`
→ "Sue ate and drinks."

## 7. Phrasal verbs / particles

`register-lexicon-entry` with `:lemma "verb" :particle "out"` defines a
phrasal verb. Pre-registered: `PICK-UP`, `CARRY-OUT`, `TURN-OFF`,
`TURN-ON`.

### 7.1 Tense / aspect / voice

| Input                                                        | Output                          |
|--------------------------------------------------------------|---------------------------------|
| `[GIRL]<-(agnt)<-[PICK-UP]->(obj)->[PIE].`                   | A girl picks up a pie.          |
| `[GIRL]<-(agnt)<-[PICK-UP: @past]->(obj)->[PIE].`            | A girl picked up a pie.         |
| `[GIRL]<-(agnt)<-[PICK-UP: @progressive]->(obj)->[PIE].`     | A girl is picking up a pie.     |
| `[GIRL]<-(agnt)<-[PICK-UP: @perfect]->(obj)->[PIE].`         | A girl has picked up a pie.     |
| `[PIE]<-(obj)<-[PICK-UP].`                                   | A pie is picked up.             |
| `[GIRL]<-(agnt)<-[PICK-UP: @passive]->(obj)->[PIE].`         | A pie is picked up by a girl.   |

### 7.2 Pronoun-driven splitting

When the surface direct object surfaces as a pronoun, the particle
moves *after* it:

```
[BOY: *z]<-(agnt)<-[PICK-UP: @active]->(obj)->[BOY: *z].
  →  A boy picks him up.

[GIRL: *z]<-(agnt)<-[PICK-UP: @active]->(obj)->[GIRL: *z].
  →  A girl picks her up.
```

Auto-reflexive cases (same coref on agnt and obj) need `@active` because
the head IS the dobj — the head-driven Sowa transformation would
otherwise flip them to passive.

## 8. Anaphora

A second mention of the same referent (instance equality or shared coref
label) becomes a pronoun. Gender resolution consults the lexicon entry
for the type, then `*given-name-genders*`, then a human/non-human default.

| Input                                                  | Output                  |
|--------------------------------------------------------|-------------------------|
| `[BOY: *z]<-(agnt)<-[GIVE]->(rcpt)->[BOY: *z].`        | A boy gives to him.     |
| `[GIRL: *z]<-(agnt)<-[GIVE]->(rcpt)->[GIRL: *z].`      | A girl gives to her.    |
| `[PERSON: *z]<-(agnt)<-[GIVE]->(rcpt)->[PERSON: *z].`  | A person gives to them. |

Singular human of unknown gender uses singular-they ("they have", not
"they has" — `verb-agreement-number` returns `:plural` for this case).

The `*anaphora-cross-coref*` flag (default NIL) controls whether two
distinct concepts linked via a `coreference` slot count as the same
referent for pronoun selection. Off by default to keep nested
mental-attitude contexts unambiguous; toggle via Customize
(`cgraph-anaphora-cross-coref`).

## 9. Relative clauses (Sowa Rule 3)

A non-head NP that is the agent of an unrealized predication becomes a
relative clause:

```
[BOY]<-(agnt)<-[GIVE]->(obj)->[DOG]<-(agnt)<-[EAT]->(obj)->[PIE].
  →  A boy gives a dog that eats a pie.

[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL]<-(agnt)<-[EAT]->(obj)->[PIE].
  →  A boy gives a girl who eats a pie.
```

`who` for human types, `that` otherwise (driven by the `:human-p`
lexicon flag).

The split form of phrasal verbs works inside relative clauses too:

```
[BOY]<-(agnt)<-[GIVE]->(obj)->[GIRL: *z]<-(agnt)<-[PICK-UP]->(obj)->[GIRL: *z].
  →  A boy gives a girl who picks her up.
```

## 10. Embedded clauses (Sowa Rule 4, first half)

A `[PROPOSITION: ...]` referent on a verb's `:dobj` becomes a
`that`-clause:

```
[PERSON: ivan]<-(expr)<-[KNOW]->(stat)->[PROPOSITION: [GIRL]<-(agnt)<-[EAT]->(obj)->[PIE]].
  →  Ivan knows that a girl eats a pie.
```

The inner clause dispatches through the same realizer, so its own
voice / tense / quantifier annotations all fire normally.

## 11. Raising (Sowa Rule 4, second half)

Lexicon flag: `:raising t` on the cognitive verb (pre-registered on
`BELIEF` and `KNOW`).

### 11.1 Passive raising

Verb used without an EXPR/AGNT subject and with a clausal `:dobj` —
fires automatically on the lexicon flag alone:

```
[BELIEF]->(stat)->[PROPOSITION: [PERSON: ivan]->(loc)->[PLACE]].
  →  Ivan is believed to be in a place.

[BELIEF]->(stat)->[PROPOSITION: [DOG]->(attr)->[FAST]].
  →  A dog is believed to be fast.

[BELIEF: @past]->(stat)->[PROPOSITION: [DOG]->(attr)->[FAST]].
  →  A dog was believed to be fast.

[KNOW]->(stat)->[PROPOSITION: [PERSON: ivan]<-(agnt)<-[EAT]->(obj)->[PIE]].
  →  Ivan is known to eat a pie.
```

### 11.2 Active raising / ECM

Same lexicon flag plus `@raising` on the verb concept. Opt-in via the
annotation so existing `Mary knows that ...` tests don't change:

```
[PERSON: mary]<-(expr)<-[KNOW: @raising]->(stat)->[PROPOSITION: [PERSON: ivan]<-(agnt)<-[EAT]->(obj)->[PIE]].
  →  Mary knows Ivan to eat a pie.

[PERSON: mary]<-(expr)<-[BELIEF: @raising]->(stat)->[PROPOSITION: [DOG]->(attr)->[FAST]].
  →  Mary believes a dog to be fast.

[PERSON: mary]<-(expr)<-[BELIEF: @raising @past]->(stat)->[PROPOSITION: [DOG]->(attr)->[FAST]].
  →  Mary believed a dog to be fast.
```

Both verbal and copular inner clauses are supported.

## 12. Verbless / non-active clauses

### 12.1 Copula clauses

No AGNT/EXPR, just an entity with attribute or location predicates:

| Input                                | Output                |
|--------------------------------------|-----------------------|
| `[DOG]->(attr)->[FAST].`             | A dog is fast.        |
| `[PERSON: ivan]->(loc)->[PLACE].`    | Ivan is in a place.   |

### 12.2 Subjectless passive

An act with OBJ but no AGNT — patient becomes the surface subject, no
by-agent appears:

| Input                                          | Output                       |
|------------------------------------------------|------------------------------|
| `[PIE]<-(obj)<-[EAT].`                         | A pie is eaten.              |
| `[FOOD]<-(obj)<-[EAT].`                        | Food is eaten.               |
| `[PIE]<-(obj)<-[GIVE]->(rcpt)->[GIRL].`        | A pie is given to a girl.    |

### 12.3 HAVE clauses

POSS relation without an act — renders as "X has Y":

| Input                                          | Output                          |
|------------------------------------------------|---------------------------------|
| `[PERSON: dave]->(poss)->[CHEVY-VEHICLE].`     | Dave has a chevy-vehicle.       |
| `[BOY]->(poss)->[DOG].`                        | A boy has a dog.                |

### 12.4 Locations

| Input                                          | Output                |
|------------------------------------------------|-----------------------|
| `[DOG]->(loc)->[PLACE: #].`                    | A dog is in the place.|
| `[DOG]->(ploc)->[PLACE: #].`                   | A dog is at the place.|
| `[DOG]-(agnt)<-[SIT](loc)->[PLACE].`           | A dog sits in a place.|
| `[DOG]-(agnt)<-[SIT](ploc)->[PLACE].`          | A dog sits at a place.|

`loc` ("in") and `ploc` ("at") use different prepositions.

## 13. Leftover POSS pass

A POSS relation that the parser didn't fold into the main NP gets
appended as a coordinated tail rather than silently dropped:

```
[PERSON: sue]-(agnt)<-[GIVE]-(obj)->[FOOD] (rcpt)->[DOG: spot], (poss)->[DOG: spot].
  →  Sue gives food to Spot, and she has Spot.

[PERSON: Dave]-(agnt)<-[GIVE]-(obj)->[FOOD] (rcpt)->[DOG: spot], (poss)->[DOG: spot].
  →  Dave gives food to Spot, and he has Spot.
```

Possessive prefix (when the parser DOES fold it):

```
[CHEVY-VEHICLE]-(attr)→[OLD] (inst)←[DRIVE]-(agnt)→[PERSON: dave *j]→(attr)→[YOUNG]
                (dest)→[CITY: Baltimore],(poss)←[PERSON: dave *j].
  →  Young Dave drives with Dave's old chevy-vehicle to Baltimore.
```

## 14. Adverbs

`MANNER`-style relations produce an adverbial:

```
[girl: sue]<-(agnt)<-[EAT]->(manr)->[MANNER].
  →  Sue eats somehow.
```

The surface form comes from `:adv-form` on the type's lexicon entry
(`MANNER` → "somehow"), or `adverbify` if not overridden.

## 15. Lexicon overrides — quick reference

All set via `(register-lexicon-entry 'TYPE-LABEL :slot value ...)`.
Override slots:

| Slot              | Purpose                                                         |
|-------------------|-----------------------------------------------------------------|
| `:lemma`          | Surface form of the type (`BELIEF` → "believe").                |
| `:plural`         | Irregular plural; otherwise `pluralize` applies.                |
| `:mass-p`         | Mass noun, no indefinite article ("food", not "a food").        |
| `:gender`         | `:masc` / `:fem` for gendered common nouns.                     |
| `:human-p`        | Selects "who" vs "that" in relative clauses, and pronoun set.   |
| `:adv-form`       | Override for adverb derivation.                                 |
| `:rcpt-direct`    | Verb takes recipient as direct object (inform / tell / teach).  |
| `:obj-prep`       | Preposition for the demoted info object ("about").              |
| `:particle`       | Phrasal-verb particle (`PICK-UP` :lemma "pick" :particle "up"). |
| `:raising`        | Cognitive verb supports passive raising; combined with `@raising` for active/ECM. |

`*given-name-genders*` is a separate registry for proper-noun gender —
extend with `(register-name-gender 'name :fem)`.

## 16. Annotation summary

`@<word>` annotations on a concept are parsed by `parse-at-word` in
`system/core/reader.lisp` and stored on the concept's slots. Multiple
annotations can be combined on a single concept (e.g. `[EAT: @passive
@past]`).

| Annotation                          | Effect                            |
|-------------------------------------|-----------------------------------|
| `@every` / `@all` / `@any`          | Universal quantifier              |
| `@some`                             | Existential quantifier            |
| `@past` / `@future` / `@present`    | Tense                             |
| `@progressive` / `@perfect` / `@perfect-progressive` | Aspect           |
| `@past-progressive`, `@future-perfect`, ... | Compound tense+aspect     |
| `@active` / `@passive`              | Voice                             |
| `@raising`                          | Active raising / ECM (with `:raising` lexicon flag) |
| `@<number>` / `@<number> <unit>`    | Cardinal / measure                |

## 17. Where to look next

- **Architecture**: `memory/project_generation_architecture.md` — file
  split, dispatch order, extension-point rationale, anaphora toggle,
  customize-sync gotcha.
- **Sowa rules**: `notes/graph-to-text-rules.text` — the six rules the
  realizer is built around.
- **Tests**: `test/generation-test.lisp` — every example above is a
  regression case.
- **What's missing**: `notes/graph-to-text-todo.md` — graph
  decomposition by inference (Rule 6 second half), animacy/topicality
  active-vs-passive heuristic, mixed AND/OR chains.
