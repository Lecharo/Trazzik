import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

const params = new URLSearchParams(window.location.search);
const viewerId = params.get('viewerId') || 'trazzik-webgl';

const host = document.getElementById('canvas-host');
const statusPill = document.getElementById('status-pill');
const walkHud = document.getElementById('walk-hud');
const walkFloorsEl = document.getElementById('walk-floors');
const walkExitBtn = document.getElementById('walk-exit-btn');

// ---------------------------------------------------------------------------
// 1. Renderer, Scene, Environment IBL & Cameras
// ---------------------------------------------------------------------------
const renderer = new THREE.WebGLRenderer({
  antialias: true,
  alpha: false,
  preserveDrawingBuffer: true,
  powerPreference: 'high-performance',
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.localClippingEnabled = true;
renderer.domElement.tabIndex = 0;
host.appendChild(renderer.domElement);

const scene = new THREE.Scene();
scene.background = new THREE.Color('#0f172a');
scene.fog = new THREE.Fog('#0f172a', 35, 110);

const pmrem = new THREE.PMREMGenerator(renderer);
const roomEnv = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environment = roomEnv;
scene.environmentIntensity = 0.65;

const perspCamera = new THREE.PerspectiveCamera(
  44,
  Math.max(1, window.innerWidth) / Math.max(1, window.innerHeight),
  0.08,
  250
);
perspCamera.position.set(12, 11, 14);

let orthoFrustumSize = 18;
const orthoCamera = new THREE.OrthographicCamera(-9, 9, 9, -9, 0.1, 250);
orthoCamera.position.copy(perspCamera.position);

let activeCamera = perspCamera;

const controls = new OrbitControls(activeCamera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.maxPolarAngle = Math.PI * 0.495;
controls.minDistance = 2.0;
controls.maxDistance = 85.0;
controls.target.set(4, 1.4, 5);

// ---------------------------------------------------------------------------
// 2. Studio Ground Plane & Lights
// ---------------------------------------------------------------------------
const groundGeo = new THREE.PlaneGeometry(180, 180);
const groundMat = new THREE.MeshStandardMaterial({
  color: '#1e293b',
  roughness: 0.94,
  metalness: 0.02,
});
const studioGround = new THREE.Mesh(groundGeo, groundMat);
studioGround.rotation.x = -Math.PI / 2;
studioGround.position.y = -0.06;
studioGround.receiveShadow = true;
scene.add(studioGround);

const gridHelper = new THREE.GridHelper(60, 60, '#334155', '#1e293b');
gridHelper.position.y = -0.055;
if (Array.isArray(gridHelper.material)) {
  gridHelper.material.forEach((m) => {
    m.transparent = true;
    m.opacity = 0.25;
  });
} else {
  gridHelper.material.transparent = true;
  gridHelper.material.opacity = 0.25;
}
scene.add(gridHelper);

const hemiLight = new THREE.HemisphereLight('#dcebff', '#6e655b', 0.85);
scene.add(hemiLight);

const sunLight = new THREE.DirectionalLight('#fffdf7', 2.2);
sunLight.castShadow = true;
sunLight.shadow.mapSize.width = 2048;
sunLight.shadow.mapSize.height = 2048;
sunLight.shadow.bias = -0.0005;
sunLight.shadow.normalBias = 0.025;
scene.add(sunLight);
scene.add(sunLight.target);

const fillLight = new THREE.DirectionalLight('#93c5fd', 0.42);
fillLight.position.set(-14, 10, -12);
scene.add(fillLight);

const interiorLightsGroup = new THREE.Group();
scene.add(interiorLightsGroup);

// Dynamic building root + per-floor groups for zero-rebuild exploded view
const buildingRoot = new THREE.Group();
scene.add(buildingRoot);

const labelsGroup = new THREE.Group();
scene.add(labelsGroup);

const clippingPlanes = [];
const edgeLineMaterial = new THREE.LineBasicMaterial({
  color: '#0f172a',
  transparent: true,
  opacity: 0.22,
  clippingPlanes,
});
const materialCache = new Map();
const textureCache = new Map();
const skyTextureCache = new Map();
const floorGroups = new Map();
const pickableMeshes = [];

let currentPayload = null;
let hasInitializedCamera = false;
let currentShowLabels = true;
let currentBounds = {
  minX: 0, maxX: 10, minY: 0, maxY: 3, minZ: 0, maxZ: 10,
  centerX: 5, centerY: 1.5, centerZ: 5, radius: 8,
};
let currentExplodedFactor = 0.0;
let currentSelectedModuleId = null;
let currentHighlightWall = false;

// Smooth camera tween target
let cameraTween = null;

// First-Person Walk-Through (1.65 m eye height) state
let walkMode = false;
let walkYaw = 0.0;
let walkPitch = 0.0;
let walkFloorElevation = 0.0;
let walkDragging = false;
let walkLastX = 0;
let walkLastY = 0;
const walkKeys = new Set();
const touchMoves = new Set();
let savedOrbitPos = new THREE.Vector3();
let savedOrbitTarget = new THREE.Vector3();

// ---------------------------------------------------------------------------
// 3. Procedural PBR Texture Generator (Albedo + Bump + Roughness)
// ---------------------------------------------------------------------------
function parseHexToRgb(hex) {
  const clean = (hex || '#cccccc').replace('#', '');
  const n = parseInt(clean.length === 3
    ? clean.split('').map((c) => c + c).join('')
    : clean, 16);
  return {
    r: (n >> 16) & 255,
    g: (n >> 8) & 255,
    b: n & 255,
  };
}

function rgbStr(r, g, b, a = 1) {
  const cr = Math.max(0, Math.min(255, Math.round(r)));
  const cg = Math.max(0, Math.min(255, Math.round(g)));
  const cb = Math.max(0, Math.min(255, Math.round(b)));
  return a < 1 ? `rgba(${cr},${cg},${cb},${a})` : `rgb(${cr},${cg},${cb})`;
}

function makeSeededRand(seedStr) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < seedStr.length; i++) {
    h ^= seedStr.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return () => {
    h += 0x6d2b79f5;
    let t = Math.imul(h ^ (h >>> 15), 1 | h);
    t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function createProceduralTextures(spec) {
  const cacheKey = `${spec.pattern}|${spec.color}|${spec.patternColor}`;
  if (textureCache.has(cacheKey)) return textureCache.get(cacheKey);

  const size = 512;
  const colCanvas = document.createElement('canvas');
  colCanvas.width = size;
  colCanvas.height = size;
  const ctx = colCanvas.getContext('2d');

  const bumpCanvas = document.createElement('canvas');
  bumpCanvas.width = size;
  bumpCanvas.height = size;
  const bCtx = bumpCanvas.getContext('2d');

  const base = parseHexToRgb(spec.color);
  const acc = parseHexToRgb(spec.patternColor || spec.color);
  const rand = makeSeededRand(cacheKey);

  ctx.fillStyle = rgbStr(base.r, base.g, base.b);
  ctx.fillRect(0, 0, size, size);
  bCtx.fillStyle = '#808080';
  bCtx.fillRect(0, 0, size, size);

  let repeatScale = 1.0;

  if (spec.pattern === 'woodPlanks' || spec.pattern === 'outdoorDeck') {
    repeatScale = 0.72;
    const rows = spec.pattern === 'outdoorDeck' ? 8 : 6;
    const rowH = size / rows;
    for (let r = 0; r < rows; r++) {
      const y = r * rowH;
      const shade = (rand() - 0.5) * 24;
      ctx.fillStyle = rgbStr(base.r + shade, base.g + shade * 0.9, base.b + shade * 0.75);
      ctx.fillRect(0, y, size, rowH);

      // Fine wood grain fibers
      for (let g = 0; g < 18; g++) {
        const gy = y + rand() * rowH;
        const delta = (rand() - 0.5) * 18;
        ctx.strokeStyle = rgbStr(base.r + delta, base.g + delta, base.b + delta, 0.32);
        ctx.lineWidth = 1 + rand() * 1.8;
        ctx.beginPath();
        ctx.moveTo(0, gy);
        ctx.bezierCurveTo(size * 0.33, gy + (rand() - 0.5) * 4, size * 0.66, gy + (rand() - 0.5) * 4, size, gy);
        ctx.stroke();

        bCtx.strokeStyle = rgbStr(128 + delta * 1.4, 128 + delta * 1.4, 128 + delta * 1.4, 0.35);
        bCtx.lineWidth = 1;
        bCtx.beginPath();
        bCtx.moveTo(0, gy);
        bCtx.lineTo(size, gy);
        bCtx.stroke();
      }

      // Plank seams
      const seamW = spec.pattern === 'outdoorDeck' ? 5 : 2.5;
      ctx.fillStyle = rgbStr(acc.r * 0.55, acc.g * 0.55, acc.b * 0.55, 0.82);
      ctx.fillRect(0, y, size, seamW);
      bCtx.fillStyle = '#202020';
      bCtx.fillRect(0, y, size, seamW);

      // Staggered butt joint
      const jointX = ((r * 173 + 90) % size);
      ctx.fillRect(jointX, y, 2, rowH);
      bCtx.fillRect(jointX, y, 2, rowH);
    }
  } else if (spec.pattern === 'porcelainGrid' || spec.pattern === 'hydraulicTile') {
    repeatScale = spec.pattern === 'hydraulicTile' ? 1.6 : 0.85;
    const cells = 2;
    const cell = size / cells;
    for (let cx = 0; cx < cells; cx++) {
      for (let cy = 0; cy < cells; cy++) {
        const x = cx * cell;
        const y = cy * cell;
        const v = (rand() - 0.5) * 10;
        ctx.fillStyle = rgbStr(base.r + v, base.g + v, base.b + v);
        ctx.fillRect(x, y, cell, cell);

        if (spec.pattern === 'hydraulicTile') {
          ctx.strokeStyle = rgbStr(acc.r, acc.g, acc.b, 0.55);
          ctx.lineWidth = 4;
          ctx.strokeRect(x + 18, y + 18, cell - 36, cell - 36);
          ctx.beginPath();
          ctx.moveTo(x + cell / 2, y + 20);
          ctx.lineTo(x + cell - 20, y + cell / 2);
          ctx.lineTo(x + cell / 2, y + cell - 20);
          ctx.lineTo(x + 20, y + cell / 2);
          ctx.closePath();
          ctx.stroke();
        }
      }
    }
    // Grout lines
    ctx.strokeStyle = rgbStr(acc.r * 0.72, acc.g * 0.72, acc.b * 0.72, 0.8);
    ctx.lineWidth = 4;
    bCtx.strokeStyle = '#303030';
    bCtx.lineWidth = 5;
    for (let i = 0; i <= cells; i++) {
      const p = i * cell;
      ctx.beginPath(); ctx.moveTo(p, 0); ctx.lineTo(p, size); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, p); ctx.lineTo(size, p); ctx.stroke();
      bCtx.beginPath(); bCtx.moveTo(p, 0); bCtx.lineTo(p, size); bCtx.stroke();
      bCtx.beginPath(); bCtx.moveTo(0, p); bCtx.lineTo(size, p); bCtx.stroke();
    }
  } else if (spec.pattern === 'marbleVeins') {
    repeatScale = 0.55;
    // Soft luminous mineral clouding
    for (let i = 0; i < 16; i++) {
      const gx = rand() * size;
      const gy = rand() * size;
      const gr = 60 + rand() * 140;
      const grad = ctx.createRadialGradient(gx, gy, 5, gx, gy, gr);
      grad.addColorStop(0, rgbStr(acc.r, acc.g, acc.b, 0.14));
      grad.addColorStop(1, rgbStr(base.r, base.g, base.b, 0));
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, size, size);
    }
    // Organic Calacatta veins
    for (let v = 0; v < 9; v++) {
      ctx.strokeStyle = rgbStr(acc.r, acc.g, acc.b, 0.24 + rand() * 0.28);
      ctx.lineWidth = 1.2 + rand() * 3.0;
      ctx.beginPath();
      let px = rand() * size;
      let py = 0;
      ctx.moveTo(px, py);
      for (let s = 1; s <= 6; s++) {
        px += (rand() - 0.45) * 90;
        py = (s / 6) * size;
        ctx.lineTo(px, py);
      }
      ctx.stroke();
    }
    // Fine slab joints
    ctx.strokeStyle = rgbStr(acc.r, acc.g, acc.b, 0.22);
    ctx.lineWidth = 2;
    ctx.strokeRect(1, 1, size - 2, size - 2);
  } else if (spec.pattern === 'exposedBrick') {
    repeatScale = 1.25;
    const rows = 10;
    const cols = 4;
    const rowH = size / rows;
    const colW = size / cols;
    // Mortar bed
    ctx.fillStyle = rgbStr(205, 198, 188);
    ctx.fillRect(0, 0, size, size);
    bCtx.fillStyle = '#242424';
    bCtx.fillRect(0, 0, size, size);

    for (let r = 0; r < rows; r++) {
      const offset = (r % 2) * (colW / 2);
      for (let c = -1; c <= cols; c++) {
        const bx = c * colW + offset;
        const by = r * rowH;
        const jitter = (rand() - 0.5) * 28;
        ctx.fillStyle = rgbStr(base.r + jitter, base.g + jitter * 0.7, base.b + jitter * 0.55);
        ctx.fillRect(bx + 3, by + 3, colW - 6, rowH - 6);

        const bumpVal = 185 + Math.round((rand() - 0.5) * 35);
        bCtx.fillStyle = rgbStr(bumpVal, bumpVal, bumpVal);
        bCtx.fillRect(bx + 3, by + 3, colW - 6, rowH - 6);
      }
    }
  } else if (spec.pattern === 'travertineStone') {
    repeatScale = 0.8;
    const bands = 14;
    const bh = size / bands;
    for (let i = 0; i < bands; i++) {
      const d = (rand() - 0.5) * 20;
      ctx.fillStyle = rgbStr(base.r + d, base.g + d * 0.9, base.b + d * 0.8);
      ctx.fillRect(0, i * bh, size, bh);
      bCtx.fillStyle = rgbStr(128 + d, 128 + d, 128 + d);
      bCtx.fillRect(0, i * bh, size, bh);
    }
    ctx.strokeStyle = rgbStr(acc.r * 0.8, acc.g * 0.8, acc.b * 0.8, 0.45);
    ctx.lineWidth = 3;
    ctx.strokeRect(1, 1, size - 2, size / 2 - 2);
    ctx.strokeRect(1, size / 2 + 1, size - 2, size / 2 - 2);
  } else if (spec.pattern === 'naturalGrass') {
    repeatScale = 1.1;
    for (let i = 0; i < 2400; i++) {
      const gx = rand() * size;
      const gy = rand() * size;
      const len = 4 + rand() * 10;
      const d = (rand() - 0.5) * 36;
      ctx.strokeStyle = rgbStr(base.r + d * 0.6, base.g + d, base.b + d * 0.5, 0.65);
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      ctx.moveTo(gx, gy);
      ctx.lineTo(gx + (rand() - 0.5) * 5, gy - len);
      ctx.stroke();

      const bv = 100 + Math.round(rand() * 110);
      bCtx.fillStyle = rgbStr(bv, bv, bv, 0.5);
      bCtx.fillRect(gx, gy, 2, 4);
    }
  } else {
    // paintedWall / polishedConcrete / solid: subtle architectural micro-grain
    repeatScale = 0.7;
    const count = spec.pattern === 'polishedConcrete' ? 1400 : 750;
    for (let i = 0; i < count; i++) {
      const px = rand() * size;
      const py = rand() * size;
      const d = (rand() - 0.5) * (spec.pattern === 'polishedConcrete' ? 22 : 10);
      ctx.fillStyle = rgbStr(base.r + d, base.g + d, base.b + d, 0.28);
      ctx.fillRect(px, py, 3, 3);
      const bv = 128 + Math.round(d * 1.8);
      bCtx.fillStyle = rgbStr(bv, bv, bv, 0.35);
      bCtx.fillRect(px, py, 3, 3);
    }
  }

  const map = new THREE.CanvasTexture(colCanvas);
  map.wrapS = THREE.RepeatWrapping;
  map.wrapT = THREE.RepeatWrapping;
  map.repeat.set(repeatScale, repeatScale);
  map.colorSpace = THREE.SRGBColorSpace;
  map.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());

  const bumpMap = new THREE.CanvasTexture(bumpCanvas);
  bumpMap.wrapS = THREE.RepeatWrapping;
  bumpMap.wrapT = THREE.RepeatWrapping;
  bumpMap.repeat.set(repeatScale, repeatScale);

  const bundle = { map, bumpMap };
  textureCache.set(cacheKey, bundle);
  return bundle;
}

function getOrCreateMaterial(spec) {
  if (materialCache.has(spec.key)) {
    const existing = materialCache.get(spec.key);
    existing.clippingPlanes = clippingPlanes;
    return existing;
  }

  let mat;
  if (spec.pattern === 'glass' || spec.transmission > 0.05) {
    mat = new THREE.MeshPhysicalMaterial({
      color: new THREE.Color(spec.color),
      roughness: spec.roughness,
      metalness: spec.metalness,
      transmission: spec.transmission,
      ior: 1.5,
      thickness: 0.08,
      transparent: true,
      opacity: Math.max(0.28, spec.alpha),
      side: THREE.DoubleSide,
      clippingPlanes,
    });
  } else {
    const tex = createProceduralTextures(spec);
    mat = new THREE.MeshStandardMaterial({
      map: tex.map,
      bumpMap: tex.bumpMap,
      bumpScale: spec.bumpScale,
      roughness: spec.roughness,
      metalness: spec.metalness,
      transparent: spec.alpha < 0.99,
      opacity: spec.alpha,
      side: spec.doubleSided ? THREE.DoubleSide : THREE.FrontSide,
      clippingPlanes,
    });
  }
  materialCache.set(spec.key, mat);
  return mat;
}

// ---------------------------------------------------------------------------
// 4. Sky Gradient, Floating 3D Labels, Lighting, GPU Clipping & Exploded Offsets
// ---------------------------------------------------------------------------
function getSkyGradientTexture(topHex, midHex, bottomHex) {
  const key = `${topHex}|${midHex}|${bottomHex}`;
  if (skyTextureCache.has(key)) return skyTextureCache.get(key);
  const c = document.createElement('canvas');
  c.width = 4;
  c.height = 256;
  const ctx = c.getContext('2d');
  const grad = ctx.createLinearGradient(0, 0, 0, 256);
  grad.addColorStop(0.0, topHex);
  grad.addColorStop(0.55, midHex);
  grad.addColorStop(1.0, bottomHex);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 4, 256);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  skyTextureCache.set(key, tex);
  return tex;
}

function disposeLabels() {
  while (labelsGroup.children.length > 0) {
    const child = labelsGroup.children[0];
    labelsGroup.remove(child);
    if (child.material) {
      if (child.material.map) child.material.map.dispose();
      child.material.dispose();
    }
  }
}

function createRoomLabelSprite(lbl) {
  const w = 512;
  const h = 168;
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const ctx = c.getContext('2d');

  // Rounded dark translucent architectural pill
  const r = 24;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.88)';
  ctx.strokeStyle = 'rgba(56, 189, 248, 0.72)';
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(r + 6, 8);
  ctx.lineTo(w - r - 6, 8);
  ctx.quadraticCurveTo(w - 6, 8, w - 6, r + 8);
  ctx.lineTo(w - 6, h - r - 8);
  ctx.quadraticCurveTo(w - 6, h - 8, w - r - 6, h - 8);
  ctx.lineTo(r + 6, h - 8);
  ctx.quadraticCurveTo(6, h - 8, 6, h - r - 8);
  ctx.lineTo(6, r + 8);
  ctx.quadraticCurveTo(6, 8, r + 6, 8);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  const title = String(lbl.text || '').toUpperCase().slice(0, 22);
  const sub = String(lbl.sub || '').slice(0, 26);

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#f8fafc';
  ctx.font = '700 42px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  ctx.fillText(title, w / 2, sub ? 62 : h / 2);

  if (sub) {
    ctx.fillStyle = '#bae6fd';
    ctx.font = '600 32px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText(sub, w / 2, 118);
  }

  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  const mat = new THREE.SpriteMaterial({
    map: tex,
    transparent: true,
    depthTest: false,
    depthWrite: false,
  });
  const sprite = new THREE.Sprite(mat);
  sprite.scale.set(2.35, 0.77, 1);
  sprite.renderOrder = 25;
  const baseY = (lbl.y || 0.35) + 0.55;
  sprite.position.set(
    lbl.x || 0,
    baseY + Math.max(0, lbl.floorIndex || 0) * currentExplodedFactor * 2.4,
    lbl.z || 0
  );
  sprite.userData = { baseY, floorIndex: lbl.floorIndex || 0 };
  return sprite;
}

function buildRoomLabelSprites(roomLabels) {
  disposeLabels();
  if (!roomLabels || roomLabels.length === 0) return;
  for (const lbl of roomLabels) {
    labelsGroup.add(createRoomLabelSprite(lbl));
  }
  updateLabelsVisibility();
}

function updateLabelsVisibility() {
  labelsGroup.visible = Boolean(currentShowLabels) && !walkMode;
}

function applyLighting(sunPreset, bounds, interiorLights) {
  const cx = bounds.centerX;
  const cy = bounds.centerY;
  const cz = bounds.centerZ;
  const r = Math.max(8, bounds.radius * 1.8);

  // Clear old interior lights
  while (interiorLightsGroup.children.length > 0) {
    interiorLightsGroup.remove(interiorLightsGroup.children[0]);
  }

  let skyTop = '#0c1a30';
  let skyMid = '#1b314f';
  let skyBottom = '#111b2c';
  let fogHex = '#142238';
  let groundHex = '#1e293b';
  let sunColor = '#fffdf7';
  let sunIntensity = 2.3;
  let sunPos = [cx + r * 0.8, cy + r * 1.15, cz + r * 0.75];
  let hemiSky = '#dcebff';
  let hemiGround = '#6e655b';
  let hemiIntensity = 0.92;
  let envIntensity = 0.65;
  let exposure = 1.08;

  if (sunPreset === 'morningEast') {
    skyTop = '#122642';
    skyMid = '#284b6e';
    skyBottom = '#1b293b';
    fogHex = '#1d324a';
    groundHex = '#233144';
    sunColor = '#ffebd2';
    sunIntensity = 2.45;
    sunPos = [cx + r * 1.15, cy + r * 0.85, cz - r * 0.55];
    hemiSky = '#e0f2fe';
    hemiGround = '#78716c';
    hemiIntensity = 0.95;
  } else if (sunPreset === 'goldenHourWest') {
    skyTop = '#181936';
    skyMid = '#5b3952';
    skyBottom = '#2c2233';
    fogHex = '#2b2234';
    groundHex = '#282330';
    sunColor = '#ffb26b';
    sunIntensity = 2.85;
    sunPos = [cx - r * 1.2, cy + r * 0.68, cz + r * 0.85];
    hemiSky = '#fde68a';
    hemiGround = '#475569';
    hemiIntensity = 0.78;
    envIntensity = 0.55;
    exposure = 1.14;
  } else if (sunPreset === 'nightInterior') {
    skyTop = '#040711';
    skyMid = '#0b1328';
    skyBottom = '#070b14';
    fogHex = '#080e1c';
    groundHex = '#111827';
    sunColor = '#7ca4e8';
    sunIntensity = 0.55;
    sunPos = [cx - r * 0.6, cy + r * 1.2, cz - r * 0.8];
    hemiSky = '#334155';
    hemiGround = '#1e293b';
    hemiIntensity = 0.32;
    envIntensity = 0.22;
    exposure = 1.18;

    // Warm 2700K interior point lights per room (capped at 10 for 60 FPS)
    const list = (interiorLights || []).slice(0, 10);
    for (const l of list) {
      const pt = new THREE.PointLight('#ffbe78', 4.2, 9.5, 1.65);
      pt.position.set(
        l.x,
        l.y + Math.max(0, l.floorIndex) * currentExplodedFactor * 2.4,
        l.z
      );
      pt.userData = { baseY: l.y, floorIndex: l.floorIndex };
      interiorLightsGroup.add(pt);
    }
  }

  scene.background = getSkyGradientTexture(skyTop, skyMid, skyBottom);
  scene.fog.color.set(fogHex);
  groundMat.color.set(groundHex);
  scene.environmentIntensity = envIntensity;
  renderer.toneMappingExposure = exposure;

  hemiLight.color.set(hemiSky);
  hemiLight.groundColor.set(hemiGround);
  hemiLight.intensity = hemiIntensity;

  sunLight.color.set(sunColor);
  sunLight.intensity = sunIntensity;
  sunLight.position.set(sunPos[0], sunPos[1], sunPos[2]);
  sunLight.target.position.set(cx, cy, cz);
  sunLight.target.updateMatrixWorld();

  const shadowSpan = Math.max(10, bounds.radius * 1.55);
  sunLight.shadow.camera.left = -shadowSpan;
  sunLight.shadow.camera.right = shadowSpan;
  sunLight.shadow.camera.top = shadowSpan;
  sunLight.shadow.camera.bottom = -shadowSpan;
  sunLight.shadow.camera.near = 1;
  sunLight.shadow.camera.far = r * 4.2;
  sunLight.shadow.camera.updateProjectionMatrix();
}

function applySectionCut(axis, ratio, bounds) {
  clippingPlanes.length = 0;
  if (axis === 'axisX') {
    const cutX = bounds.minX + (bounds.maxX - bounds.minX) * ratio;
    clippingPlanes.push(new THREE.Plane(new THREE.Vector3(-1, 0, 0), cutX));
  } else if (axis === 'axisY') {
    // Trazzik Y maps to Three.js Z
    const cutZ = bounds.minZ + (bounds.maxZ - bounds.minZ) * ratio;
    clippingPlanes.push(new THREE.Plane(new THREE.Vector3(0, 0, -1), cutZ));
  }
  for (const mat of materialCache.values()) {
    mat.clippingPlanes = clippingPlanes;
    mat.needsUpdate = true;
  }
  edgeLineMaterial.clippingPlanes = clippingPlanes;
  edgeLineMaterial.needsUpdate = true;
}

function applyExplodedFactor(factor) {
  currentExplodedFactor = factor;
  for (const [floorIdx, grp] of floorGroups.entries()) {
    grp.position.y = floorIdx > 0 ? floorIdx * factor * 2.4 : 0;
  }
  for (const pt of interiorLightsGroup.children) {
    if (pt.userData && typeof pt.userData.baseY === 'number') {
      const fIdx = Math.max(0, pt.userData.floorIndex || 0);
      pt.position.y = pt.userData.baseY + fIdx * factor * 2.4;
    }
  }
  for (const sp of labelsGroup.children) {
    if (sp.userData && typeof sp.userData.baseY === 'number') {
      const fIdx = Math.max(0, sp.userData.floorIndex || 0);
      sp.position.y = sp.userData.baseY + fIdx * factor * 2.4;
    }
  }
}

function applySelectionHighlight(selectedModuleId, highlightWall) {
  currentSelectedModuleId = selectedModuleId;
  currentHighlightWall = highlightWall;
  for (const mesh of pickableMeshes) {
    const isHit =
      selectedModuleId &&
      mesh.userData.moduleId === selectedModuleId &&
      (!highlightWall || mesh.userData.isWallFace);
    if (mesh.userData.baseMaterial) {
      if (isHit) {
        if (!mesh.userData.selectedMaterial) {
          const cloned = mesh.userData.baseMaterial.clone();
          if (cloned.emissive) {
            cloned.emissive = new THREE.Color('#00b8d4');
            cloned.emissiveIntensity = 0.28;
          }
          mesh.userData.selectedMaterial = cloned;
        }
        mesh.material = mesh.userData.selectedMaterial;
      } else {
        mesh.material = mesh.userData.baseMaterial;
      }
    }
  }
}

function switchProjection(isPerspective) {
  if (walkMode) return;
  const nextCam = isPerspective ? perspCamera : orthoCamera;
  if (nextCam === activeCamera) return;
  nextCam.position.copy(activeCamera.position);
  nextCam.lookAt(controls.target);
  if (!isPerspective) {
    const dist = nextCam.position.distanceTo(controls.target);
    orthoFrustumSize = Math.max(6, dist * 0.72);
    updateOrthoFrustum();
  }
  activeCamera = nextCam;
  controls.object = activeCamera;
  controls.update();
}

function updateOrthoFrustum() {
  const aspect = Math.max(1, window.innerWidth) / Math.max(1, window.innerHeight);
  orthoCamera.left = (-orthoFrustumSize * aspect) / 2;
  orthoCamera.right = (orthoFrustumSize * aspect) / 2;
  orthoCamera.top = orthoFrustumSize / 2;
  orthoCamera.bottom = -orthoFrustumSize / 2;
  orthoCamera.updateProjectionMatrix();
}

// ---------------------------------------------------------------------------
// 5. Scene Loading from Dart Payload
// ---------------------------------------------------------------------------
function disposeBuilding() {
  while (buildingRoot.children.length > 0) {
    const child = buildingRoot.children[0];
    buildingRoot.remove(child);
    child.traverse((obj) => {
      if (obj.geometry) obj.geometry.dispose();
      if (obj.userData && obj.userData.selectedMaterial) {
        obj.userData.selectedMaterial.dispose();
      }
    });
  }
  floorGroups.clear();
  pickableMeshes.length = 0;
}

function loadScenePayload(payload) {
  currentPayload = payload;
  currentBounds = payload.bounds || currentBounds;
  const settings = payload.settings || {};

  disposeBuilding();

  const matLookup = new Map();
  for (const m of payload.materials || []) {
    matLookup.set(m.key, getOrCreateMaterial(m));
  }

  for (const meshData of payload.meshes || []) {
    if (!meshData.positions || meshData.positions.length === 0) continue;
    const fIdx = meshData.floorIndex ?? 0;
    let group = floorGroups.get(fIdx);
    if (!group) {
      group = new THREE.Group();
      floorGroups.set(fIdx, group);
      buildingRoot.add(group);
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute(
      'position',
      new THREE.Float32BufferAttribute(meshData.positions, 3)
    );
    if (meshData.normals && meshData.normals.length === meshData.positions.length) {
      geo.setAttribute(
        'normal',
        new THREE.Float32BufferAttribute(meshData.normals, 3)
      );
    } else {
      geo.computeVertexNormals();
    }
    if (meshData.uvs && meshData.uvs.length > 0) {
      geo.setAttribute('uv', new THREE.Float32BufferAttribute(meshData.uvs, 2));
    }
    if (meshData.indices && meshData.indices.length > 0) {
      geo.setIndex(meshData.indices);
    }

    const mat =
      matLookup.get(meshData.materialKey) ||
      new THREE.MeshStandardMaterial({ color: '#cbd5e1', roughness: 0.7 });

    const mesh = new THREE.Mesh(geo, mat);
    mesh.castShadow = Boolean(meshData.castShadow);
    mesh.receiveShadow = Boolean(meshData.receiveShadow);
    mesh.userData = {
      floorIndex: fIdx,
      moduleId: meshData.moduleId || null,
      floorId: meshData.floorId || null,
      isWallFace: Boolean(meshData.isWallFace),
      baseMaterial: mat,
    };

    group.add(mesh);
    if (meshData.castShadow && !mat.transmission) {
      const edgesGeo = new THREE.EdgesGeometry(geo, 32);
      const edges = new THREE.LineSegments(edgesGeo, edgeLineMaterial);
      group.add(edges);
    }
    if (meshData.moduleId) {
      pickableMeshes.push(mesh);
    }
  }

  studioGround.position.y = (currentBounds.minY || 0) - 0.06;
  gridHelper.position.y = (currentBounds.minY || 0) - 0.055;
  gridHelper.position.x = currentBounds.centerX;
  gridHelper.position.z = currentBounds.centerZ;

  currentShowLabels = settings.showLabels !== false;
  applyExplodedFactor(settings.explodedFactor || 0.0);
  applySectionCut(
    settings.sectionCutAxis || 'none',
    settings.sectionCutRatio ?? 0.65,
    currentBounds
  );
  applyLighting(
    settings.sunPreset || 'studioNoon',
    currentBounds,
    payload.interiorLights || []
  );
  buildRoomLabelSprites(payload.roomLabels || []);
  rebuildWalkFloorButtons(payload.floors || []);
  applySelectionHighlight(
    settings.selectedModuleId || null,
    Boolean(settings.highlightWallSelection)
  );
  switchProjection(settings.isPerspective !== false);

  if (!hasInitializedCamera) {
    hasInitializedCamera = true;
    setCameraPreset('iso', true);
  }

  statusPill.classList.add('hidden');
}

// ---------------------------------------------------------------------------
// 6. Camera Presets & First-Person 1.65m Walk-Through
// ---------------------------------------------------------------------------
function setCameraPreset(presetId, instant = false) {
  if (walkMode) setWalkMode(false);
  const b = currentBounds;
  const dist = Math.max(7.5, b.radius * 2.15);
  const target = new THREE.Vector3(b.centerX, b.centerY * 0.85, b.centerZ);
  let pos;

  switch (presetId) {
    case 'front':
      pos = new THREE.Vector3(b.centerX, b.centerY + dist * 0.14, b.centerZ + dist);
      break;
    case 'back':
      pos = new THREE.Vector3(b.centerX, b.centerY + dist * 0.14, b.centerZ - dist);
      break;
    case 'left':
      pos = new THREE.Vector3(b.centerX - dist, b.centerY + dist * 0.14, b.centerZ);
      break;
    case 'right':
      pos = new THREE.Vector3(b.centerX + dist, b.centerY + dist * 0.14, b.centerZ);
      break;
    case 'top':
      pos = new THREE.Vector3(b.centerX, b.centerY + dist * 1.25, b.centerZ + 0.01);
      break;
    case 'realistic':
      pos = new THREE.Vector3(
        b.centerX - dist * 0.62,
        b.centerY + dist * 0.42,
        b.centerZ + dist * 0.78
      );
      break;
    case 'iso':
    default:
      pos = new THREE.Vector3(
        b.centerX - dist * 0.56,
        b.centerY + dist * 0.66,
        b.centerZ + dist * 0.72
      );
      break;
  }

  if (instant) {
    activeCamera.position.copy(pos);
    controls.target.copy(target);
    orthoFrustumSize = Math.max(6, dist * 0.72);
    updateOrthoFrustum();
    controls.update();
    cameraTween = null;
    return;
  }

  cameraTween = {
    startPos: activeCamera.position.clone(),
    endPos: pos,
    startTarget: controls.target.clone(),
    endTarget: target,
    startTime: performance.now(),
    duration: 420,
  };
}

function rebuildWalkFloorButtons(floors) {
  if (!walkFloorsEl) return;
  walkFloorsEl.innerHTML = '';
  if (!floors || floors.length <= 1) return;
  floors.forEach((f, idx) => {
    const btn = document.createElement('button');
    btn.className = 'walk-btn';
    btn.textContent = `P${idx + 1}`;
    btn.dataset.elevation = String(f.elevation || 0);
    btn.addEventListener('click', () => {
      walkFloorElevation = f.elevation || 0;
      perspCamera.position.y = walkFloorElevation + 1.65;
      highlightActiveWalkFloor();
      renderer.domElement.focus();
    });
    walkFloorsEl.appendChild(btn);
  });
  highlightActiveWalkFloor();
}

function highlightActiveWalkFloor() {
  if (!walkFloorsEl) return;
  walkFloorsEl.querySelectorAll('.walk-btn').forEach((btn) => {
    const elev = parseFloat(btn.dataset.elevation || '0');
    btn.classList.toggle('active', Math.abs(elev - walkFloorElevation) < 0.25);
  });
}

function setWalkMode(enabled, floorElevation = null) {
  if (enabled === walkMode) {
    if (enabled && typeof floorElevation === 'number') {
      walkFloorElevation = floorElevation;
      perspCamera.position.y = walkFloorElevation + 1.65;
      highlightActiveWalkFloor();
    }
    return;
  }

  walkMode = enabled;
  if (walkMode) {
    savedOrbitPos.copy(activeCamera.position);
    savedOrbitTarget.copy(controls.target);
    activeCamera = perspCamera;
    controls.enabled = false;
    cameraTween = null;

    const floors = (currentPayload && currentPayload.floors) || [];
    walkFloorElevation =
      typeof floorElevation === 'number'
        ? floorElevation
        : floors.length > 0
          ? floors[0].elevation
          : currentBounds.minY || 0;

    // Start near front-center interior looking inward at human eye height (1.65m)
    const startX = currentBounds.centerX;
    const startZ = currentBounds.maxZ - 0.9;
    perspCamera.position.set(startX, walkFloorElevation + 1.65, startZ);
    walkYaw = 0;
    walkPitch = -0.04;
    applyWalkOrientation();
    highlightActiveWalkFloor();
    walkHud.classList.add('visible');
    updateLabelsVisibility();
    // Auto-focus iframe/canvas so WASD / Arrow keys work immediately
    window.focus();
    renderer.domElement.focus();
  } else {
    walkHud.classList.remove('visible');
    walkKeys.clear();
    touchMoves.clear();
    perspCamera.position.copy(savedOrbitPos);
    controls.target.copy(savedOrbitTarget);
    controls.object = activeCamera;
    controls.enabled = true;
    controls.update();
    updateLabelsVisibility();
    postToParent({ type: 'walkModeChanged', enabled: false });
  }
}

function applyWalkOrientation() {
  const euler = new THREE.Euler(walkPitch, walkYaw, 0, 'YXZ');
  perspCamera.quaternion.setFromEuler(euler);
}

walkExitBtn.addEventListener('click', () => setWalkMode(false));
document.querySelectorAll('.walk-btn[data-move]').forEach((btn) => {
  const dir = btn.getAttribute('data-move');
  const start = (e) => { e.preventDefault(); touchMoves.add(dir); };
  const stop = () => touchMoves.delete(dir);
  btn.addEventListener('pointerdown', start);
  btn.addEventListener('pointerup', stop);
  btn.addEventListener('pointerleave', stop);
  btn.addEventListener('pointercancel', stop);
});

window.addEventListener('keydown', (e) => {
  if (!walkMode) return;
  if (e.key === 'Escape') {
    setWalkMode(false);
    return;
  }
  walkKeys.add(e.key.toLowerCase());
});
window.addEventListener('keyup', (e) => {
  walkKeys.delete(e.key.toLowerCase());
});

// ---------------------------------------------------------------------------
// 7. Pointer Raycasting (Tap surface -> Open Flutter 3D Configurator) & Walk Look
// ---------------------------------------------------------------------------
const raycaster = new THREE.Raycaster();
const pointerNdc = new THREE.Vector2();
let pointerDownX = 0;
let pointerDownY = 0;

renderer.domElement.addEventListener('pointerdown', (e) => {
  pointerDownX = e.clientX;
  pointerDownY = e.clientY;
  if (walkMode && e.button === 0) {
    walkDragging = true;
    walkLastX = e.clientX;
    walkLastY = e.clientY;
  }
});

renderer.domElement.addEventListener('pointermove', (e) => {
  if (walkMode && walkDragging) {
    const dx = e.clientX - walkLastX;
    const dy = e.clientY - walkLastY;
    walkLastX = e.clientX;
    walkLastY = e.clientY;
    walkYaw -= dx * 0.0045;
    walkPitch = Math.max(-1.25, Math.min(1.25, walkPitch - dy * 0.0038));
    applyWalkOrientation();
  }
});

renderer.domElement.addEventListener('pointerup', (e) => {
  walkDragging = false;
  if (e.button !== 0) return;
  const dist = Math.hypot(e.clientX - pointerDownX, e.clientY - pointerDownY);
  if (dist > 6) return; // Dragged orbit/look, not a tap

  const rect = renderer.domElement.getBoundingClientRect();
  pointerNdc.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
  pointerNdc.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;

  raycaster.setFromCamera(pointerNdc, activeCamera);
  const hits = raycaster.intersectObjects(pickableMeshes, false);
  if (hits.length > 0) {
    const hit = hits[0].object;
    postToParent({
      type: 'surfaceTapped',
      moduleId: hit.userData.moduleId,
      floorId: hit.userData.floorId,
      isWallFace: Boolean(hit.userData.isWallFace),
    });
  } else if (!walkMode) {
    postToParent({
      type: 'surfaceTapped',
      moduleId: null,
      floorId: null,
      isWallFace: false,
    });
  }
});

// ---------------------------------------------------------------------------
// 8. Messaging Bridge (Flutter <-> Three.js)
// ---------------------------------------------------------------------------
function postToParent(msg) {
  window.parent.postMessage({ source: 'trazzik-webgl', viewerId, ...msg }, '*');
}

function captureSnapshot(filename = 'trazzik_render_webgl.png') {
  renderer.render(scene, activeCamera);
  const dataUrl = renderer.domElement.toDataURL('image/png');
  const a = document.createElement('a');
  a.href = dataUrl;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  postToParent({ type: 'snapshotSaved', filename });
}

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || data.target !== 'trazzik-webgl') return;
  if (data.viewerId && data.viewerId !== viewerId) return;

  switch (data.type) {
    case 'loadScene':
      if (data.payload) loadScenePayload(data.payload);
      break;
    case 'updateSettings': {
      const s = data.settings || {};
      if (typeof s.explodedFactor === 'number') {
        applyExplodedFactor(s.explodedFactor);
      }
      if (s.sectionCutAxis !== undefined) {
        applySectionCut(s.sectionCutAxis, s.sectionCutRatio ?? 0.65, currentBounds);
      }
      if (s.sunPreset) {
        applyLighting(
          s.sunPreset,
          currentBounds,
          (currentPayload && currentPayload.interiorLights) || []
        );
      }
      if ('selectedModuleId' in s) {
        applySelectionHighlight(s.selectedModuleId, Boolean(s.highlightWallSelection));
      }
      if (typeof s.isPerspective === 'boolean') {
        switchProjection(s.isPerspective);
      }
      if (typeof s.showLabels === 'boolean') {
        currentShowLabels = s.showLabels;
        updateLabelsVisibility();
      }
      break;
    }
    case 'setCameraPreset':
      setCameraPreset(data.preset || 'iso', Boolean(data.instant));
      break;
    case 'zoomStep': {
      if (walkMode) break;
      const factor = data.factor || 1.0;
      if (activeCamera === perspCamera) {
        const dir = new THREE.Vector3().subVectors(activeCamera.position, controls.target);
        dir.multiplyScalar(factor).clampLength(2.2, 80.0);
        activeCamera.position.copy(controls.target).add(dir);
      } else {
        orthoFrustumSize = Math.max(4, Math.min(60, orthoFrustumSize * factor));
        updateOrthoFrustum();
      }
      controls.update();
      break;
    }
    case 'setWalkMode':
      setWalkMode(Boolean(data.enabled), data.floorElevation);
      break;
    case 'captureSnapshot':
      captureSnapshot(data.filename || 'trazzik_render_webgl.png');
      break;
  }
});

// ---------------------------------------------------------------------------
// 9. Resize & Main Render Loop
// ---------------------------------------------------------------------------
window.addEventListener('resize', () => {
  const w = Math.max(1, window.innerWidth);
  const h = Math.max(1, window.innerHeight);
  perspCamera.aspect = w / h;
  perspCamera.updateProjectionMatrix();
  updateOrthoFrustum();
  renderer.setSize(w, h);
});

const clock = new THREE.Clock();
const forwardVec = new THREE.Vector3();
const rightVec = new THREE.Vector3();

function animate() {
  requestAnimationFrame(animate);
  const dt = Math.min(0.05, clock.getDelta());

  if (walkMode) {
    const speed = 2.8 * dt;
    forwardVec.set(-Math.sin(walkYaw), 0, -Math.cos(walkYaw));
    rightVec.set(Math.cos(walkYaw), 0, -Math.sin(walkYaw));

    if (walkKeys.has('w') || walkKeys.has('arrowup') || touchMoves.has('forward')) {
      perspCamera.position.addScaledVector(forwardVec, speed);
    }
    if (walkKeys.has('s') || walkKeys.has('arrowdown') || touchMoves.has('back')) {
      perspCamera.position.addScaledVector(forwardVec, -speed);
    }
    if (walkKeys.has('a') || walkKeys.has('arrowleft') || touchMoves.has('left')) {
      perspCamera.position.addScaledVector(rightVec, -speed);
    }
    if (walkKeys.has('d') || walkKeys.has('arrowright') || touchMoves.has('right')) {
      perspCamera.position.addScaledVector(rightVec, speed);
    }
    // Keep camera smoothly bounded inside/around site at 1.65 m eye height
    perspCamera.position.x = Math.max(
      currentBounds.minX - 6,
      Math.min(currentBounds.maxX + 6, perspCamera.position.x)
    );
    perspCamera.position.z = Math.max(
      currentBounds.minZ - 6,
      Math.min(currentBounds.maxZ + 6, perspCamera.position.z)
    );
    perspCamera.position.y = walkFloorElevation + 1.65;
  } else if (cameraTween) {
    const elapsed = performance.now() - cameraTween.startTime;
    const t = Math.min(1, elapsed / cameraTween.duration);
    const ease = 1 - Math.pow(1 - t, 3);
    activeCamera.position.lerpVectors(cameraTween.startPos, cameraTween.endPos, ease);
    controls.target.lerpVectors(cameraTween.startTarget, cameraTween.endTarget, ease);
    controls.update();
    if (t >= 1) cameraTween = null;
  } else {
    controls.update();
  }

  renderer.render(scene, activeCamera);
}

animate();
postToParent({ type: 'ready' });
