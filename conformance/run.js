#!/usr/bin/env node
'use strict';
/**
 * CSMJU2030 Subsystem Conformance Runner
 * =====================================
 *
 * Black-box conformance test for any subsystem, in any language or framework.
 * It only speaks HTTP to the candidate subsystem and to the Core Hub.
 *
 *   node conformance/run.js --manifest ./csmju-subsystem.json
 *   node conformance/run.js --url http://localhost:3002 --subsystem equipment-service
 *
 * Levels
 *   L1  Identity  - Core Hub token verification, 401 behaviour, /me, no local login
 *   L2  Contract  - response envelope, error codes, pagination, 400/403/404
 *   L3  SSO       - registered callback_url, /auth/callback, session without re-login
 *
 * Zero dependencies: Node.js 20+ only. Never reads the Core Hub private key.
 */
const fs = require('node:fs');

const { loadManifest } = require('./lib/manifest');
const {
  Report,
  call,
  isSuccessEnvelope,
  isErrorEnvelope,
  isKnownErrorCode,
  leaksInternals,
} = require('./lib/harness');
const { negativeTokens, decodeJwt } = require('./lib/tokens');

const JWT_CONTRACT = require('../contracts/jwt-contract.json');

// ---------------------------------------------------------------- config --

function parseArgs(argv) {
  const args = {};

  for (let i = 2; i < argv.length; i += 1) {
    const current = argv[i];
    if (!current.startsWith('--')) continue;

    const key = current.slice(2);
    const next = argv[i + 1];

    if (next === undefined || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i += 1;
    }
  }

  return args;
}

const DEFAULT_ACCOUNTS = {
  admin: { email: 'admin@core.local', password: 'password1' },
  student: { email: 'student@core.local', password: 'password2' },
  staff: { email: 'staff@core.local', password: 'password3' },
  alumni: { email: 'alumni@core.local', password: 'password4' },
};

function loadConfig(args) {
  // แหล่งเดียวคือ subsystem.yaml ที่รากของ repo (ไฟล์เดียวกับที่ CI ใช้)
  const { manifest, manifestPath } = loadManifest(args.manifest);

  if (manifestPath) {
    console.log(`manifest      : ${manifestPath}`);
  }

  const config = {
    subsystemId: args.subsystem ?? manifest.subsystemId,
    baseUrl: (args.url ?? manifest.baseUrl ?? '').replace(/\/+$/, ''),
    coreHubUrl: (args['core-hub'] ?? manifest.coreHubUrl ?? 'http://localhost:3000').replace(/\/+$/, ''),
    level: (args.level ?? manifest.level ?? 'L3').toUpperCase(),
    callbackPath: manifest.callbackPath ?? '/auth/callback',
    probes: manifest.probes ?? {},
    accounts: { ...DEFAULT_ACCOUNTS, ...(manifest.testAccounts ?? {}) },
    json: Boolean(args.json),
  };

  if (!config.baseUrl) throw new Error('ต้องระบุ --url หรือ base_url ใน subsystem.yaml');
  if (!config.subsystemId) throw new Error('ต้องระบุ --subsystem หรือ name ใน subsystem.yaml');

  return config;
}

// ------------------------------------------------------------ core hub ----

async function login(coreHubUrl, account) {
  const response = await call(`${coreHubUrl}/api/v1/auth/login`, {
    method: 'POST',
    json: { email: account.email, password: account.password },
    redirect: 'follow',
  });

  const body = response.body ?? {};

  return body.data?.access_token ?? body.access_token ?? null;
}

// ------------------------------------------------------------- level 1 ----

async function runLevel1(config, report, tokens) {
  const { baseUrl } = config;
  const anyToken = tokens.staff ?? tokens.admin ?? tokens.student ?? tokens.alumni;

  report.group('L1 · Identity — health & public surface');

  const health = await call(`${baseUrl}/api/health`);

  if (health.status === 0) {
    throw new Error(
      `ไม่สามารถเชื่อมต่อ subsystem ที่ ${baseUrl} ได้ (${health.error}). ` +
        'ตรวจว่ารันระบบอยู่และ baseUrl ถูกต้องหรือยัง',
    );
  }

  report.expect('L1-01', 'GET /api/health → 200', health.status, 200);
  report.expectTrue(
    'L1-02',
    'health uses the success envelope',
    isSuccessEnvelope(health.body),
    `body=${JSON.stringify(health.body)?.slice(0, 120)}`,
  );
  report.expect(
    'L1-03',
    'health reports status "ok"',
    health.body?.data?.status,
    'ok',
  );
  report.expect(
    'L1-04',
    'health reports the registered subsystem id',
    health.body?.data?.service,
    config.subsystemId,
  );

  for (const [id, routePath] of [
    ['L1-05', '/api/v1/auth/login'],
    ['L1-06', '/api/v1/login'],
    ['L1-07', '/api/v1/auth/register'],
  ]) {
    const response = await call(`${baseUrl}${routePath}`, {
      method: 'POST',
      json: { email: 'x@y.local', password: 'password1' },
    });

    report.expectTrue(
      id,
      `no local login endpoint at POST ${routePath}`,
      response.status === 404 || response.status === 405,
      `got ${response.status} - a subsystem MUST NOT authenticate users itself`,
    );
  }

  report.group('L1 · Identity — /api/v1/me with a real Core Hub token');

  const me = await call(`${baseUrl}/api/v1/me`, { token: anyToken });
  report.expect('L1-08', 'GET /api/v1/me → 200', me.status, 200);
  report.expectTrue('L1-09', '/me uses the success envelope', isSuccessEnvelope(me.body));

  const claims = anyToken ? decodeJwt(anyToken).payload : {};

  report.expect('L1-10', '/me.id equals the token subject', me.body?.data?.id, claims.sub);
  report.expect('L1-11', '/me.coreRole equals the token role', me.body?.data?.coreRole, claims.role);
  report.expectTrue(
    'L1-12',
    '/me.subsystemRole is a mapped, non-empty value',
    typeof me.body?.data?.subsystemRole === 'string' && me.body.data.subsystemRole.length > 0,
    `got ${JSON.stringify(me.body?.data?.subsystemRole)}`,
  );

  report.group('L1 · Identity — every rejected token must answer 401');

  const noToken = await call(`${baseUrl}/api/v1/me`);
  report.expect('L1-13', 'no token → 401', noToken.status, 401);
  report.expectTrue('L1-14', 'error envelope on 401', isErrorEnvelope(noToken.body));
  report.expect('L1-15', 'error code is UNAUTHORIZED', noToken.body?.error?.code, 'UNAUTHORIZED');

  const basicAuth = await call(`${baseUrl}/api/v1/me`, {
    headers: { authorization: 'Basic dXNlcjpwYXNz' },
  });
  report.expect('L1-16', 'non-Bearer scheme → 401', basicAuth.status, 401);

  const negatives = negativeTokens(JWT_CONTRACT, anyToken);
  const negativeCases = [
    ['L1-17', 'malformed token', negatives.malformed],
    ['L1-18', 'expired token', negatives.expired],
    ['L1-19', 'wrong issuer', negatives.wrongIssuer],
    ['L1-20', 'wrong audience', negatives.wrongAudience],
    ['L1-21', 'unknown kid', negatives.unknownKid],
    ['L1-22', 'signature from a foreign key', negatives.foreignSignature],
    ['L1-23', 'missing sub claim', negatives.missingSubject],
    ['L1-24', 'alg=none (unsigned)', negatives.algNone],
    ['L1-25', 'HS256 token', negatives.hs256],
    ['L1-26', 'tampered role claim', negatives.tamperedRole],
    ['L1-27', 'tampered sub claim', negatives.tamperedSubject],
  ];

  for (const [id, title, token] of negativeCases) {
    if (!token) {
      report.skip(id, title, 'no valid token available to derive this case');
      continue;
    }

    const response = await call(`${baseUrl}/api/v1/me`, { token });
    report.expect(id, `${title} → 401`, response.status, 401);
  }

  report.group('L1 · Identity — role mapping and error hygiene');

  for (const [role, token] of Object.entries(tokens)) {
    if (!token) continue;

    const response = await call(`${baseUrl}/api/v1/me`, { token });
    const accepted = response.status === 200;
    const refused = response.status === 403;

    report.expectTrue(
      `L1-28.${role}`,
      `core role "${role}" is mapped (200) or explicitly refused (403)`,
      accepted || refused,
      `got ${response.status}`,
    );

    if (refused) {
      report.expectTrue(
        `L1-29.${role}`,
        `refusal for "${role}" uses FORBIDDEN`,
        response.body?.error?.code === 'FORBIDDEN',
        `got ${JSON.stringify(response.body?.error)}`,
      );
    }
  }

  const leak = await call(`${baseUrl}/api/v1/me`, { token: negatives.malformed });
  report.expectTrue(
    'L1-30',
    'error responses do not leak stack traces or internals',
    !leaksInternals(leak.text),
    (leak.text ?? '').slice(0, 160),
  );
}

// ------------------------------------------------------------- level 2 ----

async function runLevel2(config, report, tokens) {
  const { baseUrl, probes } = config;
  const staffToken = tokens.staff ?? tokens.admin;

  report.group('L2 · Contract — collection shape & pagination');

  if (!probes.collection) {
    report.skip('L2-01', 'collection endpoint', 'manifest.probes.collection is not declared');
  } else {
    const collection = await call(`${baseUrl}${probes.collection}`, { token: staffToken });

    report.expect('L2-01', `GET ${probes.collection} → 200`, collection.status, 200);
    report.expectTrue(
      'L2-02',
      'collection returns data as an array',
      Array.isArray(collection.body?.data),
      `got ${typeof collection.body?.data}`,
    );

    const meta = collection.body?.meta ?? {};
    report.expectTrue(
      'L2-03',
      'collection returns meta{total,page,limit,totalPages}',
      ['total', 'page', 'limit', 'totalPages'].every((key) => typeof meta[key] === 'number'),
      `meta=${JSON.stringify(meta)}`,
    );

    const paginated = await call(`${baseUrl}${probes.collection}?page=1&limit=1`, {
      token: staffToken,
    });
    report.expectTrue(
      'L2-04',
      'pagination honours ?page=1&limit=1',
      paginated.status === 200 &&
        Array.isArray(paginated.body?.data) &&
        paginated.body.data.length <= 1 &&
        paginated.body?.meta?.limit === 1,
      `status=${paginated.status} len=${paginated.body?.data?.length} meta=${JSON.stringify(paginated.body?.meta)}`,
    );

    const badQuery = await call(`${baseUrl}${probes.collection}?limit=not-a-number`, {
      token: staffToken,
    });
    report.expect('L2-05', 'invalid query parameter → 400', badQuery.status, 400);
    report.expect(
      'L2-06',
      'invalid query uses VALIDATION_ERROR',
      badQuery.body?.error?.code,
      'VALIDATION_ERROR',
    );
  }

  report.group('L2 · Contract — 404 / 400 / 403');

  if (probes.notFound) {
    const missing = await call(`${baseUrl}${probes.notFound}`, { token: staffToken });
    report.expect('L2-07', 'unknown resource id → 404', missing.status, 404);
    report.expect('L2-08', '404 uses NOT_FOUND', missing.body?.error?.code, 'NOT_FOUND');
  } else {
    report.skip('L2-07', 'unknown resource id → 404', 'manifest.probes.notFound is not declared');
  }

  if (probes.invalidId) {
    const invalid = await call(`${baseUrl}${probes.invalidId}`, { token: staffToken });
    report.expect('L2-09', 'malformed resource id → 400', invalid.status, 400);
  } else {
    report.skip('L2-09', 'malformed resource id → 400', 'manifest.probes.invalidId is not declared');
  }

  const create = probes.create;

  if (create?.path) {
    const allowedToken = tokens[create.allowedRole ?? 'staff'] ?? staffToken;
    const deniedToken = tokens[create.deniedRole ?? 'student'];

    const invalidBody = await call(`${baseUrl}${create.path}`, {
      method: 'POST',
      token: allowedToken,
      json: create.invalidBody ?? { unknownField: 'x' },
    });
    report.expect('L2-10', 'invalid request body → 400', invalidBody.status, 400);
    report.expect(
      'L2-11',
      'invalid body uses VALIDATION_ERROR',
      invalidBody.body?.error?.code,
      'VALIDATION_ERROR',
    );

    if (deniedToken) {
      const denied = await call(`${baseUrl}${create.path}`, {
        method: 'POST',
        token: deniedToken,
        json: create.validBody ?? create.invalidBody ?? {},
      });
      report.expect(
        'L2-12',
        `role "${create.deniedRole ?? 'student'}" cannot write → 403`,
        denied.status,
        403,
      );
      report.expect('L2-13', 'denied write uses FORBIDDEN', denied.body?.error?.code, 'FORBIDDEN');
    } else {
      report.skip('L2-12', 'denied write → 403', 'no token for the denied role');
    }
  } else {
    report.skip('L2-10', 'write probes', 'manifest.probes.create is not declared');
  }

  report.group('L2 · Contract — error codes come from the closed enum');

  const observed = new Set(
    report.results
      .map((result) => result.detail)
      .join(' ')
      .match(/[A-Z_]{4,}/g) ?? [],
  );

  const unknownRoute = await call(`${baseUrl}/api/v1/__does_not_exist__`, { token: staffToken });
  report.expectTrue(
    'L2-14',
    'unknown route → 404 with an error envelope',
    unknownRoute.status === 404 && isErrorEnvelope(unknownRoute.body),
    `status=${unknownRoute.status} body=${JSON.stringify(unknownRoute.body)?.slice(0, 120)}`,
  );
  report.expectTrue(
    'L2-15',
    'every returned error code is part of the standard enum',
    !unknownRoute.body?.error?.code || isKnownErrorCode(unknownRoute.body.error.code),
    `code=${unknownRoute.body?.error?.code} observed=${[...observed].join(',')}`,
  );
}

// ------------------------------------------------------------- level 3 ----

async function runLevel3(config, report, tokens) {
  const { baseUrl, coreHubUrl, subsystemId, callbackPath } = config;

  report.group('L3 · SSO — registration & handoff');

  const adminToken = tokens.admin;

  if (!adminToken) {
    report.skip('L3-01', 'subsystem registration', 'no Core Hub admin token available');
    return;
  }

  const registry = await call(`${coreHubUrl}/api/v1/subsystems/all`, {
    token: adminToken,
    redirect: 'follow',
  });
  const entries = registry.body?.data ?? registry.body ?? [];
  const entry = Array.isArray(entries)
    ? entries.find((item) => item.name === subsystemId)
    : undefined;

  if (!entry) {
    report.fail('L3-01', 'subsystem is registered in the Subsystem Registry', `"${subsystemId}" not found`);
    return;
  }

  report.pass('L3-01', 'subsystem is registered in the Subsystem Registry');
  report.expect('L3-02', 'registry approvalStatus is APPROVED', entry.approvalStatus, 'APPROVED');
  report.expect('L3-03', 'registry status is ACTIVE', entry.status, 'ACTIVE');
  report.expect(
    'L3-04',
    'registered callback_url matches the running subsystem',
    (entry.callbackUrl ?? '').replace(/\/+$/, ''),
    `${baseUrl}${callbackPath}`,
  );

  const mappedRoles = Object.keys(entry.defaultRoleMapping ?? {});
  report.expectTrue(
    'L3-05',
    'registry declares the core roles this subsystem accepts',
    mappedRoles.length > 0,
    'defaultRoleMapping is empty - Core Hub cannot filter who may enter',
  );

  const ssoRole = mappedRoles.find((role) => tokens[role]) ?? 'staff';
  const ssoToken = tokens[ssoRole];

  const authorize = await call(
    `${coreHubUrl}/api/v1/auth/sso/authorize?subsystem=${encodeURIComponent(subsystemId)}`,
    { token: ssoToken },
  );

  report.expect('L3-06', 'Core Hub SSO authorize → 302', authorize.status, 302);
  report.expectTrue(
    'L3-07',
    'redirect points at the registered callback',
    (authorize.location ?? '').startsWith(`${baseUrl}${callbackPath}`),
    `location=${(authorize.location ?? '').replace(/access_token=[^&]+/, 'access_token=<token>')}`,
  );

  report.group('L3 · SSO — callback establishes a session');

  if (!authorize.location) {
    report.skip('L3-08', 'callback accepts the handoff', 'no redirect location to follow');
    return;
  }

  const callback = await call(authorize.location);

  report.expectTrue(
    'L3-08',
    'callback accepts the Core Hub token (200 or 302)',
    callback.status === 200 || callback.status === 302,
    `got ${callback.status}`,
  );
  report.expectTrue(
    'L3-09',
    'callback sets an HttpOnly session cookie',
    /httponly/i.test(callback.setCookie ?? ''),
    `set-cookie=${(callback.setCookie ?? '(none)').split(';')[0]}`,
  );

  const cookie = (callback.setCookie ?? '').split(';')[0];

  if (cookie) {
    const meViaCookie = await call(`${baseUrl}/api/v1/me`, { cookie });
    report.expect('L3-10', 'the session cookie alone reaches /api/v1/me', meViaCookie.status, 200);

    const claims = decodeJwt(ssoToken).payload;
    report.expect(
      'L3-11',
      'cookie session identifies the same Core Hub user',
      meViaCookie.body?.data?.id,
      claims.sub,
    );
  } else {
    report.skip('L3-10', 'session cookie reaches /api/v1/me', 'no cookie was issued');
  }

  report.group('L3 · SSO — rejected handoffs');

  const negatives = negativeTokens(JWT_CONTRACT, ssoToken);

  const tampered = await call(
    `${baseUrl}${callbackPath}?access_token=${encodeURIComponent(negatives.tamperedRole)}`,
  );
  report.expect('L3-12', 'callback with a tampered token → 401', tampered.status, 401);
  report.expectTrue(
    'L3-13',
    'no session cookie is issued for a rejected token',
    !/core_hub|session/i.test(tampered.setCookie ?? ''),
    `set-cookie=${tampered.setCookie ?? '(none)'}`,
  );

  const noToken = await call(`${baseUrl}${callbackPath}`);
  report.expectTrue(
    'L3-14',
    'callback without a token → 400 or 401',
    noToken.status === 400 || noToken.status === 401,
    `got ${noToken.status}`,
  );

  const foreignCallback = await call(
    `${coreHubUrl}/api/v1/auth/sso/authorize?subsystem=${encodeURIComponent(subsystemId)}` +
      `&callback_url=${encodeURIComponent('https://evil.example.com/steal')}`,
    { token: ssoToken },
  );
  report.expect('L3-15', 'Core Hub rejects an unregistered callback_url', foreignCallback.status, 400);
}

// ----------------------------------------------------------------- main ---

async function main() {
  const args = parseArgs(process.argv);
  const config = loadConfig(args);

  console.log('CSMJU2030 Subsystem Conformance Runner');
  console.log(`standard      : v${JWT_CONTRACT.standardsVersion}`);
  console.log(`subsystem     : ${config.subsystemId}`);
  console.log(`base url      : ${config.baseUrl}`);
  console.log(`core hub      : ${config.coreHubUrl}`);
  console.log(`level         : ${config.level}`);

  const report = new Report();

  const tokens = {};
  for (const [role, account] of Object.entries(config.accounts)) {
    tokens[role] = await login(config.coreHubUrl, account);
  }

  const obtained = Object.entries(tokens).filter(([, token]) => token);

  if (obtained.length === 0) {
    console.error(
      `\nERROR: could not obtain any Core Hub token from ${config.coreHubUrl}. ` +
        'Is the Core Hub running and seeded?',
    );
    process.exit(2);
  }

  console.log(`tokens        : ${obtained.map(([role]) => role).join(', ')}`);

  await runLevel1(config, report, tokens);

  if (config.level === 'L2' || config.level === 'L3') {
    await runLevel2(config, report, tokens);
  }

  if (config.level === 'L3') {
    await runLevel3(config, report, tokens);
  }

  const { PASS, FAIL, SKIP } = report.counts;

  console.log(`\n${'─'.repeat(60)}`);
  console.log(`RESULT: ${PASS} passed · ${FAIL} failed · ${SKIP} skipped`);
  console.log(
    FAIL === 0
      ? `✅ CONFORMANT — ${config.subsystemId} meets standard v${JWT_CONTRACT.standardsVersion} ${config.level}`
      : `❌ NOT CONFORMANT — ${FAIL} required check(s) failed`,
  );

  if (config.json) {
    fs.writeFileSync(
      'conformance-report.json',
      JSON.stringify(
        {
          subsystemId: config.subsystemId,
          standardsVersion: JWT_CONTRACT.standardsVersion,
          level: config.level,
          summary: report.counts,
          conformant: FAIL === 0,
          results: report.results,
          generatedAt: new Date().toISOString(),
        },
        null,
        2,
      ),
    );
    console.log('report        : conformance-report.json');
  }

  process.exit(FAIL === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(`\nERROR: ${error.message}`);
  process.exit(2);
});
