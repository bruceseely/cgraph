# The type browser

A web page for exploring the concept-type lattice and editing the type
catalog. Start it with the session:

```lisp
(cg:init :web t)       ; or :web 8070 for another port
```

and open http://localhost:8060/. The page is served on 127.0.0.1 only. Every
gesture is a single plain click, left or right; there are no double-clicks or
modifier keys.

## The page

- **Sidebar** (left): every concept type, alphabetically, or every relation
  type under the *Relation Types* tab. The filter box matches a prefix of the
  whole name or of any hyphenated part of it: `stage` finds `LIFE-STAGE`. A
  relation that no part of the English generator reads is marked, since such a
  relation is silently left out of generated text. A type's aliases have rows
  of their own, `CAR → AUTOMOBILE`, and clicking one does exactly what clicking
  the type does; filtering on an alias also shows the type.
- **Graph** (middle): the lattice for the types you have selected -- every
  inheritance path from the top type ⊤ through each selected type to the
  bottom type ⊥. Selecting several types shows the union of their paths, which
  is a way to see how they interact. A type with aliases shows them in its box:
  `AUTOMOBILE (AUTO, CAR)`.
- **Canonical graphs** (right): types you pin, with their canonical graphs,
  shown as linear notation or drawn as a graph (*Options* above the pane).
  *Clear* unpins them all; the ✕ on an entry unpins one.
- **Toolbar** (top): the selected types as chips, and the buttons below.

## Clicks

| Where | Left click | Right click |
|-------|------------|-------------|
| a type in the sidebar | select or deselect it, and pin its canonical graph | show or hide its subtypes; if it isn't in the graph, show it connected to what is |
| a node in the graph | select or deselect it, and pin its canonical graph | show or hide its subtypes |
| the graph background | remove the types shown by right clicks | |
| a chip in the toolbar | deselect that type | |
| a relation in the sidebar | open it in the relation form | |

Types revealed by a right click are drawn with a yellow background, so you
can tell them from the paths of your selection.

## Buttons

- **Save** writes the current lattice as `<types>.dot` and `<types>.png` to
  `~/.cgraph/data/`. Clicking the file name it reports copies it to the
  clipboard (and to the Emacs kill ring, under SLIME).
- **Initialize** reloads the type catalog from its files and redraws.
- **New Type** / **Edit Type** open the type form. After *Edit Type*, the next
  type you click is the one edited. In the form, `+` next to the supertypes
  arms a one-time pick: the next type you click becomes a supertype, and
  clicks after that explore the graph again. *also called* takes the type's
  aliases, separated by spaces or commas. *Draw…* opens the canonical graph
  in the [graph editor](graph-editor.md). *Duplicate*, on a type being
  edited, starts a new type as a copy of it: see [Copying a type](#copying-a-type).
- **New Relation** opens the relation form; its source and destination slots
  are filled the same way, with `+` and then a click on a type.
- **Options** sets display options.
- **Editor** opens the [graph editor](graph-editor.md) on an empty graph.

## Saving types

Types are saved into the type set in use (see [setup](setup.md#type-sets)).
The shipped default types are read-only: a save while they are loaded is
refused, and the page offers to create a type set of your own, then makes the
save there.

A canonical graph is checked before it is saved. It must parse, and it must be
headed by a concept of the type being saved: BABY's graph starts with `[BABY]`.
A graph headed by another type describes that type, and is almost always a
line copied from a sibling and not edited, so the save refuses it and says so.
`(cg:check-type-lattice)` reports the same thing for graphs already in a type
set's files.

## Copying a type

A new type is often like one you have: BANANA like APPLE, BAG like BOX. Open
the one to copy with *Edit Type*, press *Duplicate*, type the new name over
the old, and *Create*. The copy gets the original's supertypes, canonical
graph and note. Where the canonical graph names the original's own type, it is
renamed on Create, so BANANA's graph says `[BANANA]`, not `[APPLE]`.

At the REPL, `:like` on `define-concept-type` does the same:

```lisp
(cg:define-concept-type :label 'banana :like 'apple)
```

It copies the supertypes, the canonical graph (renamed), and whether the type
takes a graph as its referent. Anything you give alongside it wins:
`:like 'apple :supertypes '(tropical-fruit)` keeps APPLE's graph but not its
place in the lattice. Not copied: aliases, subtypes, the definition.

The copy is made once. Nothing links the two afterwards, so a later change to
APPLE leaves BANANA as it was.

A copy is the original's **sibling**, not a kind of it. A relation that names
APPLE in its signature does not accept BANANA, so a canonical graph that relies
on that, as PLACE's `[PLACE]←(loc)←[⊤]` does, is refused for the copy. If the
new type really is a kind of the old one, make the old one its supertype.

A city or a person is not a new type: Boston is `[CITY: Boston]`, an individual
of the type CITY.
