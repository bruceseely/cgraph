# Type browser and graph editor — integration

Five questions asked on 2026-08-16, in the order they arose:

1. Create a concept type while editing a graph.
2. Draw a graph to serve as a new type's canonical graph.
3. Create *relation* types the same way.
4. And then, from what (3) turned up: is the way a relation type reaches
   English a fundamental obstacle to custom ontologies?
5. And from what (4) proposed: is a relation hierarchy wanted for *reasoning*,
   or only for generation? Because that decides whether it is a day's work or
   a design job.

The first two are small. The third is small in the catalog and not small in
the realizer. The fourth is the real finding, and the rest of this note exists
mostly to hold it. The fifth turned out to have a cheerful answer.

Written as analysis, before any of it was built. Most of it since has been:
§1, §2, §3 and §4(a) were all built on 2026-08-16, and each section carries what
building it settled or corrected. Struck-through headings are done; what remains
outstanding is §4(b), the relation hierarchy, and the `:role` keys' one open
question in §5 about joins.

The analysis is left standing rather than rewritten into a description of the
result, because in several places the thing that was wrong about it is the most
useful part — §4(a) in particular was listed here as an optional nicety and
turned out to be the piece without which the rest is unreachable.

---

## What the two UIs already share

`cgraph-editor.asd` says it, and it is worth restating because it is what
makes (1) and (2) cheap: the editor is a separate ASDF system but **not** a
separate server. Its handlers register on the type browser's acceptor, so it
shares an origin with the browser and reuses `/api/types`, `/api/relations`
and `/api/options` without CORS.

What they do not share is any awareness of each other. Grepping
`web/index.html`, `web/graph.js`, `editor/editor.html` and `editor/editor.js`
for cross-references turns up nothing at all. They are neighbours that have
never spoken. A link each way in the two headers is the ten-minute version of
this whole note, and should probably go first.

## 1. ~~Create a concept type while editing~~ — built 2026-08-16, JS only

`/api/create-type` (`system/web/api.lisp:482`) already does the work:
creates the type live in the process-global catalog, validates any canonical
graph, appends the form to the source file, rolls back on a bad graph. The
editor page can POST to it directly.

The refresh is free. `refresh()` (`editor/editor.js:1266`) refetches
`/api/editor/choices` on every pass, and `all-concept-type-objects`
(`system/editor/api.lisp:463`) reads the live catalog. A type created
mid-session appears in the concept column with no plumbing.

The affordance should live in the empty-filter state, which already says
"nothing here starts with 'X'" (`editor.js:458`) — that is precisely the
moment you want to be offered the type you were reaching for.

**The wrinkle worth designing around.** While filling a slot, the concept
list is filtered to what the relation admits (`rel-far-end-types`,
`system/editor/api.lisp:498`). Create `LASAGNA` under `⊤` while filling an
`(obj)` slot and it will *not* appear in the slot you made it for — which
reads as a bug. So the supertype field must prefill from the focus's type or
whatever is in the target slot, never default to `⊤`.

Built as estimated, no server change. Two things the building settled:

- **The supertype menu is drawn from the column itself**, not offered as free
  choice. That is this wrinkle solved rather than guarded against: every entry
  offered is admissible in the slot, and a subtype of anything admissible is
  admissible, so whatever you pick lands. Measured with `[DOG]` and `(agnt)`:
  23 entries, `ANIMAL` absent, `ACT` present.
- **The offer lives in the empty-filter state**, not in a permanent button. A
  column whose job is to show what is legal should not carry a standing
  invitation to add something that is not.

## 2. ~~Draw the canonical graph~~ — built 2026-08-16, one small server change

The precedent exists. `open-nested-editor-session`
(`system/editor/referent.lisp:339`) already creates a session **from an HTTP
request with nobody blocked on it** — exactly the shape needed — and
`finish-nested-editor-session` forgets it, since there is no `unwind-protect`
behind it. The string entry point (`kind :string`, result =
`session-plain-render`) already exists too.

Missing:

- **`/api/editor/open-string`** — a `:string` session with no caller, web-owned
  so finish drops it from the registry. ~15 lines, modelled on the nested one.
- **`/api/editor/finish` returns the text.** Today it returns only state and
  parent (`system/editor/api.lisp:548`); for a web-owned string session it
  should also hand back `session-result`, which is already the rendered string.
- **The return trip.** The nested editor's model is navigate-away-and-come-back
  (`editor.js:1238`). The type form is the same shape plus one thing: the
  label, supertypes and note in the form must survive the round trip. A
  `sessionStorage` stash before navigating, restored on return with the
  committed graph dropped into the canonical field.

The second-tab-plus-`BroadcastChannel` alternative avoids the stash but fights
the session model, which treats a closed tab as "not a decision". Wrong fit.

**A trap that turned out not to be one.** ~2/3 of catalog types are relinearized
by a parse→format round trip, so committing an *unchanged* graph looks like it
would rewrite the stored text. It does not: `canonical-unchanged-p`
(`system/web/api.lisp:438`) compares against the formatted form as well as the
raw one, and the editor's plain render is `format-cgraph` of the same parse.
"Drew it, changed nothing" is correctly recognised as no change.

Built as estimated. `OPEN-WEB-STRING-SESSION` is
`OPEN-NESTED-EDITOR-SESSION`'s shape with no parent, and `WEB-OWNED` marks the
one thing that distinguishes it: no parent *and* no blocked caller. The result
travels back in the `FINISH` response because that is the only route left when
nobody is waiting on the semaphore.

The `back` parameter is restricted to a same-origin path — it arrives on the
URL, and a full URL there would let a crafted link bounce someone off the
editor to anywhere.

One thing the note did not foresee: building this turned up a defect older than
it, in `EDITOR-ADD-CONCEPT`. Recorded in `notes/known-issues.md` rather than
here, because it is not a missing feature.

---

## 3. Relation types — simpler than concept types, except where they are not

### The catalog half is easy

A relation type is flat. The class (`system/core/types.lisp:1109`) is label +
`source-types` (a list) + `dest-type` (single) + `desc`. No lattice to
maintain, no cycle checking, no `check-type-lattice` equivalent.

The persistence layer is nearly free. Both type files are flat sequences of
`(:label …)` plists, and the machinery written for concept types —
`concept-type-in-file-p`, `%skip-to-form`, `concept-type-form-span`,
`splice-…`, `remove-…` (`system/web/api.lisp:237-338`) — **never looks at
`:supertypes`**. It is already generic over `:label` plists and only named for
concepts. Rename those, write one `relation-type-def-string`, and the write
side is done.

Delete needs a referrer check like `concept-type-referrers`
(`system/web/api.lisp:357`): a relation label appears inside concept types'
canonical graphs, so deleting one can break a type.

### Where the form should live

The create form differs from the concept form — two type-slots and a
description, no lattice, no canonical graph — but it needs the *same* thing
the concept form needs: a way to name a concept type by pointing at the
lattice. `#nt-add-super` (`web/graph.js:~931`) already arms a one-shot pick
that fills a form field from a click on the graph. Aiming it at "source type"
or "dest type" is the same mechanism with a different target.

This matters more than it sounds. In the editor you would have `[EAT]` and
`[DOG]` in hand, so prefilling those gives a relation too narrow to ever
reuse; the real signature is `act → animate`. Getting from the one to the
other **is** the lattice. That is the argument for the form living where the
lattice already is.

Also: `<title>` at `web/index.html:6` is "CGraph Type Browser" and it browses
only concept types. Adding relations makes the name true rather than needing
it corrected.

### What the browser already half-has

`/api/relations?type=X` (`system/web/api.lisp:716`) answers "which relations
take X as input / as output", marking exact vs. inherited. What is missing is
the *catalog* view: relations as a browsable list independent of any concept
type. There is no `relation-type-graph.lisp` to write, because with no
hierarchy there is nothing to diagram — a sorted `source → dest` table is the
honest view. (See below for why "no hierarchy" is itself the problem.)

---

## 4. The fundamental issue

### The asymmetry

A relation type's behaviour in English is spread over five tables in
`system/generation/syntax-roles.lisp`, all keyed by relation label and all
literal `defparameter`s in repo source:

| | line | what it decides |
|---|---|---|
| `*relation-syntax-table*` | 14 | syntactic role + preposition |
| `*generation-relation-labels*` | 144 | labels the realizer names literally |
| `*clause-level-pp-relations*` | 159 | adjunct vs. NP post-modifier |
| `*pp-relation-priority*` | 164 | modifier ordering |
| `*np-pp-prepositions*` | 196 | preposition by which side the NP is on |

The first is the one that matters most: `relation-role-entry` (line 167) does
a plain `assoc` against it, and an unmapped relation gets `NIL`.

Compare the concept side, which faces the identical problem and solves it
twice over:

|  | default comes from | override hook | persisted |
|---|---|---|---|
| concept type | **derived from the lattice** — `pos-from-hierarchy` walks supertypes against `*pos-hierarchy-roots*` (`lexicon.lisp:97,110`); lemma defaults to the downcased label | `register-lexicon-entry` (`lexicon.lisp:74`), explicitly documented as extensible at runtime | no |
| relation type | **nothing** | **nothing** | no |

That table is the finding. It is not that relation types are spread over five
tables — that is a symptom, and a tidier single table would not help. It is
that **relation types have neither a default nor an override hook, so there is
nowhere for a new one's linguistic behaviour to come from.**

A custom concept type is born realizable: POS is inherited through the lattice
and the lemma is its own name, so the common case needs no registration at
all, and the irregular case can be corrected in-image. A custom relation type
is born mute, and cannot be corrected without editing repo source and
recompiling.

So yes — this is fundamental, and yes, it affects ontology authoring and
incremental relation editing alike. It is not a consequence of putting a
create form on the web; the web form only makes it impossible to ignore. Any
user writing their own `relation-types.lisp` today already hits it. They just
hit it silently.

Silently is the word: `%lint-relation-syntax-coverage`
(`system/generation/lexicon-lint.lisp:73`) exists precisely because "an
unmapped relation is silently dropped during generation." The system already
knows about this failure and already has a name for it. What it lacks is a way
to *fix* it from outside the source tree.

### The missing relation hierarchy

The reason relations cannot derive a default is that there is no relation
hierarchy to derive it from. And that absence is itself odd on three counts:

**The slots are already there.** `relation-type` inherits `supertypes` and
`subtypes` from `type-object` (`system/core/types.lisp:43-50`). Nothing ever
populates them — `make-relation-type` (line 1337) does not even accept
`:supertypes`, and `relation-types.lisp` never mentions them. The hook exists
and was never used.

**Sowa's theory has one.** A relation type hierarchy is not an invention that
would have to be justified; it is a part of the theory that went
unimplemented.

**The hierarchy is already written down — in prose.** Two pairs in
`relation-types.lisp` describe a subtype relation in their `:desc` and then
fail to represent it, and both check out against the concept lattice
(`individual` ⊃ `entity` ⊃ `physical`):

- `part` (individual → individual) says *"The general case, including events…
  For parts of physical objects, see `physical-part'"*; `physical-part`
  (physical → entity) says *"The physical-object case of `part'"*. Both arcs
  narrow. A clean specialization.
- `loc` (entity → place) *"links anything to its place"*; `ploc` (physical →
  place) *"links an object to its place"*. Source narrows, destination
  identical. A clean specialization.

And one pair that *looks* like a third and is not: `size` (collection →
number) and `psize` (physical → size) share no signature relationship —
`physical` is not a subtype of `collection` — despite `psize` carrying a
description copy-pasted from `size` ("the number of members in a set or
collection"), which is simply wrong for a physical→size relation. Worth
noting because representing the hierarchy would have caught it. A latent
structure you can only write in prose is a structure nothing can check.

### Two fixes, at different depths

**(a) ~~A registration hook~~ — built 2026-08-16.**
`register-relation-syntax`, mirroring `register-lexicon-entry`: a hash
consulted ahead of the declarative defaults, so a user ontology can say how its
own relations behave. This does not change the model — it makes custom
ontologies *possible* to make realizable, which they were not.

Scoped to `*relation-syntax-table*` only, deliberately. The other four tables
degrade gracefully when a relation is absent — `pp-priority-rank` falls back to
`most-positive-fixnum`, `*clause-level-pp-relations*` is a membership test where
absent means "stays in the NP", and `np-pp-preposition` returns `NIL` — so only
the syntax table is a hard gate on whether the relation is emitted at all.

Two things the design got right by copying the lexicon, and one it had to add:

- **No validation at the setter.** `register-lexicon-entry` deliberately
  validates nothing, leaving it to the lint. The same choice here has a sharper
  payoff: `%lint-unrealizable-syntax-roles` reports a bad role *with its
  consequence spelled out*, which beats a signal at registration time. But it
  only works because the lint now walks the **effective** mapping rather than
  the table — so `relation-syntax-entries` is what all four checks read.
- **A registration counts as coverage.** `%live-relation-syntax-entries` had to
  see registrations too, or an ontology supplying its own agentive relation
  would still read as having no `:subject` and every graph would be reported as
  rendering copular.
- **The lint message names the hook.** The old text said the relation had no
  entry in `*relation-syntax-table*` — which is an instruction to edit the
  repo, the exact thing the hook exists to avoid.

What (a) does *not* do is give relation types a default. That still needs (b).

**~~The remaining option under (a)~~ — built the same day, and it turned out
not to be optional.** Saying it in the relation-types file itself, as extra
keys on the existing form: `(:label benef :source-types act :dest-type animate
:role :pp :prep "for")`. `parse-relation-type-def`
(`system/core/types.lisp:1390`) already tolerated unknown keys via
`&allow-other-keys`, exactly as `:note` is tolerated on the concept side, so
the file format did not change and older files are unaffected.

This note first listed it as a nice-to-have whose cost was that the ontology
file "starts carrying generator concerns". Finishing the hook showed that to be
the wrong framing, because **a registration had nowhere else to live**:

- `load-relation-types` (`system/core/types.lisp:1406`) **reads** the file as
  data — a `read` loop handing each form to `parse-relation-type-def`. It is
  never `load`ed as code, so a `(register-relation-syntax …)` form placed there
  would be destructured as a type definition.
- `setup-cgraph` loads no user init file. There is no such step.

So without the keys, the hook could only be driven from the REPL — lost on the
next reload — or from a private file the user must remember to load. The keys
are what make the hook reachable at all.

Two pieces of machinery it needed:

- **The dependency has to point generation → core**, since the realizer loads
  after core. `*relation-syntax-hook*` is declared NIL in
  `system/setup/definitions.lisp` beside `*mass-type-p*`, which is the same
  hole for the same reason, and `syntax-roles.lisp` fills it — the move
  `lexicon.lisp:377` already makes. With no generation system loaded, `:role`
  keys are read and ignored, which is right for an image that cannot realize
  anything anyway.
- **Clearing has to be symmetric.** `initialize-types`
  (`system/setup/initialize.lisp:67`) clears both catalogs before reloading, so
  `clear-relation-catalog` now clears the registrations too, via a second hook.
  Without it a `:role` deleted from an ontology would go on applying until the
  image restarted — the one staleness a reload exists to cure.

A pleasant consequence: the registrations become a *projection* of the ontology
file rather than hand-managed state, which is what makes
`*relation-syntax-overrides*` being a `defparameter` correct rather than merely
tolerable. Cleared on reload, rebuilt by `initialize-types`.

**(b) A relation type hierarchy.** Populate the inherited supertype slots and
derive the role by walking up, mirroring `pos-from-hierarchy`. This makes
custom ontologies realizable *by default* — a new relation under `loc` behaves
like `loc` until told otherwise — which is the actual goal, and the property
the concept side already has.

(b) is the right answer and much the larger job: it is an ontology decision
per relation, it touches the reader and the projection code that assume
relation types are atomic, and it needs its own `check-type-lattice`. It also
subsumes most of (a), since most relations would inherit rather than declare.

### Recommended order

1. ~~**(a) first**, scoped to `*relation-syntax-table*` only.~~ Done
   2026-08-16. Verified end to end rather than only by lint: a `BENEF` relation
   defined at runtime and absent from every table renders
   `[EAT]- (agnt)→[DOG] (obj)→[FOOD] (benef)→[CAT].` as *"A dog eats food."* —
   the arc silently gone — and after
   `(register-relation-syntax 'benef :pp "for")` as *"A dog eats food for a
   cat."* That transition is the whole feature, and it is the thing the lint
   tests could not have shown. The `:role` keys followed the same day, and the
   end-to-end check moved with them: a `BENEF` relation defined **only** in an
   ontology file, as `(:label benef :source-types act :dest-type animate :role
   :pp :prep "for")`, loads, registers itself, satisfies the coverage lint and
   renders *"A dog eats food for a cat."* — with no code anywhere outside that
   file. Which is the whole point of §4.
2. **Surface the lint at creation time.** Whatever form creates a relation
   should run `%lint-relation-syntax-coverage`'s check and say so: *"created —
   with no syntax role it will be dropped from generated English."* Cheap, and
   now cheaper still: since (a), the check's own message names
   `register-relation-syntax` as the remedy, so the UI can quote it rather than
   compose its own.
3. **(b) when there is evidence it is wanted** — which is to say, once the
   relation catalog has grown enough through use that declaring each new
   relation's syntax by hand is the annoyance rather than the safety net.
   See §5 for what (b) costs outside generation, which is less than expected.

Do not block the UI work on any of this. (1) and (2) at the top of this note
touch none of it.

---

## 5. What a relation hierarchy would cost in reasoning

§4 recommended deferring (b) partly because its blast radius was unknown. It
is now known, and it is smaller than assumed. The costs separate into three
piles that can be paid independently.

### Projection: one line, and the TODO is already written

`relation-type-projects-p` (`system/operations/projection.lisp:120`) is
already its own generic function, parallel to `type-projects-p`, and it says
what it is waiting for:

```lisp
(defmethod relation-type-projects-p ((pattern-type relation-type) (target-type relation-type))
  ;; For now, require exact type match for relations
  ;; Could be extended to support relation type hierarchies
  (types-equal pattern-type target-type))
```

`types-equal` → `subsumes-p` and projection honours the hierarchy.

**Query comes free.** `query.lisp` reaches everything through `project`
(lines 34, 71, 115) and never compares relation types itself, so it inherits
the change with no separate work.

### The lattice predicates only look generic

This is the part that is not free. They are concept-typed nearly all the way
down, in a way that reads as generic until you try it:

- `subtype-p` **is** generic — it dispatches on `(type-object type-object)`
  (`system/core/types.lisp:322`).
- …but it calls `has-subtype`, defined **only** on
  `(concept-type concept-type)` (line 319). So `subtype-p` on two relation
  types finds no applicable method and errors.
- `has-subtype` → `subtypes` → `collect-subtypes`, also concept-type-only
  (lines 309, ~296).
- `subsumes-p` is `(concept-type concept-type)` only (line 1507).
- The symbol-taking `subtype-p` methods (325/328/331) hardcode
  `get-concept-type`, so `(subtype-p 'ploc 'loc)` searches the *concept*
  catalog and fails in a way that names the wrong problem.

None of this is hard: every method *body* is already type-neutral, walking
`direct-supertypes`/`direct-subtypes`, which `relation-type` inherits from
`type-object`. It is widening about five specializers from `concept-type` to
`type-object`, and splitting the symbol methods so each resolves against its
own catalog. But these are core predicates with callers everywhere, so it
wants the suite run behind it rather than a spot check.

Construction is real work too: `make-relation-type` (line 1337) does not
accept `:supertypes` at all, there is no `define-relation-type` mirroring
`define-concept-type` (line 685), and a `check-relation-lattice` would be
wanted alongside.

### `rel-use` needs nothing

It computes from signatures independently (`system/core/types.lisp:1141`), so
with `ploc ⊑ loc` in place it already returns both for a compatible pair,
which is the right answer. The editor's relation column behaves exactly as it
does today.

It does raise one design question: does a relation subtype **inherit** its
signature, or must it restate it? Concept types never face this, having no
signature. Restating is probably right — the signatures are precisely what
`check-relation-lattice` verifies, and inheriting them makes the check
vacuous.

### Joins are the actual design question

Three sites compare relation types with `types-equal` and are *not*
projection:

- `system/operations/maximal-join.lisp:166` and `:197`
- `system/operations/graph-combination.lisp:380` (structural similarity)

Concept types in a join go to `maximal-common-subtype`
(`system/core/types.lisp:374`, used by `conformity.lisp:17`). The relation
analogue does not exist and is not mechanical. Joining `[X]→(loc)→[Y]` with
`[X]→(ploc)→[Y]` should presumably yield `(ploc)` — but **there is no `⊥` for
relations**, so two incomparable relation types have no meet and
`maximal-common-subtype` has no answer to give. The join must then choose
between leaving the arcs unmerged and failing. That is semantics, not code,
and nothing forces the decision yet.

### The soundness rule

For `ploc ⊑ loc` to be valid under projection, ploc's admissible pairs must be
a subset of loc's — which means narrowing on **both** arcs, source and
destination alike. (A relation is a predicate; subtyping it is implication, so
its extension shrinks, and narrowing the signature is what shrinks it.) Both
prose pairs recorded in §4 satisfy this, checked against the concept lattice.
This is the rule `check-relation-lattice` enforces.

### What this changes about the order

Generation-only is nearly free. Reasoning costs the predicate widening plus a
join decision — and the two separate cleanly, because **projection can honour
the hierarchy while joins stay on `types-equal`**. That combination is
strictly conservative: a join would only ever miss a merge, never make a wrong
one. So the join semantics can wait for a case that actually needs them.

The order in §4 stands. What §5 removes is the fear that (b) is unbounded: it
is a day of careful widening plus one line, with the genuinely open question
(join semantics) safely deferrable.

---

## Sizing, all together

| | estimate | touches Lisp |
|---|---|---|
| Links between the two UIs | 10 min | no |
| ~~Concept type from the editor~~ | done 2026-08-16 | no |
| ~~Draw a canonical graph~~ | done 2026-08-16 | lightly |
| Relation-type endpoints | half a day | yes (mostly renames) |
| Relation browser/editor pane | ~a day | no |
| ~~(a) registration hook~~ | done 2026-08-16 | yes |
| (b) relation hierarchy, generation only | ~a day (see §5) | yes |
| (b) + projection honours it | + widening the lattice predicates, ~half a day, plus the suite | yes, in core |
| (b) + joins honour it | not estimated — needs the meet semantics decided first | yes |
