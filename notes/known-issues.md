# Known issues

Defects that are on no feature list, because they are not missing features.
Both were found on 2026-08-13/14 while building decomposition, and both are
older than that work.

## ~~`graphs-equal` does not compare graphs~~ — fixed

`system/core/graph-utils.lisp`. Three faults, stacked, and no test on the
function at all — which is how three could live there at once.

- The **list method** compared the concepts and **ignored relations
  entirely**, by `set-exclusive-or`, so `[EAT]→(agnt)→[DOG]` and
  `[EAT]→(obj)→[DOG]` were equal, and so was a graph holding a second copy of
  one of its concepts.
- The **general method** handed `(head g)` — a node — to the list method,
  which expects a list. Comparing two `graph` objects therefore filtered a
  single node and answered on the wreckage.
- `nodes-equal` on two **relations** called `relatins-equal`, which is a
  misspelling and names nothing. It could only be reached through
  `graphs-equal`, which filtered relations out before it got there.

Fixed 2026-08-14, with `test/graph-equality-test.lisp` to hold it. Also
`relations-equal` compared `(num-arcs rel1)` with itself, and `every` stops at
the shorter list, so a two-arc and a three-arc relation agreeing on their
first two arcs were equal.

The comparison now takes the concepts as given and the relations **induced**
by them — every endpoint among those concepts. Not by walking the arcs, which
was the first attempt and reaches too far: the result of
`combine-conceptual-graph-lists` is still attached to the graphs it was built
from, so a walk collected six concepts where the answer had four. The list is
the claim about what the graph is; the arcs say how those concepts are joined.

What it still is **not** is an isomorphism test: two graphs whose concepts and
relations agree one for one can differ in which of two identical-looking
concepts a relation attaches to. Telling those apart needs a search, and
`project` is the function that searches. For "do these two graphs say the same
thing", mutual projection is the CG notion and is what `decomposition-test`
uses.

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
