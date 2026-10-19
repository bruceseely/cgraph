# Tutorial

A first session with CGraph. Every example below runs as written, from any
package, on the shipped default types, and shows its real result. If you
haven't installed CGraph yet, see [setup](setup.md).

```lisp
(ql:quickload "cgraph")
(cg:init)
```

## Types

A conceptual graph is built from typed concepts and relations, so a session
starts with a type catalog. The shipped one is small -- about 90 concept
types and 20 relation types -- and is meant to be replaced by your own (see
[type sets](setup.md#type-sets)).

```lisp
(length (cg:all-concept-types))           ; → 91
(cg:get-concept-type 'cat)                ; → CAT, a concept-type object
```

A type can be named by a symbol, a keyword or a string, in any case, from any
package; they all find the same object:

```lisp
(eq (cg:get-concept-type "cat") (cg:get-concept-type :cat))   ; → T
```

The types form a lattice, not a tree: a type may have several supertypes,
everything is below the top type ⊤, and everything is above the bottom type ⊥.

```lisp
(cg:direct-supertypes 'cat)               ; → (ANIMAL)
(cg:direct-subtypes 'animal)              ; → (DOG CAT)
(cg:subtype-p 'cat 'animal)               ; → T
(cg:subtype-p 'car 'animal)               ; → NIL
(cg:minimal-common-supertype 'cat 'car)   ; → PHYSICAL
```

`(cg:print-concept-types)` prints the whole lattice, and the
[type browser](type-browser.md) draws it.

## Graphs

Graphs are written in CG linear notation: concepts in square brackets,
relations in parentheses, arrows between them. `make-cgraph` parses a string
into a graph:

```lisp
(cg:make-cgraph "[person: Sue]←(agnt)←[give]-(obj)→[cake] (rcpt)→[dog: Spot].")
; → #<GRAPH [PERSON:Sue]←(agnt)←[GIVE]-(obj)→[CAKE](rcpt)→[DOG:Spot].>
```

The `-` after `[give]` says that more than one relation hangs off that
concept; each one follows. `format-cgraph` lays a graph out, one branch per
line:

```lisp
(cg:format-cgraph
 (cg:make-cgraph "[PERSON: Sue]←(agnt)←[GIVE]-(obj)→[CAKE] (rcpt)→[DOG: Spot]."))
; → "[PERSON:Sue]←(agnt)←[GIVE]-
;                       (obj)→[CAKE]
;                       (rcpt)→[DOG:Spot]."
```

Every concept and relation is checked against the catalog as the graph is
built. `agnt` links an act to its agent, so a graph with an animal in the act's
place is refused, with an explanation of which types would have fitted:

```lisp
(cg:make-cgraph "[CAT]←(agnt)←[ANIMAL].")
; error: concept-type ANIMAL is not consistent with ACT, the in-arc type
; of the agnt relation ...
```

## Referents

What follows the colon in a concept is its referent: which thing, or how many.

| Concept | Means |
|---------|-------|
| `[CAT]` | a cat |
| `[CAT: Tom]` | the cat named Tom |
| `[CAT: #]` | the cat (a specific one, not named) |
| `[DOG: {Fido, Spot}]` | the dogs Fido and Spot |
| `[CAT: {*} @3]` | three cats |
| `[PROPOSITION: [DOG: Spot]←(agnt)←[EAT]]` | the proposition that Spot eats |

A graph can sit inside a concept as its referent, which is how CGraph says
what someone believes, says or knows. [Referents](referents.md) catalogs
every form the reader accepts, including coreference (`*x`, `?x`) and
measures. A named thing is an *individual*, an object of its own that every
concept naming it shares; see [individuals](individuals.md).

## English

`graph-to-text` says a graph in English:

```lisp
(cg:graph-to-text
 (cg:make-cgraph "[PERSON: Sue]←(agnt)←[GIVE]-(obj)→[CAKE] (rcpt)→[DOG: Spot]."))
; → "Sue gives a cake to Spot."

(cg:graph-to-text (cg:make-cgraph "[CAT: {*} @3]←(agnt)←[EAT]→(obj)→[FOOD]."))
; → "Three cats eat food."

(cg:graph-to-text (cg:make-cgraph "[CAT: #]←(agnt)←[EAT]→(obj)→[FOOD]."))
; → "The cat eats food."

(cg:graph-to-text
 (cg:make-cgraph "[PERSON: Sue]←(agnt)←[INFORM]-(rcpt)→[PERSON: Dave]
                    (thme)→[PROPOSITION: [DOG: Spot]←(agnt)←[EAT]→(obj)→[CAKE]]."))
; → "Sue informs Dave that Spot eats a cake."
```

The words come from the type names and the lattice: a type under `ACT` is a
verb, one under `ENTITY` a noun. Where that guesses wrong, a
[lexicon override](lexicon-overrides.md) says otherwise.
[Generation](generation.md) is a tour of everything the generator produces.

## A knowledge base

`cg:init` makes an empty context, `*context*`, and every graph `make-cgraph`
builds is added to it. `query` finds the graphs that match a pattern, binding
the pattern's variables:

```lisp
(cg:init)                                   ; start with an empty context
(cg:make-cgraph "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
(cg:make-cgraph "[DOG: Spike]←(agnt)←[EAT]→(obj)→[CAKE].")
(cg:make-cgraph "[PERSON: Dave]←(agnt)←[DRIVE]→(obj)→[CAR].")

(cg:format-query-results (cg:query "[ANIMAL: *x]←(agnt)←[EAT]" cg:*context*))
; 2 matches found:
;   Graph: [CAT:Tom]←(agnt)←[EAT]→(obj)→[FOOD].
;     X = [CAT:Tom]
;   Graph: [DOG:Spike]←(agnt)←[EAT]→(obj)→[CAKE].
;     X = [DOG:Spike]

(cg:format-query-results (cg:query "[PERSON: *x]←(agnt)←[ACT: *y]" cg:*context*))
; 1 match found:
;   Graph: [PERSON:Dave]←(agnt)←[DRIVE]→(obj)→[CAR].
;     Y = [DRIVE]
;     X = [PERSON:Dave]

(cg:graphs-to-text (cg:graphs cg:*context*))
; → "Tom eats food. Spike eats a cake. Dave drives a car."
```

`[ANIMAL: *x]` matches a cat and a dog because both types are below `ANIMAL`;
`[ACT: *y]` matches `DRIVE` the same way. Calling `(cg:init)` again empties the
context and keeps the types.

## Operations

Sowa's operations on graphs. Each takes graphs or strings.

**Projection** asks whether one graph is a more general version of another --
whether the first can be mapped onto the second, each concept onto one of
the same type or a subtype:

```lisp
(cg:projection-p "[ANIMAL]←(agnt)←[EAT]." "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
; → T
(cg:projection-p "[DOG]←(agnt)←[EAT]." "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
; → NIL
(cg:format-projection-mapping
 (cg:project "[ANIMAL]←(agnt)←[EAT]." "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]."))
; → "{[EAT] -> [EAT], [ANIMAL] -> [CAT:Tom]}"
```

**Maximal join** merges two graphs on the largest part they share:

```lisp
(cg:format-cgraph (cg:maximal-join "[CAT: Tom]←(agnt)←[EAT]" "[EAT]→(obj)→[FOOD]"))
; → "[CAT:Tom]←(agnt)←[EAT]→(obj)→[FOOD]."
```

**Combining** merges two graphs that describe the same situation, specializing
where one is more general -- here a cat becomes Tom:

```lisp
(cg:graph-to-text
 (cg:combine-conceptual-graphs (cg:make-cgraph "[CAT]←(agnt)←[EAT]→(manr)→[QUICKLY].")
                               (cg:make-cgraph "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")))
; → "Tom eats food quickly."
```

**Type definitions** give a type a defining graph, which `expand-type`
substitutes for it:

```lisp
(cg:define-concept-type :label 'pet-owner :supertypes '(person)
                        :definition "[PERSON: *lambda]→(poss)→[ANIMAL]")
(cg:format-cgraph (cg:expand-type (cg:graph-head (cg:make-cgraph "[PET-OWNER: Sue]."))))
; → "[PERSON:Sue]→(poss)→[ANIMAL]."
```

## Settings

These are variables in the `:cg` package. Set them in
[`~/.cgraph/initializations.lisp`](setup.md#initializationslisp) to have them
in every session.

| Variable | When true |
|----------|-----------|
| `*always-show-individual-id*` | every named concept shows its individual's id, not only when two would otherwise look the same |
| `*always-show-node-ref*` | every concept and relation shows its node reference, to tell apart nodes that print alike |
| `*always-format-nodes*` | concepts and relations print as notation, not as `#<CONCEPT CAT>` |
| `*allow-dynamic-individual-creation*` | (default) a name in a graph creates its individual; turn it off if your own program owns the individuals |

## Next

- [API.md](../API.md) -- every exported function
- [The type browser](type-browser.md) -- `(cg:init :web t)`
- [Emacs](emacs.md) -- editing CG notation in Emacs
