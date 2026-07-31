// CGraph editor — session skeleton.
//
// Proves the plumbing only: fetch the working graph, apply one operation,
// finish with commit or cancel and release the blocked REPL thread. The panes,
// type columns and click model described in notes/graph-editor.md come next.

const params    = new URLSearchParams(location.search);
const SESSION   = params.get('session');

const graphEl   = document.getElementById('graph');
const scratchEl = document.getElementById('scratch');
const statusEl  = document.getElementById('status');
const addBtn    = document.getElementById('add');
const updateBtn = document.getElementById('update');
const cancelBtn = document.getElementById('cancel');

document.getElementById('session-label').textContent =
  SESSION ? `session ${SESSION}` : '(no session)';

function setStatus(msg, kind) {
  statusEl.textContent = msg || '';
  statusEl.className = kind || '';
}

// Refs travel outbound only. The server renders "[DOG +394]"; we strip the
// "+NNN" for display and keep the mapping, which is what click targets will
// resolve against once the graph pane is real. The reader rejects +NNNN, so
// this text is never sent back — edits go as operations against refs.
const REF_RE = /\s\+(\d+)(?=[\]\)])/g;

function stripRefs(withRefs) {
  const refs = [];
  const plain = withRefs.replace(REF_RE, (_, n) => {
    refs.push(Number(n));
    return '';
  });
  return { plain, refs };
}

function render(data) {
  const { plain, refs } = stripRefs(data.withRefs || '');
  graphEl.textContent = plain || '(empty graph)';
  graphEl.dataset.refs = JSON.stringify(refs);
  // Seed the editable field with the plain form so Apply is an edit of what
  // you see, not a blind replacement.
  if (document.activeElement !== scratchEl) scratchEl.value = data.plain || '';
}

async function call(url, opts) {
  const resp = await fetch(url, opts);
  const data = await resp.json().catch(() => ({ ok: false, error: `HTTP ${resp.status}` }));
  if (!resp.ok || !data.ok) throw new Error(data.error || `HTTP ${resp.status}`);
  return data;
}

async function load() {
  try {
    render(await call(`/api/editor/state?session=${encodeURIComponent(SESSION)}`));
    setStatus('');
  } catch (err) {
    setStatus(err.message, 'error');
  }
}

addBtn.addEventListener('click', async () => {
  const text = scratchEl.value.trim();
  if (!text) { scratchEl.focus(); return; }
  try {
    render(await call(
      `/api/editor/op?session=${encodeURIComponent(SESSION)}`
      + `&op=replace&text=${encodeURIComponent(text)}`,
      { method: 'POST' }));
    setStatus('');
  } catch (err) {
    setStatus(err.message, 'error');
  }
});

async function finish(action) {
  try {
    await call(
      `/api/editor/finish?session=${encodeURIComponent(SESSION)}&action=${action}`,
      { method: 'POST' });
    [addBtn, updateBtn, cancelBtn, scratchEl].forEach(el => el.disabled = true);
    setStatus(action === 'commit'
                ? 'Committed — the REPL call has returned. You can close this window.'
                : 'Cancelled — the original is unchanged. You can close this window.',
              'done');
  } catch (err) {
    setStatus(err.message, 'error');
  }
}

updateBtn.addEventListener('click', () => finish('commit'));
cancelBtn.addEventListener('click', () => finish('cancel'));

load();
