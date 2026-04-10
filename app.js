const STORAGE_KEY = "gungahacks_dashboard_v1";
const statuses = ["Ideas", "Todo", "In Progress", "Done"];

const state = loadState();

const memberForm = document.getElementById("memberForm");
const memberList = document.getElementById("memberList");
const noteForm = document.getElementById("noteForm");
const noteList = document.getElementById("noteList");
const cardForm = document.getElementById("cardForm");
const board = document.getElementById("board");

const memberTemplate = document.getElementById("memberTemplate");
const noteTemplate = document.getElementById("noteTemplate");
const cardTemplate = document.getElementById("cardTemplate");

const seedBtn = document.getElementById("seedBtn");
const exportBtn = document.getElementById("exportBtn");
const importInput = document.getElementById("importInput");
const resetBtn = document.getElementById("resetBtn");
const boardStats = document.getElementById("boardStats");

memberForm.addEventListener("submit", (e) => {
  e.preventDefault();
  const name = document.getElementById("memberName").value.trim();
  const stack = document.getElementById("memberStack").value.trim();
  const role = document.getElementById("memberRole").value.trim();
  if (!name || !stack || !role) return;

  state.members.unshift({ id: id(), name, stack, role });
  memberForm.reset();
  persistAndRender();
});

noteForm.addEventListener("submit", (e) => {
  e.preventDefault();
  const content = document.getElementById("noteInput").value.trim();
  if (!content) return;
  state.notes.unshift({ id: id(), content, at: new Date().toISOString() });
  noteForm.reset();
  persistAndRender();
});

cardForm.addEventListener("submit", (e) => {
  e.preventDefault();
  const title = document.getElementById("cardTitle").value.trim();
  const owner = document.getElementById("cardOwner").value.trim();
  const priority = document.getElementById("cardPriority").value;
  const notes = document.getElementById("cardNotes").value.trim();
  if (!title || !owner) return;

  state.cards.unshift({ id: id(), title, owner, priority, notes, status: "Ideas" });
  cardForm.reset();
  persistAndRender();
});

exportBtn.addEventListener("click", () => {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `gungahacks-dashboard-${new Date().toISOString().slice(0,10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
});

importInput.addEventListener("change", async (e) => {
  const file = e.target.files[0];
  if (!file) return;
  try {
    const text = await file.text();
    const imported = JSON.parse(text);
    if (!imported || !Array.isArray(imported.members) || !Array.isArray(imported.notes) || !Array.isArray(imported.cards)) {
      throw new Error("Invalid dashboard file");
    }
    state.members = imported.members;
    state.notes = imported.notes;
    state.cards = imported.cards;
    persistAndRender();
  } catch (err) {
    alert("Import failed: " + err.message);
  }
  importInput.value = "";
});

seedBtn.addEventListener("click", () => {
  state.members = [
    { id: id(), name: "Kavi", stack: "iOS + AI automation", role: "Integrator" },
    { id: id(), name: "Teammate A", stack: "LeetCode / CS", role: "Builder" },
    { id: id(), name: "Teammate B", stack: "Frontend + docs", role: "Stability" },
  ];
  state.notes = [
    { id: id(), content: "Demo path first. No architecture debates mid-sprint.", at: new Date().toISOString() },
    { id: id(), content: "Vibe lane: UI states/docs/tests only.", at: new Date().toISOString() },
  ];
  state.cards = [
    { id: id(), title: "Lock project scope", owner: "Kavi", priority: "High", notes: "Freeze core deliverable in 10 minutes.", status: "Todo" },
    { id: id(), title: "Build core feature", owner: "Teammate A", priority: "High", notes: "Ship vertical slice.", status: "In Progress" },
    { id: id(), title: "Polish empty/error states", owner: "Teammate B", priority: "Medium", notes: "Safe lane work.", status: "Ideas" },
  ];
  persistAndRender();
});

resetBtn.addEventListener("click", () => {
  if (!confirm("Reset dashboard data? This wipes local browser data.")) return;
  state.members = [];
  state.notes = [];
  state.cards = [];
  persistAndRender();
});

function renderMembers() {
  memberList.innerHTML = "";
  for (const member of state.members) {
    const node = memberTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".name").textContent = member.name;
    node.querySelector(".stack").textContent = `• ${member.stack}`;
    node.querySelector(".role").textContent = member.role;
    node.querySelector(".remove").addEventListener("click", () => {
      state.members = state.members.filter((m) => m.id !== member.id);
      persistAndRender();
    });
    memberList.appendChild(node);
  }
}

function renderNotes() {
  noteList.innerHTML = "";
  for (const note of state.notes) {
    const node = noteTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".content").textContent = note.content;
    node.querySelector(".time").textContent = " • " + new Date(note.at).toLocaleString();
    node.querySelector(".remove").addEventListener("click", () => {
      state.notes = state.notes.filter((n) => n.id !== note.id);
      persistAndRender();
    });
    noteList.appendChild(node);
  }
}

function renderBoard() {
  board.innerHTML = "";
  for (const status of statuses) {
    const col = document.createElement("section");
    col.className = "column";
    const h = document.createElement("h3");
    h.textContent = status;
    col.appendChild(h);

    const cards = state.cards.filter((c) => c.status === status);
    if (!cards.length) {
      const empty = document.createElement("p");
      empty.className = "muted";
      empty.textContent = "No cards";
      col.appendChild(empty);
    }

    for (const card of cards) {
      const node = cardTemplate.content.firstElementChild.cloneNode(true);
      node.querySelector(".title").textContent = card.title;
      node.querySelector(".owner").textContent = `Owner: ${card.owner}`;
      node.querySelector(".notes").textContent = card.notes || "No extra notes.";

      const priority = node.querySelector(".priority");
      priority.textContent = card.priority;
      priority.classList.add(card.priority);

      const statusSelect = node.querySelector(".statusSelect");
      statusSelect.value = card.status;
      statusSelect.addEventListener("change", () => {
        card.status = statusSelect.value;
        persistAndRender();
      });

      node.querySelector(".delete").addEventListener("click", () => {
        state.cards = state.cards.filter((c) => c.id !== card.id);
        persistAndRender();
      });
      col.appendChild(node);
    }

    board.appendChild(col);
  }
}

function persistAndRender() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  render();
}

function render() {
  renderMembers();
  renderNotes();
  renderBoard();
  renderStats();
}

function renderStats() {
  const counts = statuses.map((s) => `${s}: ${state.cards.filter((c) => c.status === s).length}`).join(" • ");
  boardStats.textContent = `${state.cards.length} total cards • ${counts}`;
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { members: [], notes: [], cards: [] };
    const parsed = JSON.parse(raw);
    return {
      members: Array.isArray(parsed.members) ? parsed.members : [],
      notes: Array.isArray(parsed.notes) ? parsed.notes : [],
      cards: Array.isArray(parsed.cards) ? parsed.cards : [],
    };
  } catch {
    return { members: [], notes: [], cards: [] };
  }
}

function id() {
  return Math.random().toString(36).slice(2, 10);
}

render();
