# CGraph documentation

Start with the [tutorial](tutorial.md). [API.md](../API.md) documents every
exported function.

## Using CGraph

- [Setup](setup.md) -- installing, `cg:init`, directories, type sets
- [Tutorial](tutorial.md) -- types, graphs, referents, English, queries and
  the graph operations, with examples that run as written
- [Referents](referents.md) -- every form a concept's referent can take
- [Individuals](individuals.md) -- how named things are represented

## Generating English

- [Generation](generation.md) -- a tour of what `graph-to-text` produces
- [Lexicon overrides](lexicon-overrides.md) -- telling the generator how a type
  is worded when the lattice guesses wrong
- [Generation tables](generation-tables.md) -- which tables to look at when
  you add a type or find a wrong word

## Tools

- [The type browser](type-browser.md) -- the web page for exploring and
  editing the type lattice
- [Emacs](emacs.md) -- editing CG notation under SLIME

The web graph editor has no user guide yet; `notes/graph-editor.md` is its
design document.

`notes/` holds design notes and working journals, not user documentation.
