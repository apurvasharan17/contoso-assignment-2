const fs = require('node:fs');
fs.rmSync('dist', { recursive: true, force: true });
fs.mkdirSync('dist');
for (const file of ['server.js', 'package.json']) fs.copyFileSync(file, `dist/${file}`);
fs.writeFileSync('dist/release.json', JSON.stringify({ version: process.env.GITHUB_SHA || 'local' }));
console.log('Built deployable dist directory.');
