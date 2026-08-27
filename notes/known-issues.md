# Known issues

Defects that are on no feature list, because they are not missing features.
New ones belong here; fixed ones stay, struck through, because what a thing
was wrong about is worth as much as the fix.

The first two entries were found on 2026-08-13/14 while building decomposition,
were older than that work, and were fixed on 2026-08-14. The third was found on
2026-08-16 and fixed the same day. The fourth was found on 2026-08-25 while
building the relation join semantics and fixed the same day. The fifth was
found on 2026-08-27 while building the canonical-graph guidance and is
**outstanding** -- it is a limit of where the check stands, not a defect in
what it does.

## ~~`individuals-equal` ignores the id, so `simplify` can delete an assertion~~ — fixed

`system/core/individual.lisp:115`. Found on 2026-08-25 while building the
relation join semantics, and older than that work by a long way — it has
nothing to do with relation types and reproduces with a single relation type.

    (defmethod individuals-equal ((ind1 individual) (ind2 individual))
      (and
       (types-equal (individual-type ind1) (individual-type ind2))
       (properties-equal (properties ind1) (properties ind2))))

**No `id`.** Two genuinely different individuals of the same type carrying no
properties are therefore equal. `same-individual-p`, eleven lines below it,
does compare the id — so the correct predicate exists and this is not it.

The damage travels: `individuals-equal` → `referents-equal` → `objects-equal`
→ `relations-equivalent-p` → `simplify`, which removes what it takes to be a
duplicate relation. So

    [PERSON: #603]- (loc)→[CITY: #604] (loc)→[CITY: #605]

simplifies to `[PERSON: #603]→(loc)→[CITY: #604]`, and the claim that the
person is also at #605 is **gone**. Not reordered or merged — deleted. Simplify
is supposed to remove only what the rest of the graph already says.

Named individuals are safe, which is why nothing has tripped over it: a name
lives in `properties`, so `properties-equal` separates `[CITY: Annapolis]`
from `[CITY: Baltimore]`. It is bare `#nnn` referents that collide, and those
are mostly written by tests.

Fixed 2026-08-25, and the pass it was going to need turned out not to be
needed. The worry above was that some of the eight call sites might want the
loose "same kind of thing" reading — `conformity.lisp:46` in particular. Read
one at a time, **every one of them says "same individual" in its own comment**
and wants identity: `retrieve-concepts-having-individual`, `remove-from-set`,
`referents-joinable-p`, and the `objects-equal` dispatch. The loose reading is
already provided separately, under its own name, at the one site that wants it
— `individuals-compatible-p` (`graph-combination.lisp:356`), type plus
compatible properties and no id, sitting on the line directly below the
`individuals-equal` call it is the alternative to.

So `individuals-equal` now delegates to `same-individual-p` rather than
repeating its clauses, which is what stops the two drifting apart again. The
whole suite passed unchanged — nothing depended on the loose behaviour.

`individual-identity-test` holds it (in `test/individual-test.lisp`). Checked
that it is load-bearing by reverting the method and re-running: two of its
seven checks fail, the predicate one and the `simplify` one, while the other
five — reflexivity, a true duplicate still collapsing, named individuals
unaffected — pass either way and are there to catch a fix that goes too far.

`test/relation-join-test.lisp` still uses named cities throughout, and its
comment now records why that mattered rather than why it is required.

## ~~A concept-type click with no focus corrupts a non-empty graph~~ — fixed

`system/editor/operations.lisp`, `editor/editor.js`. Found while building the
create-a-type-from-the-editor affordance, which lives in the column where it
happens; it is older than that work and reachable from `(edit-cgraph "[EAT]")`
as easily as from anything new.

`EDITOR-ADD-CONCEPT` exists to give an EMPTY graph its first node, and says so.
Its `COND` installed the concept when the working graph was missing or headless
and otherwise **fell through and returned it anyway** — unattached, because
there was nothing to attach it to. The page then set its focus to that
`NODE-REF`, and every request afterwards answered `no node N in this graph`.

Unclearable, in the specific sense the editor already has a name for: the error
was true again each time anything was tried, so the status line could not be
cleared by any action, and only a reload recovered. The graph itself was never
damaged — the concept simply went nowhere — so nothing looked wrong except that
the editor had stopped working.

The trigger is ordinary: a session loads with a graph and no focus (focus is set
by clicking a concept **in the graph**), and the first thing clicked is a
concept type in the list rather than a concept in the graph. Both are lists of
type names a few centimetres apart.

Fixed on both sides. `EDITOR-ADD-CONCEPT` now signals rather than returning a
concept with nowhere to go, and the page checks whether the graph pane is
showing anything before asking — so the usual case is a sentence naming the
click that was wanted, not a round trip to be refused.

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


## Canonical conformance does not see a shared far end

Found 2026-08-27 while building the canonical-graph guidance in the editor.
Outstanding, and probably should stay that way.

The guidance pane judges each arc of the focus against the canonical graphs
bearing on the focus's type. That judgement is **local to one focus**, and a
concept node can be the far end of arcs from more than one of them:

    [INFORM]-(obj)→[X]
    [GIVE]  -(obj)→[X]      ← the same node

X has to answer to INFORM's `(obj)→[INFORMATION]` and to GIVE's
`(obj)→[ENTITY]` at once. Focus the INFORM and the pane judges X against
INFORMATION alone; focus the GIVE and it judges the same node against ENTITY
alone. Neither view is wrong and neither is the whole constraint, so a node can
pass both inspections it is ever given and still satisfy no single type.

Note this is **coreference, not inheritance**. The multiple-inheritance case --
a type reaching two ancestors that both carry a canonical graph -- IS handled:
`canonical-arc-conformance` takes the conjunction across graphs, and
`narrow-to-subtypes` intersects across groups. The gap here is one node in two
graphs, not one type with two parents.

The arithmetic is the same in both, and it is the meet:
`maximal-common-subtype` (types.lisp) is what c1ed76b already argued concepts
need -- *"a concept carries exactly one type, so joining [MAN: Dave] with
[DOCTOR: Dave] must find a single type meaning both"*. Two constraints on one
node want the same answer.

Why it is not simply fixed:

- **The check would have to leave the focus.** Everything in the pane is about
  the focus and its arcs. Judging a shared node means walking to every relation
  it touches, from every concept that reaches it, which is a different question
  than the pane is built to ask and would report problems about arcs not on
  screen.
- **The intersection can be empty.** `maximal-common-subtype(information, act)`
  is NIL -- incomparable branches have no common subtype. That is a real and
  useful finding, but it means a node can be in a state that no type satisfies,
  so a checker that *refused* edits could reach a position with no legal move.
  It is the last argument against ever making canonical conformance an
  enforcement rather than a report.

So the present behaviour -- report per focus, refuse nothing -- is sound as far
as it goes, and the honest statement of the limit is that a green pane means
"conforms as seen from here", not "conforms".
