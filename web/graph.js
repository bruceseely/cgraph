const chipsEl        = document.getElementById('chips');
const typeListEl     = document.getElementById('type-list');
const container      = document.getElementById('graph-container');
const errorMsg       = document.getElementById('error-msg');
const placeholder    = document.getElementById('placeholder');
const cgEntriesEl    = document.getElementById('cg-entries');
const cgPlaceholder  = document.getElementById('cg-placeholder');

const selected    = new Set();
const expandedSub = new Set();   // node ids with subtypes force-shown
const revealed    = new Set();   // undisplayed types exposed + connected to the display
let baselineNodeIds = new Set(); // node ids visible before any expansion/reveal

// Any temporary (non-permanent) additions currently active?
function hasTemp() { return expandedSub.size > 0 || revealed.size > 0; }

// Snapshot the baseline node set just before the first temporary addition,
// so newly-revealed nodes can be tinted; clear it once none remain.
function snapshotBaselineIfNeeded() {
  if (!hasTemp())
    baselineNodeIds = new Set(
      [...container.querySelectorAll('g.node')].map(n => n.id).filter(Boolean)
    );
}
function clearBaselineIfEmpty() {
  if (!hasTemp()) baselineNodeIds.clear();
}

// Is a type currently drawn in the lattice?
function isDisplayed(name) {
  for (const n of container.querySelectorAll('g.node'))
    if (n.id === name) return true;
  return false;
}

// ── Error display ─────────────────────────────────────────────────────────────

// The banner above the panes: red for errors, blue for prompts, hidden when empty.
function showError(msg) { console.error('[cgraph]', msg); errorMsg.textContent = msg; errorMsg.className = 'is-error'; }
function showInfo(msg)  { errorMsg.textContent = msg; errorMsg.className = 'is-info'; }
function clearError()   { errorMsg.textContent = ''; errorMsg.className = ''; }

// ── Viz initialisation ────────────────────────────────────────────────────────

let vizInstance = null;

async function getViz() {
  if (vizInstance) return vizInstance;
  const mod = await import('/viz.js');
  vizInstance = await mod.instance();
  return vizInstance;
}

// ── Chips (top bar) ───────────────────────────────────────────────────────────

function renderChips() {
  chipsEl.replaceChildren(
    ...[...selected].map(name => {
      const chip = document.createElement('span');
      chip.className = 'chip';
      chip.title = `Remove ${name}`;
      chip.textContent = `${name} `;
      const xSpan = document.createElement('span');
      xSpan.className = 'chip-x';
      xSpan.textContent = '✕';
      chip.appendChild(xSpan);
      chip.addEventListener('click', () => deselect(name));
      return chip;
    })
  );
}

// ── Sidebar list ──────────────────────────────────────────────────────────────

function renderSidebar(names) {
  console.log('[cgraph] renderSidebar:', names.length, 'types');
  typeListEl.replaceChildren(
    ...names.map(name => {
      const el = document.createElement('div');
      el.className = 'type-item'
                   + (selected.has(name) ? ' selected' : '')
                   + (superSet.has(name) ? ' is-super' : '');
      el.textContent = name;
      el.dataset.name = name;
      el.addEventListener('click', () => {
        // After "Edit Type", the next click chooses which type to edit.
        if (pickTargetMode) { loadTypeForEdit(name); return; }
        // After "+" in the supertypes cell, the next click adds ONE supertype;
        // otherwise clicks explore the graph normally, even while the form is open.
        if (pickSuperMode) { addSupertypeAndExit(name); return; }
        // Same one-shot gesture, aimed at the relation form's two type slots.
        if (pickRelSlot) { fillRelSlotAndExit(name); return; }
        if (selected.has(name)) deselect(name);
        else selectType(name);
        addCgEntry(name);
      });
      el.addEventListener('contextmenu', e => {
        e.preventDefault();
        if (revealed.has(name))      revealType(name);   // toggle an active reveal off
        else if (isDisplayed(name))  toggleExpand(name); // shown: normal subtype expand
        else if (selected.size > 0)  revealType(name);   // hidden: expose + connect
        // else: empty lattice — nothing to connect to, ignore
      });
      return el;
    })
  );
}

function updateSidebarItem(name) {
  for (const el of typeListEl.children) {
    if (el.dataset.name === name) {
      el.classList.toggle('selected', selected.has(name));
      break;
    }
  }
}

// ── Selection logic ───────────────────────────────────────────────────────────

function selectType(name) {
  selected.add(name);
  updateSidebarItem(name);
  renderChips();
  updateSaveBtn();
  redraw();
}

function deselect(name) {
  selected.delete(name);
  updateSidebarItem(name);
  renderChips();
  updateSaveBtn();
  redraw();
}

// Toggle subtype expansion for a displayed type (lattice nodes and sidebar items).
function toggleExpand(name) {
  if (expandedSub.has(name)) {
    expandedSub.delete(name);
  } else {
    snapshotBaselineIfNeeded();
    expandedSub.add(name);
  }
  clearBaselineIfEmpty();
  redraw();
}

// Toggle reveal of an undisplayed type: expose it + its subtypes and connect it
// to the existing display via its ancestral spine (sidebar right-click only).
function revealType(name) {
  if (revealed.has(name)) {
    revealed.delete(name);
  } else {
    snapshotBaselineIfNeeded();
    revealed.add(name);
  }
  clearBaselineIfEmpty();
  redraw();
}

// ── Graph rendering ───────────────────────────────────────────────────────────

async function redraw() {
  clearError();
  if (selected.size === 0) {
    container.replaceChildren(placeholder);
    return;
  }
  try {
    const viz = await getViz();
    let url = `/api/dot?types=${encodeURIComponent([...selected].join(','))}`;
    if (expandedSub.size > 0)
      url += `&expand_sub=${encodeURIComponent([...expandedSub].join(','))}`;
    if (revealed.size > 0)
      url += `&reveal=${encodeURIComponent([...revealed].join(','))}`;

    const resp = await fetch(url);
    if (!resp.ok) { showError((await resp.text()) || `Server error: ${resp.status}`); return; }
    const dot = await resp.text();
    const svg = viz.renderSVGElement(dot);

    svg.querySelectorAll('g.node').forEach(node => {
      if (!node.id) return;
      node.style.cursor = 'pointer';

      const shape = node.querySelector('polygon, rect, ellipse');

      // Selected types (from chips): thick dark border.
      if (selected.has(node.id) && shape) {
        shape.setAttribute('stroke', '#1a3a6b');
        shape.setAttribute('stroke-width', '2.5');
      }

      // Expand/reveal anchor nodes: blue fill tint.
      if (shape && (expandedSub.has(node.id) || revealed.has(node.id)))
        shape.setAttribute('fill', '#d6eaf8');

      // Newly added nodes (by expansion or reveal spine/subtypes): yellow fill.
      if (shape && baselineNodeIds.size > 0 && !baselineNodeIds.has(node.id) &&
          !expandedSub.has(node.id) && !revealed.has(node.id))
        shape.setAttribute('fill', '#fef9e7');

      // Nodes with a pinned CG entry: subtle green tint.
      if (shape && cgEntries.has(node.id) &&
          !expandedSub.has(node.id) && !revealed.has(node.id) &&
          !(baselineNodeIds.size > 0 && !baselineNodeIds.has(node.id)))
        shape.setAttribute('fill', '#eafaf1');

      // Single click: select/deselect + add CG entry.
      // Double click: toggle CG entry out.
      let singleClickTimer = null;
      node.addEventListener('click', e => {
        // After "Edit Type", a graph-node click chooses which type to edit.
        if (pickTargetMode) { loadTypeForEdit(node.id); return; }
        // After "+" in the supertypes cell, a graph-node click adds ONE supertype;
        // otherwise clicks explore/select normally, even while the form is open.
        if (pickSuperMode) { addSupertypeAndExit(node.id); return; }
        // The relation form's source/dest slots use the same gesture — which is
        // the whole reason the relation form lives here rather than in a pane of
        // its own: picking a signature means pointing at the lattice.
        if (pickRelSlot) { fillRelSlotAndExit(node.id); return; }
        if (e.detail >= 2) {
          if (singleClickTimer) { clearTimeout(singleClickTimer); singleClickTimer = null; }
          if (cgEntries.has(node.id)) removeCgEntry(node.id);
        } else {
          addCgEntry(node.id);   // immediate — async fetch starts now
          singleClickTimer = setTimeout(() => {
            singleClickTimer = null;
            if (selected.has(node.id)) deselect(node.id);
            else                       selectType(node.id);
          }, 350);
        }
      });

      // Right-click: toggle subtype expansion.
      node.addEventListener('contextmenu', e => {
        e.preventDefault();
        toggleExpand(node.id);
      });
    });

    container.replaceChildren(svg);
  } catch (err) {
    showError(err.message);
  }
}

// ── CG string parser ─────────────────────────────────────────────────────────
// Parses CG linear notation into a list of {src, rel, dst} arc objects.
// Handles: [A]→(r)→[B], [A]←(r)←[B], [A]-(r1)→[B1] (r2)→[B2],
//          nested fanouts via -, commas resetting to root, mixed chains.

function parseCgString(str) {
  if (!str) return [];

  // Tokenize
  const tokens = [];
  let i = 0;
  while (i < str.length) {
    const c = str[i];
    if (c === '[') {
      const end = str.indexOf(']', i + 1);
      if (end === -1) { i++; continue; }
      const label = str.slice(i + 1, end).trim();
      if (label) tokens.push({ type: 'concept', label });
      i = end + 1;
    } else if (c === '(') {
      const end = str.indexOf(')', i + 1);
      if (end === -1) { i++; continue; }
      const label = str.slice(i + 1, end).trim();
      if (label) tokens.push({ type: 'rel', label });
      i = end + 1;
    } else if (c === '\u2192') {
      tokens.push({ type: 'rarrow' }); i++;
    } else if (c === '\u2190') {
      tokens.push({ type: 'larrow' }); i++;
    } else if (c === '-' && str[i + 1] === '>') {
      tokens.push({ type: 'rarrow' }); i += 2;
    } else if (c === '<' && str[i + 1] === '-') {
      tokens.push({ type: 'larrow' }); i += 2;
    } else if (c === '-') {
      tokens.push({ type: 'dash' }); i++;
    } else if (c === '.') {
      tokens.push({ type: 'dot' }); i++;
    } else if (c === ',') {
      tokens.push({ type: 'comma' }); i++;
    } else {
      i++;
    }
  }

  const arcs = [];
  let pos = 0;
  const peek = () => tokens[pos];
  const consume = () => tokens[pos++];

  const tok0 = peek();
  if (!tok0 || tok0.type !== 'concept') return arcs;
  consume();
  const root = tok0.label;
  let current = root;
  let fanoutSrc = root;

  while (pos < tokens.length) {
    const tok = peek();
    if (!tok || tok.type === 'dot') { consume(); break; }

    if (tok.type === 'comma') {
      consume();
      current = root; fanoutSrc = root;
      continue;
    }

    if (tok.type === 'dash') {
      consume();
      fanoutSrc = current;
      continue;
    }

    if (tok.type === 'rarrow' || tok.type === 'larrow') {
      // Explicit chain: first arrow consumed here, then (r), then second arrow, then [concept].
      // src is always 'current' (the notation origin); dir encodes the arrow direction.
      const firstArr = tok.type;
      consume();
      const relTok = peek();
      if (!relTok || relTok.type !== 'rel') continue;
      consume();
      const arrTok = peek();
      if (!arrTok || (arrTok.type !== 'rarrow' && arrTok.type !== 'larrow')) continue;
      consume();
      const destTok = peek();
      if (!destTok || destTok.type !== 'concept') continue;
      consume();
      // Forward: first→ second→  or  first← second←(both match, same direction)
      // Backward: first→ second←  or  first← second←
      // Rule: if both arrows same direction → forward; if second is ← → back.
      const dir = arrTok.type === 'larrow' ? 'back' : 'forward';
      arcs.push({ src: current, rel: relTok.label, dst: destTok.label, dir });
      current = destTok.label;
      continue;
    }

    if (tok.type === 'rel') {
      // Fanout arc from fanoutSrc: (r)→[other] (forward) or (r)←[other] (back).
      // fanoutSrc is always the notation origin (selected-type side).
      consume();
      const arrTok = peek();
      if (!arrTok || (arrTok.type !== 'rarrow' && arrTok.type !== 'larrow')) continue;
      consume();
      const otherTok = peek();
      if (!otherTok || otherTok.type !== 'concept') continue;
      consume();
      arcs.push({ src: fanoutSrc, rel: tok.label, dst: otherTok.label,
                  dir: arrTok.type === 'rarrow' ? 'forward' : 'back' });
      current = otherTok.label;
      // Immediately following dash: other becomes new fanout source
      if (peek() && peek().type === 'dash') {
        consume();
        fanoutSrc = current;
      }
      continue;
    }

    consume(); // skip unexpected token
  }

  return arcs;
}

// ── CG DOT renderer ───────────────────────────────────────────────────────────
// Converts {src, rel, dst} arcs to a Graphviz DOT string using CG visual form:
// concept nodes as boxes, relation nodes as ellipses.

function arcsToDot(typeName, arcs) {
  const conceptToId = new Map();
  let nodeN = 0;
  const getConceptId = label => {
    if (!conceptToId.has(label)) conceptToId.set(label, `c${++nodeN}`);
    return conceptToId.get(label);
  };
  for (const { src, dst } of arcs) { getConceptId(src); getConceptId(dst); }

  const esc = s => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"');

  const lines = [
    `digraph "cg_${typeName.replace(/\W/g, '_')}" {`,
    '  graph [rankdir="LR" margin=0.1 pad=0.1];',
    '  node [fontname=Helvetica fontsize=10 margin="0.06,0.03"];',
    '  edge [arrowsize=0.55 color="#888"];',
  ];

  for (const [label, id] of conceptToId)
    lines.push(`  ${id} [label="${esc(label)}" shape=box style=filled fillcolor="#fffde7" color="#bbb"];`);

  arcs.forEach(({ src, rel, dst, dir = 'forward' }, i) => {
    const rid = `r${i + 1}`;
    lines.push(`  ${rid} [label="${esc(rel)}" shape=ellipse fontsize=8 height=0.2 margin="0.04,0.02" style=filled fillcolor="#e8f4f8" color="#aaa"];`);
    if (dir === 'back') {
      // Layout: src (selected type) on the left; arrowheads point leftward back toward src.
      lines.push(`  ${getConceptId(src)} -> ${rid} [dir=back];`);
      lines.push(`  ${rid} -> ${getConceptId(dst)} [dir=back];`);
    } else {
      lines.push(`  ${getConceptId(src)} -> ${rid};`);
      lines.push(`  ${rid} -> ${getConceptId(dst)};`);
    }
  });

  lines.push('}');
  return lines.join('\n');
}

// ── Canonical graph pane ──────────────────────────────────────────────────────

// Map from uppercase label → entry DOM element.
const cgEntries = new Map();
// Map from uppercase label → {bodyEl, svg, linear} — both render forms.
const cgEntryData = new Map();

// 'graph' | 'linear'. Seeded from the CL option *canonical-graph-format* at
// startup (see loadOptions); this initial value is the fallback for when the
// server can't be reached, and matches that option's default so the two agree.
let cgDisplayMode = 'linear';

function applyDisplayMode(key) {
  const data = cgEntryData.get(key);
  if (!data) return;
  const { bodyEl, svg, linear } = data;
  const showLinear = txt => {
    const pre = document.createElement('pre');
    pre.className = 'cg-linear';
    pre.textContent = txt;
    bodyEl.className = 'cg-entry-body';
    bodyEl.replaceChildren(pre);
  };

  if (cgDisplayMode === 'graph') {
    if (svg) {
      bodyEl.className = 'cg-entry-body';
      bodyEl.replaceChildren(svg);
    } else if (linear) {
      showLinear(linear);
    }
  } else {
    if (linear) {
      showLinear(linear);
    } else if (svg) {
      bodyEl.className = 'cg-entry-body';
      bodyEl.replaceChildren(svg);
    }
  }
}

function syncDisplayModeButtons() {
  document.querySelectorAll('.opt-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.mode === cgDisplayMode)
  );
}

function setDisplayMode(mode) {
  if (mode === cgDisplayMode) return;
  cgDisplayMode = mode;
  syncDisplayModeButtons();
  for (const key of cgEntries.keys()) applyDisplayMode(key);
}

async function addCgEntry(label) {
  const key = label.toUpperCase();

  if (cgEntries.has(key)) {
    cgEntries.get(key).scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    return;
  }

  const entryEl = document.createElement('div');
  entryEl.className = 'cg-entry';

  const headEl = document.createElement('div');
  headEl.className = 'cg-entry-head';

  const nameEl = document.createElement('span');
  nameEl.className = 'cg-entry-name';
  nameEl.textContent = key;

  const removeBtn = document.createElement('button');
  removeBtn.className = 'cg-entry-remove';
  removeBtn.title = `Remove ${key}`;
  removeBtn.textContent = '✕';
  removeBtn.addEventListener('click', () => removeCgEntry(key));

  headEl.appendChild(nameEl);
  headEl.appendChild(removeBtn);

  const bodyEl = document.createElement('div');
  bodyEl.className = 'cg-entry-body loading';
  bodyEl.textContent = '…';

  entryEl.appendChild(headEl);
  entryEl.appendChild(bodyEl);

  cgEntries.set(key, entryEl);
  cgEntryData.set(key, { bodyEl, svg: null, linear: null });
  cgPlaceholder.hidden = true;
  cgEntriesEl.prepend(entryEl);
  cgEntriesEl.scrollTop = 0;

  try {
    const resp = await fetch(`/api/relations?type=${encodeURIComponent(label)}`);
    if (!resp.ok) {
      bodyEl.className = 'cg-entry-body empty';
      bodyEl.textContent = '(lookup failed)';
      return;
    }
    const data = await resp.json();
    bodyEl.classList.remove('loading');

    if (data.canonical_graph_format_error) {
      console.warn('[cgraph] pcg format error for', key, ':', data.canonical_graph_format_error);
    }

    const entryData = cgEntryData.get(key);

    // Store linear text: prefer formatted (pcg output), fall back to raw string.
    entryData.linear = data.canonical_graph_formatted || data.canonical_graph || null;

    // Build SVG from raw CG text.
    const cgText = data.canonical_graph;
    if (cgText) {
      const arcs = parseCgString(cgText);
      if (arcs.length > 0) {
        try {
          const dot = arcsToDot(key, arcs);
          const viz = await getViz();
          const svg = viz.renderSVGElement(dot);
          svg.removeAttribute('width');
          svg.removeAttribute('height');
          entryData.svg = svg;
        } catch (_) {}
      }
    }

    // Display based on current mode; fall back to empty message if neither available.
    if (entryData.svg || entryData.linear) {
      applyDisplayMode(key);
    } else {
      bodyEl.className = 'cg-entry-body empty';
      bodyEl.textContent = 'no canonical graph';
    }
  } catch (err) {
    bodyEl.className = 'cg-entry-body empty';
    bodyEl.textContent = '(error)';
  }

  redraw();
}

function removeCgEntry(key) {
  key = key.toUpperCase();
  const el = cgEntries.get(key);
  if (!el) return;
  el.remove();
  cgEntries.delete(key);
  cgEntryData.delete(key);
  if (cgEntries.size === 0) cgPlaceholder.hidden = false;
  redraw();
}

document.getElementById('cg-clear-btn').addEventListener('click', () => {
  cgEntries.clear();
  cgEntryData.clear();
  for (const el of [...cgEntriesEl.children]) {
    if (el !== cgPlaceholder) el.remove();
  }
  cgPlaceholder.hidden = false;
  redraw();
});

// ── Options panel ─────────────────────────────────────────────────────────────

(function () {
  const btn     = document.getElementById('options-btn');
  const panel   = document.getElementById('cg-options');

  btn.addEventListener('click', () => {
    const opening = panel.hidden;
    panel.hidden = !opening;
    btn.classList.toggle('open', opening);
  });

  document.querySelectorAll('.opt-btn').forEach(b =>
    b.addEventListener('click', () => setDisplayMode(b.dataset.mode))
  );
}());

// ── CG pane resizer ───────────────────────────────────────────────────────────

(function () {
  const resizer = document.getElementById('cg-resizer');
  const cgPane  = document.getElementById('cg-pane');

  resizer.addEventListener('mousedown', e => {
    e.preventDefault();
    const startX     = e.clientX;
    const startWidth = cgPane.getBoundingClientRect().width;
    resizer.classList.add('dragging');

    const onMove = e => {
      const newWidth = Math.max(150, Math.min(700, startWidth + (startX - e.clientX)));
      cgPane.style.width = newWidth + 'px';
    };

    const onUp = () => {
      resizer.classList.remove('dragging');
      document.removeEventListener('mousemove', onMove);
      document.removeEventListener('mouseup', onUp);
    };

    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp);
  });
}());

// ── Sidebar resizer ───────────────────────────────────────────────────────────

(function () {
  const resizer = document.getElementById('sidebar-resizer');
  const sidebar = document.getElementById('sidebar');

  resizer.addEventListener('mousedown', e => {
    e.preventDefault();
    const startX     = e.clientX;
    const startWidth = sidebar.getBoundingClientRect().width;
    resizer.classList.add('dragging');

    const onMove = e => {
      const newWidth = Math.max(120, Math.min(600, startWidth + (e.clientX - startX)));
      sidebar.style.width = newWidth + 'px';
    };

    const onUp = () => {
      resizer.classList.remove('dragging');
      document.removeEventListener('mousemove', onMove);
      document.removeEventListener('mouseup', onUp);
    };

    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp);
  });
}());

// ── Container-level mouse handling ────────────────────────────────────────────

// Left-click on background: clear all temporary additions (expansions + reveals).
container.addEventListener('click', e => {
  if (e.target.closest('g.node')) return;
  if (hasTemp()) {
    expandedSub.clear();
    revealed.clear();
    baselineNodeIds.clear();
    redraw();
  }
});

// Right-click on background: suppress the browser context menu.
container.addEventListener('contextmenu', e => {
  if (!e.target.closest('g.node')) e.preventDefault();
});

// ── Save-status click: copy to clipboard + Emacs kill-ring ────────────────

document.getElementById('save-status').addEventListener('click', async () => {
  const el = document.getElementById('save-status');
  const text = el.textContent;
  if (!text) return;

  // Mac clipboard
  navigator.clipboard.writeText(text).catch(() => {});

  // Emacs kill-ring (best-effort, ignore errors)
  fetch(`/api/kill-ring?text=${encodeURIComponent(text)}`, { method: 'POST' }).catch(() => {});

  // Brief visual feedback
  el.style.color = '#2ecc71';
  setTimeout(() => { el.style.color = ''; }, 800);
});

// ── Save button ───────────────────────────────────────────────────────────

function updateSaveBtn() {
  document.getElementById('save-btn').disabled = selected.size === 0;
}

document.getElementById('save-btn').addEventListener('click', async () => {
  const btn = document.getElementById('save-btn');
  btn.disabled = true;
  btn.textContent = 'Saving…';
  clearError();
  try {
    let url = `/api/save?types=${encodeURIComponent([...selected].join(','))}`;
    if (expandedSub.size > 0)
      url += `&expand_sub=${encodeURIComponent([...expandedSub].join(','))}`;
    if (revealed.size > 0)
      url += `&reveal=${encodeURIComponent([...revealed].join(','))}`;
    const resp = await fetch(url, { method: 'POST' });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || !data.ok) {
      showError(data.error || `Save failed: ${resp.status}`);
      btn.textContent = 'Save';
      btn.disabled = selected.size === 0;
    } else {
      const path = data.png || data.dot;
      const basename = path.split('/').pop().replace(/\.(png|dot)$/, '');
      document.getElementById('save-status').textContent = basename;
      btn.textContent = 'Saved ✓';
      setTimeout(() => { btn.textContent = 'Save'; btn.disabled = selected.size === 0; }, 2000);
    }
  } catch (err) {
    showError(err.message);
    btn.textContent = 'Save';
    btn.disabled = selected.size === 0;
  }
});

// ── Initialize button ─────────────────────────────────────────────────────

document.getElementById('init-btn').addEventListener('click', async () => {
  const btn = document.getElementById('init-btn');
  btn.disabled = true;
  btn.textContent = 'Initializing…';
  clearError();
  try {
    const resp = await fetch('/api/initialize', { method: 'POST' });
    if (!resp.ok) {
      const data = await resp.json().catch(() => ({}));
      showError(data.error || `Initialize failed: ${resp.status}`);
      return;
    }
    // Reload the type list.
    const typesResp = await fetch('/api/types');
    if (!typesResp.ok) { showError(`Could not reload types: ${typesResp.status}`); return; }
    const names = await typesResp.json();

    // Drop any selected types that no longer exist.
    const nameSet = new Set(names);
    for (const name of [...selected])
      if (!nameSet.has(name)) selected.delete(name);

    // Clear expansions/reveals and redraw.
    expandedSub.clear();
    revealed.clear();
    baselineNodeIds.clear();

    renderSidebar(names);
    renderChips();
    updateSaveBtn();
    document.getElementById('save-status').textContent = '';
    redraw();
  } catch (err) {
    showError(err.message);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Initialize';
  }
});

// ── Bootstrap ─────────────────────────────────────────────────────────────────

console.log('[cgraph] graph.js starting');

// Pull the CL-side options before anything renders. setDisplayMode is a no-op
// when the server agrees with the built-in default, so the common case costs
// nothing; a failed fetch leaves that default in place rather than blocking.
async function loadOptions() {
  try {
    const resp = await fetch('/api/options');
    if (!resp.ok) throw new Error(`/api/options returned ${resp.status}`);
    const opts = await resp.json();
    if (opts.canonical_graph_format === 'graph' ||
        opts.canonical_graph_format === 'linear') {
      setDisplayMode(opts.canonical_graph_format);
    }
  } catch (err) {
    console.warn('[cgraph] using built-in option defaults:', err.message);
  }
  syncDisplayModeButtons();
}

loadOptions();

fetch('/api/types')
  .then(resp => {
    if (!resp.ok) throw new Error(`/api/types returned ${resp.status}`);
    return resp.json();
  })
  .then(names => {
    console.log('[cgraph] got', names.length, 'types');
    renderSidebar(names);
  })
  .catch(err => showError(`Could not load type list: ${err.message}`));

// ── New / Edit Type editor ──────────────────────────────────────────────────────

const newTypeForm = document.getElementById('new-type-form');
const ntLabel     = document.getElementById('nt-label');
const ntSupers    = document.getElementById('nt-supers');
const ntSupEmpty  = document.getElementById('nt-supers-empty');
const ntAddSuper  = document.getElementById('nt-add-super');
const ntCanon     = document.getElementById('nt-canonical');
const ntNote      = document.getElementById('nt-note');
const ntStatus    = document.getElementById('nt-status');
const ntCreateBtn = document.getElementById('nt-create');
const ntSaveBtn   = document.getElementById('nt-save');
const ntDeleteBtn = document.getElementById('nt-delete');
const editTypeBtn = document.getElementById('edit-type-btn');

// Supertypes are chosen by clicking existing types (sidebar or graph), never typed —
// so a supertype can only ever be a name the catalog already has.
const superSet     = new Set();
let   editingLabel   = null;   // null = creating a new type; a name = editing that type
let   pickTargetMode = false;  // after "Edit Type", waiting for a type click to choose one
let   pickSuperMode  = false;  // after "+" in the supertypes cell, waiting for ONE type click

function newTypeFormOpen() { return !newTypeForm.hidden; }
function setNtHint(msg) { ntStatus.textContent = msg || ''; }

function renderSuperChips() {
  ntSupers.querySelectorAll('.nt-chip').forEach(c => c.remove());
  ntSupEmpty.style.display = superSet.size ? 'none' : '';
  for (const name of superSet) {
    const chip = document.createElement('span');
    chip.className = 'nt-chip';
    chip.title = 'remove supertype';
    const x = document.createElement('span');
    x.className = 'x';
    x.textContent = '✕';
    chip.append(name, x);
    chip.addEventListener('click', () => toggleSupertype(name));
    ntSupers.insertBefore(chip, ntAddSuper);   // keep the "+" button last
  }
}

// Reflect supertype membership on the sidebar item for NAME.
function updateSidebarSuper(name) {
  for (const el of typeListEl.children)
    if (el.dataset.name === name) { el.classList.toggle('is-super', superSet.has(name)); break; }
}

function toggleSupertype(name) {
  if (editingLabel && name === editingLabel) return;   // a type can't be its own supertype
  if (superSet.has(name)) superSet.delete(name);
  else                    superSet.add(name);
  renderSuperChips();
  updateSidebarSuper(name);
}

// The "+" button arms a one-shot mode: the NEXT type click (list or graph) is added
// as a supertype, then normal graph-exploration behaviour resumes. Click "+" again
// before each additional supertype. Mirrors the "Edit Type" one-shot pick.
function enterPickSuper() {
  pickSuperMode = true;
  ntAddSuper.classList.add('active');
  showInfo('click one type (in the list or graph) to add as a supertype');
}

function exitPickSuper() {
  pickSuperMode = false;
  ntAddSuper.classList.remove('active');
  if (errorMsg.classList.contains('is-info')) clearError();
}

function addSupertypeAndExit(name) {
  exitPickSuper();
  if (editingLabel && name === editingLabel) {   // a type can't be its own supertype
    showError(`${name} can't be its own supertype`);
    return;
  }
  if (!superSet.has(name)) {
    superSet.add(name);
    renderSuperChips();
    updateSidebarSuper(name);
  }
}

ntAddSuper.addEventListener('click', () => {
  if (pickSuperMode) exitPickSuper();   // second click cancels
  else               enterPickSuper();
});

function clearSuperSet() {
  const names = [...superSet];
  superSet.clear();
  renderSuperChips();
  names.forEach(updateSidebarSuper);
}

// Open the form to create (edit=null) or to edit an existing type.
function openForm({ edit = null, supers = [], canon = '', note = '' } = {}) {
  hideRelForm();               // the two forms are never open at once
  editingLabel = edit;
  pickTargetMode = false;
  exitPickSuper();                           // start out of supertype-pick mode
  editTypeBtn.classList.remove('active');
  const isEdit = edit !== null;
  ntLabel.value    = isEdit ? edit : '';
  ntLabel.readOnly = isEdit;                 // the type being edited can't be renamed here
  clearSuperSet();
  supers.forEach(s => superSet.add(s));
  renderSuperChips();
  superSet.forEach(updateSidebarSuper);
  ntCanon.value = canon;
  ntNote.value  = note;
  ntCanon.classList.remove('field-error');
  ntCreateBtn.hidden = isEdit;               // Create ↔ Save
  ntSaveBtn.hidden   = !isEdit;
  ntDeleteBtn.hidden = !isEdit;              // nothing to delete while creating
  disarmDelete();                            // never inherit an arm from a previous type
  clearError();
  setNtHint(isEdit ? `editing ${edit} — “+” adds a supertype; explore the graph freely`
                   : '“+” adds a supertype; explore the graph freely');
  newTypeForm.hidden = false;
  syncEditorFields();          // size both textareas to the prefilled content
  (isEdit ? ntCanon : ntLabel).focus();
}

function hideForm() {
  newTypeForm.hidden = true;
  exitPickSuper();            // leave supertype-pick mode if it was armed
  clearSuperSet();            // drop the sidebar is-super highlights
  editingLabel = null;
  ntLabel.readOnly = false;
  disarmDelete();
  setNtHint('');
  clearError();
}

// ── Delete a type ───────────────────────────────────────────────────────────────
// Two clicks, not a confirm(): the first arms the button and says what is about
// to happen, the second does it. Same one-shot arming the "+" supertype pick and
// the graph editor's slots use, so the gesture is already familiar here — and it
// keeps a modal from freezing the page over what is usually a just-made typo.
//
// The guard that matters is on the server, not here: it refuses any type that
// still has subtypes, is named in another type's canonical graph, or appears in
// a relation's signature. So an armed Delete cannot silently take a referrer
// with it; the worst case is a refusal explaining what to fix first.

// Arming changes the button's COLOUR and the hint line, never its label: a
// control that resizes as it arms shifts the buttons beside it, and the one
// beside this is Cancel. Growing it to "Delete xat — click again" moved Cancel
// out from under the pointer, so the click meant to back out committed the
// delete instead. The wording belongs where it costs no width.
let deleteArmed = false;
let hintBeforeArm = '';

function disarmDelete() {
  if (deleteArmed) setNtHint(hintBeforeArm);
  deleteArmed = false;
  ntDeleteBtn.classList.remove('armed');
}

function armDelete() {
  hintBeforeArm = ntStatus.textContent;
  deleteArmed = true;
  ntDeleteBtn.classList.add('armed');
  setNtHint(`click Delete again to remove ${editingLabel} — Cancel, or any edit, backs out`);
}

async function deleteType() {
  const label = editingLabel;
  if (!label) return;
  if (!deleteArmed) { armDelete(); return; }
  disarmDelete();
  setNtHint(`deleting ${label}…`);
  try {
    const resp = await fetch(`/api/delete-type?label=${encodeURIComponent(label)}`,
                             { method: 'POST' });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || !data.ok) {
      setNtHint('');
      showError(data.error || `failed: ${resp.status}`);
      return;
    }
    hideForm();
    selected.delete(label);      // a deleted type must not linger as a chip
    await refreshTypeList();
    await redraw();
  } catch (err) {
    setNtHint('');
    showError(err.message);
  }
}

ntDeleteBtn.addEventListener('click', deleteType);
// Typing into the form is a change of mind about deleting it.
for (const el of [ntCanon, ntNote]) el.addEventListener('input', disarmDelete);

function cancelPickTarget() {
  pickTargetMode = false;
  editTypeBtn.classList.remove('active');
  if (errorMsg.classList.contains('is-info')) clearError();
}

document.getElementById('new-type-btn').addEventListener('click', () => {
  cancelPickTarget();
  if (newTypeFormOpen() && editingLabel === null) hideForm();   // toggle the create form
  else openForm();                                              // open/switch to create
});

editTypeBtn.addEventListener('click', () => {
  if (pickTargetMode) { cancelPickTarget(); return; }
  hideForm();
  pickTargetMode = true;
  editTypeBtn.classList.add('active');
  showInfo('click a type (in the list or graph) to edit');
});

document.getElementById('nt-cancel').addEventListener('click', hideForm);

async function loadTypeForEdit(name) {
  pickTargetMode = false;
  editTypeBtn.classList.remove('active');
  clearError();
  try {
    const resp = await fetch(`/api/type-def?label=${encodeURIComponent(name)}`);
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || data.error) { showError(data.error || `could not load ${name}`); return; }
    openForm({ edit: data.label, supers: data.supertypes || [], canon: data.canonical || '', note: data.note || '' });
  } catch (err) {
    showError(err.message);
  }
}

async function refreshTypeList(selectName) {
  const resp = await fetch('/api/types');
  if (!resp.ok) throw new Error(`could not reload types: ${resp.status}`);
  const names = await resp.json();
  renderSidebar(names);
  if (selectName && !selected.has(selectName)) selectType(selectName);
}

async function submitType() {
  const editing = editingLabel !== null;
  const label = editing ? editingLabel : ntLabel.value.trim();
  // Newlines are preserved: the form-based splice handles multi-line definitions,
  // so indentation the user adds for readability survives a round-trip.
  const canon = ntCanon.value.trim();
  const note  = ntNote.value.trim();
  ntCanon.classList.remove('field-error');
  if (!label)         { showError('a type name is required'); if (!editing) ntLabel.focus(); return; }
  if (!superSet.size) { showError('click at least one supertype'); return; }
  setNtHint(editing ? 'saving…' : 'creating…');
  try {
    const path = editing ? 'edit-type' : 'create-type';
    // canonical + note are always sent — an empty value clears them on an edit.
    const url = `/api/${path}?label=${encodeURIComponent(label)}`
              + `&supertypes=${encodeURIComponent([...superSet].join(','))}`
              + `&canonical=${encodeURIComponent(canon)}`
              + `&note=${encodeURIComponent(note)}`;
    const resp = await fetch(url, { method: 'POST' });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || !data.ok) {
      const msg = data.error || `failed: ${resp.status}`;
      setNtHint('');
      showError(msg);   // errors surface in the banner above the panes
      // A defective canonical graph also rings the field it came from.
      if (/canonical/i.test(msg)) { ntCanon.classList.add('field-error'); ntCanon.focus(); }
      return;
    }
    hideForm();
    await refreshTypeList(data.label);
    // An edit changes the live lattice (e.g. a dropped supertype); the displayed
    // graph is fetched fresh from /api/dot, so redraw to reflect the new shape.
    // (A create is picked up by refreshTypeList's selectType; an edit of an
    // already-selected type needs an explicit redraw.)
    if (editing) redraw();
  } catch (err) {
    setNtHint('');
    showError(err.message);
  }
}

ntCreateBtn.addEventListener('click', submitType);
ntSaveBtn.addEventListener('click', submitType);

// The editor fields form one partitioned bar, so the two textareas share a
// single height: the taller of the two contents (capped at the CSS max-height).
// The single-line cells (name, supertypes) stretch to match via align-items.
function syncFieldHeights() {
  for (const el of [ntCanon, ntNote]) el.style.height = 'auto';
  // +2px so the last line clears the bottom edge — at a fractional device-pixel-ratio
  // the content height can round a hair short and clip the final line into a scrollbar.
  const h = Math.min(Math.max(ntCanon.scrollHeight, ntNote.scrollHeight) + 2, 192);  // 192px ≈ 12rem cap
  for (const el of [ntCanon, ntNote]) el.style.height = h + 'px';
}

// Width of a vertical scrollbar, measured once — reserved in the canonical field's
// width so a tall graph's scrollbar (or a pixel of sub-pixel rounding) can't push the
// widest line into a horizontal scrollbar.
let scrollbarPx = null;
function scrollbarWidth() {
  if (scrollbarPx == null) {
    const probe = document.createElement('div');
    probe.style.cssText = 'position:absolute;top:-9999px;width:100px;height:100px;overflow:scroll;';
    document.body.appendChild(probe);
    scrollbarPx = probe.offsetWidth - probe.clientWidth;
    document.body.removeChild(probe);
  }
  return scrollbarPx;
}

// Size the canonical field's WIDTH to just past its widest line, so it takes only
// as much horizontal room as its (reformatted) graph needs.
//
// The field is set to wrap="off": the canonical graph has meaningful hard line
// breaks and must NEVER soft-wrap. This also sidesteps a Firefox quirk where a
// soft-wrapped textarea keeps a stale wrap after its width changes (until some later
// reflow forces a re-layout). With wrap off the lines are fixed; a too-narrow field
// would scroll horizontally, so we grow the width until nothing overflows.
//
// A hidden span in the field's own computed font gives a fast width estimate; the
// grow-loop then fits exactly using the field's OWN rendering (scrollWidth vs
// clientWidth), which is robust across browsers and device-pixel-ratios — including
// the sub-pixel rounding that a fractional dpr (e.g. page zoom) introduces. An empty
// field measures the placeholder, so a type with no canonical graph still gets a
// sensible default width.
let canonMeasure = null;
function sizeCanonicalWidth() {
  ntCanon.setAttribute('wrap', 'off');       // preserve hard line breaks; never soft-wrap
  ntCanon.style.flex = '0 0 auto';           // hold the width; don't stretch or shrink
  const cs = getComputedStyle(ntCanon);
  if (!canonMeasure) {
    canonMeasure = document.createElement('span');
    canonMeasure.style.cssText =
      'position:absolute;visibility:hidden;white-space:pre;top:-9999px;left:-9999px;';
    document.body.appendChild(canonMeasure);
  }
  for (const p of ['fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'letterSpacing'])
    canonMeasure.style[p] = cs[p];
  const lines = (ntCanon.value || ntCanon.placeholder || '').split('\n');
  let textW = 0;                             // widest line, measured one line at a time
  for (const line of lines) {
    canonMeasure.textContent = line;
    textW = Math.max(textW, canonMeasure.getBoundingClientRect().width);
  }
  const padX = parseFloat(cs.paddingLeft) + parseFloat(cs.paddingRight);
  const padY = parseFloat(cs.paddingTop)  + parseFloat(cs.paddingBottom);
  const lineHeight = parseFloat(cs.lineHeight) || parseFloat(cs.fontSize) * 1.4;
  const floor = 8 * 16;                      // never narrower than ~8rem
  const cap   = Math.round(window.innerWidth * 0.85);  // leave a little room for the other cells

  // Fit the height first (with wrap off it's stable and independent of width) so a
  // graph that fits shows no vertical scrollbar to skew the width fit below.
  ntCanon.style.height = Math.min(lines.length * lineHeight + padY, 192) + 'px';  // 192px ≈ 12rem cap

  // Be lenient on width: measured line + padding + a comfortable margin (~1 line's
  // worth) + a reserved vertical-scrollbar width. Landing a pixel short pops a
  // horizontal scrollbar, and that scrollbar also steals the bottom line's vertical
  // space — so a generous margin avoids BOTH the too-narrow look and the one-line
  // vertical overflow. The grow-loop below is a backstop if even that falls short.
  const margin = Math.ceil(lineHeight) + scrollbarWidth();
  let width = Math.max(floor, Math.min(Math.ceil(textW) + padX + margin, cap));
  ntCanon.style.width = width + 'px';
  let guard = 0;
  while (guard++ < 200 && width < cap && ntCanon.scrollWidth > ntCanon.clientWidth + 1) {
    width = Math.min(cap, width + 6);
    ntCanon.style.width = width + 'px';
  }
}

// Width first (it affects wrapping), then the shared height.
function syncEditorFields() {
  sizeCanonicalWidth();
  syncFieldHeights();
}
for (const el of [ntCanon, ntNote]) el.addEventListener('input', syncEditorFields);

// Editing the canonical field clears its error ring.
ntCanon.addEventListener('input', () => ntCanon.classList.remove('field-error'));

for (const el of [ntLabel, ntCanon, ntNote]) {
  el.addEventListener('keydown', e => {
    // Plain Enter submits; Shift+Enter inserts a newline in the textareas.
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); submitType(); }
    else if (e.key === 'Escape')          { hideForm(); }
  });
}

// ── Relation types: sidebar tab, list, and the New/Edit Relation form ─────────
//
// A relation type is its SIGNATURE — the name alone identifies nothing — so both
// the list and the form are built around a pair of concept types rather than
// around a name with attributes hanging off it. That is the one real difference
// from the concept side; everything else here deliberately reuses its gestures,
// because a reader who has understood that form should not have to learn a
// second visual language for this one.
//
// The form lives beside the concept form, above the graph, for a reason worth
// stating: source and destination are PICKED from the lattice, never typed. So
// the graph has to stay visible and clickable while the form is open, which
// rules out a pane or a modal.

const relationListEl = document.getElementById('relation-list');
const newRelForm  = document.getElementById('new-rel-form');
const nrLabel     = document.getElementById('nr-label');
const nrSources   = document.getElementById('nr-sources');
const nrSrcEmpty  = document.getElementById('nr-sources-empty');
const nrAddSource = document.getElementById('nr-add-source');
const nrDest      = document.getElementById('nr-dest');
const nrDestEmpty = document.getElementById('nr-dest-empty');
const nrAddDest   = document.getElementById('nr-add-dest');
const nrSuper     = document.getElementById('nr-super');
const nrRole      = document.getElementById('nr-role');
const nrPrep      = document.getElementById('nr-prep');
const nrDesc      = document.getElementById('nr-desc');
const nrNote      = document.getElementById('nr-note');
const nrStatus    = document.getElementById('nr-status');
const nrCreateBtn = document.getElementById('nr-create');
const nrSaveBtn   = document.getElementById('nr-save');
const nrDeleteBtn = document.getElementById('nr-delete');

const sourceSet = new Set();
let destType      = null;   // a single name, or null — a relation has exactly one
let editingRel    = null;   // null = creating; a name = editing that relation
let pickRelSlot   = null;   // null | 'source' | 'dest' — which slot the next click fills
let lastRelTypes  = [];
let syntaxRoles   = [];

function newRelFormOpen() { return !newRelForm.hidden; }

function setNrHint(msg, kind) {
  nrStatus.textContent = msg || '';
  nrStatus.className = kind || '';
}

// ── Sidebar tabs ──────────────────────────────────────────────────────────────

function showSidebarTab(which) {
  for (const btn of document.querySelectorAll('.side-tab'))
    btn.classList.toggle('active', btn.dataset.tab === which);
  typeListEl.hidden     = which !== 'concepts';
  relationListEl.hidden = which !== 'relations';
  // "the list on the left" stops being the concept list when the other tab is
  // showing, so the empty-graph message has to follow the tab. The graph area
  // itself does NOT change meaning — it is still the concept lattice, and still
  // where the relation form's "+" picks from, which is what the second wording
  // has to get across rather than just going blank.
  placeholder.textContent = which === 'relations'
    ? 'Relations are edited from the list on the left. Select a concept type to draw the lattice here — “+” in a relation form picks from it.'
    : 'Select a type from the list on the left.';
  // Fetched on first view rather than at startup: the concept list is what the
  // page opens on, and one more request before first paint buys nothing.
  if (which === 'relations' && !lastRelTypes.length) refreshRelationList();
}

for (const btn of document.querySelectorAll('.side-tab'))
  btn.addEventListener('click', () => showSidebarTab(btn.dataset.tab));

// ── The relation list ─────────────────────────────────────────────────────────

function relationRowEl(r) {
  const el = document.createElement('div');
  el.className = 'rel-item';
  el.dataset.name = r.label;

  const head = document.createElement('div');
  const name = document.createElement('span');
  name.className = 'rel-item-name';
  name.textContent = r.label;
  head.append(name);

  // The badge is the reason this list is worth having: it is the only place the
  // catalog shows which relations have no syntax role, and a relation with no
  // role is invisible in generated English rather than broken — exactly the
  // failure that is impossible to notice from anywhere else.
  // A role no realizer reads drops the relation exactly as no role does, so the
  // badge marks both the same way. Anything else would show a relation as
  // spoken when it is silent — which is the failure this badge exists to catch.
  const roleEntry = r.role ? syntaxRoles.find(s => s.role === r.role) : null;
  // Unknown until the roles have loaded: assume fine rather than raise a false
  // alarm. PAINTRELATIONTYPES runs again once they arrive.
  const dead = r.role ? (roleEntry ? !roleEntry.implemented : false) : true;
  const badge = document.createElement('span');
  // An inherited role is real but second-hand, and saying so matters here: the
  // definition does not contain it, so a reader comparing list to file would
  // otherwise find it missing.
  badge.className = 'rel-item-role' + (dead ? ' none' : (r.inherited ? ' inherited' : ''));
  badge.textContent = (r.role || 'no role') + (r.inherited ? ' ⇡' : '');
  badge.title = !r.role
    ? 'no syntax role — this relation will not appear in generated English'
    : dead
      ? `:${r.role} is declared but no realizer reads it — this relation will not appear in generated English`
      : `surfaces as :${r.role}${r.prep ? ` with "${r.prep}"` : ''}`;
  head.append(badge);
  el.append(head);

  if (r.supertypes && r.supertypes.length) {
    const sup = document.createElement('span');
    sup.className = 'rel-item-super';
    sup.textContent = `⊑ ${r.supertypes.join(', ')}`;
    sup.title = 'inherits signature and syntax role from this';
    head.append(sup);
  }

  const sig = document.createElement('div');
  sig.className = 'rel-item-sig';
  sig.textContent = `${r.sources.join(', ')} → ${r.dest}`;
  el.append(sig);

  el.title = r.desc || '';
  el.addEventListener('click', () => loadRelationForEdit(r.label));
  return el;
}

function paintRelationTypes() {
  relationListEl.replaceChildren();
  if (!lastRelTypes.length) {
    relationListEl.innerHTML = '<div class="rel-item-sig" style="padding:.5rem .75rem">no relation types</div>';
    return;
  }
  relationListEl.append(...lastRelTypes.map(relationRowEl));
}

async function refreshRelationList(selectName) {
  try {
    const resp = await fetch('/api/relation-types');
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || data.error) { showError(data.error || 'could not load relation types'); return; }
    lastRelTypes = data;
    paintRelationTypes();
    if (selectName) showSidebarTab('relations');
  } catch (err) { showError(err.message); }
}

// ── Role menu ─────────────────────────────────────────────────────────────────
// Fetched, never hard-coded: *GENERATION-SYNTAX-ROLES* decides which roles a
// realizer actually reads, and a copy here is a copy that can drift from it.

async function loadSyntaxRoles() {
  try {
    const resp = await fetch('/api/syntax-roles');
    const data = await resp.json().catch(() => ([]));
    if (Array.isArray(data)) syntaxRoles = data;
  } catch { /* the menu degrades to "(none)" only; not worth an error banner */ }
  renderRoleMenu();
  // The badges depend on which roles are implemented, and the list may already
  // be painted from before this resolved — so repaint rather than leave a row
  // showing an unreadable role as though it were fine.
  if (lastRelTypes.length) paintRelationTypes();
}

// Rebuilt whenever the relation list is, and never containing the relation
// being edited: a relation cannot be its own supertype, and offering it only to
// have the server refuse is worse than not offering it.
function renderSuperMenu(current, editing) {
  nrSuper.replaceChildren();
  const none = document.createElement('option');
  none.value = '';
  none.textContent = '⊑ (no parent)';
  none.title = 'a relation of its own, inheriting nothing';
  nrSuper.append(none);
  for (const r of lastRelTypes) {
    if (editing && r.label === editing) continue;
    const opt = document.createElement('option');
    opt.value = r.label;
    opt.textContent = `⊑ ${r.label}`;
    opt.title = `${r.sources.join(', ')} → ${r.dest}`
              + (r.role ? ` — surfaces as :${r.role}` : ' — no syntax role');
    nrSuper.append(opt);
  }
  // Only one is offered even though the model takes a list: multiple
  // inheritance of a SIGNATURE has no obvious meaning (whose arcs must you
  // narrow?), and nothing has asked for it. The file format allows several.
  nrSuper.value = (current && current[0]) || '';
}

function renderRoleMenu() {
  nrRole.replaceChildren();
  // "(no role)" is a real choice, not an empty state: a relation used only for
  // projection never needs to be spoken. The warning after saving is advice.
  const none = document.createElement('option');
  none.value = '';
  none.textContent = '(no role)';
  none.title = 'legal — but the relation will not appear in generated English';
  nrRole.append(none);
  for (const r of syntaxRoles) {
    const opt = document.createElement('option');
    opt.value = r.role;
    // An unimplemented role drops the relation exactly as no role does, so it is
    // marked rather than silently offered as though it worked. The mark LEADS
    // the name instead of trailing it as "(not implemented)": a <select> is as
    // wide as its widest option, so a trailing phrase on one option set the
    // width of the whole control — and clipping it instead would have hidden
    // the mark on the one option that needs it.
    opt.textContent = (r.implemented ? '' : '⚠ ') + r.role;
    opt.title = (r.implemented ? '' :
                 'declared, but no realizer reads it — a relation mapped here is ' +
                 'dropped exactly as one with no role is. ')
      + (r.examples && r.examples.length
         ? `like ${r.examples.slice(0, 6).join(', ')}`
         : 'no relation in this catalog uses it yet');
    nrRole.append(opt);
  }
}

// Only :pp and :iobj read a preposition; the server refuses one without a role.
// Disabling rather than hiding keeps the field bar from reflowing as you change
// the menu, which would move every control to its right.
function syncPrepEnabled() {
  const role = nrRole.value;
  const takesPrep = role === 'pp' || role === 'iobj';
  nrPrep.disabled = !role || !takesPrep;
  if (nrPrep.disabled) nrPrep.value = '';
  nrPrep.placeholder = takesPrep ? 'preposition' : '—';
}
nrRole.addEventListener('change', () => { syncPrepEnabled(); disarmRelDelete(); });
nrSuper.addEventListener('change', disarmRelDelete);

// ── The two type slots ────────────────────────────────────────────────────────

function renderRelChips() {
  for (const c of nrSources.querySelectorAll('.nt-chip')) c.remove();
  for (const c of nrDest.querySelectorAll('.nt-chip')) c.remove();
  nrSrcEmpty.style.display  = sourceSet.size ? 'none' : '';
  nrDestEmpty.style.display = destType ? 'none' : '';
  for (const name of sourceSet)
    nrSources.insertBefore(relChip(name, () => { sourceSet.delete(name); renderRelChips(); }),
                           nrAddSource);
  if (destType)
    nrDest.insertBefore(relChip(destType, () => { destType = null; renderRelChips(); }),
                        nrAddDest);
}

function relChip(name, onRemove) {
  const chip = document.createElement('span');
  chip.className = 'nt-chip';
  chip.title = 'remove';
  const x = document.createElement('span');
  x.className = 'x';
  x.textContent = '✕';
  chip.append(name, x);
  chip.addEventListener('click', () => { onRemove(); disarmRelDelete(); });
  return chip;
}

function enterPickRel(slot) {
  cancelPickTarget();
  exitPickSuper();
  pickRelSlot = slot;
  nrAddSource.classList.toggle('active', slot === 'source');
  nrAddDest.classList.toggle('active', slot === 'dest');
  showInfo(slot === 'source'
    ? 'click one type (in the list or graph) to add as a source'
    : 'click one type (in the list or graph) as the destination');
}

function exitPickRel() {
  pickRelSlot = null;
  nrAddSource.classList.remove('active');
  nrAddDest.classList.remove('active');
  if (errorMsg.classList.contains('is-info')) clearError();
}

function fillRelSlotAndExit(name) {
  const slot = pickRelSlot;
  exitPickRel();
  // A destination is single, so picking replaces rather than accumulates —
  // otherwise correcting a mis-click would need a removal first.
  if (slot === 'dest') destType = name;
  else                 sourceSet.add(name);
  renderRelChips();
  disarmRelDelete();
}

nrAddSource.addEventListener('click',
  () => (pickRelSlot === 'source' ? exitPickRel() : enterPickRel('source')));
nrAddDest.addEventListener('click',
  () => (pickRelSlot === 'dest' ? exitPickRel() : enterPickRel('dest')));

// ── Opening and closing ───────────────────────────────────────────────────────

function openRelForm({ edit = null, supertypes = [], sources = [], dest = '',
                       role = '', prep = '', desc = '', note = '', warning = '' } = {}) {
  hideForm();                    // the two forms are never open at once
  editingRel = edit;
  const isEdit = edit !== null;
  nrLabel.value    = isEdit ? edit : '';
  nrLabel.readOnly = isEdit;     // renaming would orphan every graph using it
  sourceSet.clear();
  sources.forEach(s => sourceSet.add(s));
  destType = dest || null;
  renderRelChips();
  renderSuperMenu(supertypes, edit);
  nrRole.value = role || '';
  syncPrepEnabled();
  nrPrep.value = prep || '';
  nrDesc.value = desc;
  nrNote.value = note;
  nrCreateBtn.hidden = isEdit;
  nrSaveBtn.hidden   = !isEdit;
  nrDeleteBtn.hidden = !isEdit;
  disarmRelDelete();
  clearError();
  setNrHint(warning || (isEdit
    ? `editing ${edit} — “+” picks types from the list or graph`
    : '“+” picks the source and destination from the list or graph'),
    warning ? 'warn' : '');
  newRelForm.hidden = false;
  syncRelFieldHeights();
  (isEdit ? nrRole : nrLabel).focus();
}

function hideRelForm() {
  newRelForm.hidden = true;
  exitPickRel();
  editingRel = null;
  nrLabel.readOnly = false;
  disarmRelDelete();
  setNrHint('');
  clearError();
}

async function loadRelationForEdit(name) {
  clearError();
  try {
    const resp = await fetch(`/api/relation-type-def?label=${encodeURIComponent(name)}`);
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || data.error) { showError(data.error || `could not load ${name}`); return; }
    openRelForm({ edit: data.label, supertypes: data.supertypes || [],
                  sources: data.sources || [], dest: data.dest || '',
                  role: data.role || '', prep: data.prep || '',
                  desc: data.desc || '', note: data.note || '',
                  warning: data.warning || '' });
  } catch (err) { showError(err.message); }
}

document.getElementById('new-rel-btn').addEventListener('click', () => {
  if (newRelFormOpen() && editingRel === null) hideRelForm();
  else openRelForm();
});
document.getElementById('nr-cancel').addEventListener('click', hideRelForm);

// ── Submit ────────────────────────────────────────────────────────────────────

async function submitRelation() {
  const editing = editingRel !== null;
  const label = editing ? editingRel : nrLabel.value.trim();
  if (!label)          { showError('a relation name is required'); if (!editing) nrLabel.focus(); return; }
  if (!sourceSet.size) { showError('click + to pick at least one source type'); return; }
  if (!destType)       { showError('click + to pick a destination type'); return; }
  setNrHint(editing ? 'saving…' : 'creating…');
  try {
    const path = editing ? 'edit-relation-type' : 'create-relation-type';
    const url = `/api/${path}?label=${encodeURIComponent(label)}`
              + `&supertypes=${encodeURIComponent(nrSuper.value)}`
              + `&sources=${encodeURIComponent([...sourceSet].join(','))}`
              + `&dest=${encodeURIComponent(destType)}`
              + `&role=${encodeURIComponent(nrRole.value)}`
              + `&prep=${encodeURIComponent(nrPrep.disabled ? '' : nrPrep.value.trim())}`
              + `&desc=${encodeURIComponent(nrDesc.value.trim())}`
              + `&note=${encodeURIComponent(nrNote.value.trim())}`;
    const resp = await fetch(url, { method: 'POST' });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || !data.ok) {
      setNrHint('');
      showError(data.error || `failed: ${resp.status}`);
      return;
    }
    await refreshRelationList();
    showSidebarTab('relations');
    // A warning means the write SUCCEEDED and something about it is worth
    // knowing — so the form stays open showing it, rather than closing as a
    // clean save does. Closing on a warning would be the same as hiding it.
    if (data.warning) {
      if (!editing) openRelForm({ edit: data.label, supertypes: nrSuper.value ? [nrSuper.value] : [],
                                  sources: [...sourceSet], dest: destType,
                                  role: nrRole.value, prep: nrPrep.value,
                                  desc: nrDesc.value, note: nrNote.value,
                                  warning: data.warning });
      else setNrHint(data.warning, 'warn');
    } else {
      hideRelForm();
    }
  } catch (err) {
    setNrHint('');
    showError(err.message);
  }
}

nrCreateBtn.addEventListener('click', submitRelation);
nrSaveBtn.addEventListener('click', submitRelation);

// ── Delete ────────────────────────────────────────────────────────────────────
// The same two-step arm the concept form uses, for the same reasons: no modal,
// and the button never changes width as it arms.

let relDeleteArmed = false;
let nrHintBeforeArm = '';
let nrHintKindBeforeArm = '';

function disarmRelDelete() {
  if (relDeleteArmed) setNrHint(nrHintBeforeArm, nrHintKindBeforeArm);
  relDeleteArmed = false;
  nrDeleteBtn.classList.remove('armed');
}

function armRelDelete() {
  nrHintBeforeArm = nrStatus.textContent;
  nrHintKindBeforeArm = nrStatus.className;
  relDeleteArmed = true;
  nrDeleteBtn.classList.add('armed');
  setNrHint(`click Delete again to remove ${editingRel} — Cancel, or any edit, backs out`);
}

nrDeleteBtn.addEventListener('click', async () => {
  const label = editingRel;
  if (!label) return;
  if (!relDeleteArmed) { armRelDelete(); return; }
  disarmRelDelete();
  setNrHint(`deleting ${label}…`);
  try {
    const resp = await fetch(`/api/delete-relation-type?label=${encodeURIComponent(label)}`,
                             { method: 'POST' });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || !data.ok) {
      setNrHint('');
      showError(data.error || `failed: ${resp.status}`);
      return;
    }
    hideRelForm();
    await refreshRelationList();
  } catch (err) {
    setNrHint('');
    showError(err.message);
  }
});

// ── Field sizing and keys ─────────────────────────────────────────────────────

function syncRelFieldHeights() {
  for (const el of [nrDesc, nrNote]) el.style.height = 'auto';
  const h = Math.min(Math.max(nrDesc.scrollHeight, nrNote.scrollHeight) + 2, 192);
  for (const el of [nrDesc, nrNote]) el.style.height = h + 'px';
}
for (const el of [nrDesc, nrNote]) {
  el.addEventListener('input', () => { syncRelFieldHeights(); disarmRelDelete(); });
}
for (const el of [nrLabel, nrPrep]) el.addEventListener('input', disarmRelDelete);

for (const el of [nrLabel, nrPrep, nrDesc, nrNote]) {
  el.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); submitRelation(); }
    else if (e.key === 'Escape')          { hideRelForm(); }
  });
}

loadSyntaxRoles();

// ── Draw the canonical graph in the editor ───────────────────────────────────
//
// The editor and this page share an acceptor and an origin, so the round trip
// is a navigation rather than anything cleverer. The one thing a navigation
// costs is the form: the label, supertypes and note you had typed are gone the
// moment we leave. So they go into sessionStorage first and are restored on the
// way back, with the drawn graph dropped into the canonical field.
//
// A second tab plus BroadcastChannel was the alternative and is a worse fit:
// the editor's session model treats a closed tab as "not a decision" — sessions
// are resumable at their URL — so a design that depends on the tab still being
// there fights the thing it is built on. Navigating away and back is exactly
// what a nested editor already does when you descend into a graph referent.

const NT_STASH = 'cgraph.typeform';

function stashTypeForm() {
  sessionStorage.setItem(NT_STASH, JSON.stringify({
    editing: editingLabel,
    label:   ntLabel.value,
    supers:  [...superSet],
    canon:   ntCanon.value,
    note:    ntNote.value
  }));
}

// Restored on load, not on demand: coming back is an ordinary page load, so
// there is no event to hang this on other than the load itself.
function restoreTypeForm() {
  const raw = sessionStorage.getItem(NT_STASH);
  if (!raw) return;
  sessionStorage.removeItem(NT_STASH);   // one restore per stash, never a stale one
  let s;
  try { s = JSON.parse(raw); } catch { return; }
  const drawn = sessionStorage.getItem(NT_STASH + '.result');
  sessionStorage.removeItem(NT_STASH + '.result');
  openForm({ edit: s.editing, supers: s.supers || [],
             canon: drawn !== null ? drawn : (s.canon || ''),
             note: s.note || '' });
  // openForm fills the name from `edit', which is null while creating — so the
  // half-typed name of a type that does not exist yet has to be put back here.
  if (s.editing === null) ntLabel.value = s.label || '';
  syncEditorFields();
  if (drawn !== null) setNtHint('canonical graph drawn — Create or Save to keep it');
}

document.getElementById('nt-draw').addEventListener('click', async () => {
  const text = collapseWhitespace(ntCanon.value);
  setNtHint('opening the editor…');
  try {
    const resp = await fetch(`/api/editor/open-string?text=${encodeURIComponent(text)}`,
                             { method: 'POST' });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok || !data.ok) {
      setNtHint('');
      showError(data.error || `could not open the editor: ${resp.status}`);
      return;
    }
    stashTypeForm();
    // `back' tells the editor where to return. Same-origin and same acceptor,
    // so this is an ordinary path, never a cross-site hop.
    location.href = `/editor?session=${data.session}&back=${encodeURIComponent('/')}`;
  } catch (err) {
    setNtHint('');
    showError(err.message);
  }
});

// The stored canonical is one line; the editor emits several. Same rule the
// server applies on save (COLLAPSE-GRAPH-WHITESPACE), applied here so what we
// hand the editor is what the field means.
function collapseWhitespace(s) { return (s || '').replace(/\s+/g, ' ').trim(); }

restoreTypeForm();
