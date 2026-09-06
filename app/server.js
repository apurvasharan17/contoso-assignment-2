const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const release = JSON.parse(fs.readFileSync(path.join(__dirname, 'release.json'), 'utf8'));

function handler(req, res) {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', environment: process.env.APP_ENV || 'local', version: release.version }));
  } else if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end('<h1>Contoso Learning Solutions</h1><p>Assignment 2: automated deployment using Bicep and GitHub Actions.</p>');
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
}
if (require.main === module) {
  http.createServer(handler).listen(process.env.PORT || 8080, '0.0.0.0');
}
module.exports = { handler };
