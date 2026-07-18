import http from 'k6/http';
import { check, sleep } from 'k6';

// k6 Load Test Configuration
export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: '10s', target: 10 }, // Ramp up to 10 users
    { duration: '15s', target: 10 }, // Stay at 10 users
    { duration: '5s', target: 0 },   // Ramp down
  ],
  thresholds: {
    // 90% of requests must complete under 500ms (main API SLA)
    http_req_duration: ['p(90)<500', 'p(95)<1000'],
    // Request error rate must be less than 1%
    http_req_failed: ['rate<0.01'],
  },
};

// Target staging API from environment or fallback to local
const BASE_URL = __ENV.API_TARGET_URL || 'http://localhost:8085';

export default function () {
  // Test root gateway endpoint (landing page)
  const resRoot = http.get(`${BASE_URL}/`);
  check(resRoot, {
    'root status is 200': (r) => r.status === 200,
  });

  sleep(0.5);

  // Test gateway health check
  const resHealth = http.get(`${BASE_URL}/health`);
  check(resHealth, {
    'health status is 200': (r) => r.status === 200,
  });

  sleep(0.5);
}
