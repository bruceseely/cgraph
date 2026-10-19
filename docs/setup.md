# Setting up CGraph

## Installing

CGraph needs a Common Lisp (it is developed on SBCL, and the engine and its
tests also pass on ECL) and Quicklisp. Clone the repository somewhere ASDF
can find it, such as `~/quicklisp/local-projects/`, then:

```lisp
(ql:quickload "cgraph")
(cg:init)
```

`cg:init` is the one call a session needs. It loads a type set, reads
`~/.cgraph/initializations.lisp` if there is one, and makes a fresh, empty
knowledge base (`*context*`). It writes nothing, and works the same from any
package. Calling it again starts over with the same types.

```lisp
(cg:init)                          ; the shipped types, read-only
(cg:init :types "kitchen")         ; your type set ~/.cgraph/types/kitchen/
(cg:init :types "~/my-domain/")    ; a type set in a directory of your own
(cg:init :web t)                   ; also start the web UI on port 8060
```

`:web t` (or a port number) loads the [type browser](type-browser.md) and the
graph editor and starts their server at http://localhost:8060/. Hunchentoot
is fetched by Quicklisp the first time.

## Directories

`*cgraph*` names `~/.cgraph/`, where per-user files go. Nothing is created
there until something is written:

| Path | Variable | What goes there |
|------|----------|-----------------|
| `~/.cgraph/initializations.lisp` | | forms evaluated by `cg:init`, in the `:cg` package |
| `~/.cgraph/types/<name>/` | | your type sets |
| `~/.cgraph/data/` | `*cgraph-data-directory*` | plots from `graph-concept-types` and the web UI's Save |
| `~/.cgraph/logs/` | `*cgraph-log-directory*` | web-server logs |

`(cg:report-directories)` prints where each of these is.

### initializations.lisp

Settings you want in every session go in `~/.cgraph/initializations.lisp`.
The forms are evaluated in the `:cg` package, so names need no prefix:

```lisp
(setf *always-show-individual-id* t)
(setf *anaphora-cross-coref* nil)
```

## Type sets

A *type set* is a directory holding `concept-types.lisp` and
`relation-types.lisp`, and optionally `lexicon-overrides.lisp` (how its types
are worded in English; see [lexicon overrides](lexicon-overrides.md)). CGraph
reads the set's files where they are -- nothing is copied, deleted or
symlinked -- and `*cgraph-types-directory*` names the set in use. The web type
editor saves into the same files.

`cg:init` takes the set to use as `:types`:

- with no `:types`, the first time, the shipped `default-types/` in the
  cgraph source tree. These are **read-only**: the type editor refuses to save
  into them. Later calls without `:types` keep the set already in use.
- `:types "kitchen"`, a name: `~/.cgraph/types/kitchen/`.
- `:types "~/repo/my-types/"`, a path: any directory, such as one in its own
  git repository.

A `:types` that names no type set is an error, and leaves the session as it
was.

To change or add types, make a set of your own. `(cg:create-type-set
"kitchen")` copies the set now loaded -- the defaults, until you choose
another -- into `~/.cgraph/types/kitchen/` and switches to it, so the type
editor saves there. It copies every file in the source set's directory except
hidden ones (a set may carry a lexicon, notes, a README), and refuses to
overwrite a set that exists. `:from` names a different set to copy; `:switch
nil` copies without switching. Next session, `(cg:init :types "kitchen")`.

The web type editor does the same from the page. A save while the defaults
are loaded is refused, and a strip under the toolbar asks for a type set name
instead; *Create and save* makes the set and then makes the save that was
refused, so nothing typed is lost. *Cancel* leaves the form as it was and
reports why the save didn't happen. The page only accepts a name (letters,
digits, `-`, `_`, `.`), never a path, so sets made there always land in
`~/.cgraph/types/`.

After editing a set's files by hand, `(cg:init)` reloads them. It also empties
the knowledge base; to reload only the types, use `(cg::initialize-types)`.

### Writing the catalog back out

`(cg:save-concept-types file)` and `(cg:save-relation-types file)` write the
*live* catalog in the form the loader reads -- for dumping a catalog you have
changed in the image. What they write loads back into an equal catalog
(`type-test4` holds that contract).

**Do not save over a hand-maintained catalog file.** The writer emits the live
catalog and nothing else, so anything the file carries that is not a type
definition is lost -- `default-types/relation-types.lisp`, for one, holds
commented-out entries. Write somewhere else and diff.

## Lower-level setup functions

`cg:init` is made of three functions that still work on their own:
`setup-cgraph` points cgraph at a type set and loads it, `reset-cgraph` makes
a fresh context and reloads, and `initialize-cgraph` clears individuals,
variables and coreferences and reloads the types. See [API.md](../API.md).

## Emacs

The Emacs side is optional; see [Emacs](emacs.md).
