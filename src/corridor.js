import * as THREE from 'three';
import { mulberry32 } from './gfx.js';

const BX = 15, BY = 8.5;
const SPAWN_Z = -290;

export function createCorridor(scene, camera, ship, burst, canvas) {
  const group = new THREE.Group();
  group.visible = false;
  scene.add(group);
  const dl = new THREE.DirectionalLight(0xfff0dd, 3.4);
  dl.position.set(-30, 40, 25);
  group.add(dl);
  group.add(new THREE.AmbientLight(0x7a86b0, 1.1));

  const rnd0 = mulberry32(2024);
  const geos = [0, 1, 2].map((k) => {
    const g = new THREE.IcosahedronGeometry(1, 1);
    const p = g.attributes.position;
    const r = mulberry32(100 + k);
    for (let i = 0; i < p.count; i++) { const s = 0.78 + r() * 0.4; p.setXYZ(i, p.getX(i) * s, p.getY(i) * s, p.getZ(i) * s); }
    g.computeVertexNormals();
    return g;
  });
  const rockMat = [0x8d8378, 0x7a7068, 0x9a8f84].map((c) => new THREE.MeshStandardMaterial({ color: c, roughness: 1, flatShading: true }));
  const POOL = 90;
  const rocks = [];
  for (let i = 0; i < POOL; i++) {
    const m = new THREE.Mesh(geos[i % 3], rockMat[i % 3]);
    m.visible = false;
    group.add(m);
    rocks.push({ m, active: false, r: 1, hit: false, passed: false, spin: new THREE.Vector3() });
  }

  const NS = 110;
  const sp = new Float32Array(NS * 6), sx = [], sy = [], sz = [];
  for (let i = 0; i < NS; i++) {
    const a = rnd0() * 6.283, r = 6 + rnd0() * 24;
    sx.push(Math.cos(a) * r); sy.push(Math.sin(a) * r * 0.7); sz.push(-230 + rnd0() * 250);
  }
  const sGeo = new THREE.BufferGeometry();
  sGeo.setAttribute('position', new THREE.BufferAttribute(sp, 3));
  const streaks = new THREE.LineSegments(sGeo, new THREE.LineBasicMaterial({ color: 0x8fa4d8, transparent: true, opacity: 0.45, fog: false }));
  streaks.frustumCulled = false;
  group.add(streaks);

  const keys = {};
  const ptr = { x: 0, y: 0, down: false };
  const kmap = { ArrowLeft: 'l', KeyA: 'l', ArrowRight: 'r', KeyD: 'r', ArrowUp: 'u', KeyW: 'u', ArrowDown: 'd', KeyS: 'd' };
  window.addEventListener('keydown', (e) => { if (kmap[e.code]) { keys[kmap[e.code]] = true; if (state.active) e.preventDefault(); } });
  window.addEventListener('keyup', (e) => { if (kmap[e.code]) keys[kmap[e.code]] = false; });
  const setPtr = (e) => { ptr.x = (e.clientX / window.innerWidth) * 2 - 1; ptr.y = -((e.clientY / window.innerHeight) * 2 - 1); };
  canvas.addEventListener('pointerdown', (e) => { ptr.down = true; setPtr(e); });
  window.addEventListener('pointermove', (e) => { if (ptr.down) setPtr(e); });
  window.addEventListener('pointerup', () => { ptr.down = false; });

  const state = { active: false };
  let run = null;
  let shake = 0, time = 0;

  const rand = (a, b) => a + Math.random() * (b - a);
  const gauss = () => (Math.random() + Math.random() + Math.random() - 1.5) / 1.5;

  function spawn(o, shipX, shipY) {
    const slot = rocks.find((x) => !x.active);
    if (!slot) return;
    const r = (1.1 + Math.pow(Math.random(), 2) * 2.2) * o.sizeMul;
    let x, y;
    if (Math.random() < o.aimed) { x = shipX + gauss() * 4; y = shipY + gauss() * 2.5; }
    else { x = rand(-BX - 3, BX + 3); y = rand(-BY - 2, BY + 2); }
    slot.active = true; slot.hit = false; slot.passed = false; slot.r = r;
    slot.m.position.set(x, y, SPAWN_Z);
    slot.m.scale.setScalar(r);
    slot.m.visible = true;
    slot.spin.set(rand(-1, 1), rand(-1, 1), rand(-1, 1));
    run.spawned++;
  }

  function botInput(o, s) {
    if (o.bot === 'dumb') return [0, 0];
    if (time < run.botUntil) return run.botTarget;
    if (Math.random() > (o.botSkill ?? 0.75)) {
      run.botUntil = time + 0.5;
      run.botTarget = [Math.random() * 2 - 1, Math.random() * 2 - 1];
      return run.botTarget;
    }
    const vis = 1.52 / run.dens;
    let best = null;
    for (let gx = -BX; gx <= BX; gx += 3) {
      for (let gy = -BY; gy <= BY; gy += 3) {
        let cost = Math.hypot(gx - s.x, gy - s.y) * 0.25;
        for (const k of rocks) {
          if (!k.active || k.hit) continue;
          const z = k.m.position.z;
          if (z < -vis || z > 4) continue;
          const dx = (k.m.position.x - gx) / (k.r * 0.8 + 2.9), dy = (k.m.position.y - gy) / (k.r * 0.8 + 1.5);
          const d2 = dx * dx + dy * dy;
          if (d2 < 1.6) cost += (1.6 - d2) * 40 / (1 + Math.abs(z) / 40);
        }
        if (!best || cost < best.cost) best = { cost, gx, gy };
      }
    }
    return [Math.max(-1, Math.min(1, (best.gx - s.x) / 3)), Math.max(-1, Math.min(1, (best.gy - s.y) / 3))];
  }

  function step(h) {
    const o = run.o;
    const par = o.getParams();
    const thr = par.thr, sens = par.sens;
    run.dens = 0.005 + (1 - sens) * 0.02;
    scene.fog.density = run.dens;
    const s = run.ship;
    time += h;

    let ix = (keys.r ? 1 : 0) - (keys.l ? 1 : 0), iy = (keys.u ? 1 : 0) - (keys.d ? 1 : 0);
    if (!ix && !iy && ptr.down) { ix = Math.max(-1, Math.min(1, (ptr.x * BX - s.x) / 4)); iy = Math.max(-1, Math.min(1, (ptr.y * BY - s.y) / 3)); }
    if (o.bot) [ix, iy] = botInput(o, s);
    const maxV = 21 * thr * (o.pilot ? 1.25 : 1) * (o.thrustBoost ? 1.3 : 1);
    const resp = Math.min(1, 5 * thr * h);
    s.vx += (ix * maxV - s.vx) * resp;
    s.vy += (iy * maxV * 0.8 - s.vy) * resp;
    s.x = Math.max(-BX, Math.min(BX, s.x + s.vx * h));
    s.y = Math.max(-BY, Math.min(BY, s.y + s.vy * h));

    run.spawnClock += h;
    while (run.spawned < o.count && run.spawnClock >= (run.spawned / o.count) * o.spawnTime) spawn(o, s.x, s.y);

    for (const k of rocks) {
      if (!k.active) continue;
      const p = k.m.position, prev = p.z;
      p.z += o.speed * h;
      k.m.rotation.x += k.spin.x * h; k.m.rotation.y += k.spin.y * h;
      if (!k.hit) {
        const zmin = Math.min(prev, p.z), zmax = Math.max(prev, p.z);
        if (zmax >= -1.8 && zmin <= 2.0) {
          const dx = p.x - s.x, dy = p.y - s.y;
          const ex = k.r * 0.8 + 2.4, ey = k.r * 0.8 + 1.0;
          if ((dx / ex) ** 2 + (dy / ey) ** 2 < 1) {
            k.hit = true;
            const loc = Math.abs(dx) > 1.5 && Math.abs(dx) > Math.abs(dy) * 1.2 ? 'arrays' : dy > 0.55 ? 'sensors' : dy < -0.55 ? 'thrusters' : 'centre';
            const amount = Math.round((5 + k.r * 3.2) * (o.shieldPosture ? 0.6 : 1) * (0.85 + Math.random() * 0.3));
            run.hits++;
            shake = 1;
            burst.emit(new THREE.Vector3(s.x + dx * 0.4, s.y + dy * 0.4, -1), 34, 0xffb070, 14);
            o.onHit({ loc, amount, size: k.r });
            k.active = false; k.m.visible = false;
            if (o.shouldAbort && o.shouldAbort()) { run.abort = true; }
            continue;
          }
        }
      }
      if (!k.passed && p.z > 3 && !k.hit) { k.passed = true; run.dodged++; }
      if (p.z > 22) { k.active = false; k.m.visible = false; }
    }

    if (run.spawned >= o.count && !rocks.some((k) => k.active)) run.endTimer += h;
    if (run.abort || run.endTimer > 1.0) finish();
  }

  function visuals(dt) {
    const s = run.ship;
    ship.group.position.set(s.x, s.y, 0);
    ship.group.rotation.set(s.vy * 0.025, 0, -s.vx * 0.04);
    shake = Math.max(0, shake - dt * 2.2);
    const sh = shake * shake * 0.5;
    camera.position.set(s.x * 0.55 + (Math.random() - 0.5) * sh, s.y * 0.55 + 3.4 + (Math.random() - 0.5) * sh, 13.5);
    camera.lookAt(s.x * 0.35, s.y * 0.35 + 0.4, -26);
    const a = sGeo.attributes.position.array, L = 0.9 + run.o.speed * 0.05;
    for (let i = 0; i < NS; i++) {
      sz[i] += run.o.speed * 1.15 * dt;
      if (sz[i] > 18) sz[i] = -230;
      a.set([sx[i], sy[i], sz[i], sx[i], sy[i], sz[i] - L * 3], i * 6);
    }
    sGeo.attributes.position.needsUpdate = true;
    run.o.onTick({ hits: run.hits, progress: Math.min(1, (run.spawned + (run.spawned >= run.o.count ? 0 : 0)) / run.o.count), vis: Math.round(1.52 / run.dens) });
  }

  function finish() {
    if (!state.active) return;
    state.active = false;
    group.visible = false;
    scene.fog = null;
    const res = { hits: run.hits, dodged: run.dodged, aborted: run.abort };
    const done = run.done;
    run = null;
    done(res);
  }

  return {
    get active() { return state.active; },
    group,
    runField(opts) {
      return new Promise((resolve) => {
        const o = { sizeMul: 1, aimed: 0.35, spawnTime: 18, ...opts };
        rocks.forEach((k) => { k.active = false; k.m.visible = false; });
        scene.fog = new THREE.FogExp2(0x02030a, 0.006);
        group.visible = true;
        run = { o, botUntil: 0, botTarget: [0, 0], ship: { x: 0, y: 0, vx: 0, vy: 0 }, hits: 0, dodged: 0, spawned: 0, spawnClock: 0, endTimer: 0, dens: 0.006, abort: false, done: resolve };
        time = 0; shake = 0;
        state.active = true;
        ship.group.position.set(0, 0, 0);
        ship.group.rotation.set(0, 0, 0);
        visuals(0);
      });
    },
    update(dt) {
      if (!state.active || !run) return;
      let rem = dt;
      while (rem > 1e-6 && state.active) {
        const h = Math.min(0.03, rem);
        step(h);
        rem -= h;
      }
      if (state.active) visuals(dt);
    },
  };
}
