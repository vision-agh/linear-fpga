const gridEl = document.getElementById("draw-grid");
const statusEl = document.getElementById("status");
const predictionEl = document.getElementById("prediction");
const cyclesEl = document.getElementById("cycles");
const backendBadgeEl = document.getElementById("backend-badge");
const logitsListEl = document.getElementById("logits-list");
const filesBoxEl = document.getElementById("files-box");
const auditBoxEl = document.getElementById("audit-box");
const configBoxEl = document.getElementById("config-box");
const notesBoxEl = document.getElementById("notes-box");
const backendSelectEl = document.getElementById("backend-select");
const layerConfigEl = document.getElementById("layer-config");
const saveConfigBtnEl = document.getElementById("save-config-btn");

let drawing = false;
let drawMode = "paint";
const GRID_SIZE = 28;
const pixels = new Array(GRID_SIZE * GRID_SIZE).fill(0);
const BRUSH_KERNEL = [
  { dr: 0, dc: 0, weight: 1.0 },
  { dr: -1, dc: 0, weight: 0.55 },
  { dr: 1, dc: 0, weight: 0.55 },
  { dr: 0, dc: -1, weight: 0.55 },
  { dr: 0, dc: 1, weight: 0.55 },
  { dr: -1, dc: -1, weight: 0.2 },
  { dr: -1, dc: 1, weight: 0.2 },
  { dr: 1, dc: -1, weight: 0.2 },
  { dr: 1, dc: 1, weight: 0.2 },
  { dr: -2, dc: 0, weight: 0.08 },
  { dr: 2, dc: 0, weight: 0.08 },
  { dr: 0, dc: -2, weight: 0.08 },
  { dr: 0, dc: 2, weight: 0.08 },
];
let currentConfig = null;

function setStatus(text) {
  statusEl.textContent = text;
}

function clampByte(value) {
  return Math.max(0, Math.min(255, Math.round(value)));
}

function paintCell(index, value) {
  pixels[index] = clampByte(value);
  const cell = gridEl.children[index];
  const intensity = pixels[index] / 255;
  cell.dataset.value = pixels[index] > 0 ? "1" : "0";
  const r = Math.round(15 + intensity * (244 - 15));
  const g = Math.round(27 + intensity * (247 - 27));
  const b = Math.round(45 + intensity * (251 - 45));
  cell.style.backgroundColor = `rgb(${r}, ${g}, ${b})`;
}

function resetGrid() {
  for (let i = 0; i < pixels.length; i += 1) {
    paintCell(i, 0);
  }
  predictionEl.textContent = "-";
  backendBadgeEl.textContent = backendSelectEl.value;
  cyclesEl.textContent = "-";
  logitsListEl.innerHTML = "";
  filesBoxEl.textContent = "No simulation yet.";
}

function buildGrid() {
  for (let row = 0; row < GRID_SIZE; row += 1) {
    for (let col = 0; col < GRID_SIZE; col += 1) {
      const index = row * GRID_SIZE + col;
      const cell = document.createElement("button");
      cell.type = "button";
      cell.className = "grid-cell";
      cell.dataset.index = String(index);
      cell.dataset.value = "0";
      cell.style.setProperty("--fill", "0");
      cell.setAttribute("aria-label", `Pixel ${row}, ${col}`);
      cell.addEventListener("pointerdown", (event) => {
        drawing = true;
        drawMode = event.button === 2 ? "erase" : "paint";
        applyBrush(index, drawMode);
        event.preventDefault();
      });
      cell.addEventListener("pointerenter", () => {
        if (drawing) {
          applyBrush(index, drawMode);
        }
      });
      gridEl.appendChild(cell);
    }
  }
  gridEl.addEventListener("contextmenu", (event) => event.preventDefault());
}

function applyBrush(index, mode) {
  const row = Math.floor(index / GRID_SIZE);
  const col = index % GRID_SIZE;
  for (const { dr, dc, weight } of BRUSH_KERNEL) {
    const rr = row + dr;
    const cc = col + dc;
    if (rr < 0 || rr >= GRID_SIZE || cc < 0 || cc >= GRID_SIZE) {
      continue;
    }
    const target = rr * GRID_SIZE + cc;
    const delta = 255 * weight;
    const nextValue = mode === "paint" ? Math.max(pixels[target], delta) : pixels[target] - delta;
    paintCell(target, nextValue);
  }
}

function getPixels() {
  return [...pixels];
}

function renderLogits(logits) {
  logitsListEl.innerHTML = "";
  if (!Array.isArray(logits)) {
    return;
  }
  const maxValue = Math.max(...logits.map((value) => Math.abs(value)), 1);
  logits.forEach((value, index) => {
    const row = document.createElement("div");
    row.className = "logit-row";

    const label = document.createElement("span");
    label.className = "logit-label";
    label.textContent = index;

    const bar = document.createElement("div");
    bar.className = "logit-bar";

    const fill = document.createElement("div");
    fill.className = "logit-fill";
    fill.style.width = `${Math.max(3, (Math.abs(value) / maxValue) * 100)}%`;
    bar.appendChild(fill);

    const number = document.createElement("span");
    number.className = "logit-value";
    number.textContent = value;

    row.append(label, bar, number);
    logitsListEl.appendChild(row);
  });
}

async function loadJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}`);
  }
  return response.json();
}

async function refreshAuditAndConfig() {
  const [audit, config] = await Promise.all([
    loadJson("/api/audit"),
    loadJson("/api/config"),
  ]);
  currentConfig = config;
  auditBoxEl.textContent = JSON.stringify(audit, null, 2);
  configBoxEl.textContent = JSON.stringify(config, null, 2);
  renderLayerConfig(config.layers);
  notesBoxEl.textContent = `UI feature count: ${config.ui.num_features}\nAvailable backends: ${config.ui.backends.join(", ")}`;
}

function renderLayerConfig(layers) {
  layerConfigEl.innerHTML = "";
  for (const layerName of ["fc1", "fc2", "fc3"]) {
    const layer = layers[layerName];
    const row = document.createElement("div");
    row.className = "layer-row";
    row.innerHTML = `
      <strong>${layerName.toUpperCase()}</strong>
      <label>Temp <input type="number" step="1" data-layer="${layerName}" data-field="temp" value="${layer.temp}"></label>
      <label>Mul/feature <input type="number" step="1" min="1" data-layer="${layerName}" data-field="mul_per_feature" value="${layer.mul_per_feature}"></label>
    `;
    layerConfigEl.appendChild(row);
  }
}

async function saveConfig() {
  const layers = {};
  for (const input of layerConfigEl.querySelectorAll("input")) {
    const { layer, field } = input.dataset;
    layers[layer] ||= {};
    layers[layer][field] = Number(input.value);
  }
  setStatus("Saving config...");
  try {
    const result = await loadJson("/api/config", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ layers }),
    });
    currentConfig = { ...(currentConfig || {}), layers: result.layers };
    configBoxEl.textContent = JSON.stringify({ ...(currentConfig || {}), layers: result.layers }, null, 2);
    setStatus("Config saved.");
  } catch (error) {
    setStatus(`Config save failed: ${error.message}`);
  }
}

async function runSelfTest() {
  setStatus("Checking runtime...");
  try {
    const result = await loadJson("/api/self-test", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    cyclesEl.textContent = result.metrics?.cycles ?? "-";
    filesBoxEl.textContent = JSON.stringify(
      {
        weights: result.weights,
        note: "This checks the simulator path. The drawing flow below still uses fresh canvas pixels.",
      },
      null,
      2
    );
    setStatus("Runtime check passed.");
  } catch (error) {
    setStatus(`Runtime check failed: ${error.message}`);
  }
}

async function runSimulation() {
  setStatus("Running classification...");
  try {
    const result = await loadJson("/api/simulate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pixels: getPixels(), backend: backendSelectEl.value }),
    });
    predictionEl.textContent = result.prediction;
    backendBadgeEl.textContent = result.backend ?? backendSelectEl.value;
    cyclesEl.textContent = result.metrics?.cycles ?? "-";
    filesBoxEl.textContent = JSON.stringify(result.files, null, 2);
    renderLogits(result.logits);
    setStatus("Classification finished.");
  } catch (error) {
    setStatus(`Classification failed: ${error.message}`);
  }
}

window.addEventListener("pointerup", () => {
  drawing = false;
});

document.getElementById("clear-btn").addEventListener("click", resetGrid);
document.getElementById("simulate-btn").addEventListener("click", runSimulation);
document.getElementById("self-test-btn").addEventListener("click", runSelfTest);
saveConfigBtnEl.addEventListener("click", saveConfig);
buildGrid();
resetGrid();
backendSelectEl.addEventListener("change", () => {
  backendBadgeEl.textContent = backendSelectEl.value;
});
refreshAuditAndConfig().catch((error) => {
  auditBoxEl.textContent = `Failed to load audit/config: ${error.message}`;
  configBoxEl.textContent = `Failed to load audit/config: ${error.message}`;
});
