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
const focusLabel  = $('focus-label');

$('session-label').textContent = SESSION ? `session ${SESSION}` : '(no session)';

// ── editor-pane state ────────────────────────────────────────────────────────
// focus/target hold {ref, text} for an existing node, or {type} for a concept
// that does not exist yet. relation holds {label, direction, legal}, where
// `legal' is the directions the lattice permits for the pane's current pair --
// [] , ['forward'], ['reverse'] or both. A boolean "is it symmetric" cannot
// express the case that matters here, an arc pointing the ONE way that is not
// allowed, so the set is carried instead and REFRESH reconciles it.
const pane = { focus: null, relation: null, target: null };

const OPPOSITE = d => (d === 'reverse' ? 'forward' : 'reverse');
// The focus's current arcs, as the display pane last showed them. Kept so that
// picking a target already joined to the focus can fill the relation in for
// you — the link exists, so there is nothing to choose.
let focusArcs = [];
// A concept slot whose type zone was clicked: the next type-list click fills
// that slot instead of creating a new concept. Same one-shot arming the type
// editor uses for supertypes.
let armedSlot = null;

function setStatus(msg, kind) {
  statusEl.textContent = msg || '';
  statusEl.className = kind || '';
}

async function call(url, opts) {
  const resp = await fetch(url, opts);
  const data = await resp.json().catch(() => ({ ok: false, error: `HTTP ${resp.status}` }));
  if (!resp.ok || !data.ok) throw new Error(data.error || `HTTP ${resp.status}`);
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
  if (armedSlot) {
    setSlot(armedSlot, { ref, text: label });
    armedSlot = null;
  } else if (!pane.focus) {
    pane.focus = { ref, text: label };
  } else {
    pane.target = { ref, text: label };
    // If the two are already joined, fill the relation in rather than making
    // you re-pick what the graph already says. `legal' is filled by the next
    // choices fetch, which is what decides whether the arrows can be flipped.
    const existing = focusArcs.find(a => a.conceptRef === ref);
    if (existing && !pane.relation) {
      pane.relation = { label: existing.relation,
                        direction: existing.direction,
                        legal: null };
    }
  }
  refresh();
}

function setSlot(which, value) {
  pane[which] = value;
  if (which === 'focus') { pane.target = null; pane.relation = null; }
}

// ── editor pane ──────────────────────────────────────────────────────────────

function slotText(slot) {
  if (!slot) return null;
  if (slot.ref !== undefined && slot.ref !== null) return slot.text;
  return `[${slot.type.toUpperCase()}]`;
}

function paintSlot(el, slot, placeholder, kind) {
  el.replaceChildren();
  el.classList.toggle('empty', !slot);
  el.classList.toggle('armed', armedSlot === kind);
  if (!slot) { el.textContent = placeholder; return; }

  if (kind === 'relation') { el.textContent = `(${slot.label})`; return; }

  // A concept has two click zones: the type arms the type list, the referent
  // opens a sub-editor. The referent zone is inert until the referent editor
  // exists — see the Open section of notes/graph-editor.md.
  const text = slotText(slot);
  const m = /^\[([^\]:]+)(?::(.*))?\]$/.exec(text);
  if (!m) { el.textContent = text; return; }

  el.append(document.createTextNode('['));
  const type = document.createElement('span');
  type.className = 'zone-type';
  type.textContent = m[1].trim();
  type.title = 'click to pick a different type';
  type.addEventListener('click', ev => {
    ev.stopPropagation();
    armedSlot = (armedSlot === kind) ? null : kind;
    refresh();
  });
  el.append(type);

  const ref = document.createElement('span');
  ref.className = 'zone-ref disabled';
  ref.textContent = m[2] !== undefined ? `: ${m[2].trim()}` : '';
  ref.title = 'referent editor not built yet';
  el.append(ref);
  el.append(document.createTextNode(']'));
}

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
  $('add').disabled = !(pane.focus && pane.focus.ref !== undefined
                        && pane.relation && pane.target);
}

[arrowLeft, arrowRight].forEach(a => a.addEventListener('click', () => {
  if (!flippable(pane.relation)) return;
  pane.relation.direction = OPPOSITE(pane.relation.direction);
  refresh();
}));

$('clear').addEventListener('click', () => {
  pane.focus = pane.relation = pane.target = null;
  armedSlot = null;
  refresh();
});

// ── type columns ─────────────────────────────────────────────────────────────

function paintConceptList(types) {
  conceptList.replaceChildren();
  if (!types.length) {
    conceptList.innerHTML = '<div class="type-empty">no consistent types</div>';
    return;
  }
  for (const t of types) {
    const el = document.createElement('div');
    el.className = 'type-item';
    el.textContent = t;
    el.addEventListener('click', () => onConceptTypeClick(t));
    conceptList.append(el);
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
  relationList.replaceChildren();
  if (!rels.length) {
    relationList.innerHTML = '<div class="type-empty">no consistent relations</div>';
    return;
  }

  const here = pane.focus ? (slotText(pane.focus) || 'the focus') : 'the focus';
  const groups = [
    ['forward', `from ${here}`],
    ['reverse', `into ${here}`]
  ];

  for (const [direction, heading] of groups) {
    const rows = rels.filter(r => r.direction === direction)
                     .sort((a, b) => a.label.localeCompare(b.label));
    if (!rows.length) continue;      // no heading for a group with nothing in it
    const head = document.createElement('div');
    head.className = 'group-head';
    head.textContent = heading;
    relationList.append(head);
    for (const r of rows) relationList.append(relationRow(r));
  }
}

// Clicking a type CREATES a concept — unless a slot is armed, in which case it
// re-types that slot instead.
function onConceptTypeClick(type) {
  let notice = null;
  if (armedSlot) {
    const slot = pane[armedSlot];
    if (slot && slot.ref !== undefined && slot.ref !== null) {
      // Passed through REFRESH rather than set directly: refresh now clears the
      // status line, so a message set beforehand would be wiped on the way out.
      notice = ['That concept already exists in the graph; '
                + 'clear the slot to put a new one there.', 'error'];
    } else {
      setSlot(armedSlot, { type });
    }
    armedSlot = null;
  } else if (!pane.focus) {
    createFirstConcept(type);
    return;
  } else {
    pane.target = { type };
  }
  refresh({ notice });
}

// An empty graph gets its first node this way: the concept is created straight
// away and becomes the focus, since there is nothing to attach it to yet.
async function createFirstConcept(type) {
  try {
    const data = await call(`/api/editor/concept?${q({ session: SESSION, type })}`,
                            { method: 'POST' });
    pane.focus = { ref: data.ref, text: `[${type.toUpperCase()}]` };
    renderGraph(data.withRefs);
    setStatus('');
    await refresh();
  } catch (err) { setStatus(err.message, 'error'); }
}

// ── display pane ─────────────────────────────────────────────────────────────

function paintDisplay(arcs) {
  focusArcs = arcs || [];
  displayBody.replaceChildren();
  focusLabel.textContent = pane.focus ? slotText(pane.focus) : '';
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
    line.className = 'arc-line';
    const text = document.createElement('span');
    text.className = 'text';
    text.textContent = a.direction === 'reverse'
      ? `←(${a.relation})←${a.concept}`
      : `→(${a.relation})→${a.concept}`;
    // Clicking the concept in a line focuses it — how you move around, and how
    // you remove the current focus (focus a neighbour first).
    text.style.cursor = 'pointer';
    text.addEventListener('click', () => {
      pane.focus = { ref: a.conceptRef, text: a.concept };
      pane.relation = pane.target = null;
      refresh();
    });
    const x = document.createElement('span');
    x.className = 'x';
    x.textContent = '✕';
    x.title = 'remove this arc';
    x.addEventListener('click', () => removeArc(a.relationRef));
    line.append(text, x);
    displayBody.append(line);
  }
}

// ── operations ───────────────────────────────────────────────────────────────

$('add').addEventListener('click', async () => {
  const t = pane.target;
  try {
    const data = await call(`/api/editor/add?${q({
      session: SESSION,
      focus: pane.focus.ref,
      relation: pane.relation.label,
      direction: pane.relation.direction,
      target: (t.ref !== undefined && t.ref !== null) ? t.ref : null,
      target_type: t.type || null
    })}`, { method: 'POST' });
    pane.relation = pane.target = null;
    renderGraph(data.withRefs);
    paintDisplay(data.focus);
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
function showVeil(action) {
  const veil = $('veil');
  veil.className = action === 'commit' ? 'committed' : 'cancelled';
  veil.querySelector('.headline').textContent =
    action === 'commit' ? 'Committed' : 'Cancelled';
  veil.querySelector('.detail').textContent =
    action === 'commit'
      ? 'The edited graph was installed and the REPL call has returned.'
      : 'Nothing was changed — the original graph is untouched.';
  veil.hidden = false;
}

async function finish(action) {
  try {
    await call(`/api/editor/finish?${q({ session: SESSION, action })}`,
               { method: 'POST' });
    finished = true;   // closing the window now is not a disconnect worth reporting
    document.querySelectorAll('button').forEach(b => b.disabled = true);
    setStatus('');     // the veil says it, and says it where you are looking
    showVeil(action);
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
  paintEditor();
  try {
    if (!opts.keepGraph) {
      const state = await call(`/api/editor/focus?${q({
        session: SESSION,
        focus: pane.focus && pane.focus.ref !== undefined ? pane.focus.ref : null
      })}`);
      renderGraph(state.withRefs);
      paintDisplay(state.focus);
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
    return [`(${rel.label}) cannot link ${slotText(pane.focus)} and ${target} `
            + `in either direction — pick another relation.`, 'error'];
  }
  rel.direction = legal[0];
  return [`(${rel.label}) only runs the other way between these two — `
          + `direction corrected.`, 'note'];
}

refresh();
