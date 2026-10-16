let ctx = null, master = null, on = false;

function init() {
  if (ctx) return true;
  try {
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain();
    master.gain.value = 0;
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass'; lp.frequency.value = 420;
    lp.connect(master); master.connect(ctx.destination);
    [55, 82.4, 110.3, 164.8].forEach((f, i) => {
      const o = ctx.createOscillator(), g = ctx.createGain(), lfo = ctx.createOscillator(), lg = ctx.createGain();
      o.type = i % 2 ? 'triangle' : 'sine'; o.frequency.value = f;
      g.gain.value = 0.12 / (i + 1);
      lfo.frequency.value = 0.05 + i * 0.03; lg.gain.value = 0.05 / (i + 1);
      lfo.connect(lg); lg.connect(g.gain);
      o.connect(g); g.connect(lp);
      o.start(); lfo.start();
    });
    return true;
  } catch (e) { ctx = null; return false; }
}

function beep(freq, dur, type = 'square', vol = 0.06, delay = 0) {
  if (!on || !ctx) return;
  const t = ctx.currentTime + delay;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type; o.frequency.value = freq;
  g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g); g.connect(ctx.destination);
  o.start(t); o.stop(t + dur + 0.02);
}

export const audio = {
  toggle() {
    if (!init()) return false;
    on = !on;
    if (ctx.state === 'suspended') ctx.resume();
    master.gain.linearRampToValueAtTime(on ? 0.55 : 0, ctx.currentTime + 0.4);
    return on;
  },
  get on() { return on; },
  warn() { beep(300, 0.18); beep(220, 0.25, 'square', 0.06, 0.2); },
  alarm() { for (let i = 0; i < 4; i++) beep(i % 2 ? 520 : 760, 0.16, 'square', 0.05, i * 0.2); },
  ok() { beep(660, 0.1, 'sine', 0.06); beep(880, 0.16, 'sine', 0.06, 0.1); },
  thud() { beep(70, 0.35, 'sawtooth', 0.12); },
};
