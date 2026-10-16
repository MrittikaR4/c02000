import { MAX_DAYS, SUBS } from './data.js';

export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const subName = (id) => SUBS.find((x) => x.id === id).name;

export function newState(crew) {
  const h = {};
  SUBS.forEach((x) => (h[x.id] = 100));
  return {
    power: 100, budget: 120, days: 0, science: 0,
    crew, h,
    knownShield: 100,
    shieldCheckedDay: -1,
    log: [],
    failed: null,
  };
}

export const has = (s, role) => s.crew.includes(role);

export const thrusterFactor = (s) => 0.5 + (0.5 * s.h.thrusters) / 100;
export const sensorFactor = (s) => 0.4 + (0.6 * s.h.sensors) / 100;
export const solarFactor = (s) => 0.3 + (0.7 * s.h.arrays) / 100;
export const powerUnits = (s) => Math.round(18 + (12 * s.h.arrays) / 100);

export function pathCost(s, p) {
  const mult = 1 + (100 - s.h.thrusters) / 150;
  return { power: Math.ceil(p.power * mult), budget: p.budget, days: p.days };
}

export function scanGain(s, base) {
  return Math.round(base * sensorFactor(s) * (has(s, 'scientist') ? 1.5 : 1));
}

export function damage(s, id, amount, source) {
  let a = amount;
  if (id === 'life' && has(s, 'medic')) a = Math.ceil(a / 2);
  a = Math.max(0, Math.round(a));
  if (!a) return 0;
  const before = s.h[id];
  s.h[id] = Math.max(0, before - a);
  const real = before - s.h[id];
  s.log.push({ day: s.days, sub: id, amount: real, source, hidden: id === 'shield' });
  return real;
}

export function repairInfo(s) {
  return has(s, 'engineer') ? { cost: 7, amount: 25 } : { cost: 10, amount: 20 };
}

export function repair(s, id) {
  const { cost, amount } = repairInfo(s);
  const accurate = id === 'shield' && s.knownShield === s.h.shield;
  s.budget -= cost;
  s.h[id] = Math.min(100, s.h[id] + amount);
  if (accurate) s.knownShield = s.h.shield;
  return amount;
}

export function inspectShield(s) {
  s.budget -= 4;
  s.days += 2;
  s.knownShield = s.h.shield;
  s.shieldCheckedDay = s.days;
  return s.h.shield;
}

export function leakCheck(s) {
  if (s.h.hull < 40) return damage(s, 'life', 4, 'Slow air leak from the damaged hull');
  return 0;
}

export function checkFail(s) {
  if (s.failed) return s.failed;
  if (s.h.life <= 0) s.failed = 'Life support failed. The crew could not survive.';
  else if (s.h.hull <= 0) s.failed = 'The hull broke apart.';
  else if (s.power <= 0) s.failed = 'Out of power. Life support shut down.';
  else if (s.budget < 0) s.failed = 'Budget exhausted. Mission control cancelled the flight.';
  else if (s.days > MAX_DAYS) s.failed = 'Mission deadline passed. Supplies ran out.';
  return s.failed;
}

export function reentry(s, mod = 0, rnd = Math.random) {
  const h = s.h;
  const integrity = 0.7 * h.shield + 0.1 * h.hull + 0.1 * h.thrusters + 0.1 * h.comms;
  const roll = integrity + mod + (rnd() * 20 - 10);
  let tier = roll >= 85 ? 'perfect' : roll >= 68 ? 'hard' : roll >= 45 ? 'ballistic' : 'lost';
  if (h.shield <= 15) tier = 'lost';
  else if (h.shield < 30 && (tier === 'perfect' || tier === 'hard')) tier = 'ballistic';
  return { tier, integrity: Math.round(integrity), roll: Math.round(roll) };
}

export function score(s, tier) {
  const avg = SUBS.reduce((a, x) => a + s.h[x.id], 0) / SUBS.length;
  const base = s.science * 5 + s.power + s.budget + Math.round(avg) + Math.max(0, MAX_DAYS - s.days) / 5;
  const mult = { perfect: 1, hard: 0.8, ballistic: 0.5, lost: 0 }[tier] ?? 0;
  return Math.round(base * mult);
}

export function damageChain(s) {
  return s.log
    .filter((l) => l.amount > 0)
    .slice()
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 6)
    .map((l) => {
      const unchecked = l.hidden && s.shieldCheckedDay < l.day;
      const note = unchecked ? ', never checked' : '';
      return `Day ${l.day}: ${l.source} (${subName(l.sub)} −${l.amount}%${note})`;
    });
}

export function effectLines(s) {
  return SUBS.filter((x) => s.h[x.id] < 70).map((x) => `${x.name} ended at ${s.h[x.id]}%. ${x.effect}`);
}
