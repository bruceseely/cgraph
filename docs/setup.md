## CGraph Setup

This describes my setup. If you use different systems, you'll need to do the translation. 
I am on MacOS, running SBCL under Emacs and Slime, optionally using Graphviz.

- Emacs - loaded from  https://emacsformacosx.com
- SBCL - loaded with `Homebrew`
- Slime - loaded with MELPA

The file **~/.sbcl** is loaded by SBCL after Lisp is setup.  The file contains the function *cgraph*() that users, still in the `cl-user` package, call to start CGraph. This function 

- is where the location of the cgraph code and an optional external directory containing types, are supplied
- loads the cgraph system definition and system, using `asdf`
- calls the *setup-cgraph*() function to load and initialize CGraph

This is my current version of the *cgraph*() function

````lisp
(defun cgraph ()
  (report-version-info)
  (let* ((repo-base (uiop:strcat (namestring (user-homedir-pathname)) "repo/"))
         (types-repo-path (uiop:strcat repo-base "cgraph-types/"))
         (code-path (uiop:strcat repo-base "cgraph/"))
         (cgraph-definition-file (uiop:strcat code-path "cgraph.asd"))
         (system-definition (asdf:find-system :cgraph nil)))
    (unless (asdf:component-loaded-p system-definition)
      (load cgraph-definition-file)
      (asdf:compile-system :cgraph)
      (asdf:load-system :cgraph))
    (start-cgraph code-path :external-types-directory types-repo-path)))
````

NOTE: The *cgraph*() function source is included here because it is not included in the cgraph repository, since the function is outside the cgraph system and used to start the system running.

The *start-cgraph*() function is in the `CGraph` code.  It ensures that `*package*` indicates the conceptual-graphs package. The package is defined in the system file, but is replicated as insurance. The :conceptual-graphs package has nicknames :cgraph and :cg. After the package is created, the function *setup-cgraph*() is called. It does the following:

- sets up some directories (see below)
- does some stuff for `Slime`
- removes detritus from the code area, resulting from debugging, like `fasl` files
- reports directory locations
- starts a web server
- runs regression tests

At that point, a REPL should open with a prompt indicating the `:cg` package.

#### directories

`*cgraph*` names `~/.cgraph/`, where per-user files go. Setup doesn't create
it, and doesn't write anything: `~/.cgraph/data/` (`*cgraph-data-directory*`,
plots from `graph-concept-types` and the web UI's Save) and `~/.cgraph/logs/`
(`*cgraph-log-directory*`, web-server logs) are created the first time
something is written there. `~/.cgraph/initializations.lisp` is read at
startup if it exists.

##### type sets

A *type set* is a directory holding `concept-types.lisp` and
`relation-types.lisp`, and optionally `lexicon-overrides.lisp` (how its types
are worded in English). cgraph reads the set's files where they are --
nothing is copied, deleted or symlinked -- and `*cgraph-types-directory*`
names the set in use. The web type editor saves into the same files.

`setup-cgraph` takes the set to use as `:types`:

- with no `:types`, the shipped `default-types/` in the cgraph source tree.
  These are **read-only**: the type editor refuses to save into them.
- `:types "kitchen"`, a name: `~/.cgraph/types/kitchen/`.
- `:types "~/repo/cgraph-types/"`, a path: any directory, such as one in its
  own git repository. `:external-types-directory` is the older spelling of
  the same argument.

To change or add types, make a set of your own. `(cg:create-type-set "kitchen")`
copies the set now loaded -- the defaults, until you choose another -- into
`~/.cgraph/types/kitchen/` and switches to it, so the type editor saves there.
It copies every file in the source set's directory except hidden ones (a set
may carry a lexicon, notes, a README), and refuses to overwrite a set that
exists. `:from` names a different set to copy; `:switch nil` copies without
switching. Next session, pass `:types "kitchen"` to `setup-cgraph`.

The web type editor does the same from the page. A save while the defaults
are loaded is refused, and a strip under the toolbar asks for a type set name
instead; *Create and save* makes the set and then makes the save that was
refused, so nothing typed is lost. *Cancel* leaves the form as it was and
reports why the save didn't happen. The page only accepts a name (letters,
digits, `-`, `_`, `.`), never a path, so sets made there always land in
`~/.cgraph/types/`.

The `(initialize-types)` function parses the current set's type files to
create type objects. `(reset-cgraph)` runs it, and evaluates the forms in
`initializations.lisp`; run it after changing the type files by hand.

##### writing the catalog back out

`(save-concept-types file)` and `(save-relation-types file)` write the *live*
catalog in the form the loader reads. Nothing calls either one: they are REPL
tools, for dumping a catalog you have modified in the image.

The contract is a round trip — what is written must load back into an equal
catalog — and the relation writer broke it in one field until 2026-08-13.
`:source-types` was written as a quoted string of a list, `"(ACT)"`, and the
reader's path for that is: not a list, so wrap it; intern `|(ACT)|`; find no
concept type of that name; fall back to `⊤`. So saving and reloading widened
**every relation's source constraint to the top type**, which is the constraint
`rel-use` and the graph editor's contextual filtering rest on. Nothing
signalled: the file looked right and the load succeeded — only the answers
changed, with every relation offered for every concept. `:dest-type` survived
the identical treatment by luck, holding one concept type rather than a list,
and a concept type printing as its own label.

`type-test4` now holds that contract, comparing all of the catalog across a
save and a load, and it loads into a catalog binding of its own so that a
broken round trip cannot damage the image running the test. Differences are
left in `*relation-roundtrip-mismatches*`, because the suite runs each test
with output going nowhere.

**Do not save over a hand-maintained catalog file.** The writer emits the live
catalog and nothing else, so anything the file carries that is not a type
definition is lost — `default-types/relation-types.text`, for one, holds
commented-out entries. Write somewhere else and diff.

### Emacs connection

CGraph was designed to be run from an Emacs REPL. This allows the definition of aids to facilitate use of the program. The relevant code is in the  `emacs` directory in the `*cgraph*` source directory.   

- file `dot-swank.lisp`
  
  Copy the file to the  directory `~/.swank`
  This file makes a modification to swank so that compiling a file during debugging
  creates its fasl file in the location that asdf uses, not the source code directory.
  
- .el files 
  The files are found in `cgraph/emacs/`

  - graphviz-dot-mode.el
    for graph-concept-types() and display-graph()

  - cg-utils.el

  - cg-mode.el
    not currently used
  - cg-indent.el
    used with cg-mode
  




### Startup sequence

- user starts Lisp with m-x slime or c-x l

- `.sbclrc` file is loaded (when SBCL starts up)

  - load libraries
  - define conceptual-graphs package
  - defines cgraph() function in user package
    - reports version info
    - uses ASDF to compile and load the cgraph system 
    - calls *cg::setup-cgraph*() in initialize.lisp
  - REPL opens with a prompt in `cl-user` package

- user calls `(cgraph)` in the REPL,  in `cl-user` package

  - *cgraph*() calls *setup-cgraph*() in the `cg` package

  - *setup-cgraph*() in `initialize.lisp` runs
    - ensure type files are available
    - load concept-types and relation-types
    - setup default package for SLIME worker thread
    - housekeeping
      - remove any fasl files from code source
      - report locations of important directories
      - run regression tests and report results
    - REPL  is in the CG package

  
