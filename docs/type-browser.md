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
  relation is silently left out of generated text.
- **Graph** (middle): the lattice for the types you have selected -- every
  inheritance path from the top type ⊤ through each selected type to the
  bottom type ⊥. Selecting several types shows the union of their paths, which
  is a way to see how they interact.
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
  clicks after that explore the graph again. *Draw…* opens the canonical graph
  in the [graph editor](graph-editor.md).
- **New Relation** opens the relation form; its source and destination slots
  are filled the same way, with `+` and then a click on a type.
- **Options** sets display options.
- **Editor** opens the [graph editor](graph-editor.md) on an empty graph.

## Saving types

Types are saved into the type set in use (see [setup](setup.md#type-sets)).
The shipped default types are read-only: a save while they are loaded is
refused, and the page offers to create a type set of your own, then makes the
save there.
