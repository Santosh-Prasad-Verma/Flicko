import http from 'k6/http';
import { check, sleep } from 'k6';

// =============================================================================
// k6 HTTP load test for the Flicko API gateway.
// =============================================================================
// Fully env-parameterized so the SAME script serves both the lightweight CI
// smoke run and a full 3–5K CCU pre-launch load test — no code edits needed.
//
// Defaults reproduce the original smoke profile (10 VUs), so the existing
// api-load-test.yml scheduled run is unchanged. To drive it to target CCU:
//
//   k6 run scripts/k6-load-test.js \
//     -e API_TARGET_URL=https://staging.flicko... \
//     -e PEAK_VUS=4000 \
//     -e RAMP_UP=3m -e HOLD=10m -e RAMP_DOWN=2m \
//     -e AUTH_TOKEN=eyJ...        # optional: exercises authed /api/v1 paths
//
// !!! Point at a DEDICATED STAGING stack, never production. 4000 VUs hitting
// !!! prod is a self-inflicted DoS. Watch alongside: ws-gateway conn count
// !!! (6000 cap), Redis memory (200MB), and PostgreSQL connection pool ceiling.
// =============================================================================

const BASE_URL = __ENV.API_TARGET_URL || 'http://localhost:8085';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || '';

// Env-driven load shape. Numbers chosen to make the smoke default identical to
// the original script; override via -e for a real capacity test.
const PEAK_VUS = parseInt(__ENV.PEAK_VUS || '10', 10);
const RAMP_UP = __ENV.RAMP_UP || '10s';
const HOLD = __ENV.HOLD || '15s';
const RAMP_DOWN = __ENV.RAMP_DOWN || '5s';

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: RAMP_UP, target: PEAK_VUS },
    { duration: HOLD, target: PEAK_VUS },
    { duration: RAMP_DOWN, target: 0 },
  ],
  thresholds: {
    // 90% of requests must complete under 500ms (main API SLA); 95% under 1s.
    http_req_duration: ['p(90)<500', 'p(95)<1000'],
    // Request error rate threshold for CI smoke run (< 5%).
    http_req_failed: ['rate<0.05'],
  },
};

const authHeaders = AUTH_TOKEN
  ? { headers: { Authorization: `Bearer ${AUTH_TOKEN}` } }
  : {};

export default function () {
  // 1. Root gateway endpoint (landing / liveness).
  const resRoot = http.get(`${BASE_URL}/`);
  check(resRoot, { 'root status is 200': (r) => r.status === 200 });
  sleep(0.5);

  // 2. Gateway health check.
  const resHealth = http.get(`${BASE_URL}/health`);
  check(resHealth, { 'health status is 200': (r) => r.status === 200 });
  sleep(0.5);

  // 3. Authed API path — only when a token is supplied. This exercises the
  //    real protected middleware chain (auth + distributed rate limiter),
  //    which the root/health probes bypass. Without a token we skip it rather
  //    than assert on a 401 (keeps the smoke run clean).
  if (AUTH_TOKEN) {
    const resMe = http.get(`${BASE_URL}/api/v1/users/@me/read_states`, authHeaders);
    check(resMe, {
      'authed read_states is 200/304': (r) => r.status === 200 || r.status === 304,
      'authed path not rate-limited': (r) => r.status !== 429,
    });
    sleep(0.5);
  }
}
