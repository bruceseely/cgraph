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

## ~~Individual ids are global, and the editor fixtures claim low ones~~ — fixed

Ids come from one counter for the whole image, so **any test that mints an
individual shifts every id allocated after it**. Several suites name
individuals by id — `#7` is Felix in the editor tests, `#91`–`#95` are various
dogs — so a suite that ran first and minted anything took the ids the next
one's fixtures claimed:

    (generation-test) ; passes, mints individuals
    (editor-test)     ; FAILED -- "Referent #7 is already named ..."

`editor-test` passed alone and failed after either of the others. Confirmed in
a clean worktree to predate the decomposition work.

Fixed 2026-08-14 by resetting the registry rather than by renumbering the
fixtures, which is the same courtesy `generation-test` had always paid itself
by way of `reset-cgraph`:

- `editor-test` calls `initialize-individuals` before it runs;
- `test-one` calls it before **each** test in `test-cgraph`, so the suite no
  longer passes merely because of the order it happens to be written in.

Checked over all seven orderings of the three suites, and by running
`test-cgraph`'s tests in reverse. `decomposition-test` still keeps its
individuals in the 500s; that is now belt and braces rather than the only
thing holding it together.

The underlying design is unchanged and still a little sharp: a test *can*
still assert on a specific id, and will get away with it only because nothing
runs before it in its own suite. Fixtures that captured the id they were given
rather than naming one would need no protection at all.
