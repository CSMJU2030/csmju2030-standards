'use strict';
/** Tiny zero-dependency test harness: HTTP helpers + result reporting. */

const ERROR_CODES = require('../../contracts/error-codes.json').codes;

class Report {
  constructor() {
    this.results = [];
    this.currentGroup = 'general';
  }

  group(name) {
    this.currentGroup = name;
    console.log(`\n── ${name}`);
  }

  record(status, id, title, detail = '') {
    this.results.push({ group: this.currentGroup, id, title, status, detail });

    const mark = { PASS: '  PASS', FAIL: '  FAIL', SKIP: '  SKIP' }[status];
    const line = `${mark}  ${id.padEnd(10)} ${title}`;

    console.log(detail && status !== 'PASS' ? `${line}\n            → ${detail}` : line);
  }

  pass(id, title, detail) {
    this.record('PASS', id, title, detail);
  }

  fail(id, title, detail) {
    this.record('FAIL', id, title, detail);
  }

  skip(id, title, detail) {
    this.record('SKIP', id, title, detail);
  }

  /** Asserts `actual === expected`. */
  expect(id, title, actual, expected) {
    if (actual === expected) {
      this.pass(id, title);
      return true;
    }

    this.fail(id, title, `got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
    return false;
  }

  expectTrue(id, title, condition, detail) {
    return condition ? this.pass(id, title) || true : this.fail(id, title, detail) || false;
  }

  get counts() {
    const counts = { PASS: 0, FAIL: 0, SKIP: 0 };
    for (const result of this.results) counts[result.status] += 1;
    return counts;
  }
}

/** GET/POST helper that never throws on HTTP status. */
async function call(url, options = {}) {
  const { token, cookie, json, method = 'GET', redirect = 'manual', headers = {} } = options;

  const requestHeaders = { accept: 'application/json', ...headers };

  if (token) requestHeaders.authorization = `Bearer ${token}`;
  if (cookie) requestHeaders.cookie = cookie;
  if (json !== undefined) requestHeaders['content-type'] = 'application/json';

  let response;

  try {
    response = await fetch(url, {
      method,
      redirect,
      headers: requestHeaders,
      ...(json !== undefined ? { body: JSON.stringify(json) } : {}),
    });
  } catch (error) {
    return { ok: false, status: 0, body: null, error: error.message, headers: new Headers() };
  }

  const text = await response.text();
  let body = null;

  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }

  return {
    ok: response.ok,
    status: response.status,
    headers: response.headers,
    location: response.headers.get('location'),
    setCookie: response.headers.get('set-cookie'),
    body,
    text,
  };
}

/** Standard success envelope: { success: true, data, meta? } */
function isSuccessEnvelope(body) {
  return (
    body !== null &&
    typeof body === 'object' &&
    body.success === true &&
    Object.prototype.hasOwnProperty.call(body, 'data')
  );
}

/** Standard error envelope: { success: false, error: { code, message } } */
function isErrorEnvelope(body) {
  return (
    body !== null &&
    typeof body === 'object' &&
    body.success === false &&
    body.error !== null &&
    typeof body.error === 'object' &&
    typeof body.error.code === 'string' &&
    typeof body.error.message === 'string'
  );
}

function isKnownErrorCode(code) {
  return ERROR_CODES.includes(code);
}

/** Rejects any response that leaks internals (stack traces, SQL, file paths). */
function leaksInternals(text) {
  if (typeof text !== 'string') return false;

  return /"stack"|\bat .+\(.+:\d+:\d+\)|node_modules|SELECT .+ FROM |PrismaClient/i.test(text);
}

module.exports = {
  Report,
  call,
  isSuccessEnvelope,
  isErrorEnvelope,
  isKnownErrorCode,
  leaksInternals,
  ERROR_CODES,
};
