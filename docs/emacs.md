# Emacs

CGraph runs without Emacs. With Emacs and SLIME, the files in `emacs/` add
editing aids for CG linear notation. They talk to the running Lisp through
SLIME, so most of them need a connected REPL with cgraph loaded.

**Status:** these files are written for the author's own Emacs setup.
`cg-utils.el` does `(require 'clopt)`, a Customize-to-Lisp option sync that is
not yet part of this repository, so loading it elsewhere fails at that line.
Until that is fixed, the other files can be loaded on their own.

## Files

| File | What it is |
|------|------------|
| `cg-utils.el` | the commands and keybindings below, and Customize options (`M-x customize-group RET cgraph`) mirrored from the Lisp side |
| `cg-mode.el` | a major mode for CG notation: highlighting, indentation, bracket matching |
| `cg-indent.el` | indentation and graph formatting, used by `cg-mode` |
| `graphviz-dot-mode.el` | a mode for the `.dot` files that `graph-concept-types` and `display-graph` write |
| `dot-swank.lisp` | copy to `~/.swank.lisp`: makes SLIME's compile commands put fasls where ASDF does, not beside the source |

Load them from your Emacs init, for example:

```elisp
(load "~/quicklisp/local-projects/cgraph/emacs/cg-mode.el")
(load "~/quicklisp/local-projects/cgraph/emacs/cg-indent.el")
(load "~/quicklisp/local-projects/cgraph/emacs/cg-utils.el")
```

## Keys

These bindings are global.

| Key | Command |
|-----|---------|
| `C-c t` | insert the top type, ⊤ |
| `C-c b` | insert the bottom type, ⊥ |
| `C-c ?` | describe the concept or relation type at point: supertypes, subtypes, definition, canonical graph |
| `C-M-'` | normalize the graph at point: upcase concept types, downcase relation types |
| `C-M-z` | format a graph packed on one line: normalize, split and indent |
| `C-<return>` | new line, indented as CG notation |

`cg-mode` also binds `C-M-q` to format the graph at point.

With `abbrev-mode` on, typing `<-` or `->` followed by a space or punctuation
turns it into `←` or `→`.
