# Release issues: making cgraph usable by other people

The project already has more than most hobby projects: an MIT license, a real
README, a tutorial, a long `API.md`, CI and a large test suite. What stands
between it and outside users is mostly packaging. Today it behaves like a
personal environment, not a library you can load into someone else's Lisp
image.

Items are in priority order.

## 1. Blockers: it misbehaves in someone else's image

- **Nothing is exported.** `:conceptual-graphs` has no `:export` clause, so the
  README's own examples (`cg:make-cgraph`, `cg:project`, `cg:subtype-p`) fail
  with "symbol not external"; only `cg::` works. A curated export list of about
  40–80 symbols, matched to `API.md`, would turn ~1,000 internal definitions
  into an API.
- **Loading it unlocks `COMMON-LISP` for the whole image** (`cgraph.asd:16`),
  and redefinition warnings are muffled. A library can't do that to its host.
  Use `(:shadow #:set #:type #:conjugate …)` in the `defpackage`, then remove the
  unlock and the `disable-package-locks` declaims in `set.lisp`,
  `individual.lisp` and `conformity.lisp`. This also removes the
  silent-shadowing hazard of a `defun` quietly replacing a `cl:` function.
- **The package uses `#:cl-user`** (`cgraph.asd:5`), which imports whatever
  happens to be in the user's `CL-USER`. Use only `#:cl` and `#:uiop`.
- **SWANK is a hard dependency** (`:depends-on (:swank)`). `initialize.lisp`
  calls `swank::eval-in-emacs` at setup and patches SWANK internals, and
  `web/api.lisp` uses it too. Move this into an optional `cgraph/emacs` system
  so the core loads under `sbcl --script`, Sly, or no editor at all.
  (`concept-type-graph.lisp` already guards its use with `#+swank`.)
- **Setup writes to `~/.cgraph` and rewrites symlinks there**, and a test run
  has already destroyed type files this way. A new user's first `setup-cgraph`
  shouldn't touch their home directory. By default, load the shipped
  `default-types/` read-only from the system directory, write only to a
  directory the user configures, and never create symlinks.

## 2. Portability

- **SBCL-specific code is small**: 8 references. Four are the package-lock
  handling above; the rest are `sb-mop` calls in `conformity.lisp`, which
  `closer-mop` replaces. After those two fixes the code may run on CCL/ECL.
  If not, state "SBCL only" plainly.
- **No Quicklisp install path.** Getting into the Quicklisp dist, or at least
  Ultralisp, is how CL users find and try libraries.

## 3. Global state and the API

- **One global everything.** The type hierarchy, context and name registry
  are all specials (`*concept-type-top*` etc.), and `make-top-concept-type`
  makes fresh instances, which leaves stale references behind. Two knowledge
  bases can't coexist in one image. A `with-cgraph-environment` macro that
  binds the specials would help; `system/operations/cg-env.lisp` may be most
  of the way there.
- **Startup takes ceremony.** Users must know the order `setup-cgraph` →
  `reset-cgraph` → `initialize-cgraph`, and `start-cgraph` also starts a web
  server. Provide one documented entry point, e.g.
  `(cg:init &key types-directory)`, with sensible defaults.
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
- `cgraph/emacs`

## 5. Tests and CI

- **Tests run only in a live image** via `(cg:test-all t)`. Hook them into
  `asdf:test-system`, using FiveAM, Parachute, or a thin adapter over the
  existing suite.
- **CI runs only the whole stack** (parsifal + cg-from-parse), and still
  passes `secrets.STACK_CHECKOUT_TOKEN` even though the workflow's own comment
  says no token is needed. Add a standalone job that runs only cgraph's tests on
  a clean SBCL, so contributors' PRs don't depend on other repos or secrets.

## 6. Documentation for strangers

- **Open the README with one runnable copy-paste session** that works on a
  fresh machine with Quicklisp. Emacs and SLIME are listed under Requirements,
  which will put off non-Emacs users; mark them optional.
- **Add a "what this is not, and how it compares" paragraph** covering
  CoGITaNT, Amine, and CGIF / ISO 24707 Common Logic. CG people will ask about
  interchange formats immediately; CGIF import/export would be the most
  valuable single feature for adoption.
- **Separate user docs from design journals.** `notes/` mixes them. Move the
  user-facing pieces (tutorial, setup, individuals) into `docs/` and leave the
  journals in `notes/`.
- **Fix the `.asd` description typo** ("comceptual", `cgraph.asd:24`) and bump
  `:version` past `0.0.1` when you tag a release.
