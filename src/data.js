
export const MAX_DAYS = 300;

export const SUBS = [
  { id: 'hull', name: 'Hull', effect: 'A weak hull leaks air into life support and risks breaking up.' },
  { id: 'arrays', name: 'Solar arrays', effect: 'Damaged arrays recharge less power and leave less power during a blackout.' },
  { id: 'thrusters', name: 'Thrusters', effect: 'Weak thrusters steer slowly and make every route cost more power.' },
  { id: 'sensors', name: 'Sensors', effect: 'Poor sensors shorten your warning range and reduce science from scans.' },
  { id: 'shield', name: 'Heat shield', effect: 'The heat shield decides how re-entry ends.' },
  { id: 'comms', name: 'Comms', effect: 'Weak comms hurt guidance during the final landing.' },
  { id: 'life', name: 'Life support', effect: 'If life support reaches zero the crew is lost.' },
];

export const CREW = [
  { id: 'pilot', name: 'Pilot', desc: 'Steers 25% better through asteroid fields.' },
  { id: 'engineer', name: 'Engineer', desc: 'Repairs cost less and fix more.' },
  { id: 'medic', name: 'Medic', desc: 'Halves radiation and life-support damage.' },
  { id: 'scientist', name: 'Scientist', desc: 'Scans give 50% more science.' },
];

export const PATHS = {
  fast: { label: 'Fast burn', power: 10, budget: 12, days: 15, speed: 76, note: 'faster asteroids' },
  normal: { label: 'Normal route', power: 7, budget: 8, days: 25, speed: 56, note: '' },
  ellipse: { label: 'Elliptical orbit', power: 3, budget: 6, days: 45, speed: 42, note: 'gravity assist, slow' },
};

export const SOLAR = { mars: 12, belt: 9, jupiter: 5, comet: 5, pluto: 1, blackhole: 0 };

export const STOPS = [
  {
    id: 'earth', name: 'Earth', type: 'start', orbit: { r: 90, a: 0, y: 0 },
    fact: 'Earth orbits the Sun, a star about 150 million km away, on a slightly elliptical path. The Sun makes its own light by fusing hydrogen.',
  },
  {
    id: 'mars', name: 'Mars', type: 'planet', orbit: { r: 135, a: 35, y: 3 },
    fact: 'Mars has two small moons, Phobos and Deimos. A Mars day is about 24.6 hours long.',
    scan: { base: 12, text: 'The scan found dry river valleys and signs of ancient water.' },
  },
  {
    id: 'belt', name: 'Asteroid Belt', type: 'belt', orbit: { r: 180, a: 75, y: 0 },
    fact: 'Millions of rocky bodies orbit between Mars and Jupiter. Ceres, the largest object here, is a dwarf planet.',
    scan: { base: 10, text: 'The scan measured rock types and mapped the dwarf planet Ceres.' },
  },
  {
    id: 'jupiter', name: 'Jupiter', type: 'planet', orbit: { r: 235, a: 115, y: -4 },
    fact: 'Jupiter has more than 90 known moons. The four largest are Io, Europa, Ganymede and Callisto.',
    scan: { base: 12, text: 'The scan mapped Jupiter\'s storms and its four biggest moons.' },
  },
  {
    id: 'comet', name: 'Comet', type: 'comet', orbit: null,
    fact: 'Comets follow long elliptical orbits. They speed up near the Sun and grow a glowing tail of gas and dust that always points away from it.',
    special: { label: 'Comet flyby', sub: 'choose how close to fly' },
  },
  {
    id: 'pluto', name: 'Pluto', type: 'dwarf', orbit: { r: 430, a: 215, y: -8 },
    fact: 'Pluto is a dwarf planet. It has not cleared other objects from its orbit. Its moon Charon is huge compared with Pluto.',
    scan: { base: 14, text: 'The scan found a heart-shaped plain of nitrogen ice.' },
  },
  {
    id: 'blackhole', name: 'Black Hole (simulation)', type: 'blackhole', orbit: { r: 560, a: 265, y: 6 },
    fact: 'No black hole is known anywhere near our solar system. The closest known ones are over a thousand light-years away. This region is a "what if" simulation of how a black hole bends light and slows time.',
    special: { label: 'Black hole decision', sub: 'study it, slingshot, or turn away' },
  },
  {
    id: 'earth2', name: 'Earth (Return)', type: 'end', orbit: { r: 90, a: 0, y: 0 },
    fact: 'Home orbit. Re-entry is about to put the heat shield to the test.',
  },
];

export const COMET = { a: 420, e: 0.8, nu: 130, omega: 40 };

export const CUE = {
  suspense: 'House M.D. theme: suspense, important decision',
  intermission: 'Doctor Who theme: intermission break',
  ending: 'Cornfield Chase (Interstellar): return to Earth',
  start: 'Mission start',
};
