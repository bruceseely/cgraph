# Errors and Warnings — Reference

Each message CGraph prints with a name in it has an entry here, filed under
that name. Search this page for the name you saw, without the brackets or
colon: `RELATION-NOT-MAPPED`, `relation-signature-mismatch`, and so on.

There are two kinds:

- **[Startup findings](#startup-findings)**, printed at startup under
  `--- ERROR ---`, `--- WARN ---` or `--- INFO ---` with the name in
  brackets. They come from a check of your types against the English
  generator. CGraph still runs after printing them; they tell you which
  sentences will come out wrong or incomplete.
- **[Lisp errors](#lisp-errors)**, which stop what you were doing and put you
  in the debugger. The name is the condition type, shown in the debugger's
  first lines.

---

## Startup findings

### What they are

When CGraph starts it runs `report-lexicon-lint`, which compares your type
set (`concept-types.lisp`, `relation-types.lisp`, and the optional
`lexicon-overrides.lisp`) against the tables the English generator
(`graph-to-text`) reads. The generator doesn't stop on a gap. It leaves
the piece out, or picks a worse word, and says nothing. The startup check is
the only place you hear about it.

**None of these affect building, parsing, joining or querying graphs.** They
only matter when you turn graphs into English. If you don't use
`graph-to-text`, you can ignore them, or turn them off (see below).

The severities mean:

| Severity | Meaning                                                       |
|----------|---------------------------------------------------------------|
| `ERROR`  | Some English output is being **lost**, every time.            |
| `WARN`   | Probably a mistake. Output comes out wrong or degraded.       |
| `INFO`   | Something can never take effect. Usually harmless, often normal. |

### Commands

```lisp
(cg::report-lexicon-lint)                      ; run the checks again after a fix
(cg::report-lexicon-lint :min-severity :warn)  ; errors and warnings only
(cg::report-lexicon-lint :min-severity :error) ; errors only
```

`cg::*run-lexicon-lint-on-startup*` sets how much prints at startup:
`:all` (the default), `:errors-warnings`, `:errors-only`, or `nil` for
nothing. Set it in `~/.cgraph/initializations.lisp`:

```lisp
(setf cg::*run-lexicon-lint-on-startup* :errors-only)
```

### Index

| Name | Severity | One-line meaning |
|------|----------|------------------|
| [`DUPLICATE-TABLE-KEY`](#duplicate-table-key) | WARN | A word has two rows in a word-form table; the second is never used |
| [`ENGLISH-COLLISION`](#english-collision) | INFO | Two types come out as the same English word |
| [`MALFORMED-TABLE-ROW`](#malformed-table-row) | ERROR | A row in a word-form table has the wrong shape |
| [`MISSING-GENERATION-RELATION`](#missing-generation-relation) | INFO | A relation the generator handles specially isn't defined |
| [`MISSING-GENERATION-ROOT`](#missing-generation-root) | WARN / INFO | A concept type the generator relies on isn't defined |
| [`PERSON-CHECK-SKIPPED`](#person-check-skipped) | INFO | No `PERSON` type, so the gender check couldn't run |
| [`PERSON-WITHOUT-GENDER`](#person-without-gender) | INFO | A kind of person has no gender recorded |
| [`PP-TABLE-ROLE-MISMATCH`](#pp-table-role-mismatch) | WARN | A preposition table names a relation that isn't a prepositional relation |
| [`REDUNDANT-IRREGULAR-ROW`](#redundant-irregular-row) | INFO | An "irregular" word is actually regular |
| [`RELATION-NOT-MAPPED`](#relation-not-mapped) | ERROR | A relation has no English role, so it is dropped from sentences |
| [`STALE-LEXICON-OVERRIDE`](#stale-lexicon-override) | INFO | A wording entry names a type that doesn't exist |
| [`STALE-RELATION-ENTRY`](#stale-relation-entry) | INFO | A generator table names a relation that doesn't exist |
| [`SYNTAX-ROLE-UNCOVERED`](#syntax-role-uncovered) | ERROR / WARN / INFO | No relation fills one of the English roles |
| [`UNIMPLEMENTED-LEXICON-KEY`](#unimplemented-lexicon-key) | ERROR | A wording entry uses a key that's documented but does nothing |
| [`UNIMPLEMENTED-SYNTAX-ROLE`](#unimplemented-syntax-role) | ERROR | A relation is given a role the generator doesn't produce |
| [`UNKNOWN-LEXICON-KEY`](#unknown-lexicon-key) | ERROR | A wording entry uses a key nothing reads (usually a typo) |
| [`UNKNOWN-SYNTAX-ROLE`](#unknown-syntax-role) | ERROR | A relation is given a role that doesn't exist (usually a typo) |

---

### RELATION-NOT-MAPPED

**ERROR.** Example:

```
[RELATION-NOT-MAPPED] Relation KIND has no syntax entry — it will be silently
dropped during generation. ...
```

**What it means.** To put a relation into a sentence, the generator has to
know what part of the sentence the relation's second concept becomes. Is it
the subject ("**Bob** eats")? The object ("eats **a pie**")? An adjective
("a **red** pie")? A prepositional phrase ("eats **in the kitchen**")? That
answer is the relation's *role*. This relation has none, so whenever a graph
contains it, the generator leaves that piece out. You get "a pie" where you
meant "a cherry pie".

This is usually the first finding you see after adding a relation to
`relation-types.lisp`.

**How to fix.** Choose a role, then record it in one of three ways.

The roles (the ones that work):

| Role       | The second concept becomes…    | Example                              | Typical relations |
|------------|--------------------------------|--------------------------------------|-------------------|
| `:subject` | the subject of the verb        | "**Bob** eats a pie"                 | AGNT, EXPR        |
| `:dobj`    | the direct object              | "Bob eats **a pie**"                 | OBJ, PTNT, THME   |
| `:iobj`    | the recipient, with a preposition | "gives a pie **to Mary**"         | RCPT              |
| `:pp`      | a prepositional phrase         | "eats **in the kitchen**"            | LOC, INST, DUR    |
| `:adj`     | a word before the noun         | "the **red** pie", "a **cherry** pie" | ATTR             |
| `:adv`     | a manner adverb                | "eats **quickly**"                   | MANR              |
| `:poss`    | a possessive                   | "**Bob's** pie", "Bob has a pie"     | POSS              |
| `:nmod`    | a modifier after the noun, with a preposition | "a board **of length five feet**" | CHRC   |

`:pp`, `:iobj` and `:nmod` also take a preposition (`"in"`, `"to"`, `"because of"`…).

Then do one of these:

1. **Put it in the relation's definition** (best when you keep your own type
   set). Add `:role`, and `:prep` if needed, to the line in
   `relation-types.lisp`:

   ```lisp
   (:label kind  :source-types entity :dest-type entity :role :adj :desc "...")
   (:label benef :source-types act :dest-type animate :role :pp :prep "for" :desc "...")
   ```

2. **Make it a subtype of a relation that already has a role.** A relation
   with no role of its own uses its nearest supertype's:

   ```lisp
   (:label benef :supertypes (rcpt) :source-types act :dest-type animate :desc "...")
   ```

3. **Register it from Lisp**, at the REPL or in code that defines relations
   on the fly:

   ```lisp
   (cg::register-relation-syntax 'kind :adj)
   (cg::register-relation-syntax 'benef :pp "for")
   ```

   A registration is forgotten when the types are reloaded, so for a
   permanent fix use 1 or 2.

Not sure which role? Build a small graph using the relation, try one, and
run `(graph-to-text g)` to see how it reads.

**If you didn't add the relation yourself.** Someone else's code may define
relations as it runs. If so, the role belongs wherever that code defines the
relation, using option 3.

---

### SYNTAX-ROLE-UNCOVERED

**Severity depends on the role:** ERROR for `:subject`, WARN for `:dobj`,
INFO for the rest.

**What it means.** None of the relations in your type set has this role, so
the generator can never produce that part of a sentence. The message says
what is lost. Missing `:subject` is the serious one: no sentence gets a
subject, and every graph comes out as "X is Y". Missing `:dobj` means verbs
lose their objects ("the dog eats" instead of "the dog eats a cake").
Missing `:adv` in a type set that has no manner relations is fine.

**How to fix.** Give the role to the relation in your type set that plays it,
as described under [RELATION-NOT-MAPPED](#relation-not-mapped). The message
names the usual candidates, for example "map your agentive relations (AGNT,
EXPR …) to :subject".

---

### UNKNOWN-SYNTAX-ROLE

**ERROR.** **What it means.** A relation has been given a role that doesn't
exist, usually a typo (`:pos` for `:poss`, `:obj` for `:dobj`). The
generator treats it exactly like no role at all, and drops the relation. The
message lists the real roles.

**How to fix.** Correct the role where it was set: the `:role` in
`relation-types.lisp`, or the `register-relation-syntax` call.

---

### UNIMPLEMENTED-SYNTAX-ROLE

**ERROR.** **What it means.** A relation has been given a role that is listed
as a name but that the generator doesn't produce yet. At present that is
`:pred-cmp`. The relation is dropped.

**How to fix.** Use `:dobj` for clausal complements ("wants **to go**"),
which is how PROP works.

---

### PP-TABLE-ROLE-MISMATCH

**WARN.** **What it means.** Three tables fine-tune prepositional phrases:
their order (`*pp-relation-priority*`), the preposition used after a noun
(`*np-pp-prepositions*`), and whether the phrase belongs to the clause or
the noun (`*clause-level-pp-relations*`). They are only consulted for
relations whose role is `:pp`. This one names a relation whose role is
something else, so the entry can never apply.

**How to fix.** If the relation should be prepositional, give it role `:pp`.
Otherwise remove it from the table named in the message (all three are in
`system/generation/syntax-roles.lisp`).

---

### STALE-RELATION-ENTRY

**INFO, and normal.** **What it means.** One of the generator's tables names
a relation your type set doesn't define. The entry is simply never used.
CGraph ships entries for many more relations than a typical type set has,
so a handful of these is expected.

**How to fix.** Nothing, unless you meant to define the relation. If you
did, check the label in `relation-types.lisp` for a typo.

---

### MISSING-GENERATION-RELATION

**INFO.** **What it means.** The generator treats a few relations by name. At
present only `TIME`, which lets "yesterday" or "tomorrow" come out as a bare
word instead of "at yesterday". Your type set doesn't define it, so that
special case never happens.

**How to fix.** Define the relation if you want the behaviour, or ignore the
note.

---

### MISSING-GENERATION-ROOT

**WARN, or INFO for `SITUATION`.** **What it means.** The generator decides
how to say a concept by looking at where its type sits in the hierarchy.
A type under `ACT` or `EVENT` is a verb, under `ATTRIBUTE` an adjective,
under `MANNER` an adverb, under `PERSON` a "he/she/they", under `ANIMATE`
alive. Your type set lacks the named type, so every type that should be
under it is treated as the default instead. For example, with no `ACT` and
no `EVENT`, every verb is said as a noun. The message says what breaks for
that particular type.

**How to fix.** Add the named type to `concept-types.lisp` and put the
relevant types under it. The names are fixed: the generator looks for these
exact labels. If one type doesn't fit anywhere, you can set it directly
instead with a wording entry (`:pos`, `:animate-p`, `:human-p`; see
[lexicon-overrides.md](lexicon-overrides.md)). The full table of roots and
their effects is in
[generation-tables.md](generation-tables.md#the-expected-labels).

---

### PERSON-WITHOUT-GENDER

**INFO.** **What it means.** A type under `PERSON` has no gender recorded, so
a pronoun for it is "they". That's right for `CHILD` or `TEACHER`, wrong
for `FATHER` or `QUEEN`.

**How to fix.** Record the gender in `lexicon-overrides.lisp` beside your type
files:

```lisp
(:label father :gender :masc :human-p t)
(:label queen  :gender :fem  :human-p t)
```

If "they" is correct, say so to silence the note:

```lisp
(:label teacher :ungendered t)
```

---

### PERSON-CHECK-SKIPPED

**INFO.** **What it means.** There is no `PERSON` type, so the check above had
nothing to check. No gender findings here means "couldn't look", not "all
fine". There will also be a [MISSING-GENERATION-ROOT](#missing-generation-root)
finding for `PERSON`; fix that one.

---

### UNKNOWN-LEXICON-KEY

**ERROR.** **What it means.** A wording entry (in `lexicon-overrides.lisp`, or
a `register-lexicon-entry` call) uses a key that nothing reads. It's
usually misspelled: `:mass` for `:mass-p`, `:gendr` for `:gender`. The entry
is accepted and does nothing. The message lists the valid keys.

**How to fix.** Correct the key. [lexicon-overrides.md](lexicon-overrides.md)
describes every key.

---

### UNIMPLEMENTED-LEXICON-KEY

**ERROR.** **What it means.** The key is a real, documented key, but nothing
reads it yet, so the entry does nothing. (`:past` and `:gerund` are the
usual cases.)

**How to fix.** The message says what to use instead. For verb forms, that is
a row in `*irregular-verbs*`.

---

### STALE-LEXICON-OVERRIDE

**INFO, and normal.** **What it means.** A wording entry names a type your
type set doesn't define. CGraph ships wording for a lot of common words, and
most type sets define only some of them, so many of these are expected.

**How to fix.** Nothing, unless the type is one of yours and was renamed. In
that case update the `:label` in `lexicon-overrides.lisp`.

---

### MALFORMED-TABLE-ROW

**ERROR.** **What it means.** A row in one of the word-form tables
(`*irregular-verbs*`, `*irregular-plurals*`, …) has the wrong number of
entries or a non-string in it. A short row makes the missing form fall back
to the regular rule ("bes" for "is"). A non-string causes a Lisp error later,
somewhere far from the table.

**How to fix.** The message shows the row and the columns it should have.
Fix it where the table is defined or where you added to it.

---

### DUPLICATE-TABLE-KEY

**WARN.** **What it means.** A word has two rows in the same word-form table.
Only the first is ever used.

**How to fix.** Delete one, keeping the right forms.

---

### REDUNDANT-IRREGULAR-ROW

**INFO.** **What it means.** A row in an irregular-forms table gives exactly
the forms the regular rules would produce anyway, so it changes nothing.

**How to fix.** Optional: delete the row.

---

### ENGLISH-COLLISION

**INFO.** **What it means.** Two things in your type set come out as the same
English word: two concept types, or a concept type and a relation. This
may mean one of them is a duplicate, for example a `CONTAINS` concept when the
`CNTNS` relation already says "contains". It may also be deliberate:
`EMAIL` the medium and `EMAIL-MESSAGE` the message are both "email" in
English.

**How to fix.** If they mean the same thing, remove one. If they don't, mark
the one you've settled on so the note stops appearing:

```lisp
(:label email-message :synonym-ok t)
```

---

## Lisp errors

These stop the operation and open the debugger. The name is the condition
type. Most print a message that says what went wrong.

### cgraph-parse-error

"Can't parse the graph: …", followed by the line with a caret (`^`) under the
problem. `parse-cgraph` or `make-cgraph` was given a graph string it can't
read. Common causes: unbalanced `[ ]` or `( )`, a missing arrow, a relation
written as `→(rel)` where a concept with several relations needs the
fork marker (`[EAT]- (agnt)→[DOG] (obj)→[CAKE]`), or a comma between the
arcs of one fork. Those arcs are separated by spaces. A comma ends a fork
nested inside another and goes back to the outer one:
`[EAT]- (agnt)→[CAT]- (attr)→[OLD], (obj)→[FOOD]`. See the
[tutorial](tutorial.md) for the notation.

`parse-cgif` and `read-cgif-graphs` signal it too, for CGIF text, with the
caret in that text. See [cgif.md](cgif.md).

### cgif-unsupported

"Can't write [X] as … CGIF: … has no standard CGIF form". `format-cgif` or
`write-cgif-graphs` was asked to write something its mode can't: a set, a
measure or a quantifier like `@most` outside `:mode :lossless`, anything
`:strict` would have to leave out, or a negated concept holding no graph,
`~[CAT]`, which has no CGIF form at all. The message says which. Use
`:mode :lossless` to keep cgraph's own notation (other tools may not read
it), or change the graph. See [cgif.md](cgif.md#modes).

### cgif-dropped (warning)

"Writing [X] as CGIF left out …". In `:mode :portable`, the default,
`format-cgif` writes standard CGIF and leaves out what has no logical meaning
there: the individual marker `#`, and `@past` and the other annotations. The
CGIF is still correct; it says less. `:mode :lossless` keeps them, and
`:mode :strict` refuses instead.

### concept-type-lookup-failed

A concept type name isn't in the catalog. Usually a typo in a graph or a
type definition, or a type used before the file that defines it was loaded.
Check the name with `(cg::get-concept-type 'name)`, or look in the type
browser.

### concept-type-alias-conflict

A type's `:aliases` clash with something already named: the alias is already
a type's label, or another type's alias, or it names an alias rather than a
real type. Also signalled when a type is defined under a name that is already
an alias, since defining it would change the type the alias names. The
message says which name and what it collides with. Rename one of them.

### relation-type-lookup-failed

The same for a relation name. If this happens only in the web UI, for a
relation that does exist, the running server probably has old code. Reload
with `(asdf:load-system :cgraph :force t)`, then re-initialize.

### relation-signature-mismatch

A concept was linked to a relation that doesn't allow its type. Each relation
says which types it connects. For example, `agnt` goes from an `ACT` to an
`ANIMATE`, so `[ROCK]` can't be its destination. The message names the
relation, the side, the allowed types and the type you gave. Fix the graph,
or widen the relation's `:source-types` / `:dest-type` in
`relation-types.lisp` if the relation really should allow it.

### types-read-only

You tried to save type changes to the types that ship with CGraph, which
are read-only. Make your own copy and switch to it:

```lisp
(cg:create-type-set "mine")
```

See [setup.md](setup.md) for type sets.

### cached-concept-lookup-failed

An internal lookup of a concept in the current context failed. If you see
this without having called internal functions directly, it's a bug. Please
report it with the graph that caused it.

### editor-operation-error, referent-edit-error

The graph editor refused an edit, for example a reference to a node that no
longer exists or a modifier it doesn't support. The message says why. If it
happens from ordinary clicking in the editor, it's a bug.
