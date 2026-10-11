/**
 * Unit tests for the CAFFE POS Telegram relay Worker.
 *
 * Run with:  node --test
 *
 * These tests exercise the real Worker module against a stubbed `fetch`, so no
 * network call is made and no real Telegram message is ever sent.
 */

import { test, beforeEach, describe } from 'node:test';
import assert from 'node:assert/strict';

import worker, { __test__ } from '../src/index.js';

// Placeholders only — never real credentials.
const RELAY_SECRET = 'test-relay-secret-not-a-real-value';
const BOT_TOKEN = '000000:TEST_TOKEN_PLACEHOLDER_NOT_REAL';
const OWNER_CHAT = '-1001234567890';

const VALID_ENV = {
  TELEGRAM_RELAY_SECRET: RELAY_SECRET,
  TELEGRAM_BOT_TOKEN: BOT_TOKEN,
  AUTHORIZED_CHAT_IDS: OWNER_CHAT,
};

let telegramCalls = [];
let nextTelegramResponse;

/** Replace global fetch so the worker "talks" to a stubbed Telegram. */
function installFetchStub() {
  telegramCalls = [];
  nextTelegramResponse = { ok: true, messageId: 555 };
  globalThis.fetch = async (url, init) => {
    telegramCalls.push({ url: String(url), body: JSON.parse(init.body) });
    return {
      status: nextTelegramResponse.ok ? 200 : 400,
      json: async () => ({
        ok: nextTelegramResponse.ok,
        result: { message_id: nextTelegramResponse.messageId },
        description: 'simulated upstream failure detail that must not leak',
      }),
    };
  };
}

/** Build a Request the same way the runtime would hand it to the Worker. */
function makeRequest(path, { body, headers = {}, method = 'POST', contentLength } = {}) {
  const allHeaders = { 'Content-Type': 'application/json', ...headers };
  if (contentLength !== undefined) allHeaders['Content-Length'] = String(contentLength);
  return new Request(`https://relay.test${path}`, {
    method,
    headers: allHeaders,
    body: method === 'POST' ? JSON.stringify(body ?? {}) : undefined,
  });
}

const authed = (extra = {}) => ({ 'X-Relay-Secret': RELAY_SECRET, ...extra });

beforeEach(() => {
  // Each test gets a fresh Telegram stub and cleared Worker state, so the
  // module-level rate-limit and idempotency maps cannot leak between cases.
  installFetchStub();
  __test__.resetState();
});
const uniqueKey = (() => {
  let n = 0;
  return () => `key-${Date.now()}-${n++}`;
})();

describe('authentication', () => {
  test('rejects a request with no relay secret', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { chatId: OWNER_CHAT, message: 'hi' } }),
      VALID_ENV,
    );
    assert.equal(res.status, 401);
    const json = await res.json();
    assert.equal(json.ok, false);
    assert.equal(telegramCalls.length, 0, 'must not call Telegram when unauthenticated');
  });

  test('rejects a request with an incorrect relay secret', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { chatId: OWNER_CHAT, message: 'hi' },
        headers: { 'X-Relay-Secret': 'wrong-secret' },
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 403);
    assert.equal(telegramCalls.length, 0);
  });

  test('does not distinguish "not configured" from "wrong secret"', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { chatId: OWNER_CHAT, message: 'hi' },
        headers: { 'X-Relay-Secret': 'anything' },
      }),
      { ...VALID_ENV, TELEGRAM_RELAY_SECRET: '' },
    );
    assert.equal(res.status, 503);
    const json = await res.json();
    assert.equal(json.error, 'Unauthorized.', 'must not reveal misconfiguration');
  });

  test('accepts the correct secret', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { chatId: OWNER_CHAT, message: 'hello' },
        headers: authed(),
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 200);
    assert.equal(telegramCalls.length, 1);
  });

  test('relay secret comparison is length-safe (no early exit)', () => {
    assert.equal(__test__.constantTimeEqual('abc', 'abc'), true);
    assert.equal(__test__.constantTimeEqual('abc', 'abd'), false);
    assert.equal(__test__.constantTimeEqual('abc', 'abcd'), false);
    assert.equal(__test__.constantTimeEqual('', ''), true);
  });
});

describe('chat ID authorization', () => {
  test('rejects an unauthorized chat ID', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { chatId: '-1009999999999', message: 'hi' },
        headers: authed(),
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 403);
    assert.equal(telegramCalls.length, 0, 'must not deliver to an unlisted chat');
  });

  test('client cannot override the authorized owner chat', async () => {
    await worker.fetch(
      makeRequest('/telegram/send', {
        body: { chatId: '-1009999999999', message: 'attempted takeover' },
        headers: authed(),
      }),
      VALID_ENV,
    );
    const allowed = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { chatId: OWNER_CHAT, message: 'legit' },
        headers: authed(),
      }),
      VALID_ENV,
    );
    assert.equal(allowed.status, 200);
    assert.equal(telegramCalls.length, 1);
    assert.equal(telegramCalls[0].body.chat_id, OWNER_CHAT);
  });

  test('omitting chatId resolves to the single allowlisted chat', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message: 'no chat given' }, headers: authed() }),
      VALID_ENV,
    );
    assert.equal(res.status, 200);
    assert.equal(telegramCalls[0].body.chat_id, OWNER_CHAT);
  });

  test('omitting chatId is rejected when multiple chats are allowlisted', () => {
    assert.equal(__test__.resolveChatId('', { AUTHORIZED_CHAT_IDS: 'a,b' }), null);
    assert.equal(__test__.resolveChatId('', { AUTHORIZED_CHAT_IDS: 'a' }), 'a');
    assert.equal(__test__.resolveChatId('b', { AUTHORIZED_CHAT_IDS: 'a,b' }), 'b');
    assert.equal(__test__.resolveChatId('c', { AUTHORIZED_CHAT_IDS: 'a,b' }), null);
  });

  test('empty allowlist blocks all delivery', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message: 'hi' }, headers: authed() }),
      { ...VALID_ENV, AUTHORIZED_CHAT_IDS: '' },
    );
    assert.equal(res.status, 403);
    assert.equal(telegramCalls.length, 0);
  });
});

describe('payload validation', () => {
  test('rejects an empty message', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message: '   ' }, headers: authed() }),
      VALID_ENV,
    );
    assert.equal(res.status, 400);
    assert.equal(telegramCalls.length, 0);
  });

  test('rejects an over-long message', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'x'.repeat(__test__.MAX_MESSAGE_CHARS + 1) },
        headers: authed(),
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 413);
    assert.equal(telegramCalls.length, 0);
  });

  test('rejects an oversized body', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'hi' },
        headers: authed(),
        contentLength: 999999,
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 413);
    assert.equal(telegramCalls.length, 0);
  });

  test('rejects a non-object JSON payload', async () => {
    const req = new Request('https://relay.test/telegram/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authed() },
      body: JSON.stringify(['not', 'an', 'object']),
    });
    const res = await worker.fetch(req, VALID_ENV);
    assert.equal(res.status, 400);
    assert.equal(telegramCalls.length, 0);
  });

  test('rejects malformed JSON', async () => {
    const req = new Request('https://relay.test/telegram/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...authed() },
      body: '{not json',
    });
    const res = await worker.fetch(req, VALID_ENV);
    assert.equal(res.status, 400);
    assert.equal(telegramCalls.length, 0);
  });
});

describe('secret handling', () => {
  test('uses the server-side bot token and never echoes it', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'report' },
        headers: authed(),
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 200);
    const serialized = JSON.stringify(await res.json());
    assert.equal(serialized.includes(BOT_TOKEN), false, 'token must not appear in response');
    // The token IS used server-side to build the upstream URL.
    assert.equal(telegramCalls[0].url.includes(BOT_TOKEN), true);
  });

  test('does not leak upstream Telegram error text', async () => {
    nextTelegramResponse = { ok: false, messageId: null };
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message: 'report' }, headers: authed() }),
      VALID_ENV,
    );
    assert.equal(res.status, 502);
    const json = await res.json();
    assert.equal(json.error, 'Upstream delivery failed.');
    assert.equal(JSON.stringify(json).includes('simulated upstream failure'), false);
  });

  test('rejects when the bot token secret is missing', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message: 'hi' }, headers: authed() }),
      { ...VALID_ENV, TELEGRAM_BOT_TOKEN: '' },
    );
    assert.equal(res.status, 503);
    assert.equal(telegramCalls.length, 0);
  });
});

describe('idempotency', () => {
  test('a repeated Idempotency-Key does not send twice', async () => {
    const key = uniqueKey();
    const first = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'same report' },
        headers: authed({ 'Idempotency-Key': key }),
      }),
      VALID_ENV,
    );
    const second = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'same report' },
        headers: authed({ 'Idempotency-Key': key }),
      }),
      VALID_ENV,
    );
    assert.equal(first.status, 200);
    assert.equal(second.status, 200);
    assert.equal(telegramCalls.length, 1, 'duplicate must be suppressed');
    assert.equal((await second.json()).duplicate, true);
  });

  test('different keys send separately', async () => {
    await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'a' },
        headers: authed({ 'Idempotency-Key': uniqueKey() }),
      }),
      VALID_ENV,
    );
    await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'b' },
        headers: authed({ 'Idempotency-Key': uniqueKey() }),
      }),
      VALID_ENV,
    );
    assert.equal(telegramCalls.length, 2);
  });
});

describe('rate limiting', () => {
  /** Issue one authenticated relay request. */
  async function sendOnce(message = 'report') {
    return worker.fetch(
      makeRequest('/telegram/send', {
        body: { chatId: OWNER_CHAT, message },
        headers: authed(),
      }),
      VALID_ENV,
    );
  }

  test('requests up to the limit are allowed', async () => {
    const max = __test__.RATE_LIMIT_MAX_REQUESTS;

    for (let i = 0; i < max; i++) {
      const res = await sendOnce(`report ${i}`);
      assert.equal(res.status, 200, `request ${i + 1} of ${max} should be allowed`);
    }
    assert.equal(telegramCalls.length, max, 'every allowed request is delivered');
  });

  test('the request over the limit receives 429', async () => {
    const max = __test__.RATE_LIMIT_MAX_REQUESTS;
    for (let i = 0; i < max; i++) await sendOnce(`report ${i}`);

    const res = await sendOnce('one too many');

    assert.equal(res.status, 429);
    const json = await res.json();
    assert.equal(json.ok, false);
    assert.equal(json.error, 'Too many requests.');
  });

  test('a rate-limited request does NOT call Telegram', async () => {
    const max = __test__.RATE_LIMIT_MAX_REQUESTS;
    for (let i = 0; i < max; i++) await sendOnce(`report ${i}`);
    const deliveredBefore = telegramCalls.length;

    await sendOnce('must not be delivered');

    assert.equal(telegramCalls.length, deliveredBefore,
      'the Worker must stop before calling Telegram once over the limit');
  });

  test('the limit applies before body parsing', async () => {
    const max = __test__.RATE_LIMIT_MAX_REQUESTS;
    for (let i = 0; i < max; i++) await sendOnce(`report ${i}`);

    // A malformed payload over the limit must still report 429, proving the
    // rate limiter runs before body handling rather than after.
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message: '' }, headers: authed() }),
      VALID_ENV,
    );
    assert.equal(res.status, 429);
  });

  test('unauthenticated callers cannot consume the rate-limit budget', async () => {
    const max = __test__.RATE_LIMIT_MAX_REQUESTS;

    for (let i = 0; i < max + 20; i++) {
      await worker.fetch(
        makeRequest('/telegram/send', {
          body: { chatId: OWNER_CHAT, message: 'x' },
          headers: { 'X-Relay-Secret': 'wrong' },
        }),
        VALID_ENV,
      );
    }

    // A legitimate caller must still be served.
    const res = await sendOnce('legitimate');
    assert.equal(res.status, 200);
  });
});

describe('body size limit (UTF-8)', () => {
  test('utf8ByteLength measures bytes, not UTF-16 code units', () => {
    assert.equal(__test__.utf8ByteLength('abc'), 3);
    assert.equal(__test__.utf8ByteLength('é'), 2, 'é is 1 UTF-16 unit but 2 bytes');
    assert.equal(__test__.utf8ByteLength('☕'), 3, 'coffee emoji is 3 bytes');
    assert.ok(
      __test__.utf8ByteLength('é'.repeat(100)) > 'é'.repeat(100).length,
      'multi-byte content must measure longer than its UTF-16 length',
    );
  });

  test('a multi-byte body cannot bypass the limit without Content-Length', async () => {
    // Each 'é' is 2 UTF-8 bytes but only 1 UTF-16 code unit, so a body of these
    // is exactly half the character length. A naive String.length check would
    // accept a 16 KiB-count string that is really ~32 KiB of UTF-8.
    const message = 'é'.repeat(__test__.MAX_BODY_BYTES);
    assert.ok(
      message.length <= __test__.MAX_BODY_BYTES,
      'precondition: the naive check would have passed',
    );
    assert.ok(
      __test__.utf8ByteLength(message) > __test__.MAX_BODY_BYTES,
      'the accurate byte check must reject it',
    );

    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message }, headers: authed() }),
      VALID_ENV,
    );

    assert.equal(res.status, 413, 'body must be rejected on real byte size');
    assert.equal(telegramCalls.length, 0);
  });

  test('an emoji-heavy body is also rejected', async () => {
    const message = '☕'.repeat(__test__.MAX_BODY_BYTES); // 3 bytes each
    const res = await worker.fetch(
      makeRequest('/telegram/send', { body: { message }, headers: authed() }),
      VALID_ENV,
    );
    assert.equal(res.status, 413);
    assert.equal(telegramCalls.length, 0);
  });

  test('a small multi-byte body is still accepted', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'Laporan penjualan hari ini — 3 transaksi ☕' },
        headers: authed(),
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 200, 'legitimate non-ASCII content must still work');
    assert.equal(telegramCalls.length, 1);
  });

  test('Content-Length rejection still works', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'hi' },
        headers: authed(),
        contentLength: 999999,
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 413);
  });
});

describe('CORS is defense in depth, not authentication', () => {
  test('a disallowed Origin receives no Access-Control-Allow-Origin', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'report' },
        headers: { ...authed(), Origin: 'https://evil.example.com' },
      }),
      VALID_ENV,
    );

    assert.equal(res.headers.get('Access-Control-Allow-Origin'), '');
    // Critically: the request still succeeded server-side. A browser blocks the
    // *read*, but the message WAS delivered — which is precisely why CORS must
    // not be mistaken for authentication.
    assert.equal(res.status, 200);
    assert.equal(telegramCalls.length, 1);
  });

  test('an allowlisted Origin is echoed back', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'report' },
        headers: { ...authed(), Origin: 'https://caffe-pos.pages.dev' },
      }),
      VALID_ENV,
    );
    assert.equal(res.headers.get('Access-Control-Allow-Origin'), 'https://caffe-pos.pages.dev');
  });

  test('a disallowed Origin without the relay secret is still rejected', async () => {
    // The two controls are independent: origin is irrelevant to authorization.
    const res = await worker.fetch(
      makeRequest('/telegram/send', {
        body: { message: 'report' },
        headers: { Origin: 'https://evil.example.com' },
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 401);
    assert.equal(telegramCalls.length, 0);
  });

  test('preflight from a disallowed Origin does not grant the origin', async () => {
    const res = await worker.fetch(
      new Request('https://relay.test/telegram/send', {
        method: 'OPTIONS',
        headers: { Origin: 'https://evil.example.com' },
      }),
      VALID_ENV,
    );
    assert.equal(res.status, 204);
    assert.equal(res.headers.get('Access-Control-Allow-Origin'), '');
  });
});

describe('routing and CORS', () => {
  test('unknown path returns 404', async () => {
    const res = await worker.fetch(makeRequest('/nope', { headers: authed() }), VALID_ENV);
    assert.equal(res.status, 404);
  });

  test('non-POST returns 405', async () => {
    const res = await worker.fetch(
      new Request('https://relay.test/telegram/send', { method: 'GET' }),
      VALID_ENV,
    );
    assert.equal(res.status, 405);
  });

  test('CORS preflight succeeds without auth', async () => {
    const res = await worker.fetch(
      new Request('https://relay.test/telegram/send', { method: 'OPTIONS' }),
      VALID_ENV,
    );
    assert.equal(res.status, 204);
  });

  test('test endpoint delivers a fixed message to the allowlisted chat', async () => {
    const res = await worker.fetch(
      makeRequest('/telegram/test', { body: { chatId: OWNER_CHAT }, headers: authed() }),
      VALID_ENV,
    );
    assert.equal(res.status, 200);
    assert.equal(telegramCalls[0].body.chat_id, OWNER_CHAT);
    assert.equal(telegramCalls[0].body.text.includes('Uji Coba Integrasi'), true);
  });
});