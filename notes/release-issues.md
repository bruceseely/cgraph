# Release issues: making cgraph usable by other people

The project already has more than most hobby projects: an MIT license, a real
README, a tutorial, a long `API.md`, CI and a large test suite. What stands
between it and outside users is mostly packaging. Today it behaves like a
personal environment, not a library you can load into someone else's Lisp
image.

Items are in priority order.

## 1. Blockers: it misbehaves in someone else's image

- ~~**Nothing is exported.**~~ Done 2026-10-14: 170 symbols, in `cgraph.asd`'s
  `defpackage`: what `API.md` documents, plus the classes, the lookup
  conditions, text generation and the web entry points. Twelve documented
  names stay internal (the `crawl-*` walkers, `pcg`, `graph-referent-report`
  and the variable/coreference functions). `API.md` still documents them, and
  names `add-graph` and `fcg`, which don't exist.
- ~~**Type names resolved in the caller's package.**~~ Done 2026-10-14: from
  `CL-USER`, `'cat` was `CL-USER::CAT`, so every lookup and graph-string parse
  failed unless `start-cgraph` had switched to `:cg` first. Lookups,
  constructors and the reader now resolve names in `:cg`.
- ~~**Loading it unlocks `COMMON-LISP` for the whole image.**~~ Done
  2026-10-14: `SET` and `TYPE` are now shadowed in the `defpackage`, and the
  unlock and the `disable-package-locks` declaims are gone. cgraph, cgraph-web,
  cgraph-editor and the test suite all load into a stock SBCL with `CL` locked.
- ~~**The package uses `#:cl-user`**~~ Done 2026-10-17: now only `#:cl` and
  `#:uiop`. It was harmless in practice: `:use` inherits only exported symbols,
  and SBCL's `CL-USER` exports none (checked with and without an init file),
  but anything a user exported from it would have leaked in. The dead
  `make-package` fallback in `start-cgraph` went with it.
- ~~**SWANK is a hard dependency.**~~ Done 2026-10-16, with run-time checks
  rather than a separate `cgraph/emacs` system: `cgraph.asd` no longer depends
  on SWANK, no source file names a SWANK symbol, and the `#+swank` guards are
  gone (they're decided at compile time, and ASDF reuses fasls). Everything
  that talks to Emacs goes through `eval-in-emacs-if-connected`
  (`system/setup/basic-utilities.lisp`), which does nothing without a SLIME
  connection and works from any thread. cgraph, cgraph-web and cgraph-editor
  load under `sbcl --script`. Loading `init-cgraph.el` (this machine's
  emacs-init) moved from `setup-cgraph` to `start-cgraph`, so it no longer
  breaks setup under someone else's SLIME. Found on the way: the web UI's
  "copy to kill-ring" had never reached Emacs, because SWANK's
  `eval-in-emacs` fails from a thread it didn't start; it works now.
- ~~**`setup-cgraph` deleted files under its `code-base` argument.**~~ Fixed
  2026-10-14: it recursively deleted every `*.fasl`, `*.lisp~` and `*.lisp#`
  there, so `"~/"` would have wiped a home tree. The call is gone; `code-base`
  is now ignored.
- ~~**Setup writes to `~/.cgraph` and rewrites symlinks there.**~~ Done
  2026-10-16: setup writes nothing. A *type set* is a directory of type files,
  read in place (`*cgraph-types-directory*` names it); no copies, deletes or
  `ln -s`. With no `:types`, the shipped `default-types/` are used read-only
  and the type editor refuses to save into them. `create-type-set` clones the
  current set into `~/.cgraph/types/<name>/` (or a path) and switches to it;
  `setup-cgraph :types` takes a name or a path. `data/` and `logs/` are made
  on first write. The type editor, on a refused save, offers to make a type
  set by name and then retries the save (`/api/create-type-set`).

## 2. Portability

- ~~**SBCL-specific code is small**~~ Done 2026-10-17. The four `sb-mop` calls
  in `conformity.lisp` turned out to be commented out; the one live one (the
  REPL tools) uses closer-mop. Loading under ECL 26.5.5 found three real bugs
  SBCL had tolerated: definitions made in package `COMMON-LISP` itself
  (support/debug.lisp), a reader macro returning two values, and output order
  taken from `SET-DIFFERENCE`, whose result order is unspecified (SBCL
  reverses, ECL doesn't). cgraph now shadows `UNION`, `INTERSECTION` and
  `SET-DIFFERENCE` with versions that give SBCL's order everywhere
  (system/setup/set-operations.lisp, checked against SBCL's own by
  `set-operations-test`). All 35 suites pass on SBCL and ECL; CI runs them
  on ECL since 2026-10-17, and the graph editor's suites too since
  2026-10-19, so the web and editor code loads on ECL. Not yet run
  elsewhere: the web UI itself in a browser on ECL; CCL (no native Apple
  Silicon build).
- **No Quicklisp install path.** Getting into the Quicklisp dist, or at least
  Ultralisp, is how CL users find and try libraries.

## 3. Global state and the API

- **One global everything.** The type hierarchy, context and name registry
  are all specials (`*concept-type-top*` etc.), and `make-top-concept-type`
  makes fresh instances, which leaves stale references behind. Two knowledge
  bases can't coexist in one image. A `with-cgraph-environment` macro that
  binds the specials would help; `system/operations/cg-env.lisp` may be most
  of the way there.
- ~~**Startup takes ceremony.**~~ Done 2026-10-19: `(cg:init &key types
  web)` is the one documented entry point. It loads the types once (the old
  `setup-cgraph` → `reset-cgraph` sequence loaded them twice), reads
  `initializations.lisp` in `:cg` from any package, and makes a fresh context.
  Without `:types` it keeps the set in use, so calling it again starts over
  with the same types. `:web` starts the browser and editor. The SLIME setup
  is now idempotent, and `report-directories` no longer resets the context.
  The old three functions remain as its parts; `start-cgraph` is just
  `cg:init` plus this machine's Emacs, lint and tests.
- **The CG readtable can leak into error contexts** (the SLDB `v` bug). Make
  the custom read syntax opt-in through `named-readtables` rather than
  installing it dynamically during calls.

## 4. Scope and modularity

The repo holds the engine, text generation, a web type browser, a web graph
editor and an Emacs mode. Split these into ASDF systems so people can depend on
just the engine:

- `cgraph`: core plus operations
- `cgraph/generation`
- `cgraph-web` and `cgraph-editor`, which already exist
- `cgraph/emacs` (optional now: the Emacs code is gated at run time, so
  this would be packaging only)

## 5. Tests and CI

- ~~**Tests run only in a live image**~~ Done 2026-10-17:
  `(asdf:test-system :cgraph)` runs them through a `cgraph/tests` system (a
  thin adapter over the existing suites; no framework), and signals an error
  when one fails. Loading cgraph no longer compiles the tests. The two
  `test-all`s became one, driven by `*test-suites*`, which also fails when a
  `test/*-test.lisp` file's suite isn't listed (`normalize-test` hadn't been).
  The graph editor's suites followed on 2026-10-19: `(asdf:test-system
  :cgraph-editor)`, through a `cgraph-editor/tests` system, run by
  `test/run-tests.sh` and both CI jobs. They had been reachable only by
  calling `(editor-test)` by hand, needed an initialized image, and passed
  only with `*concise*` NIL as one user's initializations.lisp set it.
- ~~**`test-all` passes only in the runner's environment.**~~ Done 2026-10-17.
  Two causes. Seven suites (referent, concept, parse, projection, graph-every,
  graph-equality, decomposition) never loaded the test types; they passed only
  when an earlier suite left them loaded, or when the user's own types happened
  to define GIRL, PIE and so on. They now use `with-test-types` like the rest.
  And the runners and four suites found tests by a bare `intern`, i.e. in
  `*package*`, so from `CL-USER` every suite looked undefined; those now intern
  in `:cg`. `(cg::test-all t)` passes from either package after an ordinary setup.
- ~~**CI runs only the whole stack**~~ Done 2026-10-19. A `cgraph` job runs
  `test/run-tests.sh` on a clean SBCL with only Quicklisp and CL left locked:
  no other repos, no secrets. The token the whole-stack job passed was
  needed after all, since cg-from-parse was private (the comment saying the
  dependencies were public was wrong). cg-from-parse is public now, so
  cgraph, parsifal and cg-from-parse all check each other out without one,
  and a pull request from a fork runs every job.

## 6. Documentation for strangers

- ~~**Open the README with one runnable copy-paste session**~~ Done
  2026-10-19: a quick start from a shell with only SBCL -- install
  Quicklisp, clone, load, `cg:init`, two graphs -- run as written in an empty
  HOME. Emacs and SLIME were already marked optional. The run found that
  `cg:init` on a fresh Quicklisp printed "cgraph/support not loaded ...
  CL-PPCRE not found"; the REPL tools are now skipped quietly when their
  dependencies aren't installed.
- **Add a "what this is not, and how it compares" paragraph** covering
  CoGITaNT, Amine, and CGIF / ISO 24707 Common Logic. CG people will ask about
  interchange formats immediately; CGIF import/export would be the most
  valuable single feature for adoption.
- ~~**Separate user docs from design journals.**~~ Done 2026-10-19: `docs/`
  holds setup, the tutorial, referents, individuals, generation, the lexicon
  overrides and tables, the type browser and Emacs, with an index;
  `notes/` keeps the design notes and journals. The tutorial, setup and
  type-browser pages were rewritten (every tutorial example runs on the
  shipped types). `docs/graph-editor.md`, a user guide for the graph editor,
  followed the same day. `cg-utils.el` used to fail to load without `clopt`,
  which isn't in the repository; since 2026-10-19 it loads without it, minus
  the Customize options (packaging `clopt` on its own is the later fix).
- ~~**README and `API.md` examples didn't run.**~~ Fixed 2026-10-14: every
  example now runs as written from a fresh setup. The README's graphs had
  their `agnt` arrows backwards; both files used `BONE`, `WALK` and `PET`,
  which `default-types/` doesn't define; `API.md` documented `add-graph` and
  `fcg` (which don't exist), and `query`'s keyword as `:all-solutions`
  (it's `:first-only`).
- ~~**`default-types/` has loose ends**~~ Done 2026-10-19, following
  `cgraph-types`: `NUMBER` is defined (under `ABSTRACT-QUALITY`), `age` is
  physical → `AGE` and `dur` situation → `TIME-DURATION`, so `(cg:init)`
  prints nothing; the duplicate `poss` and `rcpt` are gone (keeping the ones
  that were in effect). `check-type-lattice` now passes on the shipped set:
  `MANNER` is one definition, `CHARACTERISTIC` and `BODY-PART` are defined,
  and `PLACE`'s canonical graph says `[⊤]`, not `[T]`. A type that is
  only named as a supertype (what `CHARACTERISTIC` was hitting), or defined
  with no supertypes, was created under ⊤ without ⊤ listing it, so no walk
  down the lattice reached it; `make-concept-type-aux` now makes both links
  (2026-10-19, checked by `type-test`). `betw`, the one relation with two
  source types, is gone: everything that reads `:source-types` takes the
  list as alternatives, not as positions, and nothing parses, formats or
  words numbered arcs, so it never meant "between". It was the lint's one
  error. Relations of more than two arcs would have to be designed as a
  feature.
- ~~**`parse-cgraph` discards the real cause of a parse failure**~~ Done
  2026-10-19, and it was worse than this said: of 22 typical mistakes only
  one got a message that pointed at the problem. Several came back as a
  different graph with no error (`[CAT]→[DOG]` as `[CAT]`, a stray `]`
  ending the graph, a bare `FOOD` reversing an arrow), some printed
  "unhandled by linkup" and carried on, and the rest were Lisp errors (NIL is
  not a CHARACTER, a DESTRUCTURING-BIND arity error). Now every one is a
  `cgraph-parse-error` (system/core/parse-error.lisp) saying what is wrong,
  with the line and a caret; `parse-error-test` holds 18 of them. Found along
  the way: after a graph referent the concept reader skipped one more `]`,
  eating the enclosing concept's; and LINKUP's MATCH let a pattern longer than
  the remaining tokens match. Turned up in `cgraph-types`: LUNCH-EVENT's
  canonical graph has a doubled `]` and had been silently cut to
  `[LUNCH-EVENT].` A concept whose type doesn't fit its relation is a
  `relation-signature-mismatch` of its own (2026-10-19), with the caret on the
  concept, plain type names, and both fixes spelled out; it used to put the
  caret at the end, print `#<CONCEPT ANIMAL>` and `CONCEPTUAL-GRAPHS::ACT`,
  and list ACT's supertypes where it said "a subtype of ACT".
- **Fix the `.asd` description typo** ("comceptual", `cgraph.asd:24`) and bump
  `:version` past `0.0.1` when you tag a release.

## Where to start

The first two items in section 1, exports and shadowing instead of unlocking
`CL`, are each about a day of work. After those, cgraph stops being hostile to
a host image and everything else is incremental. Then do the SWANK split, then
the `~/.cgraph` defaults, and only then cut a tagged release.

None of this has been tested by loading cgraph into a clean image. The findings
come from reading the `.asd`, the package definition and `initialize.lisp`, and
from grepping the code.
