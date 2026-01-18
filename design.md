### **Main Entry Point: `measureNetwork()`**

This is the **orchestrator**. When JavaScript calls it:

```ts
const measurement = await NetworkQualityModule.measureNetwork({ 
  extended: true, 
  timeoutMs: 3000 
});
```

**What happens in native code:**
1. Detect network type + cellular generation (sync)
2. Call `measureLatency()` (async, ~500ms)
3. Call `measureThroughput()` (async, ~2s)
4. If `extended=true`, call `measurePacketLoss()` (async, ~500ms)
5. Aggregate all data into a `NetworkMeasurement` object
6. Return to JavaScript

**Why async?** The entire measurement takes 2–3 seconds. Can't block the JS thread.

---

### **State Queries (Sync Methods)**

These are **instant** and cache-safe:

```ts
// Get connectivity status (no measurement)
const { isConnected, networkType } = NetworkQualityModule.getConnectivityStatus();

// Get last measurement (if it exists)
const last = NetworkQualityModule.getLastMeasurement();
```

**Why sync?** They query OS APIs that return immediately. No network I/O.

---

### **Sub-Measurements (Advanced API)**

If an app needs **fine-grained control**, they can call individual measurements:

```ts
// Just measure latency
const { latencyMs, jitterMs } = await NetworkQualityModule.measureLatency({
  sampleCount: 3,
  timeoutMs: 500
});

// Just measure throughput
const mbps = await NetworkQualityModule.measureThroughput({
  durationMs: 2000,
  timeoutMs: 5000
});

// Just measure packet loss
const lossPercent = await NetworkQualityModule.measurePacketLoss({
  attemptCount: 10,
  timeoutMs: 500
});
```

**Why expose these?** Advanced users might want custom scoring logic, or only care about one metric.

---

### **Key Design Decisions**

| Decision | Rationale |
|----------|-----------|
| **`measureNetwork()` is the primary API** | Simpler for 99% of users; native code handles orchestration |
| **Sub-measurements are exposed** | Power users can build custom scoring or measure only what they need |
| **All times in milliseconds** | Standard JS unit; no surprises |
| **All throughput in Mbps** | Human-readable; matches what users see in speed tests |
| **Packet loss as percentage** | Easy to reason about (0–100) |
| **Sync methods return instantly** | Safe to call on render; no promise needed |
| **Async methods can timeout** | Prevents hanging if native code fails; returns partial results |

---

### **Platform-Specific Notes**

**Android:**
- Can measure signal generation and network type
- Requires: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `READ_PHONE_STATE`

**iOS:**
- **Cannot** measure cellular or Wi‑Fi RSSI (Apple doesn't expose them)
- Scoring relies on latency + throughput only
- Requires: `NSLocalNetworkUsageDescription`, `NSBonjourServices`