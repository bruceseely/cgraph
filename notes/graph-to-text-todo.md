# Graph-to-text — what's left

A snapshot of remaining work in the generation pipeline as of 2026-05-06.
Big picture status: the realizer covers Sowa's six rules in their common
forms, plus tense/aspect, voice annotations, n-ary AND/OR coordination,
shared-subject collapse, phrasal-verb particles (with pronoun-driven
splitting), and raising in both passive and active (ECM) variants.
Architecture and extension points live in
`memory/project_generation_architecture.md`; this file is the punch list.

## Deferred from the original phase plan

### 1. Graph decomposition by inference (Sowa Rule 6 second half)

The biggest deferred item. Rule 6's first half — "leave one occurrence of
the referent and replace others with coreference labels" — is implicit
in the realizer's existing anaphora handling. The second half pushes into
actual *inference*: rewriting a graph into an equivalent simpler graph
before realization, e.g. eliminating redundant predications or collapsing
chains that follow inference rules.

This is probably its own sub-project rather than a generation feature.
The hard part is deciding which rewrites are sound, and whether they
should be opt-in or always applied. A first-pass version could simply
implement a small library of rewrite rules (like existing Sowa rules:
copy, restrict, join, simplify) and let users invoke them explicitly
before passing the graph to `graph-to-text`.

### 2. Active/passive heuristic when neither annotation nor head settles it

`@passive` / `@active` annotations cover the explicit case; the
head-driven Sowa transformation covers the case where the user's topical
entry point is the patient. But for graphs without either signal, the
realizer defaults to active. An animacy/topicality heuristic could
choose passive when the agent is non-prototypical (an inanimate cause,
a generic existential) or when the patient is more topical (definite,
named, animate vs. indefinite agent).

Concretely: weight the agent and patient on animacy + definiteness +
proper-name-ness; if the patient is "heavier" by some margin, flip to
passive. This is bikeshedding-prone — the threshold is subjective. Worth
sketching only when there's a real graph that produces a sentence
people find awkward.

## Smaller follow-ups

### Mixed AND/OR chains

Graphs like `[P1]->(and)->[P2]->(or)->[P3]` currently fall through to
non-coordination dispatch (the chain detector requires a single
conjunction label). The output surfaces just the first proposition's
NP, which is intentionally bad — the user should parenthesize via
nested PROPOSITIONs. Worth revisiting only if the parenthesization
proves inconvenient.

### Annotation-parsing module split

`parse-at-word` and the @-word machinery in `system/core/reader.lisp`
are standalone enough to live in their own file (e.g.
`system/core/annotations.lisp`). Modest cleanup; not blocking. After
the recent concept-reader split, reader.lisp isn't painfully large
anymore, so this is purely cosmetic.

### Verb agreement edge cases

`verb-agreement-number` handles singular-they (singular human of
unknown gender) and the obvious number cases. Edge cases not
explicitly tested: collective nouns ("a herd eats" vs. "a herd eat"),
mass-with-cardinal ("two ounces of water is/are"), conjoined subjects
that should agree as plural ("Sue and Bob eat"). The shared-subject
coordination collapse handles the last one implicitly when subjects
match, but distinct conjoined subjects via a CG construction don't
yet exist as a feature.

## What's done (so this list is complete)

For grep/diff against future versions, the items below are *implemented*:

- Active verbal clause, head-driven passive (Sowa transformation),
  subjectless passive, copular clause, have-clause.
- Tense (`@past` / `@future` / `@present`) plus inference from a TIME
  arc with deictic adverbs ("yesterday", "tomorrow", ...).
- Aspect (`@progressive` / `@perfect` / `@perfect-progressive`) and
  compound forms (`@past-progressive`, `@future-perfect`).
- Voice annotation (`@passive` / `@active`).
- Quantifiers (`@every` / `@all` / `@any` / `@some`).
- Lexicon overrides: `:lemma`, `:plural`, `:mass-p`, `:gender`,
  `:human-p`, `:adv-form`, `:rcpt-direct`, `:obj-prep`, `:particle`,
  `:raising`.
- Anaphora on revisit, with `*anaphora-cross-coref*` toggle.
- Relative clauses (Sowa Rule 3) for unrealized predications on an NP.
- Embedded clauses (Sowa Rule 4 first half: 'that <inner>').
- Phrasal verbs / particles, with pronoun-driven splitting in active
  voice ('pick it up' vs 'pick up the toy').
- Coordination: binary AND/OR, n-ary chains with Oxford-comma
  punctuation, shared-subject collapse ('Sue eats and drinks').
- Raising (Sowa Rule 4 second half): passive ('Ivan is believed to be
  in a place') from `:raising` lexicon flag; active / ECM ('Mary
  believes Ivan to be smart') opt-in via `@raising` annotation.
