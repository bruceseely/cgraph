# Referent Catalog

Catalog of features available in the referent field of a concept, `[TYPE: <referent>]`.

Authoritative source: `system/core/reader.lisp` — specifically `read-features`,
`parse-at-word`, and the various `*-reader` functions registered in
`*cg-readtable-mods*`.

## Identity / quantity

| Form    | Meaning                                       | Reader                             |
|---------|-----------------------------------------------|------------------------------------|
| (empty) | Generic concept, no referent                  | concept-reader, reader.lisp:630    |
| `*`     | Generic                                       | `asterisk-reader`, reader.lisp:520 |
| `*x`    | Variable, defining occurrence                 | `asterisk-reader`, reader.lisp:527 |
| `?x`    | Co-reference label, bound or defining         | `question-reader`, reader.lisp:534 |
| `#123`  | Individual id                                 | `individual-reader`, reader.lisp:437 |
| `#`     | Specific-but-unidentified individual          | `individual-reader`, reader.lisp:446 |
| `Fido`  | Name (bare alpha token)                       | `read-term`, reader.lisp:151       |

A `*x` registers `x` as a variable in the current context. A `?x` is bound if
the label is already known (via prior `*x` or `?x`); otherwise it becomes a
defining occurrence and is registered as a variable so query-binding extraction
can see it (reader.lisp:726).

When both `:id` and `:name` are supplied, `check-name-id-consistency` (reader.lisp:364)
refuses to attach a different name to a pre-existing individual.

## Sets

`set-reader` (reader.lisp:321). Set members are parsed by the same `read-term`
machinery, so each member can be a name, id, or generic.

| Form                      | Meaning                                |
|---------------------------|----------------------------------------|
| `{*}` or `{}`             | Generic plural, unspecified members    |
| `{Fido, Spot}`            | Set with two named members             |
| `{Fido, #123, *}`         | Mixed: name, id, generic placeholder   |
| `{*} @ 5`                 | Plural with cardinality 5              |
| `{Fido, Spot, *} @ 4`     | Two named + 2 unspecified              |

`build-set-from-specs` (reader.lisp:422) resolves each spec to an individual
of the concept type. Generic markers (`*` or empty) drop out of the resolved
member list but still produce a set object.

## Measures

`measure-reader` (reader.lisp:499) when the `@`-token starts with a digit.

| Form           | Result                       |
|----------------|------------------------------|
| `@ 5 ft.`      | `(:measure (5 "ft."))`       |
| `@25.4 cm`     | `(:measure (25.4 "cm"))`     |

Measures may also be attached to set referents (reader.lisp:679).

## `@word` annotations

`parse-at-word` (reader.lisp:462) handles `@`-tokens that start with a letter.
Words split on `-` so tense and aspect can compose.

**Tense** — `@past`, `@future`, `@present` → `:tense :past` / `:future` / `:present`

**Aspect** — `@simple`, `@progressive`, `@perfect`, `@perfect-progressive`,
`@progressive-perfect` → `:aspect :simple` / `:progressive` / `:perfect` /
`:perfect-progressive`

**Compounds** — any combination of one tense word and one aspect word, e.g.
`@past-progressive`, `@future-perfect`, `@present-perfect-progressive`.

**Voice** — `@passive` / `@active` → `:voice :passive` / `:active`

**Quantifier** — `@every`, `@all`, `@any` → `:quantifier :universal`;
`@some` → `:quantifier :existential`; anything else (e.g. `@most`) passes
through as a generic quantifier keyword.

The annotations are stamped onto the concept via `concept-quantifier`,
`concept-tense`, `concept-aspect`, and `concept-voice` (reader.lisp:711).

## Graph referents

A concept's referent can be an entire nested graph.

| Form                          | Meaning                                          |
|-------------------------------|--------------------------------------------------|
| `[TYPE: [...nested graph...]]` | Graph referent of the named type                 |
| `[[...]]`                      | Anonymous shorthand for `[PROPOSITION: [...]]`   |
| `~[...]`                       | Negated concept                                  |

Anonymous-context handling: `concept-reader` peeks for `[` immediately after
the opening `[` and treats it as an implicit `PROPOSITION` whose referent is
the nested graph (reader.lisp:602).

Negation: `negation-reader` (reader.lisp:816) sets `*negated-concept*` so the
inner concept is marked negated. Combines with the graph-referent forms:
`~[[...]]` and `~[TYPE: [...]]` both work.

Inside a graph referent a fresh `*context*` is pushed (reader.lisp:643), which
is what scopes `*x` to the inner graph and forces cross-context references to
use `?x`.

## Combining

`read-features` (reader.lisp:543) collects every `@` / `*` / `?` / `#` / `{}` /
name token in the referent field into a single plist. `concept-reader`
(reader.lisp:660) pulls out the recognized keys —

```
:id :variable :coref :set :quantifier :tense :aspect :voice :measure :name
```

— and the remainder become individual properties.

Most features compose. Examples that exercise multiple features:

```
[CAT: Felix #7]                              ; name + id
[DOG: {Fido, Spot, *} @ 4]                   ; named-and-generic set with cardinality
[EAT: *e @past-progressive @passive]         ; variable + compound tense/aspect + voice
[PERSON: ?x @every]                          ; co-ref + universal quantifier
~[[PERSON: *x]->(loves)->[PERSON: *y]]       ; negated anonymous proposition
```
