# Lexicon overrides

The graph-to-text generator is **derivational by default** — it computes a
concept's surface form from the type lattice and the label:

- **part of speech** by walking the lattice (under `ACT` → verb, under `ENTITY`
  → noun, …)
- **lemma** = the downcased label
- **morphology** by regular rules (+s plural, +ed past, …)
- **gender / number / definiteness** from the concept's referent

**Lexicon overrides** are the escape hatch for the exceptions. Each override is a
per-concept-type plist, keyed by the upcased label, stored in
`*lexicon-overrides*` (`system/generation/lexicon.lisp`). Register one with:

```lisp
(register-lexicon-entry 'pick-up :lemma "pick" :particle "up")
```

Overrides may be registered for a type that doesn't exist yet — they simply sit
unused until a matching concept type is defined (the startup lexicon lint reports
these as `[STALE-LEXICON-OVERRIDE]`; see `system/generation/lexicon-lint.lisp`).

## The keys

### Word form / morphology
| key | meaning | example |
|-----|---------|---------|
| `:lemma` | base surface word; default = downcased label | `(belief :lemma "believe")` |
| `:plural` | irregular plural (overrides +s) | `(mouse :plural "mice")` |
| `:past` | irregular past tense | |
| `:past-participle` | irregular past participle | |
| `:present-3sg` | irregular 3rd-person singular present | |
| `:gerund` | irregular -ing form | |
| `:particle` | phrasal-verb particle | `(pick-up :lemma "pick" :particle "up")` → "pick up" / "pick it up" |

### Noun classification
| key | meaning | example |
|-----|---------|---------|
| `:pos` | force part of speech (override the lattice-derived guess) | `(<label> :pos :noun)` |
| `:mass-p` | mass noun → no indefinite article. **Default is count** (gets "a/an", pluralizes) | `(salt :mass-p t)` → "salt", not "a salt" |
| `:proper-p` | proper noun → no article, capitalized | |
| `:gender` | `:masc` / `:fem`, for pronoun selection | `(man :gender :masc)` → "he" |
| `:human-p` | human → who/he/she rather than which/it | `(woman :human-p t)` |
| `:animate-p` | animate, for pronoun / agreement | |

`:masc` and `:fem` are *values* of `:gender`, not keys of their own.

### Verb argument structure
| key | meaning | example |
|-----|---------|---------|
| `:raising` | takes a clausal complement — "X believes **that** S" | `(belief :lemma "believe" :raising t)` |
| `:rcpt-direct` | the recipient surfaces as the **direct** object (tell/inform/ask *someone* …), flipping the default `OBJ`=dobj / `RCPT`=iobj | used by INFORM/TELL |
| `:obj-prep` | preposition for the displaced object under `:rcpt-direct` (default `"about"`) | "tell someone **about** X" |
| `:adv-form` | adverb surface form for abstract manner types where suffixing fails (MANNER → "mannerly") | `(manner :adv-form "somehow")` |

## Count vs. mass, restated

A noun is a **count noun unless declared** `:mass-p t`. `mass-noun-p`
(`lexicon.lisp`) simply reads `:mass-p`; absence → `nil` → count → the
determiner logic returns `:indefinite` and the noun takes "a/an" and pluralizes.
So `:mass-p`, `:proper-p`, etc. only ever *turn off* a default behavior.

## Where overrides are registered

- `system/generation/lexicon.lisp` — mass-noun starter set, adverb-forms,
  phrasal/irregular verbs.
- `system/generation/anaphora.lisp` — gender / human-p (man, woman, boy, girl).

The mass-noun starter set pre-registers common mass nouns (`food`, `salt`,
`money`, …) whether or not the ontology defines them, so they "light up"
correctly the moment the matching concept type is added.
