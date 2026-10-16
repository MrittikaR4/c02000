import * as THREE from 'three';

export const T = { speed: 1 };
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms / T.speed));

export function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function canvasTex(w, h, draw) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

const glowCache = {};
export function glowTexture(rgb = '255,220,150') {
  if (glowCache[rgb]) return glowCache[rgb];
  const t = canvasTex(128, 128, (g, w, h) => {
    const gr = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
    gr.addColorStop(0, `rgba(${rgb},1)`);
    gr.addColorStop(0.25, `rgba(${rgb},0.45)`);
    gr.addColorStop(1, `rgba(${rgb},0)`);
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
  });
  glowCache[rgb] = t;
  return t;
}

export function glowSprite(rgb, size, opacity = 1) {
  const m = new THREE.SpriteMaterial({
    map: glowTexture(rgb), blending: THREE.AdditiveBlending, depthWrite: false,
    transparent: true, opacity, fog: false,
  });
  const s = new THREE.Sprite(m);
  s.scale.set(size, size, 1);
  return s;
}

export function planetTexture(kind, seed = 1, palette) {
  const rnd = mulberry32(seed);
  return canvasTex(512, 256, (g, w, h) => {
    const blob = (x, y, r, col, a) => {
      g.globalAlpha = a; g.fillStyle = col; g.beginPath();
      g.ellipse(x, y, r, r * (0.5 + rnd() * 0.6), rnd() * 3, 0, 6.283); g.fill(); g.globalAlpha = 1;
    };
    if (kind === 'earth') {
      g.fillStyle = '#1b4f9e'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 40; i++) blob(rnd() * w, h * 0.12 + rnd() * h * 0.76, 10 + rnd() * 40, '#2e8d49', 0.9);
      for (let i = 0; i < 30; i++) blob(rnd() * w, rnd() * h, 8 + rnd() * 30, '#8bb86b', 0.45);
      for (let i = 0; i < 70; i++) blob(rnd() * w, rnd() * h, 10 + rnd() * 40, '#ffffff', 0.22);
      g.fillStyle = '#f3f7fb'; g.fillRect(0, 0, w, 12); g.fillRect(0, h - 14, w, 14);
    } else if (kind === 'mars') {
      g.fillStyle = '#b4532c'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 70; i++) blob(rnd() * w, rnd() * h, 6 + rnd() * 34, '#7a3418', 0.5);
      for (let i = 0; i < 50; i++) blob(rnd() * w, rnd() * h, 6 + rnd() * 30, '#dc9163', 0.4);
      g.fillStyle = '#f2ece6'; g.fillRect(0, 0, w, 8); g.fillRect(0, h - 8, w, 8);
    } else if (kind === 'jupiter' || kind === 'band') {
      const pal = palette || ['#d9b38c', '#b9825a', '#efe0c8', '#9c6b4a', '#caa27a'];
      let y = 0;
      while (y < h) {
        const bh = 8 + rnd() * 22;
        g.fillStyle = pal[Math.floor(rnd() * pal.length)]; g.fillRect(0, y, w, bh + 1); y += bh;
      }
      for (let i = 0; i < 260; i++) {
        g.globalAlpha = 0.18; g.fillStyle = pal[Math.floor(rnd() * pal.length)];
        g.beginPath(); g.ellipse(rnd() * w, rnd() * h, 14 + rnd() * 50, 1.5 + rnd() * 4, 0, 0, 6.283); g.fill();
      }
      g.globalAlpha = 1;
      if (kind === 'jupiter') { g.fillStyle = '#b5472f'; g.beginPath(); g.ellipse(w * 0.65, h * 0.64, 30, 15, 0, 0, 6.283); g.fill(); g.strokeStyle = '#e8c9a8'; g.lineWidth = 3; g.stroke(); }
    } else if (kind === 'pluto') {
      g.fillStyle = '#b79f89'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 70; i++) blob(rnd() * w, rnd() * h, 8 + rnd() * 30, '#8a6f5c', 0.5);
      g.fillStyle = '#f1e8de';
      g.beginPath(); g.arc(w * 0.43, h * 0.5, 22, 0, 6.283); g.arc(w * 0.5, h * 0.5, 22, 0, 6.283); g.fill();
      g.beginPath(); g.moveTo(w * 0.43 - 20, h * 0.54); g.lineTo(w * 0.465, h * 0.5 + 44); g.lineTo(w * 0.5 + 20, h * 0.54); g.fill();
    } else if (kind === 'sun') {
      const gr = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
      gr.addColorStop(0, '#fff6c4'); gr.addColorStop(1, '#ff9d2e');
      g.fillStyle = '#ffc14a'; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 400; i++) blob(rnd() * w, rnd() * h, 3 + rnd() * 12, rnd() < 0.5 ? '#ff8a1f' : '#fff2a8', 0.25);
    } else {
      const base = palette ? palette[0] : '#8c8c8c';
      g.fillStyle = base; g.fillRect(0, 0, w, h);
      for (let i = 0; i < 120; i++) blob(rnd() * w, rnd() * h, 3 + rnd() * 20, '#5d5d5d', 0.35);
      for (let i = 0; i < 60; i++) blob(rnd() * w, rnd() * h, 3 + rnd() * 14, '#c7c7c7', 0.3);
    }
  });
}

export function createBurst(scene) {
  const N = 360;
  const pos = new Float32Array(N * 3), col = new Float32Array(N * 3), vel = new Float32Array(N * 3), life = new Float32Array(N);
  for (let i = 0; i < N; i++) pos[i * 3 + 1] = -1e5;
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
  const mat = new THREE.PointsMaterial({
    size: 1.3, vertexColors: true, transparent: true, depthWrite: false,
    blending: THREE.AdditiveBlending, fog: false, map: glowTexture('255,255,255'),
  });
  const pts = new THREE.Points(geo, mat);
  pts.frustumCulled = false;
  scene.add(pts);
  let head = 0;
  return {
    emit(p, n, color = 0xffaa66, speed = 8) {
      const c = new THREE.Color(color);
      for (let k = 0; k < n; k++) {
        const i = head; head = (head + 1) % N;
        pos[i * 3] = p.x; pos[i * 3 + 1] = p.y; pos[i * 3 + 2] = p.z;
        const v = new THREE.Vector3(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).normalize().multiplyScalar(speed * (0.3 + Math.random()));
        vel[i * 3] = v.x; vel[i * 3 + 1] = v.y; vel[i * 3 + 2] = v.z;
        life[i] = 0.5 + Math.random() * 0.8;
        col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b;
      }
    },
    update(dt) {
      for (let i = 0; i < N; i++) {
        if (life[i] <= 0) continue;
        life[i] -= dt;
        if (life[i] <= 0) { pos[i * 3 + 1] = -1e5; continue; }
        pos[i * 3] += vel[i * 3] * dt; pos[i * 3 + 1] += vel[i * 3 + 1] * dt; pos[i * 3 + 2] += vel[i * 3 + 2] * dt;
        const f = Math.min(1, life[i] * 2) ;
        col[i * 3] *= 1 - dt * 1.2 * (1 - f * 0.3); col[i * 3 + 1] *= 1 - dt * 1.4; col[i * 3 + 2] *= 1 - dt * 1.6;
      }
      geo.attributes.position.needsUpdate = true;
      geo.attributes.color.needsUpdate = true;
    },
  };
}
