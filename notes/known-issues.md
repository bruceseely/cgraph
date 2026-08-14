# Known issues

Defects that are on no feature list, because they are not missing features.
Both were found on 2026-08-13/14 while building decomposition, and both are
older than that work.

## `graphs-equal` does not compare graphs

`system/core/graph-utils.lisp:819`. Two faults, one on top of the other:

- The **list method** compares concept labels and **ignores relations
  entirely**. Two graphs with the same concepts wired up completely
  differently are equal to it.
- The **general method** does `(typecase g1 (graph (head g1)))` and passes
  that *node* to the list method, which expects a list. So calling it on two
  `graph` objects filters a node with `remove-if-not` and answers on nonsense.

It is not much used, which is presumably how it survived. When decomposition
needed "is this rejoined graph the same as the original", the answer was to
avoid it: **mutual projection** (each graph projects into the other) is both
correct and the right notion, since a rejoin may legitimately return a
different head, a different arc order and different variable names.
`graphs-equivalent-p` in `test/decomposition-test.lisp` is those two lines.

Fixing it properly means deciding what it is *for* — isomorphism, or
equivalence up to relabelling — and then either fixing it or deleting it in
favour of projection. Nothing currently depends on the answer.

## Individual ids are global, and the editor fixtures claim low ones

Ids come from one counter for the whole image, so **any test that mints an
individual shifts every id allocated after it**. The editor suite hard-codes
low ids for its own fixtures (`#7` is Felix, and there are others), so:

    (test-cgraph)    ; passes
    (generation-test); passes, mints individuals
    (editor-test)    ; FAILS -- "Referent #7 is already named ..."

`editor-test` passes alone and fails after either of the others. Confirmed in
a clean worktree at a commit before any of the decomposition work, so it is
pre-existing rather than introduced by it.

The workaround in place is that `decomposition-test` gives its individuals
explicit ids in the 500s, out of the way. That protects the suites from *that*
test; it does not fix the fragility, and the next test to mint an individual
will meet it again.

A real fix is either fixtures that do not hard-code ids, or a per-suite reset
of the counter. The second is easier and probably right: tests that assert on
`#7` are asserting on something no test should own.
