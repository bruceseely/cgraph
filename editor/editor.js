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
// that does not exist yet. relation holds {label, direction, both}.
const pane = { focus: null, relation: null, target: null };
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

function paintArrows() {
  const rel = pane.relation;
  const shown = rel ? (rel.direction === 'reverse' ? '←' : '→') : '';
  [arrowLeft, arrowRight].forEach(a => {
    a.textContent = shown;
    a.className = 'arrow' + (rel && rel.both ? ' flippable' : '');
    a.title = rel && rel.both ? 'click to reverse the arc' : '';
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
  if (!pane.relation || !pane.relation.both) return;
  pane.relation.direction = pane.relation.direction === 'reverse' ? 'forward' : 'reverse';
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

function paintRelationList(rels) {
  relationList.replaceChildren();
  if (!rels.length) {
    relationList.innerHTML = '<div class="type-empty">no consistent relations</div>';
    return;
  }
  for (const r of rels) {
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
      pane.relation = { label: r.label, direction: r.direction, both: r.both };
      refresh();
    });
    relationList.append(el);
  }
}

// Clicking a type CREATES a concept — unless a slot is armed, in which case it
// re-types that slot instead.
function onConceptTypeClick(type) {
  if (armedSlot) {
    const slot = pane[armedSlot];
    if (slot && slot.ref !== undefined && slot.ref !== null) {
      setStatus('That concept already exists in the graph; '
                + 'clear the slot to put a new one there.', 'error');
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
  refresh();
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

async function finish(action) {
  try {
    await call(`/api/editor/finish?${q({ session: SESSION, action })}`,
               { method: 'POST' });
    document.querySelectorAll('button').forEach(b => b.disabled = true);
    setStatus(action === 'commit'
      ? 'Committed — the REPL call has returned. You can close this window.'
      : 'Cancelled — the original is unchanged. You can close this window.', 'done');
  } catch (err) { setStatus(err.message, 'error'); }
}

$('update').addEventListener('click', () => finish('commit'));
$('cancel').addEventListener('click', () => finish('cancel'));

// ── refresh ──────────────────────────────────────────────────────────────────
// One place decides what the lists may contain, from what the editor pane
// holds. The lattice does the filtering; nothing here guesses.

async function refresh(opts = {}) {
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
  } catch (err) {
    setStatus(err.message, 'error');
  }
  paintEditor();
}

refresh();
