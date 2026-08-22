# Load & Stress Testing

> **Reading time:** ~5 minutes · **Audience:** DevOps · **Last Updated:** 2026-04-11

To ensure the single-VPS architecture thesis is valid, we must periodically simulate thousands of concurrent connections. Flicko uses **k6** by Grafana for distributed load testing.

---

## The Testing Paradigm

We specifically target the two distinct choke points in the architecture:
1. `msg-service`: CPU and PostgreSQL bound (Raw HTTP throughput).
2. `ws-gateway`: RAM bound (Long-lived TCP connections).

---

## 1. HTTP Stress Test (`msg-service`)

This test blasts empty POST requests at the `/messages` endpoint to saturate the Batch Insertion Engine and measure the DLQ (Dead Letter Queue) failure rate.

```javascript
// k6/message-throughput.js
import http from 'k6/http';
import { check } from 'k6';

export let options = {
    vus: 500, // 500 simultaneous virtual users
    duration: '30s', // Sustained for 30 seconds
};

export default function () {
    const payload = JSON.stringify({ content: "Load test string..." });
    const params = {
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${__ENV.JWT_TEST}` },
    };

    let res = http.post('http://api.target.com/api/v1/channels/test-uuid/messages', payload, params);
    
    // Expect 201 Created or 429 Rate Limited. 500 is a failure.
    check(res, {
        'status is 201 or 429': (r) => r.status === 201 || r.status === 429,
        'status is NOT 500': (r) => r.status !== 500,
    });
}
```

---

## 2. WebSocket Concurrent Array (`ws-gateway`)

This is the more difficult test. We spin up thousands of WebSocket connections to ensure the gateway doesn't OOM (Out Of Memory) crash.

```javascript
// k6/ws-connections.js
import ws from 'k6/ws';
import { check } from 'k6';

export let options = {
    // Ramp up to 10k connections over 20 seconds, hold for 1 minute
    stages: [
        { duration: '20s', target: 10000 },
        { duration: '1m', target: 10000 },
        { duration: '10s', target: 0 },
    ],
};

export default function () {
    const url = `wss://api.target.com/api/v1/ws`;
    
    ws.connect(url, {}, function (socket) {
        socket.on('open', function() {   
            // Execute Identity Handshake
            socket.send(JSON.stringify({ op: "Identify", data: { token: __ENV.JWT_TEST } }));
        });
        
        socket.on('message', function(msg) {
            // Assert we are receiving standard echo events
        });

        socket.setInterval(function timeout() {
            socket.send(JSON.stringify({ op: "Heartbeat" }));
        }, 25000); // Pulse every 25s
    });
}
```

---

## Safe Execution

**Never** run these scripts against Production (`api.flicko.app`). You will heavily skew usage metrics, cost us egress bandwidth fees, and potentially disrupt live users.

Instead, execute the `docker-compose.prod.yml` locally or on a staging VPS, and point the k6 binaries at the staging IP address. 
Monitor the Grafana dashboards during the execution to observe the memory curve. We expect `ws-gateway` to consume roughly ~50kb of RAM per idle WebSocket connection.
