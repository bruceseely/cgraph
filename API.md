# CGraph API Reference

This document covers the user-facing API for CGraph. All symbols are in the
`:conceptual-graphs` package (nicknames `:cg`, `:cgraph`).







---

## Setup and Initialization

### `setup-cgraph (code-base &key external-types-directory)`
Entry point for initial CGraph setup. Creates directories, loads type
definitions, configures SLIME integration, and runs the test suite.
Called once at startup.

### `initialize-cgraph ()`
Reinitializes the system: clears variables, coreferences, individuals,
reloads type definitions, and runs initialization parameters.

### `reset-cgraph ()`
Full reset: clears context, counters, and display flags, then calls
`initialize-cgraph`.

### `report-directories ()`
Prints current CGraph configuration paths (types, data, initializations).

### `ensure-concept-types-exist (definitions)`
Creates concept types from a list of definition plists. Each definition
is of the form `(:label NAME :supertypes (S1 S2) ...)`. Useful in tests
and programmatic type setup.

### `ensure-relation-types-exist (definitions)`
Same as above, for relation types.

---

## Type System

### Creating and Modifying Types

#### `define-concept-type (&key label supertypes canonical-graph graph-compatible definition)`
Define a new concept type or modify an existing one.

```lisp
(define-concept-type :label 'ROBOT
                     :supertypes '(animate)
                     :canonical-graph "[ROBOT]←(agnt)←[ACT]")
```

#### `make-concept-type (type-label &key supertypes-list canonical-graph-string graph-compatible definition-string)`
Lower-level constructor. Creates and registers a new concept type.
`type-label` can be a symbol or string.

#### `modify-concept-type (node &key supertypes canonical-graph-string graph-compatible)`
Modify an existing concept type's supertypes or properties.

#### `remove-concept-type (node)`
Remove a concept type from the hierarchy, disconnecting all inheritance links.

#### `make-relation-type (label &key source-types dest-type description)`
Create and register a new relation type. `source-types` is a list of
concept types; `dest-type` is a single concept type.

```lisp
(make-relation-type 'CTRL
                    :source-types (list (get-concept-type 'animate))
                    :dest-type (get-concept-type 'act)
                    :description "controller of an act")
```

### Looking Up Types

#### `get-concept-type (type-name)` → concept-type or nil
Retrieve a concept type by symbol, string, or type object. Returns nil
if not found.

```lisp
(get-concept-type 'cat)    ; → CAT
(get-concept-type "cat")   ; → CAT
```

#### `get-relation-type (type-name)` → relation-type
Retrieve a relation type by symbol, string, or type object.

#### `lookup-concept-type (concept-type &optional suppress-warnings)` → concept-type
Safe lookup that returns `*concept-type-top*` instead of nil on failure.

#### `concept-type-defined-p (type)` → boolean
Returns T if the symbol names a defined concept type.

#### `concept-type-exists (type-name)` → boolean
Returns T if the type name is present in the catalog.

#### `relation-type-exists (type-name)` → boolean
Returns T if the relation type name is present in the catalog.

### Querying the Hierarchy

#### `subtype-p (subtype supertype)` → boolean
Predicate: is the first type a subtype of the second? Both arguments
can be concept-type objects or symbols.

```lisp
(subtype-p 'cat 'animal)   ; → T
(subtype-p 'cat 'event)    ; → NIL
```

#### `supertype-p (type supertype)` → boolean
Predicate: is the second type a supertype of the first?

#### `proper-subtype-p (subtype supertype)` → boolean
Like `subtype-p` but returns nil when the types are equal.

#### `proper-supertype-p (supertype type)` → boolean
Like `supertype-p` but returns nil when the types are equal.

#### `subsumes-p (type1 type2)` → boolean
Does type1 subsume type2? Equivalent to: type1 equals type2, or type2
is a subtype of type1.

#### `subtypes (type)` → list
All subtypes of a type (including itself), traversing the full lattice.

#### `proper-subtypes (type)` → list
All subtypes except the type itself.

#### `supertypes (type)` → list
All supertypes of a type (including itself).

#### `proper-supertypes (type)` → list
All supertypes except the type itself.

#### `direct-subtypes (type)` → list
Immediate children in the hierarchy. Accepts a concept-type or symbol.

#### `direct-supertypes (type)` → list
Immediate parents in the hierarchy. Accepts a concept-type or symbol.

#### `maximal-common-subtype (type1 type2)` → concept-type or nil
The most specific type that is a subtype of both. Arguments can be
concept-type objects or symbols.

#### `minimal-common-supertype (type1 type2)` → concept-type or nil
The most general type that is a supertype of both.

#### `common-subtypes (type1 type2)` → list
All types that are subtypes of both.

#### `common-supertypes (type1 type2)` → list
All types that are supertypes of both.

#### `rel-use (source dest)` → list of relation-types
Find relation types that are compatible with the given source and
destination concept types.

```lisp
(rel-use 'act 'animate)   ; → (AGNT RCPT ...)
```

### Listing and Enumerating Types

#### `all-concept-types (&optional sort)` → list of symbols
All concept type symbols in the catalog. Pass T to sort alphabetically.

#### `all-relation-types (&optional sort)` → list of symbols
All relation type symbols in the catalog.

#### `collect-concept-types (&optional start-node)` → list
Collect all concept-type objects reachable from start-node (default: top).

### Walking the Hierarchy

#### `walk-concept-types (function &optional node)`
Depth-first traversal from top (or node), calling `function` on each type.

#### `walk-concept-types-down (function &optional node)`
Walk downward from node through subtypes.

#### `walk-concept-types-up (function &optional node)`
Walk upward from node through supertypes.

#### `crawl-concept-types-down (function &optional node)`
Breadth-first walk downward from node.

#### `crawl-concept-types-up (function &optional node)`
Breadth-first walk upward from node.

### Type I/O

#### `print-concept-types (&optional top-node &key indents newline)`
Print the concept type hierarchy as an indented tree.

#### `print-relation-types (&optional stream)`
Print all relation types with source types, destination type, and description.

#### `describe-concept-types ()`
Print detailed descriptions of all concept types.

#### `save-concept-types (filename)`
Save all concept types to a file in definition format.

#### `save-relation-types (filename)`
Save all relation types to a file.

#### `load-concept-types (filename &optional suppress-warnings)` → count
Load concept type definitions from a file. Returns the number loaded.

#### `load-relation-types (filename &optional suppress-warnings)` → count
Load relation type definitions from a file.

### Validation

#### `check-type-lattice ()` → boolean
Check the type lattice for structural problems: cycles, orphaned types,
and symmetry violations. Returns T if the lattice is valid.

---

## Concepts

### Creating Concepts

#### `make-concept (type referent &key context)` → concept
Create a concept. `type` can be a concept-type object or symbol.
`referent` can be nil (generic), a referent object, an individual, or a
property list.

```lisp
(make-concept 'dog nil)                          ; generic dog
(make-concept 'dog (make-individual 'dog '(:name "Spot")))  ; named dog
```

#### `get-concept (concept-type properties &key id context)` → concept
Get or create a concept from a type and properties. Handles individual
lookup and coreference detection within the current graph parse.

### Inspecting Concepts

#### `concept-type (concept)` → concept-type
The concept's type.

#### `referent (concept)` → referent or nil
The concept's referent (nil for generic concepts).

#### `properties (concept)` → plist
Properties from the concept's referent.

#### `referent-name (concept)` → string or nil
The name property from the concept's referent.

#### `generic-p (concept)` → boolean
T if the concept has no referent (is generic).

#### `is-type (concept concept-type)` → boolean
Check if the concept is of the given type.

#### `concept-p (thing)` → boolean
Type predicate.

#### `describe-concept (concept &optional stream)`
Print a detailed description of the concept.

### Comparing Concepts

#### `concepts-equal (concept1 concept2)` → boolean
Two concepts are equal if they have the same type and equal referents.

#### `referents-equal (referent1 referent2)` → boolean
Check if two referents are equal.

### Concept Arcs

#### `inarcs (concept)` → list
Relations where this concept is the destination (outarc of the relation).

#### `outarcs (concept)` → list
Relations where this concept is a source.

---

## Relations

### Creating Relations

#### `make-relation (rtype)` → relation
Create a relation. `rtype` can be a relation-type object, symbol, or string.

```lisp
(make-relation 'agnt)
(make-relation "agnt")
```

### Inspecting Relations

#### `relation-type (relation)` → relation-type
The relation's type.

#### `relation-p (thing)` → boolean
Type predicate.

#### `outarc (relation)` → concept
The destination concept (first arc).

#### `inarcs (relation)` → list
The source concepts (remaining arcs).

#### `valence (relation)` → integer
Number of arcs.

#### `signature (relation)` → list
List of concept types for all arcs.

#### `connecting-relation (concept1 concept2)` → relation or nil
Find the relation connecting two concepts.

#### `relations-equal (rel1 rel2)` → boolean
Check if two relations have the same type and equivalent arcs.

---

## Graphs

### Creating Graphs



#### `make-cgraph (graph &optional context)` → graph

The graph arg is string, graph-node, graph object, or list of nodes
The resulting graph is added to the context (defaulting to \*context\*)
This is the primary way to create graphs.

#### `parse-cgraph (string)` → concept-node list
Parse a conceptual graph from linear notation. 

```lisp
(parse-cgraph "[CAT: Whiskers]←(agnt)←[EAT]→(obj)→[FOOD].")
```

### Inspecting Graphs

#### `head (graph)` → graph-node
The graph's entry node.

#### `graph-head (graph)` → concept
The most-connected concept in the graph.

#### `nodes (graph)` → list
All nodes by traversing from the head.

#### `graph-concepts (graph)` → list
All concepts in the graph.

#### `graph-relations (graph)` → list
All relations in the graph.

#### `concepts-of-type (graph concept-type)` → list
All concepts of the given type.

#### `concept-count (graph)` → integer
Number of concepts.

#### `relation-count (graph)` → integer
Number of relations.

#### `graph-p (thing)` → boolean
Type predicate.

#### `graphs-equal (graph1 graph2)` → boolean
Compare two graphs for structural equality.

### Graph Referents

Concepts can contain entire graphs as referents. The type must have
`graph-compatible` set to T (e.g., PROPOSITION, SITUATION).

#### `graph-referent (concept)` → graph or nil
Return the graph object if this concept's referent is a graph.

#### `graph-referent-p (concept)` → boolean
Check if a concept has a graph referent.

#### `referent-concepts (concept)` → list
Concepts from this concept's graph referent.

#### `referent-relations (concept)` → list
Relations from this concept's graph referent.

---

## Individuals

#### `make-individual (type &optional properties &key id)` → individual
Create a named individual of the given type.

```lisp
(make-individual 'dog '(:name "Spot"))
(make-individual 'person '(:name "Sue") :id 42)
```

#### `get-individual (type &key id properties)` → individual or nil
Look up an individual by type and ID or properties.

#### `find-individual-with-id (id)` → individual or nil
Find an individual by numeric ID.

#### `individual-p (thing)` → boolean
Type predicate.

#### `individuals-equal (ind1 ind2)` → boolean
Check if two individuals are equal.

---

## Referents

#### `make-referent (content &optional concept)` → referent
Create a referent from an individual, graph, graph-node, or node list.

#### `referent-p (thing)` → boolean
Type predicate.

#### `content (referent)` → individual, graph, etc.
The referent's content.

#### `name-property (referent)` → string or nil
The name property.

#### `measure-property (referent)` → string or nil
The measure property.

---

## Conformity

#### `conforms (object restriction)` → boolean
Generic conformity check. Dispatches on argument types:

| object | restriction | meaning |
|--------|-------------|---------|
| concept-type | concept-type | Is the restriction a supertype? |
| concept | concept-type | Does the concept conform to the type? |
| individual | concept-type | Does the individual conform to the type? |
| graph | concept-type | Is the type graph-compatible? |
| referent | concept-type | Does the referent's content conform? |

---

## Formatting and Parsing

### Formatting (Graph → Text)

#### `format-cgraph (node-or-graph &key initial-indent indent-delta)` → string
Format a conceptual graph as a string in linear notation. This is the
primary formatting function.

```lisp
(format-cgraph (parse-cgraph "[DOG: Spot]←(agnt)←[EAT]→(obj)→[BONE]."))
; → "[DOG: Spot]←(agnt)←[EAT]→(obj)→[BONE]"
```

#### `format-concept (concept)` → string
Format a single concept: `[TYPE: referent]`.

#### `format-relation (relation)` → string
Format a single relation: `(type)`.

#### `print-cgraph (node &key indent delta stream)`
Print a formatted graph to a stream.

#### `pcg (thing)` → string or nil
Shorthand for `format-cgraph`. Works on graph-nodes and graph objects.

#### `fcg (graph-node)` → string
Alias for `format-cgraph`.

#### `graph-every-concept (node-or-graph)` → list of strings
Format each concept in the graph independently, showing its local
connections.

### Parsing (Text → Graph)

#### `parse-cgraph (string)` → graph
Parse a conceptual graph from linear notation.

**Notation summary:**
- Concepts: `[TYPE]`, `[TYPE: referent]`, `[TYPE: name @measure {set}]`
- Relations: `(relation-type)`
- Arrows: `→` or `->` (forward), `←` or `<-` (backward), `-` (continuation)
- Variables: `*x`, `*y`, etc.
- Co-references: `?label`
- Graph referents: `[PROPOSITION: [nested graph]]`
- Negation: `~[TYPE]`
- Terminator: `.` (period ends the graph)

```lisp
;; Simple graph
(parse-cgraph "[DOG: Spot]←(agnt)←[EAT]→(obj)→[BONE].")

;; Multi-branch graph
(parse-cgraph "[GIVE]-(agnt)→[PERSON: Sue](obj)→[DOG: Spot](rcpt)→[PERSON: Tom].")

;; With variables for co-reference
(parse-cgraph "[PERSON: *x]→(poss)→[DOG]←(obj)←[WALK]→(agnt)→[PERSON: *x].")
```

### String Utilities

#### `normalize-cgraph-string (graph-string &key concept-case relation-case)` → string
Normalize case of type labels in a CG string. Default: concepts UPCASE,
relations downcase.

#### `flatten-cgraph (text)` → string
Remove all whitespace from a CG string.

#### `arrows-to-ascii (graph-string)` → string
Convert Unicode arrows (→, ←) to ASCII (`->`, `<-`).

#### `arrows-to-unicode (graph-string)` → string
Convert ASCII arrows (`->`, `<-`) to Unicode (→, ←).

---

## Graph Operations

### Formation Rules

The four atomic operations on conceptual graphs (Sowa, 1984).

#### `copy-concept (concept)` → concept
Create an identical copy of a concept (same type and referent).

#### `copy-relation (relation)` → relation
Create an identical copy of a relation.

#### `copy-cgraph (graph-or-node)` → graph-node
Deep-copy an entire graph. Returns the head node of the copy.

#### `restrict-by-type (concept concept-type)` → boolean
Specialize a concept's type to a more specific subtype. Modifies the
concept in place. Returns T on success.

#### `restrict-by-referent (concept referent-or-individual)` → boolean
Specialize a concept's referent. Generic concepts can be restricted to
have individual referents. Returns T on success.

#### `restrict (concept restriction)` → boolean
Generic restrict. `restriction` can be a concept (restrict to match it),
a concept-type, an individual, or a property list.

#### `join-concepts (concept1 concept2)` → concept
Destructively combine two compatible concepts. Concept1 absorbs
concept2's type, referent, and relations. Returns concept1.

#### `concepts-joinable-p (concept1 concept2)` → boolean
Check if two concepts can be joined (compatible types and referents).

#### `types-joinable-p (type1 type2)` → boolean
Check if two types can be joined.

#### `simplify (concept)` → list
Remove duplicate relations from a concept. Returns the removed relations.

### Projection

Pattern matching: check if a pattern graph can be mapped onto a target graph.

#### `project (pattern target &key all-solutions)` → mapping or nil
Project a pattern onto a target. Returns an alist mapping pattern
concepts to target concepts, or nil if no projection exists. With
`:all-solutions t`, returns a list of all valid mappings.

Both arguments accept graph-nodes, graph objects, or strings.

```lisp
;; Does a pattern match?
(project "[ANIMAL]←(agnt)←[EAT]"
         "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
; → (([ANIMAL] . [CAT: Tom]) ([EAT] . [EAT]))

;; Predicate version
(projection-p "[ANIMAL]←(agnt)←[EAT]"
              "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
; → T
```

#### `projection-p (pattern target)` → boolean
Predicate: does a projection exist?

#### `projection-mapping (pattern target)` → mapping or nil
Return the projection mapping (same as `project`).

#### `all-projections (pattern target)` → list of mappings
Return all possible projection mappings.

#### `format-projection-mapping (mapping)` → string
Format a mapping for display.

### Maximal Join

Find and merge the largest compatible overlap between two graphs.

#### `maximal-join (graph1 graph2)` → graph-node
Compute the maximal join. Copies both graphs, joins overlapping
concepts, and returns the head of the merged result. Returns a copy
of graph1 if there is no overlap.

Both arguments accept graph-nodes, graph objects, or strings.

```lisp
(maximal-join "[CAT: Tom]←(agnt)←[EAT]"
              "[EAT]→(obj)→[FOOD]")
; → head of merged graph: [CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD]
```

#### `maximal-join-mapping (graph1 graph2)` → mapping
Return just the mapping without executing the join. Useful for debugging.

#### `format-join-mapping (mapping)` → string
Format a join mapping for display.

### Graph Combination

#### `combine-conceptual-graphs (graph1 graph2 &key alignment-strategy)` → graph
High-level graph combination using formation rules with automatic
correspondence finding.

---

## Queries

#### `query (pattern context &key all-solutions)` → list of results
Query a context (knowledge base) for graphs matching a pattern. Returns
a list of results, each of the form:

```lisp
(:graph <head-concept> :bindings ((variable . concept) ...))
```

The pattern can be a string, graph-node, or graph object. Variables in
the pattern (`*x`, `*y`) are bound to matching concepts.

```lisp
;; Add graphs to the context
(parse-cgraph "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")
(parse-cgraph "[DOG: Spike]←(agnt)←[EAT]→(obj)→[BONE].")

;; Query with a variable
(query "[ANIMAL: *x]←(agnt)←[EAT]" *context*)
```

#### `format-query-results (results &optional stream)`
Pretty-print query results.

---

## Type Definitions (Lambda Expansion)

Types can have definition graphs using a `*lambda` variable to mark the
defining concept.

```lisp
;; Define a type
(define-concept-type :label 'PET-OWNER
                     :supertypes '(person)
                     :definition "[PERSON: *lambda]→(poss)→[PET]")

;; Expand a concept's type definition
(expand-type (parse-cgraph "[PET-OWNER: Sue]"))
; → replaces [PET-OWNER: Sue] with [PERSON: Sue]→(poss)→[PET]
```

#### `expand-type (concept)` → concept
Expand a concept's type definition. Returns the lambda concept from the
expanded definition graph, or the original concept if no definition exists.

#### `ensure-definition-parsed (concept-type-or-symbol)` → type-definition or nil
Lazily parse a type's definition string. Returns the cached
type-definition object.

---

## Contexts

#### `make-context (&optional parent &key negated)` → context
Create a new context, optionally as a child of a parent context.

#### `add-graph (graph &optional context)` → graph
Add a graph to a context. Accepts a graph object, graph-node, string,
or list.

#### `add-concept (concept &optional context)`
Add a concept to a context's cache.

#### `remove-concept (concept &optional context)`
Remove a concept from the context.

#### `graph-present-p (graph &optional context)` → boolean
Check if a graph exists in the context.

### Retrieving Concepts from Context

#### `retrieve-concepts-having-properties (properties &optional context)` → list
Find concepts in the context matching the given properties.

#### `retrieve-concepts-having-individual (individual &optional context)` → list
Find concepts with the given individual.

#### `retrieve-concept (concept-type individual-or-id &key context)` → concept
Retrieve a single concept by type and individual, ID, or properties.

### Graph Referent Queries

#### `concepts-with-graph-referents (&optional context)` → list
All concepts in the context that have graph referents.

#### `all-graph-referents (&optional context)` → list
All unique graphs used as referents in the context.

#### `graph-referent-report (&optional context stream)`
Print a report of all graph referents.

---

## Co-references and Variables

### Variables

Variables (`*x`, `*y`, etc.) are single-character labels used in graph
serialization to mark concepts that appear multiple times.

#### `set-variable (node &optional new-name)` → variable-name
Assign a variable to a node.

#### `unset-variable (variable-or-node)`
Remove a variable binding.

#### `node-variable (node)` → variable-name or nil
Get the variable name for a node.

#### `variable-node (variable)` → node or nil
Get the node for a variable name.

### Co-references

Co-reference labels (`?c`, `?cat`) link concepts across multiple graphs
or contexts.

#### `set-coref-label (concept label)`
Define a co-reference label on a concept.

#### `coref-label-node (label)` → concept or nil
Get the concept with the given co-reference label.

#### `link-coreference (concept1 concept2)`
Create a bidirectional co-reference link between two concepts.

#### `coref-text (concept)` → string
Get the formatted co-reference label text (e.g., `"?c"`).

---

## Visualization

Requires [Graphviz](https://graphviz.org) and the `graphviz-dot-mode`
Emacs package.

#### `graph-concept-types (type-name-list &key landscape hide-bottom)` → filename
Generate a Graphviz diagram for the given type(s) and display it in Emacs.
`type-name-list` is a list of symbols or a single symbol.

```lisp
(graph-concept-types '(animal))
(graph-concept-types '(entity physical animate) :landscape t)
```

#### `generate-concept-type-digraph (&key type-name-list stream parents children landscape hide-bottom)`
Write Graphviz DOT source to a stream. Lower-level function for custom output.

#### `display-graph (graph-name &optional filedir)`
Display a DOT file in Emacs via `graphviz-dot-mode`. Requires SLIME.

---

## Key Global Variables

| Variable | Description |
|----------|-------------|
| `*context*` | The current active context |
| `*concept-type-top*` | The top (⊤) concept-type instance |
| `*concept-type-bottom*` | The bottom (⊥) concept-type instance |
| `*cgraph*` | Base CGraph directory (~/.cgraph/) |
| `*cgraph-types-directory*` | Directory containing type definition files |
| `*cgraph-data-directory*` | Directory for generated plots and data |
| `*concise*` | When T (default), omit extra spaces in formatting |
| `*debug-mode*` | When T, include debug info (marks, node refs) in output |
| `*include-node-ref*` | When T, show node reference numbers in output |
