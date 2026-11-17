# CGIF import and export: design

Status: **approved 2026-11-15.** CGIF goes in a separate ASDF system,
`cgraph/cgif`, in this repo, the way `cgraph/support` does. The decisions
are recorded at the end.

## What CGIF is

CGIF, the Conceptual Graph Interchange Format, is the conceptual-graph
syntax of Common Logic (ISO/IEC 24707, Annex B). It is what other CG tools
read and write. cgraph reads and writes the *linear form* (LF) instead.

```
cgraph LF:      [CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]
extended CGIF:  [Cat: Tom] [Eat *x] [Food *y] (Agnt ?x Tom) (Obj ?x ?y)
core CGIF:      [: Tom] [*x] [*y] (Cat Tom) (Eat ?x) (Food ?y) (Agnt ?x Tom) (Obj ?x ?y)
```

In CGIF, concepts and relations are listed side by side. A relation names
its arguments with coreference labels (`?x`, bound to a concept that
defines `*x`) or with constants (`Tom`). Writing nodes next to each other
means "and".

**Core CGIF** has no concept types: a concept holds only labels or names,
and "x is a cat" is the monadic relation `(Cat ?x)`. **Extended CGIF** adds
four things: type labels inside concepts (`[Cat: *x]`), the `@every`
quantifier, If/Then and Either/Or, and type expressions. Every
extended-CGIF text can be rewritten mechanically as core CGIF.

The syntax facts in this note come from John Sowa's CGIF summary
(jfsowa.com/cg/cgif.htm), which defers to the ISO text. Before writing the
parser, check the grammar against the ISO text itself. The notes below say
where the summary was silent.

## Dialect: extended CGIF, the part cgraph uses

Every cgraph concept has a type, and extended CGIF's `[Cat: Tom]` is
cgraph's `[CAT: Tom]`. So start with the part of extended CGIF that
cgraph's own graphs need. Core CGIF is harder in both directions:

- **Export:** every typed concept would split into a bare concept plus a
  type relation.
- **Import:** you'd have to guess which monadic relations are types.

Core export can come later as an option, because it's a rewrite of the
extended output. Core import can wait until someone needs to read core
files.

## Mapping

### Maps directly

| cgraph | CGIF | Notes |
|---|---|---|
| `[CAT]` | `[CAT]` or `[CAT *x1]` | A connected concept needs a label so its relations can refer to it. Export makes up a fresh label (`*x1`, `*x2`, …) and keeps a label the graph already has. |
| `[CAT: Tom]` | `[CAT: Tom]` | A relation names it by the constant: `(AGNT ?x1 Tom)`. |
| `*x`, `?x` | `*x`, `?x` | Same convention. `coreference.lisp` already follows CGIF. |
| `[A]→(rel)→[B]` | `(REL ?a ?b)` | Source first, destination last, matching CGIF's own usage: `(Agnt ?act Bob)`. |
| `~[ … ]` | `~[ … ]` | Negation. |
| `[[ … ]]` | `[ … ]` | A context with no type. |
| `[PROPOSITION: [ … ]]` | `[PROPOSITION: …]` | Extended CGIF nests a graph in a typed concept, as in `(Thme ?x [Proposition: …])`. |
| `[PERSON: ?x @every]` | `[PERSON: @every *x]` | cgraph's `@every`, `@all` and `@any` all mean the universal quantifier. |
| the graph's head | the first concept | CGIF has no head. Export writes the head first, and import takes the first concept as the head, so round trips keep it. |

**Names:** a name that is an identifier (letters, digits, `_`) is written
bare, and anything else goes in double quotes: `[CITY: "St. Louis"]`.
CGIF allows Unicode in names, so `⊤` and `⊥` can be written as they are.

**Case:** export writes labels as cgraph prints them (types upper case,
relations lower case). Import ignores case, as `parse-cgraph` does.
Sowa's summary doesn't say whether CGIF is case-sensitive; check the ISO
text.

### No standard CGIF form

For each of these the choice is to refuse, approximate, or extend:

| cgraph | Problem | Recommendation |
|---|---|---|
| `#123` (individual id) | CGIF has no individual markers. | Write it as a quoted name, `"#123"`. Another tool reads that as an ordinary constant, which is the right meaning (one particular individual). cgraph reads it back as an id. |
| `[CAT: Felix #7]` (name and id) | A concept can hold several references, but the summary doesn't say what that means. | Write the name only, in every mode, as the LF formatter does. *(Changed in step 4: a named individual always has an id, the image's own numbering, which another image wouldn't share, so there is no id worth keeping beside a name.)* |
| `#` (definite, unidentified) | Not in ISO CGIF; Sowa calls it an indexical extension. | Portable: drop it, so the concept becomes generic, and warn. Lossless: keep `#`. |
| `{Fido, Spot}`, `{*} @ 5` (sets, cardinality) | Not in ISO CGIF; only a proposed extension. | Portable: refuse with an error that names the concept. Lossless: write Sowa's proposed syntax. |
| `@ 5 ft.` (measure) | No CGIF form. | Portable: refuse. Lossless: keep it as cgraph writes it. |
| `@past`, `@progressive`, `@passive` | Hints for generating English, with no logical meaning. | Portable: drop them and warn. Lossless: keep them. |
| `@some` | It is the default meaning of a concept anyway. | Drop it quietly in portable mode; nothing is lost. *(Changed in step 4: lossless keeps it, so the round trip is exact, and strict refuses it, as it refuses everything portable drops.)* |
| `@most` and other quantifiers | Not in ISO CGIF. | Portable: refuse. Lossless: keep. |

### Modes

The table needs one switch, `:mode` on export:

- **`:portable`** (recommended default): standard extended CGIF that any
  tool can read. It drops what has no logical meaning (tense, `@some`,
  `#`), warning for anything that affects meaning, and refuses what can't
  be said (sets, measures, odd quantifiers).
- **`:strict`**: refuses anything it would drop.
- **`:lossless`**: cgraph's extensions inside the referent field, so a
  graph comes back from CGIF exactly as it went out. The round-trip tests
  use this mode. Other tools may misread the extensions, which is why it
  isn't the default.

### Import of what cgraph can't represent

- **If/Then and Either/Or:** translate to nested negations, as the
  standard defines them. `[If: A [Then: B]]` becomes `~[A ~[B]]`, which
  cgraph represents already. This is cheap, so it's worth doing in the
  first version.
- **`@every`:** sets the concept's universal quantifier.
- **Not in the first version:** actors and functions (`(Add ?x 7 | [*u])`),
  type expressions (`@*x …`), and sequence markers. Each is refused with
  an error that names it. cgraph has no actors (`system/core/actor.lisp` is
  a stub), so supporting them is a separate project.
- **Unknown types and relations:** a `cgraph-parse-error`, with the caret,
  exactly as `parse-cgraph` reports them. Type definitions do not come
  through CGIF; CGIF carries type labels, not a hierarchy.

## One graph per text

A CGIF text is one graph: nodes written side by side are joined by "and",
and the whole text may be wrapped in `[Proposition: …]`. cgraph keeps many
graphs in a context. So:

- `parse-cgif` reads a text as one graph, as the standard says, and
  accepts the optional `[Proposition: …]` wrapper.
- `read-cgif-graphs` reads a text and splits it into connected components,
  one cgraph graph each. That's what reading a file of several exported
  graphs needs. Export gives each graph its own labels, so graphs don't
  join by accident.
- `write-cgif-graphs` writes several graphs, one per line.

## API

Defined in the `:cg` package and exported from it when `cgraph/cgif`
loads, so after `(ql:quickload "cgraph/cgif")`:

```lisp
(cg:format-cgif graph &key (mode :portable) stream)   ; → string, or to STREAM
(cg:parse-cgif string)                                ; → node list, like parse-cgraph
(cg:make-cgraph (cg:parse-cgif string))               ; → a graph in *context*
(cg:read-cgif-graphs string-or-pathname)              ; → list of graphs
(cg:write-cgif-graphs graphs destination &key mode)
```

`parse-cgif` returns what `parse-cgraph` returns, so everything downstream
(`make-cgraph`, projection, generation) works on its result unchanged.

## Testing

- **Round trip:** LF → graph → CGIF (lossless) → graph → LF gives the
  original LF. Run it over every graph in `generation-test`, the referent
  catalog in `docs/referents.md` and the editor fixtures. In portable mode,
  the round trip must equal the original minus exactly what the warnings
  said was dropped.
- **Examples from the standard:** the Sowa/ISO examples (the Bob drives to
  St. Louis graph, If/Then with the cat and mat), parsed into the
  structures they describe.
- **Errors:** an error-case table like `parse-error-test`: each text, the
  words the message must contain, and where the caret goes.
- **Core rewrite:** if the core export option is built, check that its
  output parses back into the same graph.

## Build order

Small commits, each with its tests:

1. ~~System skeleton and export of the direct mappings: typed concepts,
   names, labels, binary relations, head first.~~ Done 2026-11-17:
   `system/cgif/export.lisp`, `test/cgif-test.lisp`. Type and relation
   names with a hyphen are written quoted (`"CHEVY-VEHICLE"`, `"life-stage"`),
   since a hyphen isn't allowed in a CGIF identifier.
2. ~~Import of the same, with errors in the `cgraph-parse-error` style.~~
   Done 2026-11-17: `system/cgif/import.lisp`. Rules decided on the way:
   - A label that only relation arguments refer to is wiring, and import
     drops it: `[Drive *x] (Agnt ?x Bob)` comes in as `[DRIVE]→(agnt)→…`.
     A label another concept refers to (`[Person: ?x]`) is coreference,
     and is kept.
   - A constant that no concept names, `(Agnt ?x Bob)` with no
     `[Person: Bob]`, gets a concept of the type the relation allows there.
   - On export, two concepts with the same name are told apart by labels,
     and a connected `?x` concept gets a label of its own,
     `[PERSON: ?x *x3]`, so a relation can tell it from the `*x` one.
   - Export works out coreference from the links between concepts, not from
     their stored labels, which `format-cgraph` clears (see
     known-issues.md).
   - A text that is more than one connected graph is an error until
     `read-cgif-graphs` (step 5).
3. ~~Contexts: graph referents, negation, anonymous contexts; If/Then and
   Either/Or on import.~~ Done 2026-11-17. Rules decided on the way:
   - A concept holding a graph is written with the graph inside it, and `~`
     in front when negated: `~[PROPOSITION: [CAT: *x1] …]`. A context with no
     type, `[ … ]` or `~[ … ]`, reads as a PROPOSITION, as `[[…]]` does.
   - If, Then, Either and Or read as negated PROPOSITIONs, by the
     standard's definition. Equiv and Iff are refused for now.
   - Inside a context, cgraph keeps one connected graph from its first
     concept. Nested contexts may stand beside it unconnected, which is how
     cgraph holds `~[A ~[B]]`. Export writes those too, finding them among
     the context's child contexts. Any other unconnected concept is refused.
   - A relation inside a context that names, with `?x`, a concept outside
     it gets a coreferent `[TYPE: ?x]` concept in the context, since cgraph
     can't connect a relation across contexts.
   - A negated concept holding no graph, `~[CAT]`, has no CGIF form and is
     refused on export.
   - **Departure from the design:** the outermost `[Proposition: …]` is
     *not* unwrapped as the text's wrapper. cgraph's own `[PROPOSITION: G]`
     exports as exactly that, and unwrapping it on import would lose the
     concept. Whether a text-level wrapper should be recognized belongs with
     `read-cgif-graphs` (step 5).
4. ~~`@every`, and the three modes, covering every row of the "No standard
   CGIF form" table.~~ Done 2026-11-17. `format-cgif` takes `:mode`
   (`:portable`, `:strict`, `:lossless`). Portable warns `cgif-dropped`
   for what it leaves out, and `cgif-unsupported` is the refusal.
   - `@every` is written `[PERSON: @every *x1]`: standard CGIF puts a
     defining label after it, so a concept without one gets a fresh one.
   - An id is written `"#12"` wherever the linear form writes an id, which
     is never beside a name.
   - Lossless writes cgraph's own text for sets (`{Fido, Spot}`,
     `{*}@5`), measures (`@80 kg`), `#`, and the `@` words. Import reads all
     of it in any mode, and reads a quoted `"#12"` as the id.
   - The round trip in the tests now runs in lossless over the export
     cases, the referent catalog of docs/referents.md and the
     generation-test corpus (213 graphs), and in portable over the 100 that
     portable leaves nothing out of.
5. `read-cgif-graphs` and `write-cgif-graphs`.
6. Docs: `docs/cgif.md`, `API.md`, a line in the README, and fix
   `docs/generation.md:8`, which calls a linear-form string a "CGIF string".

## Decisions

All five settled on 2026-11-15, each as recommended:

1. **Default mode:** `:portable`.
2. **Individual ids:** `#123` is written as the quoted name `"#123"`.
3. **Sets and measures in portable mode:** refused.
4. **API names and package:** `cg:parse-cgif`, `cg:format-cgif`,
   `cg:read-cgif-graphs` and `cg:write-cgif-graphs`, in `:cg`.
5. **If/Then and Either/Or on import:** in the first version.
