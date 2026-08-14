# Graph-to-text — what's left

A snapshot of remaining work in the generation pipeline, from 2026-05-06
and updated 2026-08-14 when Rule 6 landed.
Big picture status: the realizer covers Sowa's six rules in their common
forms, plus tense/aspect, voice annotations, n-ary AND/OR coordination,
shared-subject collapse, phrasal-verb particles (with pronoun-driven
splitting), and raising in both passive and active (ECM) variants.
Architecture and extension points live in
`memory/project_generation_architecture.md`; this file is the punch list.

## Deferred from the original phase plan

### 1. ~~Graph decomposition by inference (Sowa Rule 6 second half)~~ — done

Built as `system/operations/decomposition.lisp` plus `graphs-to-text`; see
§17 of `graph-to-text-features.md` for what it does and
`test/decomposition-test.lisp` for the contract.

The worry recorded here was "the hard part is deciding which rewrites are
sound." That turned out to have a clean answer, and it is the reason this
was tractable at all: **breaking up is join run backwards.** One rewrite,
not a library of them — cut at a concept, keep its identity in both pieces
— and its soundness is checkable rather than argued, since rejoining the
pieces must reproduce the original.

The advice to make it explicit first was right and is still in force:
nothing decomposes on your behalf, and `graph-to-text` still returns one
sentence for one graph.

Two things it taught, both recorded where they belong rather than here.
Cut analysis has to work in **referents, not nodes**, or a ring closed by
coreference looks like a path. And *which* seam to cut is a question about
English rather than about graphs — never the predicate, prefer a thing to
an event — which is why the policy sits in its own section of the file with
a threshold that admits to being a guess.

One thing this note got wrong for a day, kept because the mistake is
instructive. The decomposed output disagreed with itself about Dave —
`Dave has an ancient bag. He is young.` — and that was written up here as a
question of antecedent distance. It was not. Three clause paths rendered
their subject with `realize-full-np` and so never asked whether it was a
revisit: the copula, the have-clause, and the possessive modifier. All three
are fixed, the output is consistent, and what looked like a missing model
was a missing question. The real model is item 3.

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

### 3. ~~Pronoun salience — when a pronoun is safe~~ — done

`pronoun-safe-p` in `system/generation/anaphora.lisp`, beside
`uttered-or-coref-uttered-p`, which answers the other half of the question.
Behaviour and examples: §8 of `graph-to-text-features.md`.

The rule is the smallest one that answers it. A competitor is another
referent already uttered that would surface as the **same word** — surfaces
compared rather than gender and number, since the word is what a reader
hears, and `her` collides with itself across cases. The pronoun is safe when
no competitor has been mentioned more recently: the nearest antecedent is
the one a reader reaches for, so the most recent mention wins the pronoun
and everything else is named again. Losing means Rule 5's other option, the
short definite NP — `the dog`, or the name for someone who has one.

`walk-state` gained a clock for this: `uttered` records the tick rather than
`T`, so "most recently mentioned" is a fact rather than a guess. Existing
callers still read it as a flag, a tick never being zero.

Still not modelled, and both real:

- **Syntactic prominence.** A subject outranks an object at the same
  distance, and this counts only distance.
- **Decay.** An antecedent far enough back is gone whether or not anything
  competes for it; here a pronoun stays available indefinitely as long as it
  is uncontested.

Two things learned in the building, both recorded where they happened.
`realize-np`'s revisit branch never marked the concept uttered — the
*referent* had been, through some other node, but that node had not, so a
third mention through a third node introduced the thing over again. And a
first attempt to test this from the generation table was fake: inside one
sentence the competitor usually has not been uttered yet when the pronoun is
chosen (`Dave gives his cake to Bob` picks `his` before Bob is said), so
competition is a cross-sentence phenomenon and the tests live with
decomposition.

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
- Decomposition (Sowa Rule 6 second half): cut a graph at a concept that
  holds it together, speak the pieces as a sentence each, explicitly via
  `graph-to-text-decomposed`.
- Possessive anaphora: a possessor already mentioned surfaces as 'his' /
  'her' / 'its' / 'their'.
- Pronoun salience: a pronoun only when no other referent uttered more
  recently would surface as the same word; otherwise the short definite NP
  or the name.
