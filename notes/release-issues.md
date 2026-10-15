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
- **The package uses `#:cl-user`** (`cgraph.asd:5`), which imports whatever
  happens to be in the user's `CL-USER`. Use only `#:cl` and `#:uiop`.
- **SWANK is a hard dependency** (`:depends-on (:swank)`). `initialize.lisp`
  calls `swank::eval-in-emacs` at setup and patches SWANK internals, and
  `web/api.lisp` uses it too. Move this into an optional `cgraph/emacs` system
  so the core loads under `sbcl --script`, Sly, or no editor at all.
  (`concept-type-graph.lisp` already guards its use with `#+swank`.)
- **`setup-cgraph` deletes files under its `code-base` argument**, recursively:
  every `*.fasl`, `*.lisp~` and `*.lisp#` (`cleanup-files`, `initialize.lisp`).
  Passed the cgraph source directory, as the README says, that is harmless;
  passed `"~/"` it would delete every fasl in the user's home tree. A setup
  function shouldn't delete anything. Drop the cleanup, or move it to a
  developer-only function.
- **Setup writes to `~/.cgraph` and rewrites symlinks there**, and a test run
  has already destroyed type files this way. A new user's first `setup-cgraph`
  shouldn't touch their home directory. By default, load the shipped
  `default-types/` read-only from the system directory, write only to a
  directory the user configures, and never create symlinks.

## 2. Portability

- **SBCL-specific code is small**: now that the package-lock handling is gone,
  only four `sb-mop` calls in `conformity.lisp` remain, and `closer-mop`
  replaces them. After that the code may run on CCL/ECL.
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
- **`test-all` passes only in the runner's environment.** After an ordinary
  `setup-cgraph` + `reset-cgraph`, 7 suites fail with `*package*` = `:cg`
  (referent, concept, parse, projection, graph-every, graph-equality,
  decomposition) and 9 from `CL-USER`. This predates the 2026-10-14 changes.
  `test/run-tests.sh` reproduces the runner's setup (a throwaway types
  directory, `*package*` = `:cg`) and passes; the README points there.
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
- ~~**README and `API.md` examples didn't run.**~~ Fixed 2026-10-14: every
  example now runs as written from a fresh setup. The README's graphs had
  their `agnt` arrows backwards; both files used `BONE`, `WALK` and `PET`,
  which `default-types/` doesn't define; `API.md` documented `add-graph` and
  `fcg` (which don't exist), and `query`'s keyword as `:all-solutions`
  (it's `:first-only`).
- **`default-types/` has loose ends**: the relation types refer to `TIME` and
  `NUMBER`, which the concept types don't define, so a fresh setup prints
  undefined-type warnings; and `poss` and `rcpt` are each defined twice.
- **`parse-cgraph` discards the real cause of a parse failure**: it reports
  "Unable to parse token after: " plus whatever parsed before the failure,
  which is empty when the first concept fails.
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
