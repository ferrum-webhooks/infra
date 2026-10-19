// Ingest benchmark for POST /events. One tenant (user + webhook) per slot, tokens created in setup().
//
//   closed model (fixed concurrency, no think time):   k6 run -e MODE=closed -e VUS=50 -e DURATION=30s infra/bench/ingest.js
//   open model   (fixed arrival rate, shows latency under a given load):
//                                                      k6 run -e MODE=open -e RATE=500 -e DURATION=30s infra/bench/ingest.js
// Env: BASE_URL TARGET_URL USERS WARMUP(5s) EVENT_TYPE IDEMPOTENCY(0|1)
// Only requests in the measurement phase are tagged phase:measure (warm-up is excluded from the stats).
import http from 'k6/http';
import { check } from 'k6';

const BASE = __ENV.BASE_URL || 'http://127.0.0.1:8100';
const TARGET = __ENV.TARGET_URL || 'http://127.0.0.1:9000/hook';
const MODE = __ENV.MODE || 'closed';
const DURATION = __ENV.DURATION || '30s';
const WARMUP = __ENV.WARMUP || '5s';
const USERS = parseInt(__ENV.USERS || __ENV.VUS || '50');
const ET = __ENV.EVENT_TYPE || 'bench.event';
const JSON_H = { 'Content-Type': 'application/json' };

function scenario(startTime, duration, phase) {
  if (MODE === 'open') {
    return { executor: 'constant-arrival-rate', rate: parseInt(__ENV.RATE || '500'), timeUnit: '1s', duration,
             startTime, preAllocatedVUs: parseInt(__ENV.VUS || '200'), maxVUs: parseInt(__ENV.MAXVUS || '2000'),
             tags: { phase }, exec: 'ingest' };
  }
  return { executor: 'constant-vus', vus: parseInt(__ENV.VUS || '50'), duration, startTime, tags: { phase }, exec: 'ingest' };
}

function secs(s) { return s.endsWith('s') ? parseInt(s) : parseInt(s) * 60; }

export const options = {
  setupTimeout: '300s',
  scenarios: {
    warmup: scenario('0s', WARMUP, 'warmup'),
    measure: scenario(`${secs(WARMUP) + 1}s`, DURATION, 'measure'),
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  thresholds: { 'http_req_duration{phase:measure}': ['max>=0'], 'http_reqs{phase:measure}': ['count>=0'],
                'http_req_failed{phase:measure}': ['rate>=0'] },
};

export function setup() {
  const tokens = [];
  const tag = `${Date.now()}`;
  for (let i = 0; i < USERS; i++) {
    const email = `bench-${tag}-${i}@example.com`, password = 'bench-password-123';
    http.post(`${BASE}/register`, JSON.stringify({ email, password }), { headers: JSON_H });
    const r = http.post(`${BASE}/login`, JSON.stringify({ email, password }), { headers: JSON_H });
    const t = r.json('access_token');
    http.post(`${BASE}/webhooks`, JSON.stringify({ url: TARGET, event_type: ET }),
              { headers: { ...JSON_H, Authorization: `Bearer ${t}` } });
    tokens.push(t);
  }
  return { tokens };
}

export function ingest(data) {
  const token = data.tokens[(__VU - 1) % data.tokens.length];
  const headers = { ...JSON_H, Authorization: `Bearer ${token}` };
  if (__ENV.IDEMPOTENCY === '1') headers['Idempotency-Key'] = `${__VU}-${__ITER}-${Date.now()}`;
  const r = http.post(`${BASE}/events`, JSON.stringify({ event_type: ET, payload: { vu: __VU, i: __ITER, pad: 'x'.repeat(200) } }),
                      { headers, tags: { name: 'ingest' } });
  check(r, { 'accepted (202)': (res) => res.status === 202 });
}
