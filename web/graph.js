const chipsEl        = document.getElementById('chips');
const typeListEl     = document.getElementById('type-list');
const container      = document.getElementById('graph-container');
const errorMsg       = document.getElementById('error-msg');
const placeholder    = document.getElementById('placeholder');
const cgEntriesEl    = document.getElementById('cg-entries');
const cgPlaceholder  = document.getElementById('cg-placeholder');

const selected    = new Set();
const expandedSub = new Set();   // node ids with subtypes force-shown
let baselineNodeIds = new Set(); // node ids visible before any subtype expansion

// ── Error display ─────────────────────────────────────────────────────────────

function showError(msg) { console.error('[cgraph]', msg); errorMsg.textContent = msg; }
function clearError()   { errorMsg.textContent = ''; }

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
      el.className = 'type-item' + (selected.has(name) ? ' selected' : '');
      el.textContent = name;
      el.dataset.name = name;
      el.addEventListener('click', () => {
        if (selected.has(name)) deselect(name);
        else selectType(name);
        addCgEntry(name);
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

      // Expanded nodes: blue fill tint when subtypes are force-shown.
      if (shape && expandedSub.has(node.id))
        shape.setAttribute('fill', '#d6eaf8');

      // Newly revealed nodes: light fill for nodes added by expansion.
      if (shape && baselineNodeIds.size > 0 && !baselineNodeIds.has(node.id) && !expandedSub.has(node.id))
        shape.setAttribute('fill', '#fef9e7');

      // Nodes with a pinned CG entry: subtle green tint.
      if (shape && cgEntries.has(node.id) && !expandedSub.has(node.id) &&
          !(baselineNodeIds.size > 0 && !baselineNodeIds.has(node.id)))
        shape.setAttribute('fill', '#eafaf1');

      // Single click: select/deselect + add CG entry.
      // Double click: toggle CG entry out.
      let singleClickTimer = null;
      node.addEventListener('click', e => {
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
        if (expandedSub.has(node.id)) {
          expandedSub.delete(node.id);
        } else {
          if (expandedSub.size === 0)
            baselineNodeIds = new Set(
              [...container.querySelectorAll('g.node')].map(n => n.id).filter(Boolean)
            );
          expandedSub.add(node.id);
        }
        if (expandedSub.size === 0) baselineNodeIds.clear();
        redraw();
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

// ── Container-level mouse handling ────────────────────────────────────────────

// Left-click on background: clear all subtype expansions.
container.addEventListener('click', e => {
  if (e.target.closest('g.node')) return;
  if (expandedSub.size > 0) {
    expandedSub.clear();
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

    // Clear expansions and redraw.
    expandedSub.clear();
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
