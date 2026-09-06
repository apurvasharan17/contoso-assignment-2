const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { handler } = require('../server');

test('HTTP routes return health, application page and 404 correctly', async () => {
  const server = http.createServer(handler);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}`;
    const health = await fetch(`${url}/health`);
    assert.equal(health.status, 200);
    const body = await health.json();
    assert.equal(body.status, 'ok');
    assert.equal(body.environment, process.env.APP_ENV || 'local');
    assert.equal(typeof body.version, 'string');
    const page = await fetch(url);
    assert.equal(page.status, 200);
    assert.match(await page.text(), /Contoso Learning Solutions/);
    assert.equal((await fetch(`${url}/missing`)).status, 404);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
});
