# The graph editor

A web page for building and editing conceptual graphs by pointing and
clicking: you pick concept types and relations from lists the lattice has
already narrowed, and never type CG notation or worry which way an arrow
points. It runs on the same server as the [type browser](type-browser.md).

## Opening it

Start the server with the session, `(cg:init :web t)`, then:

- **From the type browser**, click **Editor** in the toolbar. It opens on an
  empty graph.
- **From the type form**, click **Draw…** beside a type's canonical graph. The
  editor opens on that graph, and UPDATE takes you back to the form with the
  drawn graph in the canonical field.
- **From the REPL**, with `cg:edit-cgraph`:

  ```lisp
  (cg:edit-cgraph)                                          ; a new graph
  (cg:edit-cgraph "[CAT: Tom]←(agnt)←[EAT]→(obj)→[FOOD].")  ; a graph string
  (cg:edit-cgraph graph)                                    ; a graph object
  (cg:edit-cgraph concept)                                  ; the graph a concept is in
  ```

  This opens a browser tab and **waits** until you press UPDATE or Cancel,
  then returns two values: the result and whether you committed. Given a
  string you get the edited string back; given a graph, the same graph object
  with the edits installed. Cancel returns what you passed in, untouched.

There is no address to type: each editing session has its own
`/editor?session=N`, made when it is opened.

Nothing is changed until you press **UPDATE**. Until then you are editing a
working copy, and **Cancel** throws it away. A session opened from the
Editor button has no caller to hand the result to, so UPDATE shows you the
finished graph as text, to copy.

## The page

```
┌─ bar ──────────────────────────────────────────────── [UPDATE] [Cancel] ┐
├─ English ───────────────────────────────────────────────────────────────┤
│ An old dog eats food.                                                   │
├─ left ───────────────────────────────────┬─ right ──────────────────────┤
│ graph      the graph, in linear notation │ relations     │ concept types│
│ editor     [focus] →(relation)→ [target] │ [filter] ✕    │ [filter] ✕   │
│            [Add] [Clear]                 │ FROM [DOG]    │ ANIMAL       │
│ referent   (when opened)                 │  (agnt)→ …    │  CAT         │
│ arcs       the focus's arcs, each with ✕ │ INTO [DOG]    │  DOG         │
│            and its canonical guidance    │  ←(obj) …     │ …            │
└──────────────────────────────────────────┴───────────────┴──────────────┘
```

- **English**: the working graph said in English, updated after every edit.
  If the generator can't say it yet, the pane says so; that is not an error in
  the graph.
- **Graph**: the whole working graph in linear notation. Click a concept in it
  to use it.
- **Editor row**: the arc you are building, as a preview of what Add will
  produce: the **focus** (the concept you are working on), a relation, and a
  **target**.
- **Arcs**: the focus's arcs, one per line, in the direction they run. Below
  them, the arcs the focus's type is expected to have (see
  [canonical guidance](#canonical-guidance)).
- **Relations** and **concept types**: what you can pick, filtered by the
  lattice for what the editor row already holds.

## Building a graph

Every edit adds one arc to the focus, or removes one.

1. **Choose a focus.** In a new graph, click a concept type in the right-hand
   column; the new concept becomes the focus. In an existing graph, click a
   concept in the graph pane.
2. **Choose a relation.** The relation column lists only relations the focus's
   type allows, in two groups: **FROM [focus]**, the arcs that go out from it,
   and **INTO [focus]**, the arcs that come in. A relation legal both ways
   appears in both.
3. **Choose a target**:
   - a **concept type** in the right-hand column makes a **new** concept; the
     column lists only types the relation allows at that end;
   - a **concept in the graph pane** links to that **existing** concept, which
     is how one concept comes to take part in several arcs. Coreference
     variables (`*x`, `?x`) appear in the notation by themselves.
4. **Add.** The arc is added, and the focus stays where it is, ready for the
   next one.

**Clear** empties the editor row without changing the graph. Clicking a
concept in the graph pane while the row is empty makes it the focus, which is
how you move around the graph.

### Direction

The arrows in the editor row are a control: when the relation is legal the
other way round, the arrows can be clicked to flip it. When they can't be
clicked, the arc can only run the way it is drawn.

The row never holds an arc the lattice forbids. If you pick a target for which
the relation runs the wrong way, the editor flips it, or drops the relation if
neither way is legal, and says which it did.

### Filters

Each column has a filter box that narrows the list further: it matches the
start of a name or of any hyphenated part of it, so `stage` finds
`LIFE-STAGE`. Relations also match their long name, such as `agent` for
`agnt`. Esc or the ✕ clears a filter. When a list is empty, the page says
whether the lattice offers nothing or your filter matches nothing.

## Changing and removing arcs

- **Remove**: click the ✕ on an arc's line. The arc goes, along with any part
  of the graph that is no longer connected to the focus. Concepts still
  reached by another path stay. The focus itself always stays; to remove it,
  make a neighbour the focus first.
- **Replace**: click an arc's relation on its line to pull the arc into the
  editor row. Add becomes **Replace**, enabled once you choose a different
  target, and the old arc is swapped for the new one.

A concept's type can't be changed in place, since it may be the far end of
several arcs. Replace the arc, or use canonical guidance's restrict (below).

## Referents

Click the **focus** in the editor row to open its referent: which thing the
concept is, and how it is qualified. Changes apply to that concept wherever it
appears in the graph.

- **Identity**: one of `—` (none: a generic concept), `?x` (a coreference
  label), a **name**, a **#n** individual id, or a **set**. For a set, add
  members one at a time by name or `#id`, and `*` says whether there are
  others besides those named. The editor writes the braces and commas.
- **Modifiers**: quantifier, tense, aspect, voice and measure, in any
  combination.
- **Carried**: anything else the referent holds that the panel has no control
  for. It is kept as it is, and written back unchanged.
- **Clear all** empties the referent; **Close** puts the panel away.

On a type whose referent can be a graph (PROPOSITION, SITUATION, BELIEF, …),
**Edit graph…** opens a nested editor on that graph. Its UPDATE brings you
back to the outer graph with the change in place; nothing is final until the
outer UPDATE.

See [referents](referents.md) for every form a referent can take.

## Canonical guidance

Under the focus's arcs, the editor lists the arcs its type's canonical graph
expects, inherited from the nearest ancestor that has one (and labelled
"inherited from …" when it is). Satisfied ones are ticked; open ones are
still to fill. An arc whose far end isn't under the type the canonical graph
asks for is reported as a conflict:

- **too general**, such as `[ENTITY]` where `[INFORMATION]` is expected: the
  editor offers a one-click restrict to a suitable subtype, keeping the
  concept and its arcs;
- **off the branch**, such as `[DOG]` where `[INFORMATION]` is expected: no
  refinement leads there, so the fix is a different concept, a different
  relation, or a change to the canonical graph itself.

Conflicts are advice, never refusals: the graph is well formed, and may be
exactly what you meant. A relation the canonical graph doesn't mention is not
constrained by it at all.

## When the REPL is waiting

While `edit-cgraph` waits, that REPL is busy. Closing or reloading the tab is
not a cancel: the session stays open, and the REPL prints how to get back:

```
;; editor session 1: browser disconnected; the call is still waiting.
;;   reopen:  http://localhost:8060/editor?session=1
;;   abandon: (cg::cancel-editor-session 1)
```

`(cg::editor-sessions)` lists the open sessions. Call
`cancel-editor-session` from a source buffer, since the REPL is the thing
waiting; or press `C-c C-c` in the REPL to stop the wait outright.

---

The design, and why it works this way, is in `notes/graph-editor.md`.
