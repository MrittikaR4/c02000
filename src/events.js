import * as S from './state.js';

const rint = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const hit = (s, id, n, src) => {
  const a = S.damage(s, id, n, src);
  return a ? `${S.subName(id)} −${a}%` : '';
};
const join = (...p) => p.filter(Boolean).join(', ');

export const MALFUNCTIONS = [
  {
    id: 'tracker', title: 'Dust blinds a star tracker',
    text: 'A micro-impact kicked up a dust cloud that blinded one of your star trackers. Without it the ship is unsure which way it is pointing. (Parker Solar Probe has this problem.)',
    options: [
      { id: 'backup', label: 'Switch to the backup tracker', sub: 'power −6 · small damage',
        run: (s) => { s.power -= 6; return join('Backup tracker online', hit(s, 'sensors', 5, 'Dust blinded a star tracker')); } },
      { id: 'recal', label: 'Recalibrate in place', sub: '3 days, budget −4 · medium damage',
        run: (s) => { s.days += 3; s.budget -= 4; return join('Slow recalibration worked', hit(s, 'sensors', 8, 'Dust blinded a star tracker')); } },
      { id: 'ignore', label: 'Ignore it', sub: 'free · big damage risk',
        run: (s) => join('The ship drifted and the tracker overheated', hit(s, 'sensors', rint(15, 25), 'Dust blinded a star tracker (ignored)')) },
    ],
  },
  {
    id: 'patch', title: 'Software patch in progress',
    text: 'A software update is half-loaded when an instrument asks to restart. (This really happened to Parker in 2023.) Do you roll back or push through?',
    options: [
      { id: 'rollback', label: 'Roll the patch back', sub: '2 days · safe',
        run: (s) => { s.days += 2; return 'Patch rolled back. No harm done.'; } },
      { id: 'push', label: 'Push the patch through', sub: '55% better science, 45% comms fault',
        run: (s) => {
          if (Math.random() < 0.55) { s.science += 6; return 'The patch worked. Sharper instruments: science +6'; }
          s.science = Math.max(0, s.science - 6);
          return join('The patch failed and the computer rebooted', hit(s, 'comms', 20, 'Failed software patch'), 'science −6');
        } },
    ],
  },
  {
    id: 'coolant', title: 'Solar array cooling fault',
    text: 'The water cooling loop for the solar arrays is overheating. Left alone, the panels can cook. (Parker uses about one gallon of water to cool its arrays.)',
    options: [
      { id: 'cut', label: 'Cut array power to cool down', sub: 'power −10 · small damage',
        run: (s) => { s.power -= 10; return join('Arrays cooled', hit(s, 'arrays', 5, 'Cooling loop fault')); } },
      { id: 'run', label: 'Keep running at full power', sub: '50% chance of heavy damage',
        run: (s) => Math.random() < 0.5 ? join('The panels cooked', hit(s, 'arrays', 25, 'Cooling loop fault (ignored)')) : 'Lucky: the panels survived.' },
    ],
  },
  {
    id: 'upset', title: 'Radiation upsets the computer',
    text: 'A charged particle flipped a bit in the main computer. The ship needs a decision about whether to reboot.',
    options: [
      { id: 'reboot', label: 'Reboot the computer', sub: '1 day · small comms damage',
        run: (s) => { s.days += 1; return join('Rebooted safely', hit(s, 'comms', 5, 'Radiation upset (rebooted)')); } },
      { id: 'wait', label: 'Wait and watch', sub: '35% chance of a bad crash',
        run: (s) => Math.random() < 0.35 ? join('The computer crashed', hit(s, 'comms', 25, 'Radiation upset (ignored)')) : 'The glitch cleared by itself.' },
    ],
  },
  {
    id: 'valve', title: 'Thruster valve sticks',
    text: 'A valve in one of the steering thrusters is sticking open and wasting fuel.',
    options: [
      { id: 'routine', label: 'Run the valve repair routine', sub: 'budget −6 · small damage',
        run: (s) => { s.budget -= 6; return join('Valve freed', hit(s, 'thrusters', 5, 'Sticking thruster valve')); } },
      { id: 'work', label: 'Work around it', sub: 'free · bigger damage',
        run: (s) => join('The ship limped on', hit(s, 'thrusters', 15, 'Sticking thruster valve (worked around)')) },
    ],
  },
  {
    id: 'breach', title: 'Micrometeoroid hits the hull',
    text: 'A tiny rock punched a small hole in the hull. Air is leaking slowly.',
    options: [
      { id: 'patch', label: 'Patch it now', sub: 'budget −5 · small damage',
        run: (s) => { s.budget -= 5; return join('Hole patched', hit(s, 'hull', 6, 'Micrometeoroid hit the hull')); } },
      { id: 'later', label: 'Deal with it later', sub: 'free · bigger damage',
        run: (s) => join('The crack spread', hit(s, 'hull', 18, 'Micrometeoroid hit the hull (ignored)')) },
    ],
  },
];

export const FLARE = {
  title: 'Solar flare!',
  text: 'A solar flare is coming. Radiation is rising fast. Radiation can damage electronics and crew.',
  options: [
    { id: 'shelter', label: 'Shelter in the shielded core', sub: 'power −8, 6 days · small damage',
      run: (s) => { s.power -= 8; s.days += 6; return join('The crew sheltered safely', hit(s, 'arrays', 5, 'Solar flare (sheltered)')); } },
    { id: 'carry', label: 'Carry on', sub: 'free · heavy radiation damage',
      run: (s) => join(hit(s, 'comms', 20, 'Solar flare radiation'), hit(s, 'arrays', 10, 'Solar flare radiation'), hit(s, 'life', 10, 'Solar flare radiation')) },
  ],
};

export function launchDebris(s) {
  const a = rint(20, 42);
  S.damage(s, 'shield', a, 'Foam debris hit the heat shield at launch');
  return a;
}

export const POWER_SYSTEMS = [
  { id: 'life', name: 'Life support', cost: 15 },
  { id: 'shield', name: 'Debris shields', cost: 10 },
  { id: 'thrusters', name: 'Thrusters', cost: 10 },
  { id: 'comms', name: 'Comms', cost: 5 },
  { id: 'lab', name: 'Science lab', cost: 10 },
];

export function resolvePowerDrop(s, chosen, timedOut) {
  const notes = [];
  const units = S.powerUnits(s);
  let keep = chosen.slice();
  if (timedOut) {
    keep = POWER_SYSTEMS.map((x) => x.id).sort(() => Math.random() - 0.5).slice(0, 2);
    notes.push('Too slow! The computer cut systems at random.');
  }
  const used = keep.reduce((a, id) => a + POWER_SYSTEMS.find((x) => x.id === id).cost, 0);
  if (used > units) {
    notes.push(`Overload! You tried to use ${used} of ${units} units. Breakers tripped.`);
    const t = hit(s, 'hull', 15, 'Power overload during blackout');
    if (t) notes.push(t);
    s.power -= 10;
    keep = ['life'];
  }
  const names = keep.map((id) => POWER_SYSTEMS.find((x) => x.id === id).name).join(', ') || 'none';
  notes.push(`Systems running: ${names}`);
  let tone = 'neutral';
  if (!keep.includes('life')) {
    s.failed = 'Life support was switched off during the power drop.';
    notes.push('Life support was off!');
    return { notes, tone: 'bad' };
  }
  if (!keep.includes('shield')) notes.push('Debris shields were off. ' + hit(s, 'hull', 20, 'Debris shields off during blackout'));
  if (!keep.includes('thrusters')) { s.days += 15; notes.push('Thrusters were off. You drifted: +15 days. ' + hit(s, 'thrusters', 10, 'Thrusters off during blackout')); }
  if (!keep.includes('comms')) { s.budget -= 5; notes.push('No comms: budget −5. ' + hit(s, 'comms', 10, 'Comms off during blackout')); }
  if (!keep.includes('lab')) { s.science = Math.max(0, s.science - 5); notes.push('Science lab was off: science −5.'); }
  if (keep.includes('shield')) { tone = 'good'; notes.push('Good priorities: crew and ship protected.'); }
  return { notes, tone };
}
