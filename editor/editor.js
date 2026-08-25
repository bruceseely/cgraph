// CGraph editor — the working loop.
//
// Design: notes/graph-editor.md
//
// The edit primitive is one arc. The editor pane holds a focus concept, a
// relation and a target concept; Add attaches that arc; each line of the
// display pane can remove one. Where you click decides what a concept MEANS:
// clicking in the graph pane references an existing node, clicking a type in
// the right-hand column creates a new one.

const params  = new URLSearchParams(location.search);
const SESSION = params.get('session');
// Where UPDATE/CANCEL should return to, when this session was opened by another
// page rather than by a REPL call. Restricted to a same-origin PATH: it comes
// off the URL, and a full URL here would let a crafted link bounce someone off
// this page to anywhere.
const BACK = (() => {
  const b = params.get('back');
  return b && b.startsWith('/') && !b.startsWith('//') ? b : null;
})();

const $ = id => document.getElementById(id);
const graphEl     = $('graph');
const slotFocus   = $('slot-focus');
const slotRel     = $('slot-relation');
const slotTarget  = $('slot-target');
const arrowLeft   = $('arrow-left');
const arrowRight  = $('arrow-right');
const conceptList = $('concept-list');
const relationList= $('relation-list');
const displayBody = $('display-body');
const statusEl    = $('status');
const englishEl   = $('english');

$('session-label').textContent = SESSION ? `session ${SESSION}` : '(no session)';

// ── editor-pane state ────────────────────────────────────────────────────────
// focus/target hold {ref, text} for an existing node, or {type} for a concept
// that does not exist yet. relation holds {label, direction, legal}, where
// `legal' is the directions the lattice permits for the pane's current pair --
// [] , ['forward'], ['reverse'] or both. A boolean "is it symmetric" cannot
// express the case that matters here, an arc pointing the ONE way that is not
// allowed, so the set is carried instead and REFRESH reconciles it.
// REPLACING holds the node-ref of an arc pulled in from the display pane. It is
// the difference between "attach this" and "put this here instead": with it set,
// the relation slot is not yours to choose -- the arc already decided -- and the
// commit goes to /api/editor/replace.
const pane = { focus: null, relation: null, target: null,
               replacing: null, pulledTarget: null };

const OPPOSITE = d => (d === 'reverse' ? 'forward' : 'reverse');
// The focus's current arcs, as the display pane last showed them. Kept so that
// picking a target already joined to the focus can fill the relation in for
// you — the link exists, so there is nothing to choose.
let focusArcs = [];
// The target slot is highlighted as the place the next pick will land. Purely a
// cue: with a focus set, a concept type or a graph concept goes to the target
// whether or not this is on. It is what a pull raises to say "this is the one
// you are changing", and clicking the slot raises it to say the same thing.
let armedTarget = false;

// Declared up here, ahead of its first reader, rather than beside the rest of
// the orphan handling below: setStatus is called from everywhere and a `let'
// read before its declaration is evaluated is a ReferenceError, not a NIL.
let orphaned = false;

function setStatus(msg, kind) {
  // Once the session is gone every request fails, and each failure would write
  // its error here — underneath the veil that already explains it, and after
  // NOTE-SESSION-GONE cleared the line. Announcing it once means refusing to
  // announce it again, and doing that here covers every caller rather than
  // asking each catch to remember.
  if (orphaned) return;
  statusEl.textContent = msg || '';
  statusEl.className = kind || '';
}

// A page can outlive its session: EDIT-CGRAPH's UNWIND-PROTECT forgets the
// session, so a C-c C-c in the blocked REPL, or a CANCEL-EDITOR-SESSION from
// another buffer, leaves this tab talking to a server that has never heard of
// it. Every request then fails identically and forever, and REFRESH's catch
// returns before the line that clears the status — so the red message is not
// merely sticky, it is unclearable, because it is true again the moment you
// try anything. That is not an error to report over and over; it is a state to
// announce once. The veil already exists for exactly this.
const SESSION_GONE = /no such editor session|session is already finished/i;
// `orphaned' itself is declared above setStatus, which reads it.

function noteSessionGone() {
  if (orphaned) return;
  orphaned = true;
  finished = true;                 // its browser leaving is no longer news
  document.querySelectorAll('button').forEach(b => b.disabled = true);
  setStatus('');                   // the veil says it, where you are looking
  showVeil('orphaned');
}

async function call(url, opts) {
  const resp = await fetch(url, opts);
  const data = await resp.json().catch(() => ({ ok: false, error: `HTTP ${resp.status}` }));
  if (!resp.ok || !data.ok) {
    const message = data.error || `HTTP ${resp.status}`;
    if (SESSION_GONE.test(message)) noteSessionGone();
    throw new Error(message);
  }
  return data;
}

const q = obj => Object.entries(obj)
  .filter(([, v]) => v !== null && v !== undefined && v !== '')
  .map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');

// ── graph pane ───────────────────────────────────────────────────────────────
// The server renders with node-refs: "[DOG +404]". Refs travel outbound only —
// they are stripped for display and kept as click targets. A single forward
// scan with a bracket stack handles nesting, where the ref sits just before the
// closing bracket of its own node: "[BELIEF: [DOG +393]…  +400]".

function renderGraph(withRefs) {
  graphEl.replaceChildren();
  if (!withRefs) {
    const em = document.createElement('span');
    em.className = 'cg-empty';
    em.textContent = '(empty graph — click a concept type to start)';
    graphEl.append(em);
    return;
  }

  const stack = [];          // open brackets: {kind, node}
  let text = '';             // pending plain text for the current level

  const flush = target => {
    if (text) { target.append(document.createTextNode(text)); text = ''; }
  };

  for (let i = 0; i < withRefs.length; i++) {
    const c = withRefs[i];

    // " +NNN" immediately before a closing bracket is the ref of the node that
    // bracket belongs to — consume it rather than displaying it.
    if (c === '+' && stack.length) {
      const m = /^\+(\d+)\s*(?=[\])])/.exec(withRefs.slice(i));
      if (m) {
        stack[stack.length - 1].ref = Number(m[1]);
        text = text.replace(/\s+$/, '');   // drop the space that preceded it
        i += m[0].length - 1;
        continue;
      }
    }

    if (c === '[' || c === '(') {
      flush(stack.length ? stack[stack.length - 1].node : graphEl);
      const span = document.createElement('span');
      span.className = c === '[' ? 'cg-concept' : 'cg-relation';
      span.append(document.createTextNode(c));
      stack.push({ kind: c, node: span, ref: null });
      continue;
    }

    if ((c === ']' || c === ')') && stack.length) {
      const top = stack[stack.length - 1];
      flush(top.node);
      top.node.append(document.createTextNode(c));
      stack.pop();
      if (top.ref !== null && top.kind === '[') top.node.dataset.ref = top.ref;
      if (top.kind !== '[') top.node.classList.remove('cg-concept');
      (stack.length ? stack[stack.length - 1].node : graphEl).append(top.node);
      continue;
    }

    text += c;
  }
  flush(stack.length ? stack[stack.length - 1].node : graphEl);

  // Concepts are clickable; relations deliberately are not.
  graphEl.querySelectorAll('.cg-concept[data-ref]').forEach(el => {
    const ref = Number(el.dataset.ref);
    if (pane.focus  && pane.focus.ref  === ref) el.classList.add('is-focus');
    if (pane.target && pane.target.ref === ref) el.classList.add('is-target');
    el.addEventListener('click', ev => {
      ev.stopPropagation();
      onGraphConceptClick(ref, el.textContent);
    });
  });
}

// Where you click decides the meaning: with the focus empty, a clicked concept
// becomes the focus; with it occupied, the click becomes the target — an arc to
// an EXISTING node, which is how two paths come to share one.
function onGraphConceptClick(ref, text) {
  const label = text.replace(/\s+/g, ' ').trim();
  if (!pane.focus) {
    setFocus({ ref, text: label });
  } else {
    armedTarget = false;               // the pick has landed; stop pointing at it
    pane.target = { ref, text: label };
    // If the two are already joined, fill the relation in rather than making
    // you re-pick what the graph already says. `legal' is filled by the next
    // choices fetch, which is what decides whether the arrows can be flipped.
    // Filling it is also what lets ADOPTMATCHINGARC see that this row is an arc
    // the graph already has, so this shortcut lands in Replace rather than one
    // click away from a duplicate.
    const existing = focusArcs.find(a => a.conceptRef === ref);
    if (existing && !pane.relation) {
      pane.relation = { label: existing.relation,
                        direction: existing.direction,
                        legal: null };
    }
  }
  refresh();
}

// Moving the focus empties the rest of the pane. A relation and a target belong
// to the arc you were building FROM the old focus, and a pull is a statement
// about one arc of one focus — move it and none of that is about anything. The
// three roads to a new focus all come through here, so the reset is stated once
// rather than remembered three times.
function setFocus(node) {
  pane.focus = node;
  pane.relation = pane.target = null;
  pane.replacing = pane.pulledTarget = null;
  armedTarget = false;
}

// ── editor pane ──────────────────────────────────────────────────────────────

function slotText(slot) {
  if (!slot) return null;
  if (slot.ref !== undefined && slot.ref !== null) return slot.text;
  return `[${slot.type.toUpperCase()}]`;
}

// The two concept slots are one click target each, and they mean different
// things — which is the point. A concept can be reached by more than one path,
// so "change the driver" and "change Dave" are different edits and must not
// share a gesture:
//
//   FOCUS   opens the referent. The focus is the cursor; the referent is what
//           that concept IS, and editing it shows up on every path that reaches
//           it — [PERSON: dave] renamed is renamed for the poss arc too.
//   TARGET  is the far end of the arc being built or changed. Clicking it says
//           "this is the one I am replacing" — it raises the highlight; the
//           replacement itself comes from the concept-type column or the graph.
//
// Neither slot retypes a concept. There is no such operation, deliberately:
// see EDITOR-REPLACE-TARGET's docstring — a concept may be the far end of
// several arcs, so retyping edits every path that reaches it.
function paintSlot(el, slot, placeholder, kind) {
  el.replaceChildren();
  el.classList.toggle('empty', !slot);
  el.classList.toggle('armed', kind === 'target' && armedTarget);
  // Cleared here, set below by whichever branch has something to say: an
  // emptied slot that kept the last one's cursor and tooltip would go on
  // advertising an edit that left with its concept.
  el.classList.remove('live');
  el.title = '';
  if (!slot) { el.textContent = placeholder; return; }

  if (kind === 'relation') { el.textContent = `(${slot.label})`; return; }

  // The focus slot is live only for a concept that EXISTS — a slot holding a
  // type the graph has not been given yet has no node-ref, so there is nothing
  // for the referent pane to edit until Add creates it. Then it says so and
  // does nothing, rather than looking clickable and going nowhere.
  const text = slotText(slot);
  const live = kind === 'target' || (slot.ref !== undefined && slot.ref !== null);
  if (live) el.classList.add('live');
  el.title = kind === 'target'
    ? 'the concept this arc points at — pick a concept type, or a concept in the graph, to put a different one here'
    : (live ? 'edit the referent'
            : 'add this concept to the graph before editing its referent');

  const m = /^\[([^\]:]+)(?::(.*))?\]$/.exec(text);
  if (!m) { el.textContent = text; return; }

  el.append(document.createTextNode(`[${m[1].trim()}`));

  const ref = document.createElement('span');
  ref.className = 'zone-ref';
  // An empty referent is still shown as one, or a generic concept would be the
  // one case with nothing there to tell you what the click is going to open.
  ref.textContent = m[2] !== undefined ? `: ${m[2].trim()}` : ': —';
  el.append(ref);
  el.append(document.createTextNode(']'));
}

// Bound once, not in PAINTSLOT — that runs on every refresh and would stack up
// a listener per repaint. Both read the pane at click time rather than closing
// over the slot they were painted with.
slotFocus.addEventListener('click', () => {
  const slot = pane.focus;
  if (!slot || slot.ref === undefined || slot.ref === null) return;
  openReferent(slot.ref, slotText(slot));
});

slotTarget.addEventListener('click', () => {
  if (!pane.target) return;
  armedTarget = !armedTarget;
  paintEditor();
});

// The arrows ARE the reverse control. They are live whenever the OPPOSITE
// direction is legal -- not merely when both are, which was the original test.
// The two differ in exactly the case you most need the control: an arc pointing
// the one way the lattice forbids, where the old test froze the arrows and left
// no way out but a reload. Static now means "one legal direction, and it is the
// one shown", which is still an honest reading of a dead affordance.
function flippable(rel) {
  return !!(rel && rel.legal && rel.legal.includes(OPPOSITE(rel.direction)));
}

function paintArrows() {
  const rel = pane.relation;
  const shown = rel ? (rel.direction === 'reverse' ? '←' : '→') : '';
  const live = flippable(rel);
  [arrowLeft, arrowRight].forEach(a => {
    a.textContent = shown;
    a.className = 'arrow' + (live ? ' flippable' : '');
    a.title = live ? 'click to reverse the arc' : '';
  });
}

function paintEditor() {
  paintSlot(slotFocus,  pane.focus,    'focus concept', 'focus');
  paintSlot(slotRel,    pane.relation, 'relation',      'relation');
  paintSlot(slotTarget, pane.target,   'concept',       'target');
  paintArrows();
  // A pulled arc commits as a replacement, and says so: the same button doing
  // two different things silently is how you delete a branch you meant to keep.
  // It stays disabled until the target actually differs from what is there now,
  // since replacing a concept with itself is a destructive no-op.
  const pulled = pane.replacing !== null && pane.replacing !== undefined;
  const changed = pulled && pane.target
                  && !(pane.target.ref !== undefined && pane.target.ref !== null
                       && pane.target.ref === pane.pulledTarget);
  $('add').textContent = pulled ? 'Replace' : 'Add';
  $('add').classList.toggle('replacing', pulled);
  $('add').disabled = !(pane.focus && pane.focus.ref !== undefined
                        && pane.relation && pane.target
                        && (!pulled || changed));
}

[arrowLeft, arrowRight].forEach(a => a.addEventListener('click', () => {
  if (!flippable(pane.relation)) return;
  pane.relation.direction = OPPOSITE(pane.relation.direction);
  refresh();
}));

$('clear').addEventListener('click', () => {
  setFocus(null);          // an empty focus empties everything else with it
  refresh();
});

// ── type columns ─────────────────────────────────────────────────────────────

// The filters narrow the list the LATTICE already narrowed, and they ask the
// server nothing: the choices are whatever the last fetch produced, so typing
// is instant and a filter survives every refresh — which matters, because
// almost everything you do here refreshes.
//
// Matching is by prefix, on the whole name or on any hyphen-separated part of
// it: `exchange' finds COMMERCIAL-EXCHANGE and `stage' finds LIFE-STAGE. Plain
// substring matching would file BREAKFAST-EVENT under `ast', which is noise in
// a vocabulary this hyphenated; whole-string prefix alone would make the second
// half of every compound name unreachable.
//
// A relation matches on either half of what its row shows, the label or the
// long name, because `agnt' and `agent' are both things you would type for the
// same row.
let lastConcepts = [];
let lastRelations = [];

function filterQuery(id) { return $(id).value.trim().toLowerCase(); }

function matchesFilter(text, q) {
  if (!q) return true;
  const s = String(text || '').toLowerCase();
  return s.startsWith(q) || s.split(/[-\s/]+/).some(part => part.startsWith(q));
}

// Called with data by REFRESH, and with none by the filter box — the list is
// repainted from the same choices either way.
function paintConceptList(types) {
  if (types) lastConcepts = types;
  // Almost everything refreshes, and a repaint would take the half-typed form
  // with it. The form closes itself on Create, Cancel or Escape.
  if (creatingType) return;
  const q = filterQuery('concept-filter');
  const shown = lastConcepts.filter(t => matchesFilter(t, q));
  conceptList.replaceChildren();
  if (!lastConcepts.length) {
    conceptList.innerHTML = '<div class="type-empty">no consistent types</div>';
    return;
  }
  // Distinct from the line above on purpose: "the lattice offers nothing" and
  // "your filter matches nothing" are different problems, and a filter you have
  // forgotten looks exactly like the first one.
  if (!shown.length) {
    // The moment a type you wanted turns out not to exist is exactly here, so
    // this is where the offer to make it belongs — rather than a "+ new type"
    // button standing permanently in a column whose whole job is to show you
    // what is already legal.
    conceptList.replaceChildren(missingTypeOffer(q));
    return;
  }
  for (const t of shown) {
    const el = document.createElement('div');
    el.className = 'type-item';
    el.textContent = t;
    el.addEventListener('click', () => onConceptTypeClick(t));
    conceptList.append(el);
  }
}

// ── Creating a concept type from here ────────────────────────────────────────
//
// The wrinkle this has to solve, and the reason the supertype is not free
// choice: while a relation is picked, this column is not the catalog, it is
// what `rel-far-end-types' says may legally go in the slot. A type created
// under the wrong parent is legal, saved, and INVISIBLE in the very slot you
// made it for — which reads as the create having silently failed.
//
// So the supertype menu is drawn from THIS LIST. Every entry in it is admissible
// here, `rel-far-end-types' returns each root with its whole subtree, and a
// subtype of anything admissible is admissible — so whatever you pick, the new
// type appears in the slot on the next refresh. That is the guarantee; the menu
// is narrow on purpose, not for lack of ambition.
//
// It is also why this is worth building at all rather than sending you to the
// type browser: over there you would have to work out which parent makes the
// type usable back here.

let creatingType = false;   // the inline form is open; keeps repaints from eating it

function missingTypeOffer(q) {
  const box = document.createElement('div');
  box.className = 'type-empty';
  box.append(`nothing here starts with “${q}” — Esc clears the filter, or `);
  const link = document.createElement('a');
  link.className = 'make-type';
  link.textContent = `create ${q}`;
  link.addEventListener('click', () => openNewTypeForm(q));
  box.append(link);
  return box;
}

function openNewTypeForm(name) {
  if (!lastConcepts.length) { setStatus('nothing legal here to inherit from', 'error'); return; }
  creatingType = true;
  const form = document.createElement('div');
  form.className = 'new-type';

  const label = document.createElement('input');
  label.type = 'text';
  label.value = name;
  label.spellcheck = false;
  label.autocomplete = 'off';

  const supers = document.createElement('select');
  supers.title = 'the new type inherits from this — every choice here is legal in this slot';
  for (const t of lastConcepts) {
    const opt = document.createElement('option');
    opt.value = t;
    opt.textContent = t;
    supers.append(opt);
  }
  // The slot's current proposal is the best default there is: picking a type and
  // then wanting a narrower one is why you are here at all.
  if (pane.target && pane.target.type && lastConcepts.includes(pane.target.type))
    supers.value = pane.target.type;

  const row = document.createElement('div');
  row.className = 'new-type-row';
  const sub = document.createElement('span');
  sub.className = 'sub';
  sub.textContent = '⊑';
  row.append(sub, supers);

  const buttons = document.createElement('div');
  buttons.className = 'new-type-row';
  const create = document.createElement('button');
  create.textContent = 'Create';
  const cancel = document.createElement('button');
  cancel.textContent = 'Cancel';
  buttons.append(create, cancel);

  const submit = () => createConceptType(label.value.trim(), supers.value);
  create.addEventListener('click', submit);
  cancel.addEventListener('click', () => { creatingType = false; paintConceptList(); });
  label.addEventListener('keydown', ev => {
    if (ev.key === 'Enter')  { ev.preventDefault(); submit(); }
    if (ev.key === 'Escape') { ev.preventDefault(); creatingType = false; paintConceptList(); }
  });

  form.append(label, row, buttons);
  conceptList.replaceChildren(form);
  label.focus();
  label.select();
}

async function createConceptType(name, supertype) {
  if (!name) { setStatus('a type name is required', 'error'); return; }
  setStatus('creating…');
  try {
    // The type browser's endpoint, unchanged — the editor shares its acceptor
    // and origin, so there is nothing to add on the server for this.
    const url = `/api/create-type?label=${encodeURIComponent(name)}`
              + `&supertypes=${encodeURIComponent(supertype)}`;
    const resp = await fetch(url, { method: 'POST' });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || !data.ok) { setStatus(data.error || `failed: ${resp.status}`, 'error'); return; }
    creatingType = false;
    setStatus('');
    // The catalog is process-global and /api/editor/choices reads it live, so
    // the new type is in the next fetch with nothing else to do. Then put it
    // where you were reaching for it: a create that left you to find and click
    // the thing you just named would have done half the job.
    await refresh();
    onConceptTypeClick(data.label);
  } catch (err) {
    setStatus(err.message, 'error');
  }
}

function relationRow(r) {
  const el = document.createElement('div');
  el.className = 'type-item';
  const dir = document.createElement('span');
  dir.className = 'dir';
  dir.textContent = r.direction === 'reverse' ? '← ' : '→ ';
  el.append(dir, document.createTextNode(r.label));
  if (r.name && r.name.toLowerCase() !== r.label.toLowerCase()) {
    const long = document.createElement('span');
    long.className = 'long';
    long.textContent = `  ${r.name}`;
    el.append(long);
  }
  el.addEventListener('click', () => {
    // A different relation is a different claim, so picking one ends any pull.
    // /api/editor/replace keeps the arc's OWN relation type — it replaces the
    // concept, not the claim — so a pull that survived this would commit the
    // relation still in the graph while the pane showed the one you just
    // picked. If the pick happens to restore the arc the row came from,
    // ADOPTMATCHINGARC picks the pull back up on the way through refresh.
    pane.replacing = pane.pulledTarget = null;
    // Seed `legal' from what this very list says, so the arrows are right on
    // the first paint rather than after the next fetch corrects them.
    pane.relation = { label: r.label, direction: r.direction,
                      legal: r.both ? ['forward', 'reverse'] : [r.direction] };
    refresh();
  });
  return el;
}

// Grouped by direction, then alphabetical within each group -- rather than one
// alphabetical list with the arrows interleaved.
//
// Direction is not a property of the relation, it is half of what you are
// choosing, so it groups rather than decorates. The two groups answer two
// different questions in the order you would ask them: what can the focus do,
// then what can be done to it. It also separates the twins -- a relation legal
// both ways otherwise renders as two near-identical adjacent rows, which reads
// like a glitch and is precisely the pair that is easy to mis-pick.
//
// The per-row arrow stays even though the heading now implies it: it is the
// same glyph the editor pane will show, and it survives scrolling past the
// heading.
function paintRelationList(rels) {
  if (rels) lastRelations = rels;
  const q = filterQuery('relation-filter');
  // Either half of the row: the label you would type from memory, or the long
  // name you would type if you did not remember the label.
  const shown = lastRelations.filter(r => matchesFilter(r.label, q)
                                       || matchesFilter(r.name, q));
  relationList.replaceChildren();
  if (!lastRelations.length) {
    relationList.innerHTML = '<div class="type-empty">no consistent relations</div>';
    return;
  }
  if (!shown.length) {
    relationList.innerHTML =
      `<div class="type-empty">nothing here starts with “${q}” — Esc clears the filter</div>`;
    return;
  }

  const here = pane.focus ? (slotText(pane.focus) || 'the focus') : 'the focus';
  const groups = [
    ['forward', `from ${here}`],
    ['reverse', `into ${here}`]
  ];

  for (const [direction, heading] of groups) {
    const rows = shown.filter(r => r.direction === direction)
                     .sort((a, b) => a.label.localeCompare(b.label));
    if (!rows.length) continue;      // no heading for a group with nothing in it
    const head = document.createElement('div');
    head.className = 'group-head';
    head.textContent = heading;
    relationList.append(head);
    for (const r of rows) relationList.append(relationRow(r));
  }
}

// Repaint on every keystroke — no round trip, so there is nothing to debounce.
// Escape clears, which is the one gesture worth having: a filter is the sort of
// thing you leave behind, and the column it applies to may be scrolled well
// away from the box by then.
for (const [id, repaint] of [['concept-filter',  () => paintConceptList()],
                             ['relation-filter', () => paintRelationList()]]) {
  const box = $(id);
  const x = $(`${id}-clear`);
  // The ✕ comes and goes with the text, unlike the display pane's, which always
  // has an arc to remove. It is the same rule the slots follow: a control that
  // cannot do anything should not be offered.
  const sync = () => {
    const live = !!box.value.trim();
    box.classList.toggle('on', live);
    x.hidden = !live;
    repaint();
  };
  x.addEventListener('click', () => { box.value = ''; sync(); box.focus(); });
  box.addEventListener('input', sync);
  box.addEventListener('keydown', ev => {
    if (ev.key === 'Escape') { box.value = ''; sync(); }
    // The lists commit nothing, so Enter has nothing to submit. Swallow it
    // rather than let it reach anything else that might be listening.
    if (ev.key === 'Enter') ev.preventDefault();
  });
}

// A type click always means a NEW concept of that type, and with a focus set it
// always lands in the target slot — whether the slot was empty, held a concept
// you had picked, or holds the far end of an arc you are replacing. Overwriting
// it is not destructive: nothing has been said to the graph until Add or
// Replace, and what the slot held was a proposal, not a node.
function onConceptTypeClick(type) {
  if (!pane.focus) {
    // CREATEFIRSTCONCEPT is for an EMPTY graph. With no focus but a graph on
    // screen -- which is every freshly loaded session over an existing graph --
    // there is nothing to attach a new concept to, and asking for one used to
    // leave the focus pointing at a node the graph did not contain. The server
    // refuses that now; saying it here means not making the round trip to be
    // told, and saying which click is the one that was wanted.
    if (graphHasConcepts()) {
      setStatus('click a concept in the graph to choose the focus first', 'note');
      return;
    }
    createFirstConcept(type);
    return;
  }
  armedTarget = false;                 // the pick has landed
  pane.target = { type };
  refresh();
}

// Whether the graph pane is showing anything. The rendered graph is the page's
// own record of what the session holds, so this needs no request.
function graphHasConcepts() {
  return !!graphEl.querySelector('.cg-concept[data-ref]');
}

// An empty graph gets its first node this way: the concept is created straight
// away and becomes the focus, since there is nothing to attach it to yet.
async function createFirstConcept(type) {
  try {
    const data = await call(`/api/editor/concept?${q({ session: SESSION, type })}`,
                            { method: 'POST' });
    setFocus({ ref: data.ref, text: `[${type.toUpperCase()}]` });
    renderGraph(data.withRefs);
    refreshEnglish();
    setStatus('');
    await refresh();
  } catch (err) { setStatus(err.message, 'error'); }
}

// ── Referent pane ────────────────────────────────────────────────────────────
// One concept's referent: an EXCLUSIVE identity plus modifiers that compose
// freely with it and with each other. That shape is the whole design — read as
// a list of forms the catalogue looks like modes to pick between, and it is
// not — so the panel is one selector plus independent controls, never a mode
// picker. See notes/graph-editor.md, "Referent editors".
//
// Every control sends ONE field. The server's setters each touch one field, so
// a request that changed two things could not fail cleanly in the middle.
//
// The tail is displayed and never edited: a feature need not be editable to be
// preserved, which is what stops the unbounded tail from being a design
// blocker. It is shown so you can see what you are carrying.

const refPane   = $('referent-pane');
const refKinds  = $('ref-kinds');
const refInputA = $('ref-input-a');
const refInputB = $('ref-input-b');

// [value, label, which inputs it needs]
//
// :VARIABLE is deliberately NOT offered, though the view reads it. A lone `*x'
// is dropped by the formatter on the very next render — a label only means
// something once a node is genuinely shared, and sharing is made by pointing
// two arcs at one node, not by typing a name for it. Offering the button would
// be offering an edit the system discards a moment later. Coreference is
// automatic; see that section of notes/graph-editor.md.
//
// Reading :VARIABLE still matters: a parse can produce one, and a view that
// could not see it would let an edit elsewhere overwrite it.
const REF_KINDS = [
  ['none',       '—',      []],
  ['coref',      '?x',     ['label']],
  ['individual', 'name',   ['name']],
  ['individual', '#n',     ['id']],
  // A set needs no input of its own: it arrives as `{*}', the generic
  // collection — "some dogs", which is what pressing this on a bare [DOG]
  // means, and the form a count attaches to. Members are added afterwards, one
  // identity at a time; `*' beside them says whether there are others.
  ['set',        '{…}',    []],
];
// `verbal' marks the three that only mean something on a type the realizer
// will conjugate. They are hidden on anything else — same show-only-real-
// choices rule the arc affordances follow: a control that cannot produce a
// legal result should not be offered.
//
// Quantifier is deliberately NOT gated. Universal quantification over an event
// is meaningful in CG ("every eating"), so `@every' on a verb is not the
// nonsense that `@past' on a dog is.
const MODIFIERS = [
  ['ref-quantifier', 'quantifier', ['', 'every', 'some'], false],
  ['ref-tense',      'tense',      ['', 'past', 'present', 'future'], true],
  ['ref-aspect',     'aspect',     ['', 'simple', 'progressive', 'perfect', 'perfect-progressive'], true],
  ['ref-voice',      'voice',      ['', 'active', 'passive'], true],
];

// Session id of the graph this one is nested inside, or null at the top level.
let nestedIn = null;

let refConcept = null;   // node-ref of the concept being edited, or null
let refView    = null;   // its last-known decomposition
// The id a clear detached, so the clear can be taken back. Clearing DETACHES an
// individual rather than destroying it — the individual keeps its properties
// and its id puts the whole thing back — but the panel stopped showing that id
// at exactly the moment it became the only way to return, which left an edit
// that was reversible in fact and irreversible in practice.
//
// Client-side and deliberately shallow: it lives as long as the panel is open
// on this concept, and any new identity supersedes it. It restores the
// INDIVIDUAL, not the referent as it stood — modifiers a Clear all also took
// belonged to the concept, not to the individual, and do not come back.
let detachedId = null;
// A kind chosen in the UI but not yet sent, because it needs a value the
// concept cannot supply. See chooseKind.
let refPending = null;

function refRowLabel(view) {
  // Which of the two individual buttons is "on" depends on what the concept
  // actually has, not on which one you last pressed.
  if (view.kind !== 'individual') return view.kind;
  return view.name ? 'individual:name' : 'individual:#n';
}

function paintReferent() {
  if (!refView) return;
  const active = refPending || refRowLabel(refView);

  refKinds.replaceChildren();
  for (const [kind, label, needs] of REF_KINDS) {
    const key = kind === 'individual' ? `individual:${label}` : kind;
    const b = document.createElement('button');
    b.className = 'kind-btn' + (key === active ? ' on' : '');
    b.textContent = label;
    b.addEventListener('click', () => chooseKind(kind, needs, key));
    refKinds.append(b);
  }

  // Only the inputs the current identity actually uses are shown — an id box
  // beside a coref label would be a field with nowhere to go.
  const needs = (REF_KINDS.find(([k, l]) =>
    (k === 'individual' ? `individual:${l}` : k) === active) || [,, []])[2];
  refInputA.hidden = !needs.includes('label') && !needs.includes('name');
  refInputB.hidden = !needs.includes('id');
  refInputA.placeholder = needs.includes('label') ? 'label' : 'name';
  // A pending kind is one the concept does not have yet, so there is nothing
  // of its own to prefill and the previous kind's text must not leak in.
  refInputA.value = refPending ? ''
                  : needs.includes('label') ? (refView.label || '')
                  : (refView.name || '');
  // The armed box says what leaving it empty will do, because that is the one
  // thing the `#n' button no longer does by itself.
  refInputB.placeholder = refPending ? 'id, or empty for #' : 'id';
  // Unlike the name box, an armed id box keeps the concept's own id rather than
  // clearing: it is the same individual either way, so prefilling makes "show
  // this by id instead of by name" one keystroke instead of a retype — and an
  // empty box here would mint a new individual on commit, silently dropping the
  // one the concept had.
  refInputB.value = refView.id === null || refView.id === undefined ? '' : String(refView.id);

  $('ref-preview').textContent = refView.identityText || '';

  // Only while the concept has no identity of its own: once it has one, the
  // offer is stale, and an undo button beside a referent it would overwrite is
  // worse than none.
  const was = $('ref-was');
  const offerable = detachedId !== null && refView.kind === 'none';
  was.hidden = !offerable;
  if (offerable) {
    was.textContent = `was #${detachedId}`;
    was.title = `Put individual #${detachedId} back, with the properties it kept. `
              + `Modifiers cleared alongside it belonged to the concept and do not return.`;
  }

  // The identity selector is meaningless for a graph referent, and the graph
  // control is meaningless without a type that can hold one, so they trade
  // places rather than sitting side by side pretending both apply.
  // Members, for a set. Each chip is an identity with its own ✕; removal is by
  // POSITION, so the order shown has to be the order the server holds.
  const isSet = refView.kind === 'set';
  $('ref-members-row').hidden = !isSet;
  if (isSet) {
    const box = $('ref-members');
    box.replaceChildren();
    const ms = refView.members || [];
    if (!ms.length) {
      const em = document.createElement('span');
      em.className = 'none';
      // `{*}' and `{}' are both memberless and are different referents, so the
      // line says which one you are looking at rather than one phrase for both.
      em.textContent = refView.open ? 'a generic plural — no members named'
                                    : 'the empty set';
      box.append(em);
    }
    ms.forEach((m, i) => {
      const chip = document.createElement('span');
      chip.className = 'member-chip';
      chip.append(document.createTextNode(m.name || `#${m.id}`));
      const x = document.createElement('span');
      x.className = 'x';
      x.textContent = '✕';
      x.title = 'remove this member';
      x.addEventListener('click', () => setRefField('set-remove', String(i)));
      chip.append(x);
      box.append(chip);
    });
    // On means `{…, *}'. It is a state of the referent rather than an action,
    // so it is painted from the view every time — pressing it is a request,
    // and the server may refuse (closing a set that carries a count).
    $('ref-open').classList.toggle('on', !!refView.open);
  }

  const graphy = !!refView.graphCompatible;
  $('ref-graph').hidden = !graphy;
  refKinds.hidden = graphy && refView.kind === 'graph';

  for (const [id, field, options, verbalOnly] of MODIFIERS) {
    const sel = $(id);
    if (!sel.dataset.built) {
      for (const o of options) {
        const opt = document.createElement('option');
        opt.value = o;
        opt.textContent = o === '' ? `${field} —` : o;
        sel.append(opt);
      }
      sel.dataset.built = '1';
      sel.addEventListener('change', () => setRefField(field, sel.value));
    }
    // A value already set outranks the gate: if the graph arrived carrying
    // [WISH: @past], hiding the control would hide the only way to remove it
    // and leave an annotation nothing on screen accounts for.
    sel.hidden = verbalOnly && !refView.verbal && !refView[field];
    sel.value = refView[field] || '';
    sel.classList.toggle('set', !!refView[field]);
  }

  const m = $('ref-measure');
  m.value = refView.measure ? `${refView.measure[0]} ${refView.measure[1]}`.trim() : '';
  // A count on a CLOSED set contradicts its own members: {Fido, Spot}@4 is a
  // set of two asserting it has four. Open the set — the `*' beside the members
  // — and the count has something to count, so this mirrors the server's rule
  // exactly rather than the blunter one it used while openness was invisible.
  // Hidden rather than offered, unless a count is already set, in which case
  // hiding it would hide the only way to remove it.
  m.hidden = isSet && !refView.open
             && (refView.members || []).length > 0 && !refView.measure;
  m.title = m.hidden ? '' : 'how many, for a set whose members are not all named';

  const tail = $('ref-tail');
  tail.replaceChildren();
  const keys = Object.keys(refView.tail || {});
  if (!keys.length) {
    const em = document.createElement('span');
    em.className = 'none';
    em.textContent = 'nothing beyond the fields above';
    tail.append(em);
  } else {
    tail.textContent = keys.map(k => `${k}: ${refView.tail[k]}`).join('   ');
  }
}

// Re-read one concept's rendered text out of the graph pane and push it
// everywhere the old text is being displayed.
function relabelConcept(ref) {
  const el = graphEl.querySelector(`.cg-concept[data-ref="${ref}"]`);
  if (!el) return;
  const text = el.textContent.replace(/\s+/g, ' ').trim();
  for (const slot of ['focus', 'target']) {
    if (pane[slot] && pane[slot].ref === ref) pane[slot].text = text;
  }
  for (const a of focusArcs) if (a.conceptRef === ref) a.concept = text;
  if (refConcept === ref) $('ref-subject').textContent = text;
}

async function openReferent(ref, label) {
  refConcept = ref;
  refPending = null;          // a half-chosen kind belongs to the concept it was chosen on
  detachedId = null;          // and so does a breadcrumb: #2 means nothing here
  $('ref-subject').textContent = label || '';
  try {
    const data = await call(`/api/editor/referent?${q({ session: SESSION, concept: ref })}`);
    refView = data.referent;
    refPane.hidden = false;
    paintReferent();
  } catch (err) { setStatus(err.message, 'error'); }
}

function closeReferent() {
  refPane.hidden = true;
  refConcept = null;
  refView = null;
  refPending = null;
  detachedId = null;
  // A message describes the action that produced it, and closing the panel
  // ends that action. Without this a refusal from the panel outlived the panel
  // itself, sitting at the bottom of a window with nothing left on screen to
  // explain it.
  setStatus('');
}

// Applying one field. The graph comes back with it, so the pane, the graph and
// the sentence all move together rather than drifting until the next refresh.
async function setRefField(field, value, extra = {}) {
  if (refConcept === null) return;
  // Read before the edit, since afterwards the id is exactly what is gone.
  // A clear leaves a breadcrumb; any other identity edit supersedes one,
  // because the concept now points somewhere and "was #2" would be offering to
  // undo something you have already replaced.
  const clearing = field === 'all' || (field === 'identity' && extra.kind === 'none');
  if (clearing) {
    const id = refView && refView.id;
    detachedId = typeof id === 'number' ? id : null;
  } else if (field === 'identity' || field.startsWith('set-')) {
    detachedId = null;
  }
  try {
    const data = await call(`/api/editor/referent/set?${q({
      session: SESSION, concept: refConcept, field, value, ...extra
    })}`, { method: 'POST' });
    refView = data.referent;
    renderGraph(data.withRefs);
    // The editor pane and the referent head hold a concept's text as it read when
    // it was CLICKED. Editing its referent changes that text, so without this
    // the graph says [PERSON: Mary] while the slot beside it still says
    // [PERSON: Sue] — the same concept, disagreeing with itself on screen.
    // The freshly rendered graph is the authority; re-read the label from it.
    relabelConcept(refConcept);
    paintReferent();
    refreshEnglish();
    setStatus('');
    await refresh({ keepGraph: true });
  } catch (err) { setStatus(err.message, 'error'); }
}

// One text box serves two different roles — a coref LABEL and an individual's
// NAME — so switching between kinds that use different roles must not carry
// the text across. It did, and clicking the button marked "?x" on [PERSON: Sue]
// produced "?sue": the name was silently repurposed as the label. The button
// has to mean what it says, so text is reused only when the role is unchanged
// (retyping a label, correcting a name) and otherwise the kind's own default
// applies.
function currentNeeds() {
  if (!refView) return [];
  const active = refPending || refRowLabel(refView);
  const entry = REF_KINDS.find(([k, l]) =>
    (k === 'individual' ? `individual:${l}` : k) === active);
  return entry ? entry[2] : [];
}

// A NAME is the one value the button cannot invent. `*x' and `?x' default to
// the conventional `x', but there is no sensible default name — the first
// version used "unnamed", which minted a real individual called that and made
// the sentence read "Unnamed eats a pie."
//
// So the button selects the KIND and the field supplies the VALUE: choosing
// `name' with nothing to go on arms the input and sends nothing until you type.
//
// An ID arms for a different reason. There IS a value to invent — a bare `#'
// is a legitimate referent, "specific but unidentified" — but inventing it on
// the press means every stray click on `#n' mints an individual and burns an
// id, and the concept you meant to point at #5 has to be corrected afterwards.
// So `#' becomes what a deliberate empty commit means rather than what a press
// means: press arms the box, Enter on a number attaches that individual, Enter
// on an empty box is the bare `#'. Both readings survive; only the accident is
// gone.
function chooseKind(kind, needs, key) {
  const was = currentNeeds();
  const keeps = role => was.includes(role);      // same slot as before?

  // Which box this kind fills, if any. Armed unless the box is already holding
  // a value for the SAME role — retyping a name or correcting an id goes
  // straight through, since the value is right there.
  //
  // `refPending !== key' is what tells a PRESS from the COMMIT that follows it.
  // Both arrive here; without it an empty box re-arms forever and the bare `#'
  // becomes unreachable, since the one way to ask for it is to commit nothing.
  const wants = needs.includes('name') ? 'name'
              : needs.includes('id')   ? 'id'
              : null;
  const box = wants === 'id' ? refInputB : refInputA;
  if (wants && refPending !== key && !(keeps(wants) && box.value.trim())) {
    refPending = key;
    paintReferent();
    box.focus();
    return;
  }

  const typed = refInputA.value.trim();

  const extra = { kind };
  if (needs.includes('label')) extra.label = (keeps('label') && typed) || 'x';
  if (needs.includes('name'))  extra.name  = typed;
  if (needs.includes('id'))    extra.id    = (keeps('id') && refInputB.value.trim()) || '#';
  refPending = null;
  setRefField('identity', '', extra);
}

// Committing a text field is Enter or blur, not every keystroke: each one is a
// server round trip that rewrites the graph.
for (const el of [refInputA, refInputB]) {
  el.addEventListener('keydown', ev => { if (ev.key === 'Enter') el.blur(); });
  el.addEventListener('blur', () => {
    if (!refView) return;
    const active = refPending || refRowLabel(refView);
    const entry = REF_KINDS.find(([k, l]) =>
      (k === 'individual' ? `individual:${l}` : k) === active);
    // An armed NAME with the box still empty stays armed: leaving a name box
    // blank is not a request to be named "". An armed ID committed empty is a
    // request, and a meaningful one — the bare `#' — so it goes through.
    if (!entry) return;
    if (refPending && entry[2].includes('name') && !refInputA.value.trim()) return;
    chooseKind(entry[0], entry[2], active);
  });
}
$('ref-measure').addEventListener('keydown', ev => { if (ev.key === 'Enter') ev.target.blur(); });
$('ref-measure').addEventListener('blur', ev => setRefField('measure', ev.target.value.trim()));
$('ref-close').addEventListener('click', closeReferent);

// "#7" names an existing individual; anything else is a name. One field rather
// than two, because a member is one identity and asking for both halves of it
// separately would make the common case (a name) cost an empty box.
function addSetMember() {
  const raw = $('ref-member-new').value.trim();
  if (!raw) return;
  $('ref-member-new').value = '';
  const extra = raw.startsWith('#') ? { id: raw } : { name: raw };
  setRefField('set-add', '', extra);
}
$('ref-member-add').addEventListener('click', addSetMember);
$('ref-member-new').addEventListener('keydown', ev => {
  if (ev.key === 'Enter') { ev.preventDefault(); addSetMember(); }
});

// Blank closes, "true" opens — the same convention `raising' uses, since both
// are booleans arriving as query parameters. The refusal it can meet (closing
// a set that carries a count) comes back as an error and leaves the toggle
// where it was, which is why the button is painted from the view rather than
// flipped on click.
$('ref-open').addEventListener('click', () => {
  if (!refView || refView.kind !== 'set') return;
  setRefField('set-open', refView.open ? '' : 'true');
});

// One request, not six: the server clears the whole referent, so there is no
// moment at which half of it is gone. A pending kind is abandoned too — it
// described an identity that no longer exists.
$('ref-clear').addEventListener('click', () => {
  refPending = null;
  setRefField('all', '');
});

// Taking the clear back. Goes through the ordinary identity setter, so the
// server does what it does for any other id — finds the individual, keeps its
// properties — and SETREFFIELD then drops the breadcrumb itself, this being an
// identity edit like any other.
$('ref-was').addEventListener('click', () => {
  if (detachedId === null) return;
  refPending = null;
  setRefField('identity', '', { kind: 'individual', id: String(detachedId) });
});

// Descend into a graph referent. The server opens a CHILD session over it and
// this page navigates there — the nested editor is the same editor, which is
// what makes the recursion fall out rather than needing to be built. Leaving
// this page is safe: sessions are resumable at their URL, which is what a
// disconnect already relies on, so coming back finds the parent as it was.
$('ref-graph').addEventListener('click', async () => {
  if (refConcept === null) return;
  try {
    const data = await call(`/api/editor/referent/graph?${q({
      session: SESSION, concept: refConcept
    })}`, { method: 'POST' });
    finished = true;        // navigating in is not a disconnect worth reporting
    location.href = data.url;
  } catch (err) { setStatus(err.message, 'error'); }
});

// ── English pane ─────────────────────────────────────────────────────────────
// Asked for only when the graph CHANGES — the add, the arc removal, the first
// concept, and the initial load. Not on REFRESH: that runs after every click,
// including the ones that merely fill the editor pane, and the sentence cannot
// have moved for any of them. Generation is the most expensive thing the editor
// can ask the server for, so it is worth asking only when the answer can differ.
//
// Deliberately not awaited by its callers, and it swallows its own errors into
// the pane rather than the status line: the sentence is a readout, and a graph
// the generator cannot yet realize is a normal thing to be holding mid-edit,
// not a failed edit.

function paintEnglish(text, note) {
  englishEl.replaceChildren();
  if (text) { englishEl.textContent = text; return; }
  const em = document.createElement('span');
  em.className = 'none';
  em.textContent = note || '—';
  englishEl.append(em);
}

async function refreshEnglish() {
  try {
    const data = await call(`/api/editor/text?${q({ session: SESSION })}`);
    paintEnglish(data.text, data.note);
  } catch (err) {
    // A dead session is not something to say about the graph. Leave the last
    // sentence standing; the veil explains why it stopped moving.
    if (orphaned) return;
    paintEnglish(null, err.message);
  }
}

// ── display pane ─────────────────────────────────────────────────────────────

function paintDisplay(arcs) {
  focusArcs = arcs || [];
  displayBody.replaceChildren();
  if (!pane.focus) {
    displayBody.innerHTML = '<div class="type-empty">no focus concept</div>';
    return;
  }
  if (!arcs || !arcs.length) {
    displayBody.innerHTML = '<div class="type-empty">nothing attached</div>';
    return;
  }
  for (const a of arcs) {
    const line = document.createElement('div');
    line.className = 'arc-line' + (pane.replacing === a.relationRef ? ' pulled' : '');
    const text = document.createElement('span');
    text.className = 'text';

    // The line has two click zones, on the same rule the graph pane uses: the
    // part you click is the part you get. The RELATION pulls the arc into the
    // editor to have its far end replaced; the CONCEPT focuses it, which is how
    // you move around and how you get off the current focus.
    const rev = a.direction === 'reverse';
    const rel = document.createElement('span');
    rel.className = 'zone-arc';
    rel.textContent = rev ? `←(${a.relation})←` : `→(${a.relation})→`;
    rel.title = 'replace the concept on this arc';
    rel.addEventListener('click', ev => {
      ev.stopPropagation();
      pullArc(a);
    });

    const con = document.createElement('span');
    con.className = 'zone-con';
    con.textContent = a.concept;
    con.title = 'focus this concept';
    con.addEventListener('click', ev => {
      ev.stopPropagation();
      setFocus({ ref: a.conceptRef, text: a.concept });
      refresh();
    });
    text.append(rel, con);
    // What the line costs. The pane shows one hop and removal acts on every hop
    // behind it, so an arc to a leaf and an arc holding a whole branch look
    // alike without this -- as does an arc whose far end is coreferent and
    // survives, which is the case a mere arc-count would flag hardest and
    // wrongest. Silence means the removal is free.
    const cost = a.pruneCount || 0;
    const toll = document.createElement('span');
    toll.className = 'toll';
    if (cost) {
      toll.textContent = `⌫${cost}`;
      toll.title = cost === 1 ? 'removing this arc drops 1 concept'
                              : `removing this arc drops ${cost} concepts`;
    }

    const x = document.createElement('span');
    x.className = 'x';
    x.textContent = '✕';
    x.title = cost ? toll.title : 'remove this arc';
    x.addEventListener('click', () => removeArc(a.relationRef));
    line.append(text, toll, x);
    displayBody.append(line);
  }
}

// Load an existing arc into the editor so its far end can be swapped. The
// relation comes along and is NOT editable here: what is being replaced is the
// concept, not the claim. The old target is left showing in the slot so the row
// reads as the arc as it stands -- pick a type or a concept and it becomes the
// arc as it will stand. Nothing is committed, and nothing is destroyed, until
// Replace; Clear puts you back.
function pullArc(a) {
  pane.replacing = a.relationRef;
  pane.pulledTarget = a.conceptRef;   // what Replace stays disabled against
  pane.relation = { label: a.relation, direction: a.direction, legal: null };
  pane.target = { ref: a.conceptRef, text: a.concept };
  armedTarget = true;                 // the slot you are about to change
  refresh();
}

// There are two roads to a row that reproduces an arc the focus already has,
// and they must end in the same place. One is PULLARC. The other is building
// the row by hand -- click the focus, then click that concept in the graph, and
// the relation fills itself in from the arc that joins them. The second used to
// leave the pane in ADD, one click from giving the focus a second identical
// arc, which nothing on either side refuses: PAINTEDITOR only checks the three
// slots are full, and EDITOR-ADD-ARC type-checks without looking for a
// duplicate. So: when the row IS a line of the display pane, it is that line,
// and the commit is a replacement.
//
// Adopted once, at the moment the row matches. After that PANE.REPLACING is
// what carries the mode -- which is the whole point, since the next thing you
// do is change the target, and a rule re-tested on every refresh would drop
// back to Add the instant it stopped matching.
//
// Duplicate relations are NOT refused in general: [CAR]->(part)->[WHEEL] and
// ->(part)->[DOOR] are both wanted, and the lattice carries no cardinality to
// tell that case from a second (agnt). What is refused is the duplicate this
// can actually recognise -- the same relation, the same direction, the same
// concept on the far end.
function adoptMatchingArc() {
  if (pane.replacing !== null && pane.replacing !== undefined) return;
  const t = pane.target;
  if (!pane.focus || !pane.relation || !t) return;
  if (t.ref === undefined || t.ref === null) return;
  const same = (a, b) => String(a).toLowerCase() === String(b).toLowerCase();
  const match = focusArcs.find(a => a.conceptRef === t.ref
                                   && same(a.relation, pane.relation.label)
                                   && a.direction === pane.relation.direction);
  if (!match) return;
  pane.replacing = match.relationRef;
  pane.pulledTarget = match.conceptRef;
  armedTarget = true;
}

// The arc under a pull can go out from under it — another edit removes it, or
// a commit lands and the display pane is rebuilt. Then the mode is about
// nothing. Only run against a freshly fetched list: FOCUSARCS is a snapshot,
// and judging a pull against a stale one would cancel a live edit.
function verifyPull() {
  if (pane.replacing === null || pane.replacing === undefined) return;
  if (!focusArcs.some(a => a.relationRef === pane.replacing)) {
    pane.replacing = pane.pulledTarget = null;
  }
}

// ── operations ───────────────────────────────────────────────────────────────

$('add').addEventListener('click', async () => {
  const t = pane.target;
  const replacing = pane.replacing;
  try {
    const data = await call(
      replacing
        ? `/api/editor/replace?${q({
            session: SESSION,
            focus: pane.focus.ref,
            relation: replacing,
            target: (t.ref !== undefined && t.ref !== null) ? t.ref : null,
            target_type: t.type || null
          })}`
        : `/api/editor/add?${q({
            session: SESSION,
            focus: pane.focus.ref,
            relation: pane.relation.label,
            direction: pane.relation.direction,
            target: (t.ref !== undefined && t.ref !== null) ? t.ref : null,
            target_type: t.type || null
          })}`, { method: 'POST' });
    // The concept just built STAYS in the target slot, now carrying the ref the
    // server minted for it. A referent can only be edited on a node that
    // exists, so clearing the slot here -- which is what this used to do --
    // meant every new concept had to be hunted down again before it could be
    // named. The relation slot is cleared, which is what keeps Add disabled and
    // a second click from making a duplicate arc.
    pane.replacing = null;
    pane.relation = null;
    pane.target = (data.created !== undefined && data.created !== null)
      ? { ref: data.created, text: slotText(t) }
      : null;
    renderGraph(data.withRefs);
    paintDisplay(data.focus);
    refreshEnglish();
    setStatus('');
    await refresh({ keepGraph: true });
  } catch (err) { setStatus(err.message, 'error'); }
});

async function removeArc(relationRef) {
  try {
    const data = await call(`/api/editor/remove?${q({
      session: SESSION, focus: pane.focus.ref, relation: relationRef
    })}`, { method: 'POST' });
    pane.relation = pane.target = null;
    renderGraph(data.withRefs);
    paintDisplay(data.focus);
    refreshEnglish();
    setStatus('');
    await refresh({ keepGraph: true });
  } catch (err) { setStatus(err.message, 'error'); }
}

// A finished session is finished, and a page that still takes clicks can only
// argue back. Disabling the four BUTTONs was not enough -- the graph concepts,
// the type rows, the arrows and the display lines are divs and spans carrying
// their own handlers, so clicking one still called REFRESH, and the error it
// came back with overwrote the very message saying the session was over. That
// is the "populated but unresponsive" state: not inert, just uselessly
// responsive.
//
// The error it overwrote it with was "no such editor session", which is worse
// than it sounds. FINISH-EDITOR-SESSION only sets the state and wakes the
// waiting thread; EDIT-CGRAPH's UNWIND-PROTECT then FORGETs the session, so by
// the time you click, lookups fail outright rather than reporting a finished
// session. The page therefore accused itself of having lost your work at the
// exact moment it had in fact completed normally.
//
// So the veil covers everything and swallows the clicks, rather than each
// handler learning to check. Nothing underneath needs to know.
//
// It does not close the tab. window.close() only works on a window script
// opened, and this one was opened by the server shelling out to the OS, so the
// browser would refuse -- better to say plainly that the tab can be closed than
// to try and silently fail.
// Fourth slot is the hint under the card, fifth is whether to offer a way back
// to the type browser. A REPL-opened session has nowhere else to be, so it gets
// the hint and no link; a session the browser opened has somewhere, so it gets
// the link and no hint — the link says it, and saying it twice is worse.
//
// The link has to live INSIDE the card. The veil is `inset: 0` deliberately, so
// that nothing underneath can still be clicked, and the one in the bar is
// underneath it.
const CLOSE_HINT = 'This session is finished — you can close this tab.';

const VEIL_TEXT = {
  commit:   ['committed', 'Committed',
             'The edited graph was installed and the REPL call has returned.',
             CLOSE_HINT, false],
  cancel:   ['cancelled', 'Cancelled',
             'Nothing was changed — the original graph is untouched.',
             CLOSE_HINT, false],
  // A session opened from the type browser's header, rather than by a REPL call
  // or by the Draw button on the type form. Neither of the two sentences above
  // is true of it: nothing was installed and no call is waiting, and there is no
  // original graph for a cancel to leave untouched. So the veil is where the
  // graph is handed over — it is the only place it can be.
  webCommit: ['committed', 'Committed',
              'This session was opened from the type browser, so no caller is '
              + 'waiting to receive the graph. Here it is:',
              '', true],
  webCancel: ['cancelled', 'Cancelled',
              'Nothing was kept. This session was opened from the type browser '
              + 'as a scratch graph, with nowhere to install one.',
              '', true],
  // Not a failure of this page, and worth saying so: the work was not lost
  // here, it stopped being wanted there.
  orphaned: ['cancelled', 'Session ended',
             'The REPL call this page was editing is no longer waiting — it was '
             + 'interrupted, or the session was cancelled from elsewhere. '
             + 'Nothing here can reach it now.',
             CLOSE_HINT, false]
};

function showVeil(action, result) {
  const veil = $('veil');
  const [cls, headline, detail, hint, back] = VEIL_TEXT[action] || VEIL_TEXT.cancel;
  veil.className = cls;
  veil.querySelector('.headline').textContent = headline;
  veil.querySelector('.detail').textContent = detail;
  veil.querySelector('.hint').textContent = hint;
  veil.querySelector('.hint').hidden = !hint;
  veil.querySelector('.nav').hidden = !back;
  // An empty graph is a legitimate result and must not render as a blank box
  // claiming to hold something, so the slot is shown only for a non-empty one.
  const box = veil.querySelector('.result');
  box.textContent = result || '';
  box.hidden = !result;
  veil.hidden = false;
}

async function finish(action) {
  try {
    const data = await call(`/api/editor/finish?${q({ session: SESSION, action })}`,
                            { method: 'POST' });
    finished = true;   // closing the window now is not a disconnect worth reporting
    // A nested editor has somewhere to go back TO, so it goes there instead of
    // veiling. The veil means "this is over"; finishing a nested graph ends
    // that graph, not the session you are actually in.
    if (data.parent) { location.href = `/editor?session=${data.parent}`; return; }
    // Same rule one level out: a session the type browser opened returns to the
    // form that opened it, carrying the graph. There is no blocked caller to
    // hand it to, so the response IS the delivery — which is why it is stashed
    // before navigating rather than passed in the URL, where a graph would be
    // both unwieldy and visible in history.
    if (BACK) {
      if (data.result !== undefined)
        sessionStorage.setItem('cgraph.typeform.result', data.result);
      location.href = BACK;
      return;
    }
    document.querySelectorAll('button').forEach(b => b.disabled = true);
    setStatus('');     // the veil says it, and says it where you are looking
    // WEB comes from the server rather than being inferred from RESULT, which a
    // cancelled web session does not carry any more than a REPL one does.
    showVeil(data.web ? (action === 'commit' ? 'webCommit' : 'webCancel') : action,
             data.result);
  } catch (err) { setStatus(err.message, 'error'); }
}

$('update').addEventListener('click', () => finish('commit'));
$('cancel').addEventListener('click', () => finish('cancel'));

// Tell the server when this page goes away, so the waiting REPL learns its
// browser left rather than sitting blocked and looking exactly as it did while
// you were editing. This is a NOTICE, not a cancel — the session keeps its
// working graph and this same URL resumes it. pagehide fires on reload too,
// which is precisely why it must not discard anything.
//
// sendBeacon rather than fetch: a request started in a page that is unloading
// is otherwise liable to be cancelled before it leaves.
let finished = false;
window.addEventListener('pagehide', () => {
  if (finished || !SESSION) return;
  navigator.sendBeacon(`/api/editor/disconnect?session=${encodeURIComponent(SESSION)}`);
});

// ── refresh ──────────────────────────────────────────────────────────────────
// One place decides what the lists may contain, from what the editor pane
// holds. The lattice does the filtering; nothing here guesses.

async function refresh(opts = {}) {
  // A message describes the action that produced it, so it must not outlive the
  // next thing you do. Nothing used to clear it but a SUCCESSFUL add or remove,
  // which meant a failed add's error sat there through every subsequent click --
  // including Clear, making a pane that had in fact been emptied look stuck.
  let notice = opts.notice || null;
  // Before the first paint, so a row that turns out to be an existing arc never
  // shows Add for the instant it takes the fetch to come back.
  adoptMatchingArc();
  paintEditor();
  try {
    if (!opts.keepGraph) {
      const state = await call(`/api/editor/focus?${q({
        session: SESSION,
        focus: pane.focus && pane.focus.ref !== undefined ? pane.focus.ref : null
      })}`);
      renderGraph(state.withRefs);
      paintDisplay(state.focus);
      // FOCUSARCS is now the server's, not a snapshot: the only point at which
      // a pull can be judged still live, and at which a row assembled against
      // an older list gets a second look.
      verifyPull();
      adoptMatchingArc();
      // The page is loaded from a URL carrying only its own session id, so
      // this is the only way it learns it is a nested editor — and what UPDATE
      // should do depends on the answer.
      if (state.parent && !nestedIn) {
        nestedIn = state.parent;
        $('session-label').textContent =
          `session ${SESSION} — a graph inside session ${state.parent}`;
        $('update').textContent = 'UPDATE ↩';
        $('update').title = `install this graph and return to session ${state.parent}`;
        $('cancel').title = `discard this graph and return to session ${state.parent}`;
      }
    }
    const choices = await call(`/api/editor/choices?${q({
      session: SESSION,
      focus: pane.focus && pane.focus.ref !== undefined ? pane.focus.ref : null,
      relation: pane.relation ? pane.relation.label : null,
      direction: pane.relation ? pane.relation.direction : null,
      target: pane.target && pane.target.ref !== undefined ? pane.target.ref : null
    })}`);
    paintConceptList(choices.concepts);
    paintRelationList(choices.relations);
    notice = (await reconcileDirection(choices)) || notice;
  } catch (err) {
    setStatus(err.message, 'error');
    paintEditor();
    return;
  }
  setStatus(notice ? notice[0] : '', notice ? notice[1] : '');
  paintEditor();
}

// Keep the pane from ever holding an arc the lattice forbids.
//
// The filtering tables assume you fill the pane left to right, and each step
// narrows the next list. But a target picked by clicking the GRAPH is not drawn
// from the narrowed list at all -- that click means "this existing node", and it
// can name one for which the relation already sitting in the pane runs the wrong
// way. Add then failed at the server, correctly but late, with a pane you could
// not repair.
//
// So reconcile after every change instead of guarding one click: whatever the
// pane now holds, ask what the lattice permits and correct it. Flipping is
// silent-but-announced rather than a rejection -- the arc you asked for exists,
// it just runs the other way, and the editor knowing which way is the whole
// point of picking rather than typing.
async function reconcileDirection(choices) {
  const rel = pane.relation;
  if (!rel || !pane.target) return null;

  const targetIsRef = pane.target.ref !== undefined && pane.target.ref !== null;
  let legal;

  if (targetIsRef) {
    // choices came back for this exact pair: the directions listed for this
    // relation ARE the legal ones.
    legal = choices.relations
      .filter(r => r.label.toLowerCase() === rel.label.toLowerCase())
      .map(r => r.direction);
  } else {
    // A target that does not exist yet is not in the graph, so the pair query
    // cannot see it. `choices.concepts' is the far-end set for the direction we
    // just asked about; the other direction needs its own question.
    const type = String(pane.target.type).toLowerCase();
    const here = choices.concepts.some(c => String(c).toLowerCase() === type);
    let there = false;
    try {
      const other = await call(`/api/editor/choices?${q({
        session: SESSION,
        focus: pane.focus && pane.focus.ref !== undefined ? pane.focus.ref : null,
        relation: rel.label,
        direction: OPPOSITE(rel.direction)
      })}`);
      there = other.concepts.some(c => String(c).toLowerCase() === type);
    } catch (err) { /* leave the pane alone if we cannot tell */ return null; }
    legal = [...(here ? [rel.direction] : []),
             ...(there ? [OPPOSITE(rel.direction)] : [])];
  }

  rel.legal = legal;
  if (legal.includes(rel.direction)) return null;

  const target = slotText(pane.target) || 'that concept';
  if (legal.length === 0) {
    pane.relation = null;
    // The pull goes with it. A replacement with no relation left in the pane is
    // a claim about nothing, and leaving it set would show a Replace button
    // that can never enable — the row cannot commit until a relation is picked,
    // and picking one ends the pull anyway.
    pane.replacing = pane.pulledTarget = null;
    return [`(${rel.label}) cannot link ${slotText(pane.focus)} and ${target} `
            + `in either direction — pick another relation.`, 'error'];
  }
  rel.direction = legal[0];
  return [`(${rel.label}) only runs the other way between these two — `
          + `direction corrected.`, 'note'];
}

refresh();
// A session opened on an existing graph already has something to say, so the
// pane is filled once at load rather than staying blank until the first edit.
refreshEnglish();
