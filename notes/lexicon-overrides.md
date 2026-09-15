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
| `:proper-p` | proper noun → no article, capitalized | `(baltimore :proper-p t)` → "to Baltimore", not "to a baltimore" |
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
- **a domain's own `lexicon-overrides.lisp`** — see below.

The mass-noun starter set pre-registers common mass nouns (`food`, `salt`,
`money`, …) whether or not the ontology defines them, so they "light up"
correctly the moment the matching concept type is added.

## A domain's own overrides

Everything above is cgraph's *own* vocabulary. A domain has vocabulary too, and
it does not belong in cgraph's source: the catalog that defines `BALTIMORE` as a
subtype of `CITY` is the thing that knows Baltimore is a proper noun. So a domain
may ship a third file beside its type files:

```
~/.cgraph/types/  →  your-types-repo/
  concept-types.lisp        what exists
  relation-types.lisp       what relates
  lexicon-overrides.lisp    how it is worded
```

One form per entry, in the same shape the type files use — each is a
`register-lexicon-entry` call with `:label` naming the type, so every key in the
tables above works:

```lisp
(:label baltimore :proper-p t)
(:label rice      :mass-p t)
(:label belief    :lemma "believe")
```

`initialize-types` loads it once the catalog is in place, through the
`*domain-lexicon-loader*` hook that `system/generation/lexicon.lisp` fills (setup
declares the hole, generation fills it — the same arrangement as `*mass-type-p*`,
so the dependency keeps pointing generation → setup). The file is found by
following `concept-types.lisp` to its truename, so it works whether the catalog
is a symlinked domain repository or the copied default one; **absence is legal**
and silent, which is the normal case.

Mounting another domain rewinds the previous one's entries first — including
restoring any shipped registration a domain had displaced — so one domain's
English never leaks into the next. A malformed form is warned about and skipped,
and the lint checks the rest: a misspelled key is `[UNKNOWN-LEXICON-KEY]`, a
label no type has is `[STALE-LEXICON-OVERRIDE]`. Reload after editing with
`(load-domain-lexicon-overrides)`; see `test/domain-lexicon-test.lisp`.
