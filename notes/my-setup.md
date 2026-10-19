# My setup

How cgraph is started on my machine. This is a note about one setup, not
user documentation -- users start with `(cg:init)`; see `docs/setup.md`.

macOS, SBCL from Homebrew, Emacs from emacsformacosx.com, SLIME from ELPA,
Graphviz optional.

## The launcher

`~/.sbclrc` (kept in `~/repo/emacs-init/dot-sbclrc`) defines `(cgraph)` in
`CL-USER`. It is outside the repository because it is what starts the system:

```lisp
(defun cgraph ()
  (ensure-swank-not-reloaded)
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
```

## Startup sequence

- `M-x slime` (or `C-x l`) starts SBCL, which loads `~/.sbclrc`; the REPL
  opens in `CL-USER`.
- `(cgraph)` loads the system with ASDF and calls `start-cgraph`
  (`system/setup/initialize.lisp`, in `CL-USER`), which:
  - switches `*package*` to `:cg`;
  - calls `(cg:init :types "~/repo/cgraph-types/" :web 8060)`;
  - loads the Emacs side through SLIME: `init-cgraph.el` from emacs-init, which
    loads the files in `emacs/`, then `cgraph-filesets.el`, then syncs the
    Customize options from Lisp;
  - prints the directories (`report-directories`);
  - runs the lexicon lint, if `*run-lexicon-lint-on-startup*`;
  - loads `cgraph/tests`, and runs them if `*run-tests-on-startup*`.
