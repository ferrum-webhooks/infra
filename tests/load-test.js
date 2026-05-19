import http from 'k6/http';

export const options = {
  vus: 50,
  duration: '60s',
};

export default function () {
  http.post(
    'http://gateway.ferrum.svc.cluster.local:8000/events',
    JSON.stringify({
      payload: { msg: 'stress-test' },
      event_type: 'test'
    }),
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );
}