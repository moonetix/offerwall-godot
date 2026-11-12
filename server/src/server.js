'use strict';

const http = require('node:http');
const { loadConfig } = require('./config');
const { openStore } = require('./store');
const { buildWallLink, formatAmount } = require('./moonetix');
const { handlePostback } = require('./postback');
const { send, sendText, readBody, bearerToken, ageConfirmed, defaultLog } = require('./http');

function createApp({ config, store, log = defaultLog }) {
  return http.createServer(async (req, res) => {
    try {
      await route(req, res, { config, store, log });
    } catch (err) {
      if (err && err.statusCode) return send(res, err.statusCode, { error: err.message });
      log('unhandled error', { error: err && err.message });
      send(res, 500, { error: 'server_error' });
    }
  });
}

// Godot web exports on another domain need CORS. Desktop and mobile exports do not.
function corsHeaders(req, config) {
  const origin = req.headers.origin;
  if (!config.corsOrigin || origin !== config.corsOrigin) return {};
  return { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' };
}

async function route(req, res, { config, store, log }) {
  const url = new URL(req.url, 'http://localhost');
  const cors = url.pathname.startsWith('/api/') ? corsHeaders(req, config) : {};

  if (req.method === 'GET' && url.pathname === '/moonetix/postback') {
    const { code, body } = handlePostback(url.searchParams, { postbackKey: config.postbackKey, store, log });
    return sendText(res, code, body);
  }

  if (req.method === 'OPTIONS' && cors['Access-Control-Allow-Origin']) {
    res.writeHead(204, {
      ...cors,
      'Access-Control-Allow-Methods': 'GET, POST',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      'Access-Control-Max-Age': '600',
    });
    return res.end();
  }

  // Demo sign-in. The player confirms they are 16 or older, and gets a random token.
  if (req.method === 'POST' && url.pathname === '/api/players') {
    const body = await readBody(req);
    if (!ageConfirmed(body)) return send(res, 400, { error: 'age_confirmation_required' }, cors);
    const player = store.createPlayer();
    log('player created', { id: player.id });
    return send(res, 201, { token: player.token, player_id: player.id }, cors);
  }

  if (url.pathname === '/api/balance' || url.pathname === '/api/offerwall-link') {
    if (req.method !== 'GET') return send(res, 405, { error: 'method_not_allowed' }, cors);
    // The player comes only from the sign-in token, never from a user ID the client sends.
    const player = store.findPlayerByToken(bearerToken(req));
    if (!player) return send(res, 401, { error: 'sign_in_required' }, cors);

    if (url.pathname === '/api/balance') {
      return send(res, 200, {
        player_id: player.id,
        balance: formatAmount(player.balance_micro),
        currency: config.currencyName,
      }, cors);
    }
    const link = buildWallLink({
      appId: config.appId,
      linkSalt: config.linkSalt,
      userId: String(player.id),
      subs: { sub1: 'godot' },
    });
    return send(res, 200, { url: link }, cors);
  }

  if (req.method === 'GET' && url.pathname === '/health') return sendText(res, 200, 'ok');

  send(res, 404, { error: 'not_found' }, cors);
}

if (require.main === module) {
  const config = loadConfig();
  const store = openStore(config.databasePath);
  createApp({ config, store }).listen(config.port, () => {
    console.log(`Listening on port ${config.port}`);
  });
}

module.exports = { createApp };
