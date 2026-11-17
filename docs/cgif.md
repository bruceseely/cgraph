# CGIF: reading and writing other tools' graphs

CGIF, the Conceptual Graph Interchange Format, is the conceptual-graph syntax
of the Common Logic standard (ISO/IEC 24707, Annex B). Other CG tools read and
write it. cgraph's own notation is the *linear form*, `[CAT]←(agnt)←[EAT]`;
CGIF writes the same graph as concepts and relations side by side, joined by
labels:

```
linear form:  [CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]
CGIF:         [CAT: Tom] [EAT: *x1] [FOOD: *x2] (agnt ?x1 Tom) (obj ?x1 ?x2)
```

`*x1` defines a label on a concept, and `?x1` refers to it. A relation lists
its arguments source first and destination last.

cgraph reads and writes *extended* CGIF, the part of it that cgraph's graphs
use. The design, and why each choice was made, is in
[notes/cgif.md](../notes/cgif.md).

## Loading

CGIF is a separate system, so the engine doesn't carry it unless asked:

```lisp
(ql:quickload "cgraph/cgif")
(cg:init)
```

Its functions are in the `cg` package.

## Writing a graph

```lisp
(cg:format-cgif (cg:make-cgraph "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]."))
; → "[CAT: Tom] [EAT: *x1] [FOOD: *x2] (agnt ?x1 Tom) (obj ?x1 ?x2)"
```

`format-cgif` takes a graph, a node list or a linear-form string. The graph's
head is written first, so reading the CGIF back puts it back.

Concepts holding a graph are written with the graph inside them, and
negation with `~`:

```lisp
(cg:format-cgif "[PERSON: Sue]←(agnt)←[DRIVE]→(thme)→[PROPOSITION: [CAR]→(attr)→[OLD]].")
; → "[PERSON: Sue] [DRIVE: *x1] [PROPOSITION: *x2 [CAR: *x3] [OLD: *x4] (attr ?x3 ?x4)] (agnt ?x1 Sue) (thme ?x1 ?x2)"

(cg:format-cgif "~[[DOG: *x]←(agnt)←[EAT] ~[[DOG: ?x]→(attr)→[OLD]]].")
; → "~[PROPOSITION: [DOG: *x] [EAT: *x1] ~[PROPOSITION: [DOG: ?x *x2] [OLD: *x3] (attr ?x2 ?x3)] (agnt ?x1 ?x)]"
```

The second is an if-then: *if a dog eats, it is old*. Names that aren't
CGIF identifiers -- letters, digits and `_` -- are written in double quotes,
so `[CITY: "St. Louis"]`, and a type with a hyphen is written
`["CHEVY-VEHICLE": *x1]`.

### Modes

Some of what a cgraph concept can say has no standard CGIF form. `:mode`
decides what becomes of it:

| cgraph | `:portable` (default) | `:strict` | `:lossless` |
|---|---|---|---|
| `[DOG: @every]` | `[DOG: @every *x1]` | same | same |
| `[CAT: #12]` | `[CAT: "#12"]` | same | same |
| `[CAT: Felix #7]` | `[CAT: Felix]` | same | same |
| `[CAT: #]`, `[EAT: @past]` | left out, with a warning | refused | kept: `[CAT: #]`, `[EAT: @past]` |
| `[CAT: @some]` | `[CAT]` | refused | `[CAT: @some]` |
| sets, measures, `@most` | refused | refused | kept: `[DOG: {Fido, Spot}]`, `[MASS: @80 kg]` |
| `~[CAT]` (negated, no graph) | refused | refused | refused |

- **`:portable`** writes standard CGIF any tool can read. What has no logical
  meaning -- tense and voice, `#`, `@some` -- is left out, and a
  `cgif-dropped` warning says what. What CGIF can't say is refused.
- **`:strict`** refuses whatever `:portable` would leave out, too.
- **`:lossless`** keeps everything, in cgraph's own notation, so a graph comes
  back from CGIF exactly as it went. Another tool may misread those parts,
  which is why it isn't the default.

A refusal is a `cgif-unsupported` error naming the concept and what it can't
write:

```
Can't write [MASS:@80kg] as portable CGIF: a measure has no standard CGIF form; :mode :lossless writes it in cgraph's notation
```

## Reading a graph

```lisp
(cg:make-cgraph
 (cg:parse-cgif "[Drive *x] [Person: Bob] [City: \"St. Louis\"] (Agnt ?x Bob) (Dest ?x \"St. Louis\")"))
; → [DRIVE]-
;      (agnt)→[PERSON:Bob]
;      (dest)→[CITY:"St. Louis"].
```

`parse-cgif` returns what `parse-cgraph` returns, so `make-cgraph`, queries,
projection and generation all work on it. What it does with CGIF's features:

- **Labels.** A label only relations refer to is how CGIF connects
  them, so it isn't kept: the `*x` above is gone. A label another concept
  refers to, `[Person: ?x]`, is coreference, and is kept.
- **Types** are read without regard to case, as in linear form: `Drive` is
  `DRIVE`.
- **Contexts.** `[Proposition: …]` is a concept holding a graph, and a
  context with no type, `[ … ]` or `~[ … ]`, is a PROPOSITION. If/Then and
  Either/Or are negations, as the standard defines them:
  `[If: A [Then: B]]` reads as `~[A ~[B]]`.
- **A name with no concept**, as in `(Agnt ?x Fido)` with no `[… : Fido]`,
  gets a concept of the type the relation allows there.
- **Comments**, `/* … */` and `; …` before a `]` or `)`, are skipped.
- **cgraph's own notation**, as `:lossless` writes it, is read whatever mode
  wrote it, and `"#12"` is read as the id #12.

What it can't read is a `cgraph-parse-error` with a caret under the problem,
as linear form gives:

```
Can't parse the graph: ?y refers to *y, which no concept defines
  [CAT: Tom] (agnt ?y Tom)
                   ^
```

Not read yet: core CGIF's concepts with no type, `[*x]`; Equiv and Iff;
actors, `(Add ?x 7 | [*u])`.

## Files of graphs

A CGIF text is one graph, in the standard's terms: everything in it is
joined by "and". To keep many graphs in one file, use `write-cgif-graphs` and
`read-cgif-graphs`:

```lisp
(cg:write-cgif-graphs (cg:graphs cg:*context*) #p"kb.cgif")     ; a graph to a line
(cg:read-cgif-graphs #p"kb.cgif")                             ; → the graphs, added to *context*
```

`write-cgif-graphs` writes to a stream, a pathname, or, given `nil`, a
string, and takes `:mode` as `format-cgif` does. Labels are unique across the
whole file, so graphs that each have their own `*x` stay apart, and a concept
coreferent with one in another graph keeps the link.

`read-cgif-graphs` takes a CGIF string or a pathname. It splits the text
into its connected parts and makes each a graph, with its first concept as
head. Parts linked only by coreference stay separate graphs and keep the
link, so another tool's

```
[Person: *p] [Eat *e] (Agnt ?e ?p) ~[ (Attr ?p ?o) [Old *o] ]
```

reads as two graphs, and the person in the second is the person in the first.
`parse-cgif`, by contrast, reads exactly one connected graph and refuses a
text that is several.

An ISO text may wrap everything in one `[Proposition: …]`. That reads as a
PROPOSITION graph unless you pass `:unwrap t`, which reads what is inside.
It isn't the default because cgraph's own `[PROPOSITION: G]` graphs are
written as exactly that text.

## Reference

[API.md](../API.md#cgif) lists the functions and conditions.
