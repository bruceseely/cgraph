# Conceptual-Graph Editor — Design

**Status:** built and working. Driven end to end in a browser on 2026-08-01
against the live catalog: focus, contextual filtering in both columns, add,
the removal cascade, the reverse control, and automatic coreference all behave
as described below. The non-graph referent editor is the one designed-but-
unbuilt piece — see "Open".

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
│ ┌─ display pane (read-only) ──┐ │ sorted by context           │
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
so the list can offer `(agnt)→` and `←(agnt)` as separate rows. Two small
additions are needed, both straightforward against the `source-types` /
`dest-type` slots:

- relations consistent with a single concept type (either side)
- concept types consistent with a given relation and a fixed other end

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
- **Referent is not a graph** → a **referent editor** (not yet designed).

Both open, edit, and finish with UPDATE or CANCEL, returning a referent. The
recursion falls out of that uniformity rather than being special-cased.

The non-graph referent editor needs real support, because referents get
complex — individuals, sets, quantifiers, measures. For a set it should offer
the available individuals to choose from and format the referent itself. The
user picks members; the editor decides where the commas go.

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

- **The non-graph referent editor** — not yet designed. Needs to cover
  individuals, sets, quantifiers, measures, with pickers rather than syntax.
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

Still to come: **nesting** (the recursive call, which needs the referent
editors) and the **type-in filters**.
