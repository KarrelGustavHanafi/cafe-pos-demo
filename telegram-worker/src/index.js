/**
 * CAFFE POS — Secure Telegram Relay Worker
 *
 * Cloudflare Worker that proxies Telegram Bot API requests so the Flutter Web
 * client never touches the bot token.
 *
 * ── Required Worker Secrets (set with `npx wrangler secret put <NAME>`) ────────
 *   TELEGRAM_BOT_TOKEN  — the Telegram bot token. NEVER stored in wrangler.toml.
 *   TELEGRAM_RELAY_SECRET — shared secret proving the caller is the CAFFE POS
 *                          client. Sent as the `X-Relay-Secret` request header.
 *   AUTHORIZED_CHAT_IDS — comma-separated allowlist of Owner chat IDs. Messages
 *                         can only ever be delivered to one of these.
 *
 * ── Security model ─────────────────────────────────────────────────────────────
 * CORS is *defense in depth only* — it is enforced by browsers and is trivially
 * bypassed by curl, scripts, or any non-browser client. Authentication is the
 * `X-Relay-Secret` header (constant-time compared) plus a server-side chat ID
 * allowlist. A caller-supplied `chatId` is only ever used to *select* from the
 * allowlist; it can never widen or override it.
 *
 * ── Endpoints ──────────────────────────────────────────────────────────────────
 *   POST /telegram/test  — send a fixed test message (chat ID still allowlisted)
 *   POST /telegram/send  — relay an owner report
 *
 * Both endpoints require `X-Relay-Secret` and an optional `Idempotency-Key`.
 */

// ── Limits ─────────────────────────────────────────────────────────────────────
const MAX_BODY_BYTES = 16 * 1024; // 16 KiB request body ceiling
const MAX_MESSAGE_CHARS = 4096; // Telegram's own practical limit
const IDEMPOTENCY_TTL_MS = 5 * 60 * 1000; // 5 minutes
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 60; // per caller per window

// ── In-memory state ────────────────────────────────────────────────────────────
// NOTE: Worker isolates are ephemeral and may be recycled at any time, and there
// is no shared state between isolates. These maps are therefore a *best-effort*
// guard that stops casual abuse; they are NOT a durable store. See the audit's
// "remaining limitations" for the Durable Object upgrade path.
const idempotencyCache = new Map();
const rateLimitBuckets = new Map();

/**
 * Allowed origins for CORS. Defense in depth only — never treated as auth.
 * Update with your real production domain(s).
 */
const ALLOWED_ORIGINS = [
  'http://localhost',
  'http://localhost:8080',
  'http://localhost:3000',
  'http://localhost:5000',
  'https://caffe-pos.pages.dev',
];

function isOriginAllowed(origin) {
  if (!origin) return false;
  if (ALLOWED_ORIGINS.includes(origin)) return true;
  // Allow any localhost port during development.
  try {
    const url = new URL(origin);
    if (url.hostname === 'localhost' || url.hostname === '127.0.0.1') return true;
  } catch {
    /* ignore */
  }
  return false;
}

function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  const allowed = isOriginAllowed(origin) ? origin : '';
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Relay-Secret, Idempotency-Key',
    'Access-Control-Max-Age': '86400',
  };
}

function jsonError(message, status, request) {
  return new Response(JSON.stringify({ ok: false, error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
  });
}

function jsonOk(data, request) {
  return new Response(JSON.stringify({ ok: true, ...data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
  });
}

// ── Crypto / comparison helpers ───────────────────────────────────────────────

/**
 * Compare two strings without an early-exit on the first differing character.
 *
 * Length is folded into the result rather than short-circuiting, so the loop
 * always runs to `max(len)` regardless of where (or whether) the inputs differ.
 * This narrows — but does not eliminate — timing side channels.
 */
function constantTimeEqual(a, b) {
  const enc = new TextEncoder();
  const ba = enc.encode(String(a));
  const bb = enc.encode(String(b));
  const max = Math.max(ba.length, bb.length);
  let diff = ba.length ^ bb.length;
  for (let i = 0; i < max; i++) {
    diff |= (ba[i] ?? 0) ^ (bb[i] ?? 0);
  }
  return diff === 0;
}

/**
 * Derive a non-reversible bucket key from the relay secret.
 * Used for rate limiting so the raw secret is never used as a map key.
 */
function secretFingerprint(secret) {
  // FNV-1a, 32-bit, hex. Not cryptographic — collision resistance is not
  // required here, only a stable, non-reversible partition key.
  let hash = 0x811c9dc5;
  for (let i = 0; i < secret.length; i++) {
    hash ^= secret.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}

function sweepCaches(now) {
  for (const [key, entry] of idempotencyCache) {
    if (entry.expiresAt <= now) idempotencyCache.delete(key);
  }
  for (const [key, bucket] of rateLimitBuckets) {
    if (bucket.windowStart + RATE_LIMIT_WINDOW_MS <= now) rateLimitBuckets.delete(key);
  }
}

/**
 * Accurate UTF-8 byte length of a string.
 *
 * `String.prototype.length` counts UTF-16 code units, which UNDER-counts real
 * bytes for any non-ASCII character (e.g. 'é' is 1 unit but 2 UTF-8 bytes;
 * emoji are surrogate pairs). Using it as a byte ceiling would therefore let a
 * multi-byte body exceed the limit. `TextEncoder` measures what is actually
 * sent over the wire.
 */
function utf8ByteLength(text) {
  return new TextEncoder().encode(text).length;
}

// ── Guards ─────────────────────────────────────────────────────────────────────

/**
 * Authenticate the caller via the `X-Relay-Secret` header.
 * Returns { ok: true, fingerprint } or { ok: false, status }.
 */
function authenticate(request, env) {
  const expected = env.TELEGRAM_RELAY_SECRET;
  if (!expected || String(expected).trim() === '') {
    // Misconfiguration must not be distinguishable from a bad secret by clients.
    return { ok: false, status: 503 };
  }
  const provided = request.headers.get('X-Relay-Secret') || '';
  if (provided === '') return { ok: false, status: 401 };
  if (!constantTimeEqual(provided, expected)) return { ok: false, status: 403 };
  return { ok: true, fingerprint: secretFingerprint(expected) };
}

/**
 * Resolve the destination chat strictly from the server-side allowlist.
 *
 * A client-supplied `chatId` is only accepted if it already appears in
 * `AUTHORIZED_CHAT_IDS`. Omitting it is allowed only when exactly one chat is
 * allowlisted (the single-owner case).
 */
function resolveChatId(requested, env) {
  const allowlist = String(env.AUTHORIZED_CHAT_IDS || '')
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value !== '');
  if (allowlist.length === 0) return null;

  const requestedId = String(requested ?? '').trim();
  if (requestedId === '') {
    return allowlist.length === 1 ? allowlist[0] : null;
  }
  for (const allowed of allowlist) {
    if (constantTimeEqual(allowed, requestedId)) return allowed;
  }
  return null;
}

/**
 * Fixed-window rate limiter. Best-effort per isolate (see state note above).
 */
function rateLimit(fingerprint, now) {
  let bucket = rateLimitBuckets.get(fingerprint);
  if (!bucket || bucket.windowStart + RATE_LIMIT_WINDOW_MS <= now) {
    bucket = { windowStart: now, count: 0 };
  }
  bucket.count += 1;
  rateLimitBuckets.set(fingerprint, bucket);
  return bucket.count <= RATE_LIMIT_MAX_REQUESTS;
}

/**
 * Read and parse a JSON body with a hard byte ceiling.
 * Rejects oversized declared or actual bodies before any allocation-heavy work.
 */
async function readJsonBody(request) {
  const declared = Number(request.headers.get('Content-Length') || '0');
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) {
    return { error: 'payload_too_large' };
  }
  let text;
  try {
    text = await request.text();
  } catch {
    return { error: 'invalid_payload' };
  }
  // Measure real UTF-8 bytes, not UTF-16 code units, so multi-byte content
  // cannot slip past the ceiling when Content-Length is absent.
  if (utf8ByteLength(text) > MAX_BODY_BYTES) return { error: 'payload_too_large' };
  if (text.trim() === '') return { error: 'invalid_payload' };
  try {
    const parsed = JSON.parse(text);
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return { error: 'invalid_payload' };
    }
    return { body: parsed };
  } catch {
    return { error: 'invalid_payload' };
  }
}

/**
 * Best-effort idempotency. Returns:
 *   { state: 'new' }        — caller should perform the send
 *   { state: 'replay', ...} — duplicate; return the original outcome
 */
function idempotencyBegin(key, fingerprint, now) {
  if (!key) return { state: 'new' };
  const composite = `${fingerprint}:${key}`;
  const cached = idempotencyCache.get(composite);
  if (cached && cached.expiresAt > now) return { state: 'replay', entry: cached };
  return { state: 'new', composite };
}

function idempotencyCommit(composite, key, result, now) {
  if (!key || !composite) return;
  idempotencyCache.set(composite, {
    result,
    expiresAt: now + IDEMPOTENCY_TTL_MS,
  });
}

/**
 * Relay a message to Telegram using the server-side token.
 * The token is used only inside this function and is never returned or logged.
 */
async function sendTelegramMessage(token, chatId, text) {
  const res = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text }),
  });
  let ok = false;
  let messageId;
  try {
    const data = await res.json();
    ok = res.status === 200 && data && data.ok === true;
    if (ok) messageId = data.result?.message_id;
  } catch {
    ok = false;
  }
  return { ok, httpStatus: res.status, messageId };
}

// ── Handlers ──────────────────────────────────────────────────────────────────

/**
 * Shared pipeline: authenticate → rate limit → body → chat allowlist → send.
 * `buildMessage` returns the text for an already-authorized chat ID.
 */
async function handleRelay(request, env, kind) {
  const now = Date.now();
  sweepCaches(now);

  const auth = authenticate(request, env);
  if (!auth.ok) {
    // Deliberately vague: never reveal whether the secret was missing,
    // wrong, or simply not configured on the server.
    return jsonError('Unauthorized.', auth.status, request);
  }

  if (!rateLimit(auth.fingerprint, now)) {
    return jsonError('Too many requests.', 429, request);
  }

  const token = env.TELEGRAM_BOT_TOKEN;
  if (!token) {
    return jsonError('Relay is not configured.', 503, request);
  }

  const parsed = await readJsonBody(request);
  if (parsed.error === 'payload_too_large') {
    return jsonError('Payload too large.', 413, request);
  }
  if (parsed.error) {
    return jsonError('Invalid payload.', 400, request);
  }
  const body = parsed.body;

  const chatId = resolveChatId(body.chatId, env);
  if (!chatId) {
    return jsonError('Chat is not authorized.', 403, request);
  }

  let text;
  if (kind === 'test') {
    text =
      '🔔 Uji Coba Integrasi CAFFE POS\n' +
      'Status: Terhubung OK ✅\n' +
      `Waktu: ${new Date(now).toISOString()}\n` +
      'Relay: Secure Cloudflare Worker';
  } else {
    const message = body.message;
    if (typeof message !== 'string' || message.trim() === '') {
      return jsonError('Invalid payload.', 400, request);
    }
    if (message.length > MAX_MESSAGE_CHARS) {
      return jsonError('Message too long.', 413, request);
    }
    text = message;
  }

  const idemKey = request.headers.get('Idempotency-Key') || '';
  const idem = idempotencyBegin(idemKey, auth.fingerprint, now);
  if (idem.state === 'replay') {
    const cached = idem.entry.result;
    return jsonOk(
      { message: 'Duplicate request suppressed.', duplicate: true, messageId: cached.messageId },
      request,
    );
  }

  let result;
  try {
    result = await sendTelegramMessage(token, chatId, text);
  } catch {
    // Never surface Telegram internals or the token.
    return jsonError('Upstream delivery failed.', 502, request);
  }

  if (!result.ok) {
    // Generic: Telegram's own error text is not returned to the caller.
    return jsonError('Upstream delivery failed.', 502, request);
  }

  idempotencyCommit(idem.composite, idemKey, { messageId: result.messageId }, now);

  return jsonOk(
    {
      message: 'Delivered.',
      messageId: result.messageId,
    },
    request,
  );
}

// ── Entry point ───────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }
    if (request.method !== 'POST') {
      return jsonError('Method not allowed.', 405, request);
    }

    const path = new URL(request.url).pathname;
    if (path === '/telegram/test') return handleRelay(request, env, 'test');
    if (path === '/telegram/send') return handleRelay(request, env, 'send');

    return jsonError('Not found.', 404, request);
  },
};

// Exported for unit tests only. Not part of the Worker runtime surface.
export const __test__ = {
  constantTimeEqual,
  resolveChatId,
  authenticate,
  readJsonBody,
  utf8ByteLength,
  // Rate-limit and idempotency state is module-level. Worker isolates are
  // ephemeral, so this reset has no production meaning; it exists purely so
  // tests can start from a clean, deterministic slate.
  resetState() {
    idempotencyCache.clear();
    rateLimitBuckets.clear();
  },
  MAX_MESSAGE_CHARS,
  MAX_BODY_BYTES,
  RATE_LIMIT_MAX_REQUESTS,
};