import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { STOPS, PATHS, SOLAR, CREW, SUBS, CUE } from './data.js';
import * as S from './state.js';
import * as E from './events.js';
import { T, createBurst } from './gfx.js';
import { createShip, updateShipLook } from './ship.js';
import { createWorld } from './world.js';
import { createCorridor } from './corridor.js';
import * as ui from './ui.js';
import { audio } from './audio.js';

const qs = new URLSearchParams(location.search);
T.speed = Number(qs.get('speed') || window.COSMOS_SPEED || 1) || 1;
const BOT = qs.get('bot') || window.COSMOS_BOT || '';
const LITE = qs.has('lite');

const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: !LITE, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, LITE ? 1 : 1.75));
renderer.setSize(innerWidth, innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x02030a);
const camera = new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.1, 6000);
camera.position.set(140, 60, 90);
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true; controls.dampingFactor = 0.06; controls.enablePan = false; controls.enabled = false;
controls.minDistance = 6; controls.maxDistance = 400;
addEventListener('resize', () => { renderer.setSize(innerWidth, innerHeight); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); });

const world = createWorld(scene, document.getElementById('labels'));
const ship = createShip();
scene.add(ship.group);
const burst = createBurst(scene);
const corridor = createCorridor(scene, camera, ship, burst, canvas);

const ease = (u) => (u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2);
const tweens = [];
const tween = (dur, fn) => new Promise((res) => tweens.push({ t: 0, dur, fn, res }));
let camMode = 'free';
const chaseTan = new THREE.Vector3(0, 0, -1);
let s = null;
let tAbs = 0, last = performance.now();

function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000); last = now; tAbs += dt;
  for (let i = tweens.length - 1; i >= 0; i--) {
    const tw = tweens[i];
    tw.t += dt * T.speed;
    const u = Math.min(1, tw.t / tw.dur);
    tw.fn(u);
    if (u >= 1) { tweens.splice(i, 1); tw.res(); }
  }
  if (corridor.active) {
    corridor.update(dt * T.speed);
  } else {
    world.update(dt, tAbs, camera);
    if (camMode === 'chase') {
      const want = ship.group.position.clone().addScaledVector(chaseTan, -13).add(new THREE.Vector3(0, 4.5, 0));
      camera.position.lerp(want, 1 - Math.exp(-3 * dt * Math.min(T.speed, 6)));
      camera.lookAt(ship.group.position.clone().addScaledVector(chaseTan, 14));
    } else if (controls.enabled) controls.update();
  }
  burst.update(dt);
  if (s) updateShipLook(ship, s.h, s.knownShield, tAbs); else updateShipLook(ship, { hull: 100, arrays: 100, thrusters: 100, sensors: 100, comms: 100, life: 100, shield: 100 }, 100, tAbs);
  renderer.render(scene, camera);
}
requestAnimationFrame(frame);

function camTo(pos, target, dur = 2.2) {
  camMode = 'free';
  controls.enabled = false;
  const p0 = camera.position.clone(), t0 = controls.target.clone();
  if (camMode === 'free' && t0.lengthSq() === 0) t0.copy(world.bodyPos(0));
  return tween(dur, (u) => {
    const e = ease(u);
    camera.position.lerpVectors(p0, pos, e);
    controls.target.lerpVectors(t0, target, e);
    camera.lookAt(controls.target);
  }).then(() => { controls.enabled = true; controls.update(); });
}

const FAIL = Symbol('fail');
function refresh() { if (s) { ui.updateHud(s); ui.updateSubs(s); } }
function guard() {
  s.power = Math.min(100, s.power);
  refresh();
  S.checkFail(s);
  if (s.failed) throw FAIL;
}
function withDiff(fn) {
  const before = { ...s.h };
  const r = fn();
  const lines = SUBS.filter((x) => x.id !== 'shield' && before[x.id] > s.h[x.id]).map((x) => `${x.name} −${before[x.id] - s.h[x.id]}%`);
  if (lines.length) { ui.toast(lines.join(' · '), 'bad'); ui.flash(); audio.warn(); }
  refresh();
  return r;
}
const pickRandom = (a) => a[Math.floor(Math.random() * a.length)];
const shuffle = (a) => a.slice().sort(() => Math.random() - 0.5);

function placeShip(p, tan) {
  ship.group.position.copy(p);
  ship.group.lookAt(p.clone().sub(tan));
  chaseTan.copy(tan);
}

async function pickPath(i) {
  ui.cue(CUE.suspense);
  const from = i - 1;
  world.showPaths(from, i);
  const ov = world.overview(from, i);
  await camTo(ov.pos, ov.target, 2.0);
  const COL = { fast: '#ff7a5c', normal: '#6ee7a0', ellipse: '#6aa8ff' };
  let opts = Object.entries(PATHS).map(([id, p]) => {
    const c = S.pathCost(s, p);
    return {
      id, dot: COL[id], label: p.label,
      sub: `power −${c.power} · budget −${c.budget} · ${c.days} days${p.note ? ' · ' + p.note : ''}`,
      disabled: c.power >= s.power || s.budget - c.budget < 0,
    };
  });
  if (opts.every((o) => o.disabled)) opts = opts.map((o) => ({ ...o, disabled: false }));
  const pid = await ui.choose('path', `Next stop: ${STOPS[i].name}`,
    'Choose your route (shown on the map). Faster burns cost more power and meet faster asteroids. Weak thrusters make every route cost more.', opts);
  world.showPaths(from, i, pid);
  return pid;
}

async function sail(curve, u0, u1, dur) {
  camMode = 'chase'; controls.enabled = false;
  ship.setFlame(1);
  await tween(dur, (u) => {
    const k = u0 + (u1 - u0) * ease(u);
    placeShip(curve.getPoint(k), curve.getTangent(k));
  });
}

function legEvents(i) {
  const n = i === 1 ? 1 : 2;
  const list = [];
  if (i === 2) list.push('belt');
  if (i === 3) list.push('powerdrop');
  for (const t of shuffle(['corridor', 'malfunction', 'flare'])) if (list.length < n) list.push(t);
  return shuffle(list);
}

async function travelLeg(from, i, pid) {
  const c = S.pathCost(s, PATHS[pid]);
  s.power -= c.power; s.budget -= c.budget; s.days += c.days;
  guard();
  const curve = world.curve(from, i, pid);
  const plan = legEvents(i);
  const segs = plan.length + 1;
  placeShip(curve.getPoint(0), curve.getTangent(0));
  for (let k = 0; k < segs; k++) {
    await sail(curve, k / segs, (k + 1) / segs, 3.4);
    if (k < plan.length) { await runEvent(plan[k], pid); guard(); }
  }
  ship.setFlame(0.15);
}

async function runEvent(type, pid) {
  ui.cue(CUE.suspense);
  if (type === 'corridor') await corridorEvent(pid, false);
  else if (type === 'belt') await corridorEvent(pid, true);
  else if (type === 'flare') await flareEvent();
  else if (type === 'malfunction') await malfunctionEvent();
  else if (type === 'powerdrop') await powerDropEvent();
}

async function choiceEvent(id, ev) {
  const opts = ev.options.map((o) => ({ id: o.id, label: o.label, sub: o.sub }));
  const pick = await ui.choose(id, ev.title, ev.text, opts);
  const opt = ev.options.find((o) => o.id === pick) || ev.options[0];
  const text = withDiff(() => opt.run(s));
  ui.toast(text, 'good');
  guard();
}
const flareEvent = async () => { ui.flash('rgba(255,210,90,.5)'); await choiceEvent('flare', E.FLARE); };
const malfunctionEvent = () => choiceEvent('malfunction', pickRandom(E.MALFUNCTIONS));

async function powerDropEvent() {
  const units = S.powerUnits(s);
  audio.alarm(); ui.flash('rgba(255,60,40,.3)');
  const r = await ui.powerPanel(units, E.POWER_SYSTEMS, 14,
    `The arrays can only supply <b>${units}</b> power units right now${s.h.arrays < 100 ? ` (array damage cut this from 30)` : ''}. Choose which systems stay on before time runs out. Going over the limit trips the breakers.`);
  const res = withDiff(() => E.resolvePowerDrop(s, r.chosen, r.timedOut));
  guard();
  await ui.say(res.tone === 'good' ? 'Power stabilised' : 'Power drop result', res.notes.join('<br>'));
}

async function corridorEvent(pid, belt) {
  const sensors = s.h.sensors, thr = s.h.thrusters;
  const notes = [];
  if (sensors < 85) notes.push(`Sensors at ${sensors}%: you will see rocks later (thicker fog).`);
  if (thr < 85) notes.push(`Thrusters at ${thr}%: steering is slower.`);
  if (!notes.length) notes.push('Your ship is in good shape, so sensors and steering are at full strength.');
  const posture = await ui.choose('posture', belt ? 'Asteroid Belt ahead' : 'Asteroid field ahead',
    `Fly through by hand. <b>Arrow keys / WASD</b>, or hold the mouse button and drag. Hits damage the part that gets hit, and that damage stays with you.<br><small>${notes.join(' ')}</small>`,
    [
      { id: 'shield', label: 'Raise debris shields', sub: 'power −4 · hits do 40% less damage' },
      { id: 'thrust', label: 'Thrusters ready', sub: 'power −4 · steering 30% stronger' },
      { id: 'hold', label: 'Hold course', sub: 'free · no changes' },
    ]);
  if (posture !== 'hold') { s.power -= 4; guard(); }
  const sp = PATHS[pid].speed;
  const count = belt ? 70 : 44;
  const savePos = ship.group.position.clone(), saveQ = ship.group.quaternion.clone();
  world.setVisible(false); controls.enabled = false; camMode = 'free';
  ui.mini('Steer: arrow keys / WASD · or hold mouse and drag');
  const botMode = BOT ? (BOT === 'dumb' ? 'dumb' : 'smart') : null;
  const res = await corridor.runField({
    speed: sp * (belt ? 0.9 : 1), count, sizeMul: belt ? 1.15 : 1, spawnTime: belt ? 24 : 18, aimed: belt ? 0.4 : 0.33,
    botSkill: Number(qs.get('skill') || 0.75),
    pilot: S.has(s, 'pilot'), thrustBoost: posture === 'thrust', shieldPosture: posture === 'shield', bot: botMode,
    getParams: () => ({ thr: S.thrusterFactor(s), sens: S.sensorFactor(s) }),
    shouldAbort: () => !!S.checkFail(s),
    onHit: ({ loc, amount }) => {
      audio.thud();
      withDiff(() => {
        if (loc === 'centre') {
          S.damage(s, 'hull', Math.round(amount * 0.6), 'Asteroid hit the nose');
          if (Math.random() < 0.7) S.damage(s, 'shield', Math.round(amount * 1.3), 'Asteroid struck the heat shield');
        } else if (loc === 'arrays') S.damage(s, 'arrays', amount, 'Asteroid hit the solar arrays');
        else if (loc === 'sensors') S.damage(s, 'sensors', amount, 'Asteroid hit the sensor boom');
        else S.damage(s, 'thrusters', amount, 'Asteroid hit the thrusters');
      });
    },
    onTick: (t) => ui.mini(`Hits: <b>${t.hits}</b> · Warning range: ${t.vis} m · ${'▮'.repeat(Math.round(t.progress * 10))}${'▯'.repeat(10 - Math.round(t.progress * 10))}`),
  });
  ui.mini(null);
  world.setVisible(true);
  ship.group.position.copy(savePos); ship.group.quaternion.copy(saveQ);
  if (corridor.group.visible) corridor.group.visible = false;
  ui.toast(`Asteroid field cleared: ${res.hits} hit${res.hits === 1 ? '' : 's'}, ${res.dodged} dodged`, res.hits ? 'bad' : 'good');
  guard();
}

async function arrive(i) {
  const st = STOPS[i];
  camMode = 'free';
  const v = world.view(i);
  await camTo(v.pos, v.target, 2.4);
  ui.cue(CUE.intermission);
  const leak = S.leakCheck(s);
  let extra = '';
  if (SOLAR[st.id] !== undefined) {
    const gain = Math.round(SOLAR[st.id] * S.solarFactor(s));
    s.power = Math.min(100, s.power + gain);
    extra += `<br><small>Solar panels recharged power by ${gain}${s.h.arrays < 70 ? ' (damaged arrays collect less)' : ''}.</small>`;
  }
  if (leak) extra += `<br><small>The damaged hull is leaking air: life support −${leak}%.</small>`;
  guard();
  await ui.say(st.name, st.fact + extra);

  if (st.id === 'comet') await cometSpecial();
  if (st.id === 'blackhole') await blackholeSpecial();
  guard();
}

async function cometSpecial() {
  const pick = await ui.choose('comet', 'Comet flyby', 'The comet is releasing gas and dust. How close do you fly?', [
    { id: 'close', label: 'Close pass', sub: 'power −6 · 2 days · lots of science · dust may hit the ship' },
    { id: 'far', label: 'Safe distance', sub: 'power −2 · less science' },
    { id: 'skip', label: 'Skip', sub: 'free' },
  ]);
  if (pick === 'close') {
    s.power -= 6; s.days += 2;
    const g = S.scanGain(s, 16); s.science += g;
    ui.toast(`Close pass: science +${g}`, 'good');
    if (Math.random() < 0.5) withDiff(() => { S.damage(s, 'sensors', 12, 'Comet dust hit the sensors'); S.damage(s, 'shield', 10, 'Comet dust pitted the heat shield'); });
  } else if (pick === 'far') {
    s.power -= 2;
    const g = S.scanGain(s, 8); s.science += g;
    ui.toast(`Distant study: science +${g}`, 'good');
    if (Math.random() < 0.1) withDiff(() => S.damage(s, 'sensors', 6, 'Stray comet dust'));
  }
}

async function blackholeSpecial() {
  const pick = await ui.choose('blackhole', 'Black hole decision (simulation)',
    'This is a "what if" simulation. Real black holes are far from our Solar System. Close to one, time and light behave strangely, and radiation is intense.', [
      { id: 'study', label: 'Study it', sub: '10 days · big science · radiation will damage arrays, sensors and comms' },
      { id: 'sling', label: 'Slingshot', sub: '55%: save 10 days and gain power · 45%: thrusters and hull strained' },
      { id: 'away', label: 'Turn away', sub: 'free · nothing gained, nothing lost' },
    ]);
  if (pick === 'study') {
    s.days += 10;
    const g = S.scanGain(s, 24); s.science += g;
    ui.toast(`Science +${g}`, 'good');
    withDiff(() => { S.damage(s, 'arrays', 15, 'Black hole radiation hit the arrays'); S.damage(s, 'sensors', 15, 'Black hole radiation hit the sensors'); S.damage(s, 'comms', 10, 'Black hole radiation hit the comms'); });
  } else if (pick === 'sling') {
    if (Math.random() < 0.55) { s.days = Math.max(0, s.days - 10); s.power = Math.min(100, s.power + 8); ui.toast('Perfect slingshot: 10 days saved, power +8', 'good'); }
    else withDiff(() => { S.damage(s, 'thrusters', 20, 'Slingshot strained the thrusters'); S.damage(s, 'hull', 10, 'Tidal stress on the hull'); });
  }
}

async function hub(i) {
  const st = STOPS[i];
  let scanned = false;
  for (;;) {
    camMode = 'free'; controls.enabled = true;
    const rep = S.repairInfo(s);
    const opts = [];
    if (st.scan && !scanned) opts.push({ id: 'scan', label: 'Scan the area', sub: 'power −8 · budget −8 · gives science' });
    opts.push({ id: 'repair', label: 'Repair a system', sub: `budget −${rep.cost} · restores ${rep.amount}%` });
    opts.push({ id: 'inspect', label: 'Inspect the heat shield', sub: `budget −4 · 2 days · last inspected: ${s.shieldCheckedDay < 0 ? 'never' : 'day ' + s.shieldCheckedDay}` });
    opts.push({ id: 'depart', label: 'Depart for the next stop', sub: '' });
    const pick = await ui.choose('hub', st.name, 'Parked. You can drag to look around. What now?', opts);
    if (pick === 'depart') return;
    if (pick === 'scan') {
      s.power -= 8; s.budget -= 8;
      const g = S.scanGain(s, st.scan.base); s.science += g; scanned = true;
      ui.toast(`${st.scan.text} Science +${g}`, 'good');
    } else if (pick === 'inspect') {
      const before = s.knownShield;
      const real = S.inspectShield(s);
      if (real < before - 3) ui.toast(`Heat shield inspected: ${real}%. Hidden damage found!`, 'bad');
      else ui.toast(`Heat shield inspected: ${real}%. No new damage.`, 'good');
    } else if (pick === 'repair') {
      const target = await ui.choose('repair', 'Repair which system?', `Costs budget ${rep.cost}.`, [
        ...SUBS.map((x) => ({ id: x.id, label: x.name, sub: `${x.id === 'shield' ? 'last known ' + s.knownShield : s.h[x.id]}%`, disabled: x.id !== 'shield' && s.h[x.id] >= 100 })),
        { id: 'cancel', label: 'Cancel', sub: '' },
      ]);
      if (target !== 'cancel') {
        if (s.budget < rep.cost) ui.toast('Not enough budget for a repair.', 'bad');
        else {
          const blind = target === 'shield' && s.knownShield !== s.h.shield;
          S.repair(s, target);
          ui.toast(blind ? 'Heat shield repaired, but its true condition is unknown until you inspect it.' : `${S.subName(target)} repaired.`, 'good');
        }
      }
    }
    guard();
  }
}

async function finale() {
  ui.cue(CUE.ending);
  const known = s.knownShield;
  const pick = await ui.choose('reentry', 'Choose your re-entry angle',
    `Last decision. Heat shield (last known): <b>${known}%</b>${s.shieldCheckedDay < 0 ? ' - never inspected!' : ''}. Comms: <b>${s.h.comms}%</b>. A shallow angle is gentler but needs good guidance from comms.`, [
      { id: 'standard', label: 'Standard angle', sub: 'no change' },
      { id: 'shallow', label: 'Shallow and slow', sub: 'less heat, but needs comms of 60% or more' },
      { id: 'steep', label: 'Steep and fast', sub: 'more heat: risky for a weak shield, a little safer for a strong one' },
    ]);
  const mod = pick === 'shallow' ? (s.h.comms >= 60 ? 8 : -12) : pick === 'steep' ? (s.h.shield >= 60 ? 4 : -10) : 0;
  const out = S.reentry(s, mod);
  const earth = world.bodyPos(7), startP = ship.group.position.clone();
  const dir = startP.clone().sub(earth).normalize();
  const endP = earth.clone().addScaledVector(dir, world.bodyRadius(7) + 1.2);
  camMode = 'chase'; controls.enabled = false;
  ship.setFlame(0.3);
  await tween(6, (u) => {
    const e = ease(u);
    const p = startP.clone().lerp(endP, e);
    placeShip(p, dir.clone().multiplyScalar(-1));
    ship.setPlasma(Math.max(0, (u - 0.45) / 0.5));
    if (u > 0.6) camera.position.add(new THREE.Vector3((Math.random() - 0.5) * 0.25, (Math.random() - 0.5) * 0.25, 0));
  });
  if (out.tier === 'lost') { burst.emit(ship.group.position, 140, 0xffa050, 16); ship.group.visible = false; ui.flash('rgba(255,255,255,.7)'); audio.thud(); }
  else { ui.flash('rgba(255,255,255,.3)'); audio.ok(); }
  ship.setPlasma(0);
  await endReport(out.tier, null, out);
}

const TIER_TEXT = {
  perfect: ['Perfect landing!', 'The heat shield held and you landed softly. Mission control erupts.'],
  hard: ['Hard landing', 'The shield held, but the landing was rough. Everyone walked away.'],
  ballistic: ['Ballistic re-entry', 'The crew survived a brutal, steep entry, but the ship was lost.'],
  lost: ['Heat shield failed', 'The shield could not protect the ship. The mission is lost.'],
};

async function endReport(tier, failReason, out) {
  const won = !failReason && tier !== 'lost';
  const score = failReason ? 0 : S.score(s, tier);
  window.COSMOS_RESULT = { won, tier, failReason, score, h: { ...s.h }, power: s.power, budget: s.budget, days: s.days, science: s.science, integrity: out && out.integrity, log: s.log.length };
  ui.hideAll();
  const head = failReason ? ['Mission failed', failReason] : TIER_TEXT[tier];
  const chain = S.damageChain(s).map((x) => `<li>${x}</li>`).join('') || '<li>No major damage. A clean flight!</li>';
  const eff = S.effectLines(s).map((x) => `<li>${x}</li>`).join('');
  const table = SUBS.map((x) => `<li>${x.name}: <b>${s.h[x.id]}%</b>${x.id === 'shield' && s.knownShield !== s.h[x.id] ? ` (you believed ${s.knownShield}%)` : ''}</li>`).join('');
  ui.report(`<div class="tier-${failReason ? 'lost' : tier}"><h1>${head[0]}</h1></div><p>${head[1]}</p>
    <div class="kpi"><div><b>${score}</b>score</div><div><b>${s.days}</b>days</div><div><b>${s.science}</b>science</div><div><b>${Math.round(s.power)}</b>power left</div></div>
    <h2>How your damage carried over</h2><ul>${chain}</ul>
    ${eff ? `<h2>What that cost you</h2><ul>${eff}</ul>` : ''}
    <h2>Final ship condition (true values)</h2><ul>${table}</ul>
    <h2>What this teaches</h2><p>Early damage does not go away. A hit in the first asteroid field can shorten your warning in the next one, and a heat shield nobody inspected can end the mission on the last day. Real spacecraft face the same problem: Parker Solar Probe has no temperature sensor on the front of its heat shield, so engineers must rely on models and careful checks.</p>`,
    'Play again', () => location.reload());
}

async function game() {
  await ui.title(`<h1>COSMOS: ODYSSEY '2000</h1>
    <p>Fly a spacecraft from Earth to the edge of the Solar System and bring it home. Every hit you take stays with the ship and changes what happens next.</p>
    <ul><li>Fly through asteroid fields by hand (arrow keys / WASD, or hold the mouse and drag).</li>
    <li>Make quick choices when systems fail or power drops.</li>
    <li>The heat shield cannot be seen from inside. Inspect it, or gamble.</li></ul>`, 'Begin');
  const crew = await ui.crewSelect(CREW);
  s = S.newState(crew);
  refresh();
  ship.group.visible = true;
  world.setVisible(true);
  ui.cue(CUE.start);
  try {
    const v0 = world.view(0);
    camera.position.copy(v0.pos).add(new THREE.Vector3(30, 14, 30)); controls.target.copy(v0.target);
    const park = world.parkPos(0);
    placeShip(park, new THREE.Vector3(0, 0, -1).applyAxisAngle(new THREE.Vector3(0, 1, 0), 0.6));
    ship.setFlame(0.2);
    await camTo(v0.pos, v0.target, 3);
    E.launchDebris(s);
    refresh();
    await ui.say('Launch complete', 'You are in orbit around Earth. During launch, cameras saw foam debris fly past the nose. Engineers cannot tell whether it struck the heat shield. (This is how the Columbia accident started in 2003.)');
    await hub(0);
    for (let i = 1; i < STOPS.length; i++) {
      const pid = await pickPath(i);
      world.clearPaths();
      await travelLeg(i - 1, i, pid);
      await arrive(i);
      if (i < STOPS.length - 1) await hub(i);
    }
    await finale();
  } catch (e) {
    if (e === FAIL) {
      audio.thud();
      await endReport('lost', s.failed, null);
    } else { console.error(e); window.COSMOS_ERROR = String(e && e.stack || e); throw e; }
  }
}

if (BOT) {
  const prio = ['life', 'shield', 'thrusters', 'comms', 'lab'];
  let hubCount = 0, lastHub = -1;
  ui.setAuto((kind, p) => {
    if (kind === 'say') return;
    if (kind === 'crew') return BOT === 'random' ? shuffle(CREW.map((c) => c.id)).slice(0, 3) : ['pilot', 'engineer', 'medic'];
    if (kind === 'power') {
      if (BOT === 'dumb') return p.systems.map((x) => x.id);
      const out = []; let used = 0; const units = S.powerUnits(s);
      for (const id of prio) { const c = p.systems.find((x) => x.id === id).cost; if (used + c <= units) { out.push(id); used += c; } }
      return out;
    }
    const ids = p.options.map((o) => o.id);
    const first = () => (p.options.find((o) => !o.disabled) || p.options[0]).id;
    if (BOT === 'random' || BOT === 'dumb') {
      if (p.id === 'hub') return Math.random() < 0.5 || BOT === 'dumb' ? 'depart' : pickRandom(ids);
      return pickRandom(p.options.filter((o) => !o.disabled)).id;
    }
    switch (p.id) {
      case 'path': return s.power < 45 ? 'ellipse' : 'normal';
      case 'posture': return s.power > 40 ? 'shield' : 'hold';
      case 'hub': {
        if (BOT === 'lazy') return 'depart';
        if (lastHub !== s.days) { hubCount = 0; lastHub = s.days; }
        hubCount++;
        const weak = SUBS.filter((x) => x.id !== 'shield' && x.id !== 'life' && s.h[x.id] < 60 && s.h[x.id] < 100).length;
        if (ids.includes('scan') && s.budget > 50 && s.power > 60 && hubCount < 2) return 'scan';
        const needInspect = s.shieldCheckedDay < 0 || s.log.some((l) => l.sub === 'shield' && l.day >= s.shieldCheckedDay);
        if (needInspect && s.budget > 22 && hubCount < 3) return 'inspect';
        if ((weak || s.knownShield < 80) && s.budget > 26 && hubCount < 5) return 'repair';
        return 'depart';
      }
      case 'repair': {
        if (s.knownShield < 80) return 'shield';
        const worst = SUBS.filter((x) => x.id !== 'shield' && s.h[x.id] < 100).sort((a, b) => s.h[a.id] - s.h[b.id])[0];
        return worst ? worst.id : 'cancel';
      }
      case 'reentry': return s.h.comms >= 60 && s.knownShield < 90 ? 'shallow' : 'standard';
      case 'comet': return s.power > 50 ? 'close' : 'far';
      case 'blackhole': return s.power > 40 && s.h.thrusters > 70 ? 'sling' : 'away';
      default: return first();
    }
  });
}

document.getElementById('snd').onclick = (e) => { e.target.textContent = 'Sound: ' + (audio.toggle() ? 'on' : 'off'); };
window.COSMOS_STATE = () => s;
ui.updateHud(S.newState([])); ui.updateSubs(S.newState([]));
game().catch((e) => { console.error(e); window.COSMOS_ERROR = String((e && e.stack) || e); });
