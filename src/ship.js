import * as THREE from 'three';
import { glowSprite } from './gfx.js';

const SCORCH = new THREE.Color(0x2a120c);

export function createShip() {
  const group = new THREE.Group();
  const parts = {};
  const mats = {};
  const reg = (id, obj) => { parts[id] = obj; mats[id] = []; group.add(obj); return obj; };
  const std = (id, color, metal = 0.55, rough = 0.45, extra = {}) => {
    const m = new THREE.MeshStandardMaterial({ color, metalness: metal, roughness: rough, emissive: 0x000000, ...extra });
    mats[id].push({ m, base: new THREE.Color(color) });
    return m;
  };
  const rotZ = (geo) => { geo.rotateX(Math.PI / 2); return geo; };

  const hull = reg('hull', new THREE.Group());
  hull.add(new THREE.Mesh(rotZ(new THREE.CylinderGeometry(0.8, 0.66, 3.0, 20)), std('hull', 0xd2d9e3)));
  const band = new THREE.Mesh(rotZ(new THREE.CylinderGeometry(0.82, 0.82, 0.25, 20)), std('hull', 0x3a4a66));
  band.position.z = 0.3; hull.add(band);

  const shield = reg('shield', new THREE.Group());
  const disc = new THREE.Mesh(rotZ(new THREE.CylinderGeometry(1.5, 1.2, 0.2, 28)), std('shield', 0x2e2e32, 0.2, 0.8));
  disc.position.z = -1.65; shield.add(disc);
  const rim = new THREE.Mesh(new THREE.TorusGeometry(1.45, 0.05, 8, 40), std('shield', 0x8a8a92, 0.8, 0.3));
  rim.position.z = -1.62; shield.add(rim);

  const arrays = reg('arrays', new THREE.Group());
  const wings = [];
  [-1, 1].forEach((side) => {
    const w = new THREE.Group();
    const arm = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.07, 0.07), std('arrays', 0x9aa3b0));
    arm.position.x = side * 0.9;
    const panel = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.04, 1.15), std('arrays', 0x2a4fa6, 0.35, 0.35, { emissive: 0x0a1a40 }));
    panel.position.x = side * 2.3;
    w.add(arm, panel);
    w.position.z = 0.2;
    wings.push(w); arrays.add(w);
  });

  const sensors = reg('sensors', new THREE.Group());
  const boom = new THREE.Group();
  const stick = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.9, 8), std('sensors', 0xb8bec8));
  stick.position.y = 0.45;
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.22, 0.34), std('sensors', 0xe0e4ea));
  head.position.y = 0.95;
  const lens = new THREE.Mesh(new THREE.CircleGeometry(0.07, 12), new THREE.MeshBasicMaterial({ color: 0x66ccff }));
  lens.position.set(0, 0.95, -0.18); lens.rotation.y = Math.PI;
  boom.add(stick, head, lens); boom.position.set(0, 0.7, -0.4);
  sensors.add(boom);

  const comms = reg('comms', new THREE.Group());
  const dish = new THREE.Mesh(new THREE.SphereGeometry(0.55, 16, 8, 0, Math.PI * 2, 0, Math.PI / 2), std('comms', 0xeeeeee, 0.3, 0.4, { side: THREE.DoubleSide }));
  dish.rotation.x = Math.PI / 2 + 0.5;
  const feed = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.5, 6), std('comms', 0xaaaaaa));
  const dishG = new THREE.Group(); dishG.add(dish, feed); feed.position.set(0, 0.25, 0.15);
  dishG.position.set(0, 0.9, 1.0);
  comms.add(dishG);

  const thrusters = reg('thrusters', new THREE.Group());
  const bell = new THREE.Mesh(rotZ(new THREE.CylinderGeometry(0.58, 0.32, 0.8, 18, 1, true)), std('thrusters', 0x707782, 0.8, 0.35, { side: THREE.DoubleSide }));
  bell.position.z = 1.9; thrusters.add(bell);
  [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sy]) => {
    const b = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.16, 0.26), std('thrusters', 0x9aa0aa));
    b.position.set(sx * 0.74, sy * 0.5, 1.1); thrusters.add(b);
  });

  const flame = new THREE.Mesh(
    new THREE.ConeGeometry(0.38, 2.4, 14).rotateX(Math.PI / 2),
    new THREE.MeshBasicMaterial({ color: 0x77ccff, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }),
  );
  flame.position.z = 3.35;
  group.add(flame);
  const flameGlow = glowSprite('120,190,255', 3.4, 0.9);
  flameGlow.position.z = 2.5; group.add(flameGlow);

  const plasma = glowSprite('255,140,60', 7, 0);
  plasma.position.z = -2.2; group.add(plasma);

  const ship = {
    group, parts, flame, flameGlow, plasma, flameLevel: 1, plasmaLevel: 0,
    setFlame(v) { this.flameLevel = v; },
    setPlasma(v) { this.plasmaLevel = v; plasma.material.opacity = Math.min(1, v); plasma.scale.setScalar(5 + v * 8); },
    wings, boom, dishG,
    _mats: mats,
  };
  return ship;
}

export function updateShipLook(ship, h, knownShield, t) {
  const M = ship._mats;
  const look = (id, v) => {
    const d = 1 - v / 100;
    M[id].forEach(({ m, base }) => {
      m.color.copy(base).lerp(SCORCH, Math.min(0.85, d * 0.95));
      if (v < 45) {
        const pulse = 0.5 + 0.5 * Math.sin(t * 6 + id.length);
        m.emissive.setRGB(1, 0.25, 0.05);
        m.emissiveIntensity = (1 - v / 45) * (0.25 + 0.5 * pulse);
      } else if (id !== 'arrays') {
        m.emissive.setRGB(0, 0, 0); m.emissiveIntensity = 0;
      } else {
        m.emissive.setRGB(0.04, 0.1, 0.25); m.emissiveIntensity = 1;
      }
    });
    return d;
  };
  const dh = look('hull', h.hull);
  look('shield', knownShield);
  const da = look('arrays', h.arrays);
  const ds = look('sensors', h.sensors);
  const dc = look('comms', h.comms);
  const dt = look('thrusters', h.thrusters);

  ship.wings[0].rotation.z = da * 0.55;
  ship.wings[1].rotation.z = -da * 0.8;
  ship.boom.rotation.z = ds * 0.9;
  ship.dishG.rotation.y = dc > 0.4 ? Math.sin(t * 3.1) * dc * 0.8 : 0;
  ship.parts.hull.scale.set(1 - dh * 0.05, 1 - dh * 0.05, 1);

  const base = ship.flameLevel * (0.45 + 0.55 * (h.thrusters / 100));
  const stutter = h.thrusters < 55 ? 0.6 + 0.4 * Math.sin(t * 31) * Math.sin(t * 17) : 1;
  const k = Math.max(0.02, base * stutter) * (0.92 + 0.08 * Math.sin(t * 40));
  ship.flame.scale.set(1, 1, k); ship.flame.position.z = 2.3 + 1.2 * k;
  ship.flame.material.opacity = 0.2 + 0.65 * Math.min(1, k);
  ship.flameGlow.material.opacity = 0.15 + 0.75 * Math.min(1, k);
  if (ship.plasmaLevel > 0) ship.plasma.material.opacity = Math.min(1, ship.plasmaLevel * (0.85 + 0.15 * Math.sin(t * 50)));
}
