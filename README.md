# CGraph

[![tests](https://github.com/bruceseely/cgraph/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/bruceseely/cgraph/actions/workflows/tests.yml)

A Common Lisp implementation of John Sowa's **Conceptual Graphs** — a knowledge representation formalism based on semantic networks and first-order logic.

## Quick start

From a shell, with [SBCL](https://www.sbcl.org/) installed (`brew install
sbcl`, or your package manager; a recent version). Skip the Quicklisp step
if you already have it:

```sh
curl -O https://beta.quicklisp.org/quicklisp.lisp
sbcl --non-interactive --load quicklisp.lisp \
     --eval '(quicklisp-quickstart:install)' \
     --eval '(ql-util:without-prompting (ql:add-to-init-file))'
git clone https://github.com/bruceseely/cgraph.git ~/quicklisp/local-projects/cgraph
sbcl
```

Then, at the SBCL prompt:

```lisp
(ql:quickload "cgraph")
(cg:init)
(cg:graph-to-text (cg:make-cgraph "[DOG: Spike]<-(agnt)<-[EAT]->(obj)->[FOOD]."))
; → "Spike eats food."
(cg:format-cgraph (cg:make-cgraph "[DOG: Spike]<-(agnt)<-[EAT]->(obj)->[FOOD]."))
; → "[DOG:Spike]←(agnt)←[EAT]→(obj)→[FOOD]."
```

`<-` and `->` can be typed for `←` and `→`. No editor is needed; Emacs and
SLIME are optional (see [Emacs integration](#emacs-integration)). The
[tutorial](docs/tutorial.md) starts from here.

## What It Does

CGraph lets you represent knowledge as typed, labeled graphs and reason over them using Sowa's formal operations. If you need a system for:

- **Building knowledge representations** using concepts, relations, and typed hierarchies
- **Querying knowledge bases** with pattern matching and variable binding
- **Combining and comparing graphs** through projection, maximal join, and formation rules
- **Defining type hierarchies** as lattices (DAGs) with multiple inheritance
- **Visualizing type structures** via Graphviz

...then CGraph may be useful to you.

## Core Capabilities

### Type System

The type hierarchy is a lattice (directed acyclic graph), not a tree. Types support multiple inheritance, with a universal top type (⊤) and bottom type (⊥). The system ships with 80+ predefined concept types covering common categories:

- **Entities**: Person, Animal, Object, Substance, Place, Organization
- **Actions**: Act, Move, Carry, Eat, Drink, Give, Sell, Transport, Drive
- **Qualities**: Color, Size, Temperature, Hardness, Texture, Speed
- **Abstract**: Proposition, Information, Collection, Set, Sequence

And 20+ predefined relation types: agent, object, recipient, location, instrument, attribute, manner, theme, possession, part, destination, and others.

Types can be extended. You can define new types with supertype relationships, canonical graphs, and conformity constraints. Type definitions are stored as text files and loaded at startup.

### Graph Construction

Graphs are built from **concepts** (typed nodes with optional referents) and **relations** (typed binary links between concepts). You can create graphs by:

- Parsing CG linear notation: `[CAT: Whiskers]←(agnt)←[EAT]→(obj)→[FOOD]`
- Constructing programmatically with `make-cgraph` to create a GRAPH object
- Constructing graph nodes with `make-concept` and `make-relation`

Concepts support named individuals, generic referents, co-reference variables, and nested graph referents. Contexts provide hierarchical grouping for knowledge organization, including negated contexts.

### Graph Operations

CGraph implements Sowa's core operations:

- **Formation Rules** — copy, restrict, join, and detach (the atomic graph operations)
- **Projection** — pattern matching to test whether one graph subsumes another, with concept mappings returned on success
- **Maximal Join** — find and merge the largest compatible overlap between two graphs
- **Graph Combination** — high-level merging using formation rules with automatic correspondence finding
- **Queries** — search a knowledge base (context) for graphs matching a pattern, with variable bindings in results
- **Type Definitions** — lambda-based type expansion for specialized reasoning

### Visualization

Export concept type hierarchies to Graphviz DOT format for rendering as diagrams.
View the concept-type hierarchy and canonical graphs in a web browser, and
build graphs by pointing and clicking: see [the type
browser](docs/type-browser.md) and [the graph editor](docs/graph-editor.md),
both started by `(cg:init :web t)`.

## Requirements

- **A Common Lisp**: developed on **SBCL**; the engine and its test suite
  also pass on **ECL**. The web UI and editor have only been run on SBCL.
- **Quicklisp**, to fetch dependencies
- **Graphviz** (optional, for type hierarchy visualization)
- **Emacs + SLIME** (optional, for the Emacs integration below)

## Getting Started

The [quick start](#quick-start) clones cgraph into
`~/quicklisp/local-projects/`; anywhere ASDF can find it will do. A session
starts with:

```lisp
(ql:quickload "cgraph")
(cg:init)
```

That loads the shipped type definitions, read-only, and writes nothing.
Calling `(cg:init)` again starts over with an empty knowledge base and the
same types. To change or add types, make a type set of your own:
`(cg:create-type-set "mine")` copies the current types to
`~/.cgraph/types/mine/` and switches to it, and next time `(cg:init :types
"mine")` loads it. `(cg:init :web t)` also starts the web type browser and
graph editor on http://localhost:8060/.

Basic usage:

```lisp
;; Parse a conceptual graph from linear notation: Spike eats food.
(cg:format-cgraph (cg:make-cgraph "[DOG: Spike]←(agnt)←[EAT]→(obj)→[FOOD]."))
; → "[DOG:Spike]←(agnt)←[EAT]→(obj)→[FOOD]."

;; Say it in English
(cg:graph-to-text (cg:make-cgraph "[DOG: Spike]←(agnt)←[EAT]→(obj)→[FOOD]."))
; → "Spike eats food."

;; Look up a type in the hierarchy
(cg:get-concept-type 'cat)
; → CAT

;; Check type relationships
(cg:subtype-p (cg:get-concept-type 'cat) (cg:get-concept-type 'animal))
; → T

;; Project one graph onto another (pattern matching)
(cg:format-projection-mapping
 (cg:project "[ANIMAL]←(agnt)←[EAT]." "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]."))
; → "{[EAT] -> [EAT], [ANIMAL] -> [CAT:Tom]}"
```

The [tutorial](docs/tutorial.md) goes further, and [API.md](API.md) is the
full reference; [docs/](docs/README.md) lists the rest.

### Running the tests

```sh
test/run-tests.sh
```

That is `(asdf:test-system :cgraph)` in a fresh SBCL: it loads the
`cgraph/tests` system and runs every suite against the test types in
`test/test-types/`, so your `~/.cgraph` is never touched, and it signals an
error if any suite fails. In an image that already has `cgraph/tests` loaded,
`(cg::test-all t)` does the same from any package: each suite loads the test
types and puts your own back afterwards. cgraph is also a dependency of
the [`cg-from-parse`](https://github.com/bruceseely/cg-from-parse)
conceptual-graph extractor, whose `test/run-all-suites.sh` is a **whole-stack
gate**: it runs this suite alongside the PARSIFAL parser and the extractor's
own suites, each in its own process, for one combined pass/fail.

## Emacs Integration

CGraph includes Emacs support in the `emacs/` directory:

- **cg-mode** — Major mode with syntax highlighting, indentation, and bracket matching for CG notation
- **Keybindings** — `C-c t` inserts ⊤, `C-c b` inserts ⊥, top and bottom type abbreviations for CG notation
  "->" followed by "[", "(", or space is replaced by "→"
  "<-" followed by "[", "(", or space is replaced by "←"
- **SLIME bridge** — Evaluate CG expressions directly from Emacs buffers

See [docs/emacs.md](docs/emacs.md).

## Project Structure

```
system/
  setup/        Initialization, global definitions, utilities
  core/         Types, concepts, relations, graphs, contexts,
                referents, conformity, parsing, formatting
  operations/   Formation rules, projection, maximal join,
                graph combination, queries, type definitions
  generation/   Graph-to-English text generation
  graphing/     Graphviz DOT generation
  web/          Web type browser (the cgraph-web system)
  editor/       Web graph editor (the cgraph-editor system)
default-types/  Predefined concept and relation type definitions
docs/           User documentation
notes/          Design notes and working journals
emacs/          Emacs major mode and SLIME integration
test/           Test suite (run with test/run-tests.sh)
```

## References

- Sowa, J.F. *Conceptual Structures: Information Processing in Mind and Machine*. Addison-Wesley, 1984.
- Sowa, J.F. *Knowledge Representation: Logical, Philosophical, and Computational Foundations*. Brooks/Cole, 2000.

## License

MIT License. See [LICENSE](LICENSE) file for details.
