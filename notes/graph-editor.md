# Conceptual-Graph Editor — Design

**Status:** built and working. Driven end to end in a browser on 2026-08-01
against the live catalog: focus, contextual filtering in both columns, add,
the removal cascade, the reverse control, and automatic coreference all behave
as described below. The non-graph referent editor is built through stage 3 —
identity, modifiers and sets — and so is the descent into a graph referent.
What is left is stage 4, which is a decision rather than a feature, and two
loose ends the set work left behind — see "Open".

A web-page editor for conceptual graphs, separate from the concept-type
browser. Where the type browser edits the *lattice*, this edits *graphs*.

The guiding constraint, stated first because it shapes everything else: **the
editor must be able to call itself.** A concept of type PROPOSITION, BELIEF,
SITUATION, … has a graph as its referent, so editing that referent opens
another editor, to arbitrary depth.

The second guiding constraint: **the user should never have to remember
syntax.** Not whether commas separate individuals in a set, not which way an
arrow points. Everything is picked, nothing is typed as CG notation.

---

## Frame

```
┌─ English pane ────────────────────────────────────────────────┐
│ An old dog eats food.                                         │
└───────────────────────────────────────────────────────────────┘
┌─ LEFT ──────────────────────────┬─ RIGHT ─────────────────────┐
│ ┌─ graph pane ────────────────┐ │ concept-types │ relation-   │
│ │ linear display of the graph │ │               │ types       │
│ │ being built; concepts are   │ │ [filter…]     │ [filter…]   │
│ │ click-selectable            │ │               │             │
│ └─────────────────────────────┘ │ ANIMAL        │ (agnt)→     │
│ ┌─ editor pane ───────────────┐ │  DOG          │ ←(agnt)     │
│ │ ⟨[EAT]⟩ →(agnt)→ ⟨[DOG]⟩    │ │  CAT          │ (obj)→      │
│ │  ▲focus   └─ to add ─┘      │ │ EAT           │ (loc)→      │
│ │  [Add] [Remove] [UPDATE]    │ │               │             │
│ └─────────────────────────────┘ │ both lists filtered and     │
│ ┌─ referent pane (on demand) ─┐ │ sorted by context           │
│ │ IDENTITY  — ?x name #n      │ │                             │
│ │ MODIFIERS quant tense …     │ │                             │
│ │ CARRIED   collar: red       │ │                             │
│ └─────────────────────────────┘ │                             │
│ ┌─ display pane (read-only) ──┐ │                             │
│ │ →(agnt)→[DOG]             ✕ │ │                             │
│ │ ←(obj)←[CAKE]             ✕ │ │ two columns for now; may    │
│ │ →(loc)→[KITCHEN]          ✕ │ │ collapse to one later       │
│ └─────────────────────────────┘ │                             │
└─────────────────────────────────┴─────────────────────────────┘
```

- **Graph pane** — the graph as linear notation, reformatted after every edit.
  Concepts are click-selectable. Relations are **not** (see "Relation clicks").
- **Editor pane** — three undelineated fields holding a concept, a relation,
  and a concept, with **arrows drawn between them showing the arc's
  direction**. The leftmost field is the **focus**: the concept being added to
  or removed from. The other two are the arc to attach. Both arrows point the
  same way, as in linear form, so the pane is a literal preview of what Add
  will produce.
- **Display pane** — read-only. The focus's neighbourhood, one relation–concept
  pair per line, in the shape linear notation uses, **with direction shown** —
  inbound and outbound arcs of the focus must not look alike. Each line carries
  an ✕.
- **English pane** — read-only. `GRAPH-TO-TEXT` on the working graph. Full
  width and above the frame, because the sentence is about the whole graph
  rather than about the focus, so it belongs to neither column.
- **Referent pane** — one concept's referent, opened by clicking the referent
  zone of a concept slot and closed again by hand. Hidden otherwise: it is
  about ONE concept, so leaving it up while the focus moves elsewhere would be
  showing a field that is no longer the one you are looking at.

### The English pane is refreshed by edits, not by clicks

`/api/editor/text` is asked only when the graph can actually have changed —
the add, the arc removal, the first concept, and the initial load — and
deliberately *not* from `refresh()`, which runs after every click, including
the many that only fill the editor pane. Generation is by far the most
expensive thing the editor asks the server for, and the sentence cannot have
moved for a click that did not touch the graph. Because every mutation is
covered, the pane is never stale, so it needs no staleness marker and no
manual refresh control.

It is its own endpoint rather than another field on the graph responses, for
the same reason: a field would be computed on the focus refresh too. And
generation is a much larger surface than the rest of the editor — lexicon,
morphology, the whole realizer — so an arc the tables do not cover is a
perfectly ordinary thing to be holding halfway through an edit. Keeping it
separate means a generator that signals cannot take an otherwise successful
add down with it. Failures are reported **in the pane**, never in the status
line: a sentence that cannot yet be produced must not look like a failed edit.
The pane distinguishes its two silences — a graph with nothing to generate
from, and a graph the generator cannot realize.

## The edit primitive is one arc

Every edit is "attach this arc to the focus" or "remove this arc." There is no
free-floating canvas state. The focus concept is the cursor; moving it is
navigation.

## Click semantics

Where you click determines what the concept *means* — this is what makes
shared concepts unambiguous without extra UI.

| Click target | Edit-pane state | Effect |
|---|---|---|
| concept in graph pane | focus empty | becomes the focus |
| concept in graph pane | focus occupied | becomes the target — an arc to an **existing** node |
| concept type in right column | either | creates a **new** concept |

Clicking in the graph *references*; clicking in the type list *creates*.

### Relation clicks

Clicking a relation in the graph pane is **not permitted**. A relation instance
can't be shared between two arcs, so the click can't mean what a concept click
means, and it can't express which direction was intended. Nothing else needs
it: removal lives on the display pane's ✕ buttons.

The symmetric-direction problem is handled in the editor pane instead, where
both concept types are known — see "Reverse button".

## Type-list filtering

Filtering is computed from the lattice, not heuristic.

| Populated | Relation list shows | Concept list shows |
|---|---|---|
| focus only | relations consistent with focus, either side | unconstrained |
| focus + target | relations consistent with both, **both directions** | — |
| focus + relation | — | concept types consistent with that pairing |

`rel-use` (`types.lisp:1136`) covers the focus+target case directly — call it
twice with the arguments swapped and keep the results **direction-labelled**,
so the list can offer `(agnt)→` and `←(agnt)` as separate rows. Two further
queries sit beside it, both straightforward against the `source-types` /
`dest-type` slots:

- `rel-uses-for` — relations consistent with a single concept type, either side
- `rel-far-end-types` — concept types consistent with a given relation and a
  fixed other end

with `rel-uses-between` for the pair. The first two return
`(relation-type . direction)` with direction relative to the **focus**, which
is what lets a relation legal both ways appear twice and be marked as such.

### The relation list is grouped by direction

Not one alphabetical list with the arrows interleaved. Two groups — focus as
source first, then focus as destination — alphabetical within each, with the
break between them labelled.

Direction is not a property of the relation; it is half of what you are
choosing. So it groups rather than decorates, and the two groups ask two
questions in the order you would ask them: what can the focus do, then what can
be done to it.

It also separates the twins. A relation legal both ways otherwise renders as
two near-identical adjacent rows —

```
← poss  possession
→ poss  possession
```

— which reads like a rendering fault, and is exactly the pair easiest to
mis-pick. It is the pair behind the `[DOG]←(poss)←[FOOD]` case below.

The asymmetric case becomes legible for free. With `[DOG]` focused and `[FOOD]`
targeted, `poss` appears under one heading and is simply **absent** from the
other, so "only one direction is available here" is a missing row rather than
something you infer from an absent twin in a mixed list.

Details that follow from the above:

- **Headings name the focus** — `FROM [DOG]` / `INTO [DOG]` — not "source" and
  "destination", which is the code's vocabulary rather than the user's.
- **Sticky**, so scrolling into a group keeps the label saying which one you
  are in. A focus alone can offer thirty-odd relations.
- **A group with nothing in it gets no heading**, so the headings never claim a
  choice that isn't there.
- **The per-row arrow stays** even though the heading implies it: it is the
  same glyph the editor pane will show, and it survives scrolling.

The cost, stated because it is real: whole-list alphabetical scanning is gone.
Knowing you want `poss` no longer tells you where to look without also knowing
the direction. Judged acceptable, since you must choose a direction anyway —
the group is information you needed regardless.

### Type-in filters

Each column has a text field that further narrows the *already constrained*
list by prefix. It filters; it never accepts CG syntax.

For relations, match the label **or** the long name, which is already the
leading token of the `:desc` slot by convention:

```
agnt  → "agent - links [ACT] to [ANIMATE]…"
chrc  → "characteristic"
```

Take `desc` up to the first `-` (or all of it when there's no dash). No new
slot needed. The convention isn't enforced, so a lint check could be added
later.

### Reversing direction — the arrows are the control

There is no separate reverse button. The arrows drawn in the editor pane *are*
the control: click either one to flip the pair.

They are clickable **whenever the opposite direction is legal** — which the two
`rel-use` calls already tell you, since a relation offered both ways appears
twice. So the affordance carries the information: static arrows mean there is
no choice to make, and there is no disabled control to explain. It also cannot
produce an invalid arc.

The test is "the opposite direction is legal", **not** "both directions are" —
the two differ in exactly the case where the control matters most, an arc
pointing the one way the lattice forbids. Under the stricter test the arrows
froze precisely there. That in turn means the pane must carry the legal
*directions* for the current pair, not a symmetric-or-not boolean; a boolean
cannot distinguish "only this way" from "only the other way."

### The pane never holds an illegal arc

The filtering table above assumes you fill the pane left to right, each step
narrowing the next list. A target picked by **clicking the graph** is not drawn
from a narrowed list at all — that click means "this existing node" — so it can
name one for which the relation already sitting in the pane runs the wrong way.

This is easy to walk into, not exotic. With `[DOG]` as the focus and nothing
else, `rel-uses-for` offers `(poss)` **both ways**: a dog is animate, so it can
possess, and also an entity, so it can be possessed. Picking `←(poss)` is
legitimate against the list shown. Choosing `[FOOD]` is what makes it illegal,
and food is not animate. Nothing noticed until the server refused the Add.

So the rule is **reconcile after every pane change**, rather than guard the one
click that happens to bypass a list:

| Legal directions for what the pane holds | Result |
|---|---|
| current one is legal | nothing happens |
| only the opposite | flip the arc, and say so |
| neither | drop the relation, keep focus and target, say so |

Flipping rather than refusing, because the arc you asked for does exist — it
just runs the other way, and the editor knowing which way is the whole point of
picking instead of typing.

The same reconciliation covers a target that is a **concept type not yet in the
graph**. The pair query cannot see a node that does not exist, so the far-end
set answers instead — one question per direction.

Two consequences worth stating, because the rest of the design leans on them:

- The server's own legality check stays as the backstop, not the interlock. It
  is right to refuse an illegal arc; it is just too late to be the only thing
  that does.
- **A message must never outlive the action that produced it.** A failed Add
  once left its error on screen through every later click, including Clear —
  which made a pane that *had* been emptied look stuck, turning a recoverable
  mistake into a dead end. Clearing the status on every refresh is what makes
  the correcting messages above readable as feedback rather than as wreckage.

## Concepts have two click zones

A concept is a type *and* a referent. Neither is edited as free text.

| Zone | Click opens |
|---|---|
| type | arms the concept-type list for a one-shot pick |
| referent | the referent editor, or a nested graph editor |

The "arm the list for one pick" pattern already exists in the type editor —
`#nt-add-super` (`graph.js:800`) arms a one-shot supertype pick so ordinary
clicks keep exploring the graph. Reuse it.

### Referent editors

Two kinds, one contract:

- **Referent is a graph** (PROPOSITION, BELIEF, SITUATION, …) → a nested
  **graph editor**. Which types qualify is already known: `graph-compatible-p`
  on `concept-type`.
- **Referent is not a graph** → a **referent editor**, designed below.

Both open, edit, and finish with UPDATE or CANCEL, returning a referent. The
recursion falls out of that uniformity rather than being special-cased.

Both are now built; this section is the design, and the subsections that follow
record where building it disagreed with the design.

The non-graph referent editor needs real support, because referents get
complex — individuals, sets, quantifiers, measures. For a set it should offer
the available individuals to choose from and format the referent itself. The
user picks members; the editor decides where the commas go.

#### What a referent is made of

Every form is catalogued in `notes/referent-catalog.md`, with verified
`reader.lisp` citations. That is the reference; this is the shape.

The keys `resolve-target-concept` pulls out divide in two, and the division is
what the UI should be built on:

- **Identity** — `:id :name :variable :coref :set`. Mutually exclusive: one
  selector with five states, plus empty for a generic concept. A concept has
  exactly one identity.
- **Modifiers** — `:quantifier :tense :aspect :voice :measure`. These compose
  freely, with each other and with any identity.

So the panel is *one exclusive control plus orthogonal ones* — not a mode
picker, which is what the list of forms first suggests.

Anything `resolve-target-concept` does not recognise becomes an arbitrary
individual property. That tail is unbounded, so no purely structured editor
can express everything the reader accepts.

#### Build it in stages, but not UI first

The tail, and the staging, are the same problem: at any moment the editor
understands less than the reader does. A stage-1 editor that knows only
identity will still be *opened* on `[EAT: *e @past-progressive @passive]` — and
if it re-emits only what it understands, pressing UPDATE silently drops the
tense, aspect and voice. Every stage is a data-loss risk until that is solved,
so it is solved first, before any control exists.

**Stage 0** is a decomposition with a lossless round trip: split a concept into
**identity / modifiers / unrecognised tail**, edit only what the current stage
understands, and re-emit the rest untouched. The contract is *emitted notation
re-parses to an equal concept*. It is pure Lisp, and testable against every row
of the referent catalog with no UI at all.

That also settles the scope question the tail poses. "Complete but narrower"
versus "escape hatch" has a third answer: **complete for editing, lossless for
everything else.** A feature need not be editable to be preserved — show it,
read-only, and hand it back verbatim. The unbounded tail stops being a design
blocker and becomes a display question.

The same discipline already runs elsewhere here: `/api/edit-type` writes the
*stored* canonical text when the graph did not change, rather than the
reformatted one. Don't rewrite what you didn't edit.

| Stage | Covers | Why there | State |
|---|---|---|---|
| 0 | decompose and re-emit losslessly | makes every later stage non-destructive; needs no UI | **built** — as a decomposition plus in-place setters, not re-emission; see below |
| 1 | identity, minus sets — empty, `*`, `*x`, `?x`, `#`, `#123`, `Fido` | the exclusive spine, and most referents are identity-only | **built**, minus `*x` — see "A variable is not offered" |
| 2 | modifiers — quantifier and measure first, then tense/aspect/voice gated on the concept type | orthogonal to 1, so it cannot destabilise it | **built** — the gate is not on the concept type; see "What actually gates tense" |
| 3 | sets — `{Fido, #123, *}`, with optional `@ N` | recurses on stage 1's selector minus `:set`, so it is cheapest last | **built** — the prediction held; the reader did not, see "Sets, and the openness the reader was dropping" |
| 4 | decide the tail | by then use will have shown whether one ever needs editing | open — the pane shows the tail read-only, which may be all it ever needs |

Graph referents were expected to "plug in at stage 1 as an alternative to the
whole panel". They did, and they are **built** — see "Descending into a graph
referent".

Two things fall out rather than needing their own work. **Graph referents** plug
in at stage 1 as an alternative to the whole panel, chosen by
`graph-compatible-p` — which is what unblocks nesting. And **sets are not a
special case**: a member is just an identity, so stage 3 is mostly wiring.

Gating tense/aspect/voice on the concept type is the same show-only-real-choices
principle the arcs follow — a control that cannot produce a legal result should
not be offered.

**Stage 1 is not shippable alone.** Identity-only covers most of what one
writes by hand, so it looks like the obvious first slice, but without stage 0
you would be afraid to press UPDATE. The smallest honest slice is 0 + 1.

#### Built: in place, not by re-emission

Stage 0 above was written as *decompose → edit → re-emit notation*, with
"emitted notation re-parses to an equal concept" as the contract. It was built
differently, and the contract is stronger for it: **edits mutate the concept in
place**, one named field at a time.

Re-emission cannot work here. Re-parsing mints new nodes, so every referent
edit would churn the `node-ref` the browser's click map is keyed on — the same
reason every other editor operation mutates rather than rebuilds. It also puts
the unbounded tail on the round trip, where any gap in the decomposition
becomes silent data loss. In place, a feature nothing names is a feature
nothing can drop, so losslessness is structural rather than earned.

So the split (`system/editor/referent.lisp`) is a **read** side —
`describe-referent` → a `referent-view` of identity / modifiers / tail — and a
**write** side of setters that each touch one field. The identity setters do
the real work, because identity is exclusive: each clears the other mechanisms
first, or a concept holding both a coref label and an individual renders as
neither.

Three things the catalog-driven test caught, all of which a
looks-right-by-inspection decomposition would have shipped:

- `*x` and `?x` are **different mechanisms**, not two spellings. `*x` is a
  `node-variable` rendered by `variable-text`; `?x` is a coreference label
  rendered by `coref-text`; a concept with both renders only the coref
  (`concept.lisp:124`). A `[DOG: *x]` concept has no referent *and* no coref
  label, so a view consulting only those reports a bare generic and the label
  is lost.
- A measure on a non-set lands in the **individual's properties**, because
  `:measure` is absent from `resolve-target-concept`'s `sans-prop` list. It is
  therefore both a modelled modifier and a member of the tail, and must be
  stripped from one of them or it gets written twice.
- A measure on a non-set **mints an anonymous individual** to hang itself on,
  so `[DISTANCE: @5 ft.]` has an `:individual` identity rather than none.

`referent-identity-text` is deliberately more explicit than `format-concept`:
the formatter drops an individual's id once its name is unambiguous
(`[CAT: Felix #7]` → `[CAT: Felix]`), which is right for notation and wrong for
an editor — the id is what the name resolves *to*, and a field you are not
shown is a field you cannot edit.

#### A variable is not offered

Stage 1 lists `*x` among the identities. The panel does not offer it. Setting
one *succeeds* — the request comes back reporting `:variable` — and the very
next render discards it, because a lone variable with no coreference partner is
dropped by design. Sharing is made by pointing two arcs at one node, not by
naming it; see "Coreference is automatic". A button whose effect evaporates a
moment later is worse than no button.

The *view* still reads `:variable`, and must: a parse can produce one, and a
view that could not see it would let an edit elsewhere overwrite it.

Two related traps, both found by driving the panel rather than reading it. One
text box serves both the coref **label** and the individual's **name**, so
switching kinds carried the text across — clicking the button marked `?x` on
`[PERSON: Sue]` produced `?sue`. Text is now reused only when the role is
unchanged. And a **name is the one value a button cannot invent**: choosing
`name` defaulted to "unnamed", which minted a real individual called that and
made the sentence read *"Unnamed eats a pie."* The button now selects the kind
and arms the field; nothing is sent until you type.

#### What actually gates tense, aspect and voice

Not the concept type, which is what this note assumed. The obvious
implementation asks whether the lexicon classifies the type `:verb`, on the
reasoning that the realizer consults that before conjugating. It does not, for
the case that matters:

```
[WISH: @past]-(expr)->[PERSON: Sue] (thme)->[PIE]   ->   Sue wished a pie.
```

`WISH` and `DESIRE` are `STATE` subtypes, `STATE` is not among
`*pos-hierarchy-roots*`, so both classify `:noun` — and the tense is realized
anyway. It arrives through `find-main-predicate`, which prefers the verb side
of a subject relation and never asks about POS. A POS gate would have hidden a
control that demonstrably works, which is the exact failure it was meant to
prevent.

So the test is the realizer's own: a concept heads a clause if it is an act or
event by the lattice, or if a relation the syntax table maps to `:subject`
points at it from the verb side. Being **graph-derived rather than
type-derived**, it also changes as you build — attaching an `(expr)` arc is
what makes the tense controls appear, which is the honest moment for them to.

A value already set outranks the gate. A graph can arrive carrying
`[WISH: @past]` whatever this thinks, and hiding the control would hide the
only way to remove it.

Quantifier is deliberately **not** gated: universal quantification over an
event is meaningful in CG, so `@every` on a verb is not the nonsense that
`@past` on a dog is.

#### Clearing the whole referent

`—` clears the identity and keeps the modifiers, those being orthogonal. That
left six interactions between `[DOG: Rex @past @passive @every]` and a bare
`[DOG]`, so there is also a **Clear all**. It is one request rather than six,
so a half-cleared referent is not a state anything can stop in, and it sits at
the far end of the *modifier* row rather than beside the identity buttons —
`—` and "clear everything" mean different things and must not look alike.

It is the one operation allowed to drop the tail, and what it does is worth
stating exactly: the unrecognised properties belong to the **individual**, so
clearing *detaches* them rather than destroying them. The individual survives
and giving the concept that id back re-attaches the lot. The catch is that the
panel stops showing the id at that point, so the thing that makes it reversible
is the thing it hides.

#### Sets, and the openness the reader was dropping

The staging rested on a claim: a set member is *just an identity*, so sets are
mostly wiring once the identity selector exists. It held.
`resolve-editor-individual` is shared between the `:individual` identity and
set membership, and the panel's member row is a list of the same things the
selector makes. `{…}` joins the identity selector and needs no input of its
own, because an empty set is a legitimate referent in its own right — `{}` is a
generic *plural*, a different claim from a generic singular. Members are added
afterwards, one at a time, each with its own ✕. No text field anywhere holds
braces: the user picks members, the editor decides where the commas go.

Two consequences worth stating because they are not free. Removal is by
**position**, so the order the page shows must be the order the server holds —
members are appended rather than pushed, since a list that reshuffled itself as
it grew would make the ✕ beside each one a guess. And emptying a set leaves
`{}` rather than no referent: collapsing it into a generic singular would
silently drop the plurality, which is the one thing the braces are there to
say. Stopping it being a set at all is what the identity selector is for.

What the design did not foresee is that the **reader** could not represent the
form the editor needed to offer. `asterisk-reader` returns `NIL` for a bare
`*`, and `set-reader`'s loop read that `NIL` as end-of-input, so `{Fido, Spot,
*}` reached `build-set-from-specs` as two named members and nothing else — with
anything after the `*` dropped too. A placeholder was then fabricated whenever
the contents came out empty, which is why `{}` and `{*}` were indistinguishable:
neither had ever read a `*`. So `{Fido, Spot, *}@4` already formatted back as
`{Fido, Spot}@4` — a set of two asserting it has four — **with no editor
involved**.

That is the same shape as stage 0's findings, one level down. An editor that
offers only legal states has to be able to *tell* which states are legal, and
here the model could not: openness was not representable, so the legitimate
partially specified set and the self-contradicting one looked alike. The editor
first declined to produce either (a stopgap: refuse `@N` whenever any member is
named), and the model was then fixed — `set-reader` peeks before reading, to
tell "a generic marker was consumed" from "there is nothing left"; `set` gained
an `open` slot; `format-set` emits the `*` whenever there are unnamed members.
The rule in `set-referent-measure` is now the real one: refuse a count only on a
**closed** set. Clearing is always allowed either way, or a graph that arrived
carrying a bad value would be stranded — and graphs will, since the reader made
them.

Two loose ends remain, and they are one fact apart. `describe-referent` reports
a set's members but not its openness, so the browser still hides the measure box
on any set with a named member — the blunt pre-fix rule, now stricter than the
server's. And the `{…}` button still produces `{}` rather than `{*}`, so the
panel cannot reach `{Fido, Spot, *}@4` even though the notation and the server
now both accept it. Putting `set-open-p` in the view closes both.

#### Descending into a graph referent

`Edit graph…` opens a **child session** over the concept's referent; the page
navigates to it and UPDATE or CANCEL brings you back. Two pieces of existing
design carried it: `editor-session` has had a `parent` slot from the start, and
sessions are already resumable at their URL — which is what a disconnect relies
on — so leaving the parent page and returning to it needed nothing new.

The child's `original` is the enclosing **concept**, not a graph, because the
graph need not exist yet. Creating an empty one on descent is the obvious
alternative and is unusable: a graph with no head cannot be formatted
(`cgraph-text` has no method for `NIL`), so attaching one broke rendering of
the *parent* — a descent you had not finished left the outer editor unable to
draw itself. `install-working-graph` therefore grew a `:graph-referent` case
that either sets an existing nested graph's head (keeping the object, and with
it the `holders` back-pointer the referent rests on) or attaches the working
graph as a new referent.

Finishing a child also **forgets** it. A child has no blocked caller and no
`unwind-protect` behind it, so without that its URL keeps resolving and a stale
tab can go on editing a graph the user believes they closed.

Returning does not raise the veil. The veil means "this is over"; finishing a
nested graph ends that graph, not the session you are in.

## Remove

Each display-pane line has an ✕. Clicking it removes the relation, then drops
whatever that leaves unreachable from the focus.

Implemented as reachability rather than as an outward walk testing "does this
concept still have more than one relation". Disconnect the arc, then keep what
is still reachable from the focus — the same rule stated directly, and it gets
three cases right without special-casing any of them:

- **Coreferent nodes survive**, because the other path still reaches them.
  Deleting one path can never silently eat a node another path depends on.
- **A dangling branch vanishes entirely**, not just its first node.
- **Cycles terminate**, because reachability visits each node once. The
  `mark` / `unmark` facility turned out not to be needed.

Two things that hold regardless:

- **Direction of travel has nothing to do with arc direction.** The focus is
  the root; the cascade runs outward from it.
- **The focus survives** even when its last arc goes; `[DOG]` is a valid graph.
  To remove the focus itself, focus on a neighbour first.

## Session model

**Never mutate the original until commit.** The session owns a working graph;
UPDATE installs it, CANCEL discards it and the original was never touched.
Cancel is therefore free at every level, rather than a restore operation.

This matters because a live graph can't be snapshotted by copying — copying
mints new node objects, and a node-ref refers to a specific Lisp object.
Reparsing generates new objects too. So "keep what you started with" is only
cheap if you never damaged it.

A nested editor's UPDATE installs into the **outer session's working graph**,
not into the original. Cancelling the outer level still discards the inner
work.

Per-operation undo is deliberately out of scope for v1. Two reasons it isn't
missed: the ✕ button already undoes the last Add, since the thing you just
added is a leaf arc; and because every edit is a discrete operation against
refs, retaining the operation list per level would give real undo later for
almost nothing.

### A closed tab is not a decision

Cancel is an explicit act — it has a button. A tab closes because of a stray
⌘W, a crash, or an ordinary reload, so treating that as "discard my work" reads
an ambiguous event harshly and makes a refresh destructive.

So a disconnect leaves the session **resumable**: it keeps its working graph,
stays `:open`, and the same URL puts you back in it. Connection state is
tracked separately from lifecycle for exactly this reason.

The hard part isn't the policy, it's that a blocked REPL looks *identical*
whether you are mid-edit or the browser has been gone for an hour. So the
disconnect is announced:

```
;; editor session 1: browser disconnected; the call is still waiting.
;;   reopen:  http://localhost:8060/editor?session=1
;;   abandon: (cg::cancel-editor-session 1)
```

Reconnects are announced too, which is what lets a reload read as a pair rather
than an alarm — and avoids needing a timer to tell reload from close. The first
load is silent, since the URL was already printed.

Announcing at all requires capturing the caller's `*standard-output*` when the
session is created: a Hunchentoot worker thread inherits none of the caller's
bindings, so there is otherwise no way to reach the REPL.

Detection is the page's `pagehide` beacon (`sendBeacon`, since a request
started while unloading is liable to be cancelled). It is **best-effort** — a
browser crash or force-quit sends nothing, and then the REPL sits blocked with
no explanation. The guaranteed recovery is `C-c C-c`, which unwinds the wait
and lets `EDIT-CGRAPH`'s `UNWIND-PROTECT` clean up.

A deliberately abandoned session goes through `CANCEL-EDITOR-SESSION`, which
must be called from a source buffer rather than the blocked REPL — SLIME runs
those in a separate worker thread. `(EDITOR-SESSIONS)` shows what is adrift:

```
#<EDITOR-SESSION 1 :open :disconnected 12m [EAT]→(agnt)→[DOG].>
```

There is no heartbeat and no reaper thread. For a single-user loopback tool
that is more machinery than the problem justifies, and browsers throttle timers
in background tabs, so a polling reaper would call a perfectly live session
dead. `*EDITOR-OPEN-TIMEOUT*` remains available as a blunt backstop.

### node-refs are session handles

Every node carries a `node-ref` (a slot on `basic-node`) identifying a specific
Lisp object.

- Refs travel **outbound only**, as a rendering. `*always-show-node-ref*`
  already produces `[DOG +394]←(agnt +396)←[EAT +398].`
- The browser strips them for display and keeps the mapping for click targets.
- Edits come back **only as operations against refs** — never as text to be
  parsed. The reader deliberately rejects `+NNNN` for integrity: a string that
  can assert node identity can forge it.
- Refs are meaningful only against a live graph the session holds. They are not
  identifiers and must never be persisted — reopen the same graph tomorrow and
  the numbers differ.

Because refs are session-scoped, the string entry point becomes:

```
string → parse → live graph (session-owned) → edit by ref → format → string
```

### Coreference is automatic

Nothing needs to mint variables. `*x` appearing twice parses to a *single*
node, and `format-cgraph` re-emits `*x` on its own when it linearizes a shared
node. Verified:

```
node-refs: (401 401)      EQ to each other? T
```

Clicking an existing concept just makes an arc to that node; the variable
appears by itself.

## Entry points

```lisp
(edit-cgraph g)        ; a live graph object — from the REPL
(edit-cgraph "…")      ; a string — e.g. a type's canonical graph
(edit-cgraph concept)  ; a concept, scoped to the graph it belongs to
(edit-cgraph)          ; empty — start a new graph
(new-cgraph)           ; alias for the above, for discoverability
```

All four names are free (`new-cgraph`, `edit-cgraph`, `edit-referent`) and
don't collide with the existing `make-cgraph`.

Returns `(values result committed-p)`. Given a string, the edited string; given
a graph, that same object with the edit installed.

Starting empty, the first concept-type click creates a concept, which becomes
the focus.

### The REPL call blocks

```
CG> (edit-cgraph g)
   ;; browser opens, you edit, you press UPDATE
[DOG]←(agnt)←[EAT]→(obj)→[FOOD].     ← returns here
```

The calling thread waits on a condition variable until the page posts commit or
cancel. This is what makes the call feel native rather than like a job
submission; returning a session handle to poll would be much worse to use.

## What this can stand on

| Asset | Where | Use |
|---|---|---|
| `parse-cgraph` / `format-cgraph` | `reader.lisp`, `formatter.lisp` | authoritative parse, canonical linearization, automatic `*x` |
| `node-ref`, `*always-show-node-ref*` | `node.lisp` | click identity, outbound |
| `mark` / `unmark` | `node.lisp` | cycle-safe removal cascade |
| `rel-use` | `types.lisp:1136` | relation filtering |
| `graph-compatible-p` | `concept-type` slot | which referents are graphs |
| `:desc` leading token | relation-type | long-name filter matching |
| armed one-shot pick | `graph.js:800` | type-zone clicks |
| `/api/*`, no-store static serving, kill-ring bridge | `system/web/` | server plumbing |

## Open

- ~~**The non-graph referent editor**~~ — built through stage 3, plus graph
  referents. What remains is stage 4: whether the tail ever needs editing, as
  opposed to the read-only display it has now. That is a question for use to
  answer, not work waiting to be done. Four things the design got wrong and
  building corrected are recorded in place: the write side is in-place mutation
  rather than re-emission, `*x` is not offerable, tense/aspect/voice are gated
  on whether the concept heads a clause rather than on its type, and a set's
  openness was not representable at all until the reader was fixed.
- **A set's openness is not in the view** — `describe-referent` reports members
  but not `set-open-p`, which leaves two small things wrong on the page: the
  measure box is hidden on any set with a named member (the stopgap rule, now
  stricter than the server's), and `{…}` makes `{}` where it should make `{*}`,
  putting `{Fido, Spot, *}@4` out of the panel's reach. See "Sets, and the
  openness the reader was dropping".
- **A cleared referent hides the id that would undo it** — Clear all detaches
  the individual, and giving the id back re-attaches it with its properties,
  but the panel stops showing that id the moment it clears. A breadcrumb
  ("was #2") would make the reversibility reachable rather than merely true.
- ~~**Formatter round-trip**~~ — done. `/api/edit-type` now compares against what
  `/api/type-def` served (`canonical-unchanged-p`, `supertypes-unchanged-p`) and
  writes nothing when nothing changed; when something else changed but the graph
  did not, it persists the *stored* text rather than the reformatted one. Three
  causes of perturbation were measured over the live catalog, not one: of 38 types
  with a canonical, 9 round-trip identically, 14 differ only by a trailing period,
  and 15 are genuinely relinearized — arcs reordered by the breadth-first walk
  (`[BOY]- (sex)… (life-stage)…` → `(life-stage)… (sex)…`) or a referent
  case-normalized (`[breakfast]` → `[BREAKFAST]`). So 29 of 38 would have been
  rewritten by opening and saving them untouched.
- **One type column or two** — still two. Nothing so far argues for collapsing
  them; relations on the left and concepts on the right runs in the order you
  fill the editor pane.
- **Vertical proportions** — the graph pane holds a fixed share while a
  three-arc graph uses a fraction of it, pushing the editor pane and the focus
  list into the bottom third. The two panes you actually work in are the ones
  being squeezed.
- **Type-in filters** — the per-column text fields described under "Type-list
  filtering" are not built. The lattice-computed narrowing is.

## First slice

Done: the non-recursive loop on a live graph object from the REPL,
`(edit-cgraph g)` — add and remove arcs, UPDATE and CANCEL — plus the string
entry point, which arrived with it since a session parses to a working graph
either way.

Since done: the **referent editor**, stages 0–3 under §Referent editors, and
the **nesting** that waited on it for the shared contract. Still to come: the
**type-in filters**, which wait on nothing.
