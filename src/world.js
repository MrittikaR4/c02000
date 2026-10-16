import * as THREE from 'three';
import { STOPS, COMET } from './data.js';
import { mulberry32, planetTexture, glowSprite, glowTexture, canvasTex } from './gfx.js';

const D2R = Math.PI / 180;
const ORB_Z = 0.92;
export const orbitPos = (r, a, y = 0) => new THREE.Vector3(r * Math.cos(a * D2R), y, r * Math.sin(a * D2R) * ORB_Z);

export function cometPos(nuDeg) {
  const { a, e, omega } = COMET;
  const p = a * (1 - e * e);
  const nu = nuDeg * D2R;
  const r = p / (1 + e * Math.cos(nu));
  const x = r * Math.cos(nu), z = r * Math.sin(nu), w = omega * D2R;
  return new THREE.Vector3(x * Math.cos(w) - z * Math.sin(w), 0, x * Math.sin(w) + z * Math.cos(w));
}

const VIEW = {
  earth: { cam: 26, park: 14, rad: 5, ang: 0.55, h: 0.3 },
  mars: { cam: 22, park: 11, rad: 3.5, ang: 0.55, h: 0.3 },
  belt: { cam: 55, park: 24, rad: 3, ang: 0.6, h: 0.3 },
  jupiter: { cam: 70, park: 28, rad: 14, ang: 0.55, h: 0.28 },
  comet: { cam: 28, park: 11, rad: 1.6, ang: 1.25, h: 0.25 },
  pluto: { cam: 20, park: 9, rad: 2.2, ang: 0.55, h: 0.3 },
  blackhole: { cam: 90, park: 48, rad: 12, ang: 0.85, h: 0.45 },
  earth2: { cam: 26, park: 14, rad: 5, ang: 0.55, h: 0.3 },
};

const rotY = (v, a) => { const c = Math.cos(a), s = Math.sin(a); return new THREE.Vector3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c); };

export function createWorld(scene, labelHost) {
  const root = new THREE.Group();
  scene.add(root);
  const spinners = [], orbiters = [], labels = [];

  {
    const rnd = mulberry32(7);
    const N = 2600, pos = new Float32Array(N * 3), col = new Float32Array(N * 3);
    for (let i = 0; i < N; i++) {
      const v = new THREE.Vector3(rnd() - 0.5, rnd() - 0.5, rnd() - 0.5).normalize().multiplyScalar(2600 + rnd() * 400);
      pos.set([v.x, v.y, v.z], i * 3);
      const k = 0.55 + rnd() * 0.45, warm = rnd();
      col.set([k, k * (0.88 + warm * 0.12), k * (0.8 + (1 - warm) * 0.2)], i * 3);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    const stars = new THREE.Points(g, new THREE.PointsMaterial({ size: 2.2, sizeAttenuation: false, vertexColors: true, fog: false, depthWrite: false }));
    stars.frustumCulled = false;
    scene.add(stars);
  }

  const addLabel = (text, obj, yoff, major) => {
    const el = document.createElement('div');
    el.className = 'lab' + (major ? ' major' : '');
    el.textContent = text;
    labelHost.appendChild(el);
    labels.push({ el, obj, yoff, major });
  };

  const sunMesh = new THREE.Mesh(new THREE.SphereGeometry(22, 48, 32), new THREE.MeshBasicMaterial({ map: planetTexture('sun', 3) }));
  root.add(sunMesh);
  const sunGlow1 = glowSprite('255,200,110', 150, 0.95); root.add(sunGlow1);
  const sunGlow2 = glowSprite('255,140,50', 340, 0.4); root.add(sunGlow2);
  const light = new THREE.PointLight(0xfff0d8, 4.2, 0, 0);
  root.add(light);
  root.add(new THREE.AmbientLight(0x6c7ba8, 1.0));
  addLabel('Sun', sunMesh, 30, false);
  spinners.push({ mesh: sunMesh, speed: 0.02 });

  const orbitLine = (r, color = 0x2a3b66, opacity = 0.7) => {
    const pts = [];
    for (let i = 0; i <= 256; i++) pts.push(orbitPos(r, (i / 256) * 360));
    const l = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineBasicMaterial({ color, transparent: true, opacity, fog: false }));
    root.add(l);
  };

  function makePlanet({ name, r, tex, pos, spin = 0.06, tilt = 0.25, atmos = 0, rings = false, label = true, major = false }) {
    const g = new THREE.Group();
    g.position.copy(pos);
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(r, 48, 32), new THREE.MeshStandardMaterial({ map: tex, roughness: 0.92, metalness: 0 }));
    mesh.rotation.z = tilt;
    g.add(mesh);
    if (atmos) {
      g.add(new THREE.Mesh(new THREE.SphereGeometry(r * 1.07, 48, 32), new THREE.MeshBasicMaterial({
        color: atmos, transparent: true, opacity: 0.2, blending: THREE.AdditiveBlending, side: THREE.BackSide, depthWrite: false, fog: false,
      })));
    }
    if (rings) {
      const inner = r * 1.5, outer = r * 2.4;
      const geo = new THREE.RingGeometry(inner, outer, 128, 1);
      const p = geo.attributes.position, uv = geo.attributes.uv;
      for (let i = 0; i < p.count; i++) { const l = Math.hypot(p.getX(i), p.getY(i)); uv.setXY(i, (l - inner) / (outer - inner), 0.5); }
      const rt = canvasTex(256, 4, (c, w, h) => {
        const rnd = mulberry32(5);
        for (let x = 0; x < w; x++) { const a = 0.25 + rnd() * 0.6; c.fillStyle = `rgba(${200 + rnd() * 40},${180 + rnd() * 30},${140 + rnd() * 30},${a})`; c.fillRect(x, 0, 1, h); }
      });
      const ring = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ map: rt, transparent: true, side: THREE.DoubleSide, depthWrite: false }));
      ring.rotation.x = Math.PI / 2 + 0.45; g.add(ring);
    }
    root.add(g);
    spinners.push({ mesh, speed: spin });
    if (label) addLabel(name, g, r + 2.5, major);
    return g;
  }
  const moon = (parent, r, dist, speed, phase, tex, incl = 0.25) => {
    const m = new THREE.Mesh(new THREE.SphereGeometry(r, 20, 14), new THREE.MeshStandardMaterial({ map: tex, roughness: 1 }));
    root.add(m); orbiters.push({ m, parent, dist, speed, phase, incl });
  };

  const rockTex = planetTexture('rock', 11), dark = planetTexture('rock', 12, ['#6b6258']);
  const bodies = {};
  const stopOrbit = (id) => STOPS.find((s) => s.id === id).orbit;

  bodies.earth = makePlanet({ name: 'Earth', r: 5, tex: planetTexture('earth', 2), pos: orbitPos(...Object.values(stopOrbit('earth'))), atmos: 0x4da6ff, spin: 0.08, major: true });
  moon(bodies.earth, 1.3, 11, 0.5, 1, rockTex);
  bodies.mars = makePlanet({ name: 'Mars', r: 3.5, tex: planetTexture('mars', 4), pos: orbitPos(...Object.values(stopOrbit('mars'))), atmos: 0xff9966, spin: 0.07, major: true });
  moon(bodies.mars, 0.35, 6.5, 1.4, 0, dark); moon(bodies.mars, 0.28, 9.5, 0.8, 2, dark);
  bodies.jupiter = makePlanet({ name: 'Jupiter', r: 14, tex: planetTexture('jupiter', 6), pos: orbitPos(...Object.values(stopOrbit('jupiter'))), spin: 0.12, tilt: 0.05, major: true });
  [[1.1, 22, 1.2, 0], [1.0, 28, 0.8, 1.7], [1.7, 36, 0.5, 3.3], [1.5, 45, 0.3, 4.4]].forEach(([r, d, sp, ph], i) => moon(bodies.jupiter, r, d, sp, ph, i % 2 ? dark : rockTex, 0.08));
  bodies.pluto = makePlanet({ name: 'Pluto', r: 2.2, tex: planetTexture('pluto', 8), pos: orbitPos(...Object.values(stopOrbit('pluto'))), spin: 0.03, major: true });
  moon(bodies.pluto, 1.1, 5.2, 0.35, 0, dark, 0.05);

  const beltO = stopOrbit('belt');
  bodies.belt = makePlanet({ name: 'Ceres (Asteroid Belt)', r: 3, tex: rockTex, pos: orbitPos(beltO.r, beltO.a, beltO.y), spin: 0.1, major: true });

  makePlanet({ name: 'Mercury', r: 1.6, tex: planetTexture('rock', 20, ['#9a928a']), pos: orbitPos(46, 200) });
  makePlanet({ name: 'Venus', r: 4.4, tex: planetTexture('band', 21, ['#e6c88a', '#d8b070', '#f1dcae']), pos: orbitPos(68, 300), atmos: 0xffd699 });
  makePlanet({ name: 'Saturn', r: 11, tex: planetTexture('band', 22, ['#e6d29c', '#cdb67e', '#f0e2b8']), pos: orbitPos(310, 165, 3), rings: true, tilt: 0.3 });
  makePlanet({ name: 'Uranus', r: 6, tex: planetTexture('band', 23, ['#9fe0e6', '#8cd0d8']), pos: orbitPos(365, 325), atmos: 0x9fe0e6 });
  makePlanet({ name: 'Neptune', r: 5.8, tex: planetTexture('band', 24, ['#3b5fd0', '#2e4cb4', '#5a7be6']), pos: orbitPos(400, 250), atmos: 0x4466ff });
  [46, 68, 90, 135, 235, 310, 365, 400, 430].forEach((r) => orbitLine(r));
  orbitLine(180, 0x4a3c30, 0.35);

  {
    const rnd = mulberry32(99);
    const N = 2200;
    const mesh = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1, 0), new THREE.MeshStandardMaterial({ color: 0x8f8579, roughness: 1, flatShading: true }), N);
    const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler();
    for (let i = 0; i < N; i++) {
      const r = 158 + (rnd() + rnd()) * 0.5 * 50, a = rnd() * 360;
      const p = orbitPos(r, a, (rnd() - 0.5) * 9);
      e.set(rnd() * 6, rnd() * 6, rnd() * 6); q.setFromEuler(e);
      const sc = 0.25 + Math.pow(rnd(), 3) * 1.5;
      m.compose(p, q, new THREE.Vector3(sc, sc * (0.6 + rnd() * 0.4), sc));
      mesh.setMatrixAt(i, m);
    }
    root.add(mesh);
  }

  const cometNucleus = new THREE.Group();
  const cPos = cometPos(COMET.nu);
  cometNucleus.position.copy(cPos);
  {
    const rock = new THREE.Mesh(new THREE.IcosahedronGeometry(1.6, 1), new THREE.MeshStandardMaterial({ color: 0x5b5650, roughness: 1, flatShading: true }));
    rock.scale.set(1.2, 0.9, 1);
    cometNucleus.add(rock);
    cometNucleus.add(glowSprite('170,215,255', 16, 0.8));
    root.add(cometNucleus);
    bodies.comet = cometNucleus;
    spinners.push({ mesh: rock, speed: 0.4 });
    addLabel('Comet', cometNucleus, 5, true);
    const pts = [];
    for (let i = 0; i <= 360; i += 2) pts.push(cometPos(i));
    root.add(new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineBasicMaterial({ color: 0x4d86a8, transparent: true, opacity: 0.55, fog: false })));
  }
  const TAIL = 900;
  const tailPhase = new Float32Array(TAIL), tailRnd = new Float32Array(TAIL * 3);
  const tailPos = new Float32Array(TAIL * 3), tailCol = new Float32Array(TAIL * 3);
  {
    const rnd = mulberry32(31);
    for (let i = 0; i < TAIL; i++) { tailPhase[i] = rnd(); tailRnd[i * 3] = rnd() - 0.5; tailRnd[i * 3 + 1] = rnd() - 0.5; tailRnd[i * 3 + 2] = rnd() - 0.5; }
  }
  const tailGeo = new THREE.BufferGeometry();
  tailGeo.setAttribute('position', new THREE.BufferAttribute(tailPos, 3));
  tailGeo.setAttribute('color', new THREE.BufferAttribute(tailCol, 3));
  const tail = new THREE.Points(tailGeo, new THREE.PointsMaterial({
    size: 4.2, vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, map: glowTexture('255,255,255'), fog: false,
  }));
  tail.frustumCulled = false;
  root.add(tail);
  const tailDir = cPos.clone().setY(0).normalize();
  const tailSide = new THREE.Vector3(-tailDir.z, 0, tailDir.x);

  const bhO = stopOrbit('blackhole');
  const bh = new THREE.Group();
  bh.position.copy(orbitPos(bhO.r, bhO.a, bhO.y));
  bodies.blackhole = bh;
  const diskTex = canvasTex(512, 256, (c, w, h) => {
    const rnd = mulberry32(77);
    const gr = c.createLinearGradient(0, 0, w, 0);
    gr.addColorStop(0, 'rgba(255,250,220,1)'); gr.addColorStop(0.15, 'rgba(255,200,110,0.95)');
    gr.addColorStop(0.5, 'rgba(255,110,30,0.6)'); gr.addColorStop(1, 'rgba(120,20,0,0)');
    c.fillStyle = gr; c.fillRect(0, 0, w, h);
    for (let i = 0; i < 260; i++) {
      c.globalAlpha = 0.12 + rnd() * 0.25; c.fillStyle = rnd() < 0.5 ? '#000' : '#fff6d0';
      c.fillRect(rnd() * w * 0.9, rnd() * h, 20 + rnd() * 120, 1 + rnd() * 3);
    }
    c.globalAlpha = 1;
  });
  diskTex.wrapT = THREE.RepeatWrapping;
  let disk;
  {
    const inner = 15, outer = 44;
    const geo = new THREE.RingGeometry(inner, outer, 160, 1);
    const p = geo.attributes.position, uv = geo.attributes.uv;
    for (let i = 0; i < p.count; i++) { const x = p.getX(i), y = p.getY(i); uv.setXY(i, (Math.hypot(x, y) - inner) / (outer - inner), (Math.atan2(y, x) / (2 * Math.PI) + 1) % 1 * 3); }
    disk = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ map: diskTex, transparent: true, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
    disk.rotation.x = -Math.PI / 2 + 0.32;
    diskTex.repeat.set(1, 1); diskTex.wrapS = THREE.ClampToEdgeWrapping;
    bh.add(disk);
    bh.add(new THREE.Mesh(new THREE.SphereGeometry(12, 40, 28), new THREE.MeshBasicMaterial({ color: 0x000000 })));
  }
  const halo = new THREE.Mesh(new THREE.RingGeometry(12.3, 19, 96, 1), new THREE.MeshBasicMaterial({
    map: (() => glowTexture('255,190,110'))(), transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, side: THREE.DoubleSide, depthWrite: false, fog: false,
  }));
  {
    const p = halo.geometry.attributes.position, uv = halo.geometry.attributes.uv;
    for (let i = 0; i < p.count; i++) { const l = Math.hypot(p.getX(i), p.getY(i)); uv.setXY(i, 0.5 + ((l - 12.3) / (19 - 12.3)) * 0.0 + 0.0, 0.5 - ((l - 12.3) / (19 - 12.3)) * 0.5); }
  }
  bh.add(halo);
  bh.add(glowSprite('255,150,60', 130, 0.35));
  root.add(bh);
  addLabel('Black hole (simulation)', bh, 24, true);

  const pathLines = [];
  const clearPaths = () => { pathLines.splice(0).forEach((l) => { root.remove(l); l.geometry.dispose(); }); };

  const parkOf = (i) => {
    const st = STOPS[i], v = VIEW[st.id], B = bodyPos(i);
    return B.clone().add(rotY(sunDir(B), -0.25).multiplyScalar(v.park)).add(new THREE.Vector3(0, v.park * 0.05, 0));
  };
  function sunDir(B) { const u = B.clone().multiplyScalar(-1).setY(0); if (u.lengthSq() < 1) u.set(1, 0, 0); return u.normalize(); }
  function bodyPos(i) {
    const g = bodies[STOPS[i].id === 'earth2' ? 'earth' : STOPS[i].id];
    return g.position.clone();
  }

  function curveFor(i0, i1, pid) {
    const A = parkOf(i0), B = parkOf(i1);
    const mid = A.clone().add(B).multiplyScalar(0.5), AB = B.clone().sub(A), len = AB.length();
    const side = new THREE.Vector3(-AB.z, 0, AB.x).normalize();
    if (side.dot(mid) < 0) side.negate();
    const bow = { fast: 0.0, normal: 0.2, ellipse: 0.5 }[pid] ?? 0.2;
    const c = mid.clone().addScaledVector(side, len * bow * 2);
    let q = new THREE.QuadraticBezierCurve3(A, c, B);
    const m = q.getPoint(0.5), d = Math.hypot(m.x, m.z);
    if (d < 75) { c.addScaledVector(side, (75 - d) * 2.2); q = new THREE.QuadraticBezierCurve3(A, c, B); }
    return q;
  }

  const world = {
    root, bodies,
    setVisible(v) { root.visible = v; labelHost.style.display = v ? '' : 'none'; },
    bodyPos, parkPos: parkOf,
    bodyRadius: (i) => VIEW[STOPS[i].id].rad,
    curve: curveFor,
    clearPaths,
    showPaths(i0, i1, only) {
      clearPaths();
      const COL = { fast: 0xff7a5c, normal: 0x6ee7a0, ellipse: 0x6aa8ff };
      Object.keys(COL).forEach((pid) => {
        if (only && only !== pid) return;
        const pts = curveFor(i0, i1, pid).getPoints(90);
        const l = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineDashedMaterial({ color: COL[pid], dashSize: 3, gapSize: 2, transparent: true, opacity: 0.95, fog: false }));
        l.computeLineDistances();
        root.add(l); pathLines.push(l);
      });
    },
    view(i) {
      const st = STOPS[i], v = VIEW[st.id], B = bodyPos(i);
      const u = sunDir(B);
      const pos = B.clone().add(rotY(u, v.ang).multiplyScalar(v.cam)).add(new THREE.Vector3(0, v.cam * v.h, 0));
      const target = B.clone().lerp(parkOf(i), 0.45);
      return { pos, target };
    },
    overview(i0, i1) {
      const A = parkOf(i0), B = parkOf(i1);
      const target = A.clone().add(B).multiplyScalar(0.5);
      const dist = A.distanceTo(B) * 0.95 + 70;
      const pos = target.clone().add(new THREE.Vector3(0.25, 0.85, 0.55).normalize().multiplyScalar(dist));
      return { pos, target };
    },
    update(dt, t, camera) {
      if (!root.visible) return;
      spinners.forEach((s) => (s.mesh.rotation.y += s.speed * dt));
      orbiters.forEach((o) => {
        const a = o.phase + o.speed * t;
        o.m.position.set(o.parent.position.x + Math.cos(a) * o.dist, o.parent.position.y + Math.sin(a) * o.dist * o.incl, o.parent.position.z + Math.sin(a) * o.dist);
      });
      const L = 110;
      for (let i = 0; i < TAIL; i++) {
        const s = (t * 0.1 + tailPhase[i]) % 1;
        const spread = 1.2 + s * 9;
        const ix = i * 3;
        tailPos[ix] = cPos.x + tailDir.x * (s * L) + tailRnd[ix] * spread + tailSide.x * s * s * 14;
        tailPos[ix + 1] = tailRnd[ix + 1] * spread;
        tailPos[ix + 2] = cPos.z + tailDir.z * (s * L) + tailRnd[ix + 2] * spread + tailSide.z * s * s * 14;
        const f = (1 - s) * (1 - s);
        tailCol[ix] = 0.5 * f; tailCol[ix + 1] = 0.72 * f; tailCol[ix + 2] = 1.0 * f;
      }
      tailGeo.attributes.position.needsUpdate = true; tailGeo.attributes.color.needsUpdate = true;
      diskTex.offset.y = (t * 0.12) % 1;
      halo.lookAt(camera.position);
      const pulse = 1 + Math.sin(t * 0.8) * 0.02;
      sunGlow1.scale.setScalar(150 * pulse);
      const v = new THREE.Vector3(), w = window.innerWidth, h = window.innerHeight;
      labels.forEach((l) => {
        l.obj.getWorldPosition(v); v.y += l.yoff;
        const dist = camera.position.distanceTo(v);
        v.project(camera);
        const ok = v.z < 1 && Math.abs(v.x) < 1.05 && Math.abs(v.y) < 1.05 && dist < (l.major ? 1400 : 700) && dist > 6;
        l.el.style.display = ok ? '' : 'none';
        if (ok) {
          l.el.style.transform = `translate(${((v.x + 1) / 2) * w}px, ${((1 - v.y) / 2) * h}px) translate(-50%, -100%)`;
          l.el.style.opacity = String(Math.max(0.25, Math.min(1, 1.6 - dist / 900)));
        }
      });
    },
  };
  return world;
}
