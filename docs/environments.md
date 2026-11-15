# Environments: more than one knowledge base

Everything cgraph knows lives in an **environment**: the concept and relation
type catalogs, the type set they came from, the individuals, the nodes, the
lexicon that says how the types are worded, and a root context holding the
graphs. `cg:*environment*` is the current one. A session that never mentions
environments uses the one cgraph starts with, and nothing changes for it.

To hold two knowledge bases at once, make a second environment and work
inside it:

```lisp
(defvar *kb-1* (cg:make-environment :types :default))   ; the shipped types
(defvar *kb-2* (cg:make-environment :types :default))   ; a second copy

(cg:with-environment (*kb-1*)
  (cg:make-cgraph "[PERSON: Sue]<-(agnt)<-[DRIVE]->(obj)->[CAR]."))

(cg:with-environment (*kb-2*)
  (cg:graphs cg:*context*))   ; => NIL -- Sue's drive is in *KB-1*'s context
```

`make-environment :types` takes a type set the way `cg:init` does: a name
for `~/.cgraph/types/NAME/`, a directory, or `:default`. It loads the types
and the lexicon that goes with them, and gives the environment an empty root
context. With no `:types` the environment is empty; load it later with
`(cg:load-environment env types)`.

`with-environment` binds `*environment*`, and `*context*` to that
environment's root context, for the extent of its body, in that thread only.

## What is shared and what isn't

**Per environment:** types, the current type-set directory (so reloading or
saving from the type browser touches that environment's files), individuals,
nodes and node refs, coreference labels and variables, the lexicon and
relation syntax registrations, and the root context.

**Shared by the whole image:** settings that say how cgraph behaves rather
than what it knows -- `*concise*`, `*debug-mode*` and the like -- and the
directories under `~/.cgraph/`. `make-environment` doesn't read
`~/.cgraph/initializations.lisp`, because what's in it is shared.

**Don't mix graphs across environments.** A graph holds the type objects of
the environment it was made in. Each environment has its own `ENTITY`, and
the two aren't `eq`. Joining, projecting or comparing a graph from one
environment with a graph from another gives wrong answers, not an error.

## The web server

`cg:start-web-server` serves the environment current where it's called, or
the one given as `:environment`. Every request runs in it, whatever the REPL
has bound since. A graph-editor session runs in the environment, and the
context, of the code that opened it: `(cg:edit-cgraph g)` inside
`with-environment` edits in that environment.

## The old variable names

`*concept-type-catalog*`, `*individuals*`, `*cgraph-types-directory*`,
`*lexicon-overrides*` and the rest still work: each is now a symbol macro
for a slot of the current environment. Reading one, `setf`ing it or
`clrhash`ing it acts on the current environment. Three things behave
differently:

- **`let` doesn't rebind them.** `(let ((*cgraph-types-directory* dir)) ...)`
  makes a lexical variable the functions called inside never see. Use
  `with-environment` to switch environments. To change one slot for a while,
  use `cg:env-let`: it sets the slot, runs the body, and puts the old value
  back however the body exits, with any other bindings `let`-bound as usual.
  `env-let` changes the environment itself, not a per-thread binding, so a
  web request served meanwhile sees the temporary value.
- **`boundp` and `symbol-value` mean nothing** for these names. They ask
  about a global value the symbol never has. Test what you need directly,
  for example `(ignore-errors cg:*concept-type-top*)`.
- **A running image that loaded an older cgraph can't take the new one.**
  SBCL refuses to turn an existing special variable into a symbol macro.
  Restart Lisp after updating.

`*context*` is the exception: it is still a real special variable, because
binding it to a child context is normal. Replace the root context with
`cg:reset-cgraph`, not `(setf *context* ...)`. Otherwise the environment, and
the web server, go on using the old one.
