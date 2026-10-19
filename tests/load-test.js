import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

// A single tenant is limited to ~50 events/s (RATE_LIMIT_REFILL_PER_SEC). VUs have no think-time, so a
// few early VUs can exceed that: the limiter answers 429, which is correct behaviour, not a failure.
const throttled = new Counter('throttled_429');

export const options = {
  vus: 50,
  duration: __ENV.DURATION || '60s',
  // (auth 429s are expected back-pressure and count as failed requests; judge ingest by the `accepted` check)
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<200'],   // SRS: p95 < 200ms on ingest
  },
};

const BASE = __ENV.BASE_URL || 'http://gateway.ferrum.svc.cluster.local:8000';
const TARGET = __ENV.TARGET_URL || 'https://webhook.site/your-id';
const JSON_H = { 'Content-Type': 'application/json' };

// Every VU is its own tenant: ingest is rate limited per user, and this also exercises isolation.
// /register and /login are per-IP rate limited (every VU shares the k6 pod's IP): back off on 429.
function post(url, body, params) {
  for (let i = 0; i < 20; i++) {
    const r = http.post(url, body, params);
    if (r.status !== 429) return r;
    sleep(Number(r.headers['Retry-After'] || 1));
  }
  return http.post(url, body, params);
}

let token;
function login() {
  const email = `k6-${__VU}-${Date.now()}@example.com`;
  const password = 'k6-load-test-password';
  post(`${BASE}/register`, JSON.stringify({ email, password }), { headers: JSON_H });
  const r = post(`${BASE}/login`, JSON.stringify({ email, password }), { headers: JSON_H });
  token = r.status === 200 ? r.json('access_token') : null;
  http.post(`${BASE}/webhooks`, JSON.stringify({ url: TARGET, event_type: 'test' }),
    { headers: { ...JSON_H, Authorization: `Bearer ${token}` } });
}

export default function () {
  if (!token) login();
  if (!token) { sleep(1); return; }   // login was rate limited; try again next iteration
  const r = http.post(`${BASE}/events`,
    JSON.stringify({ payload: { msg: 'stress-test' }, event_type: 'test' }),
    { headers: { ...JSON_H, Authorization: `Bearer ${token}`,
                 'Idempotency-Key': `${__VU}-${__ITER}` } });
  if (r.status === 429) { throttled.add(1); sleep(Number(r.headers['Retry-After'] || 1)); return; }
  check(r, { 'accepted': (res) => res.status === 202 });
}
