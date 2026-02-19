const chipsEl        = document.getElementById('chips');
const typeListEl     = document.getElementById('type-list');
const container      = document.getElementById('graph-container');
const errorMsg       = document.getElementById('error-msg');
const placeholder    = document.getElementById('placeholder');
const detailPane     = document.getElementById('detail-pane');
const detailTypeName = document.getElementById('detail-type-name');
const colInput       = document.getElementById('col-input');
const colOutput      = document.getElementById('col-output');
const modeHint       = document.getElementById('mode-hint');
const canonicalRow   = document.getElementById('canonical-row');
const canonicalValue = document.getElementById('canonical-value');

const selected    = new Set();
const expandedSub = new Set();   // node ids with subtypes force-shown

let mode = 'edit';

// ── Error display ─────────────────────────────────────────────────────────────

function showError(msg) { console.error('[cgraph]', msg); errorMsg.textContent = msg; }
function clearError()   { errorMsg.textContent = ''; }

// ── Viz initialisation ────────────────────────────────────────────────────────

let vizInstance = null;

async function getViz() {
  if (vizInstance) return vizInstance;
  const mod = await import('https://esm.sh/@viz-js/viz');
  vizInstance = await mod.instance();
  return vizInstance;
}

// ── Mode toggle ───────────────────────────────────────────────────────────────

document.querySelectorAll('.mode-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    mode = btn.dataset.mode;
    document.querySelectorAll('.mode-btn').forEach(b =>
      b.classList.toggle('active', b === btn)
    );
    modeHint.hidden = (mode !== 'edit');
    redraw();
  });
});

// ── Chips (top bar) ───────────────────────────────────────────────────────────

function renderChips() {
  chipsEl.replaceChildren(
    ...[...selected].map(name => {
      const chip = document.createElement('span');
      chip.className = 'chip';
      chip.title = `Remove ${name}`;
      chip.innerHTML = `${name} <span class="chip-x">✕</span>`;
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
      el.addEventListener('click', () =>
        selected.has(name) ? deselect(name) : selectType(name)
      );
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
  redraw();
}

function deselect(name) {
  selected.delete(name);
  updateSidebarItem(name);
  renderChips();
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

      if (mode === 'info') {
        node.addEventListener('click', () => showRelations(node.id));
      } else {
        // Edit mode — single-click (delayed): select/deselect type.
        // Double-click (e.detail >= 2): show relations.
        let singleClickTimer = null;
        node.addEventListener('click', e => {
          if (e.detail >= 2) {
            if (singleClickTimer) { clearTimeout(singleClickTimer); singleClickTimer = null; }
            showRelations(node.id);
          } else {
            singleClickTimer = setTimeout(() => {
              singleClickTimer = null;
              if (selected.has(node.id)) deselect(node.id);
              else                       selectType(node.id);
            }, 350);
          }
        });
      }

      // Right-click: toggle subtype expansion.
      node.addEventListener('contextmenu', e => {
        e.preventDefault();
        if (expandedSub.has(node.id)) expandedSub.delete(node.id);
        else                          expandedSub.add(node.id);
        redraw();
      });
    });

    container.replaceChildren(svg);
  } catch (err) {
    showError(err.message);
  }
}

// ── Detail pane ───────────────────────────────────────────────────────────────

function buildRelList(relations, container) {
  if (relations.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'rel-empty';
    empty.textContent = 'none';
    container.replaceChildren(empty);
    return;
  }
  container.replaceChildren(
    ...relations.map(rel => {
      const el = document.createElement('div');
      el.className = 'rel-item' + (rel.exact ? ' exact' : '');
      el.title = rel.desc || '';

      const nameSpan = document.createElement('span');
      nameSpan.className = 'rel-name';
      nameSpan.textContent = rel.name;
      el.appendChild(nameSpan);

      if (rel.desc) {
        const descSpan = document.createElement('span');
        descSpan.className = 'rel-desc';
        descSpan.textContent = rel.desc;
        el.appendChild(descSpan);
      }
      return el;
    })
  );
}

async function showRelations(typeName) {
  detailTypeName.textContent = '[' + typeName.toUpperCase() + ']';
  detailPane.classList.add('visible');
  colInput.replaceChildren();
  colOutput.replaceChildren();
  canonicalRow.hidden = true;

  try {
    const resp = await fetch(`/api/relations?type=${encodeURIComponent(typeName)}`);
    if (!resp.ok) { showError(`Relations lookup failed: ${resp.status}`); return; }
    const data = await resp.json();

    if (data.canonical_graph) {
      canonicalValue.textContent = data.canonical_graph;
      canonicalRow.hidden = false;
    }

    buildRelList(data.as_input,  colInput);
    buildRelList(data.as_output, colOutput);
  } catch (err) {
    showError(err.message);
  }
}

// ── Container-level mouse handling ────────────────────────────────────────────
// Attached once to the persistent container div so they work regardless of
// SVG size or whether the click lands inside the SVG or in the padding area.

// Left-click on background: clear all subtype expansions.
container.addEventListener('click', e => {
  if (e.target.closest('g.node')) return;
  if (expandedSub.size > 0) {
    expandedSub.clear();
    redraw();
  }
});

// Right-click on background: suppress the browser context menu.
container.addEventListener('contextmenu', e => {
  if (!e.target.closest('g.node')) e.preventDefault();
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
