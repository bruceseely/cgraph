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

let cgDisplayMode = 'graph'; // 'graph' | 'linear'

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

function setDisplayMode(mode) {
  if (mode === cgDisplayMode) return;
  cgDisplayMode = mode;
  document.querySelectorAll('.opt-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.mode === mode)
  );
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
  setNtHint('');
  clearError();
}

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
