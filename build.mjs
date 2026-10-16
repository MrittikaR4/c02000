import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const r = await build({ entryPoints: ['src/main.js'], bundle: true, minify: true, format: 'iife', write: false, target: 'es2020', legalComments: 'none' });
const js = r.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const html = readFileSync('template.html', 'utf8').replace('__BUNDLE__', () => js);
mkdirSync('dist', { recursive: true });
writeFileSync('dist/cosmos_odyssey_3d.html', html);
console.log('built dist/cosmos_odyssey_3d.html', (html.length / 1024).toFixed(0) + ' KB');
