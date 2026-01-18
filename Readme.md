# react-native-network-quality

A **cross-platform React Native library** to **estimate real-world network quality**
using **native measurements + lightweight heuristics**, designed for **modern RN apps**
and **New Architecture (TurboModules)**.

> This library does **not** rely on raw ICMP ping or privileged APIs.
> It focuses on **practical, privacy-safe network quality signals** that apps can
> actually use in production.

---

## Installation

```bash
npm install react-native-network-quality
# or
yarn add react-native-network-quality
```

## Usage

```typescript
import { NetworkQualityModule } from 'react-native-network-quality';

// Measure throughput
const throughputMbps = await NetworkQualityModule.measureThroughputSync(
  durationMs: 2000,
  timeoutMs: 5000
);
console.log(`Throughput: ${throughputMbps} Mbps`);

// Measure packet loss
const packetLossPercent = await NetworkQualityModule.measurePacketLossSync(
  attemptCount: 10,
  timeoutMs: 500
);
console.log(`Packet Loss: ${packetLossPercent}%`);

// Get network quality score
const qualityScore = await NetworkQualityModule.calculateNetworkQualityScore(
  throughputMbps: 150,
  packetLossPercent: 0.5
);
console.log(`Quality Score: ${qualityScore}/100`);
```


## Why This Library Exists

Most apps only know:
- `isConnected`
- `wifi` vs `cellular`

That’s **not enough** for:
- Video streaming
- Infinite feeds
- Chat / real-time updates
- Background sync
- Adaptive UI / QoS

**`react-native-network-quality` answers:**
> *Is this network good enough for what my app is about to do?*

---

## What This Library Measures

This package **estimates network quality**, not just connectivity.

### Core Signals

| Signal | How | Platform |
|------|----|---------|
| Network type | OS APIs | iOS / Android |
| Cellular generation | OS APIs | iOS / Android |
| Latency (RTT) | TCP connect timing | iOS / Android |
| Jitter | RTT variance | iOS / Android |
| Download speed | Timed native download | iOS / Android |
| Packet loss (approx) | Timeout & failure rate | iOS / Android |

> ⚠️ Packet loss & jitter are **approximations**, not raw packet inspection.

---

## What This Library Does **NOT** Do

This is intentional and by design.

❌ No ICMP ping  
❌ No raw packet sniffing  
❌ No private or restricted APIs  
❌ No App Store–violating behavior  
❌ No continuous background polling  

> iOS does **not** expose cellular or Wi‑Fi RSSI — this library does not use them.

---

## How It Works

Native Layer (TurboModule)
├─ TCP handshake timing
├─ Native download timing
├─ Failure tracking
↓
JSI (sync, low overhead)
↓
Quality heuristics
↓
Single Network Quality Score


The result is a **fast, battery-safe**, and **privacy-compliant** estimate of
network conditions.

---

## Network Quality Levels

The library converts raw signals into **actionable tiers**:

```ts
type NetworkQuality =
  | 'offline'
  | 'poor'
  | 'fair'
  | 'good'
  | 'excellent';
```

## Example use cases

- Disable autoplay on poor

- Load low-res images on fair

- Enable video streaming on good

- Allow background sync on excellent

## Platform Differences (Important)
### Android

- More accurate radio data

- Best overall quality estimation

### iOS

- No cellular or Wi‑Fi RSSI (Apple restriction)

- Quality derived from RTT & throughput only

- This library normalizes output so your app logic stays consistent.

## Performance & Battery

- No polling by default

- No background loops

- Native timing (not JS timers)

- Designed for on-demand checks
 
- You control when and how often measurements run.

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit PRs to our GitHub repository.

## License

React native network quality is licensed under The MIT License.

## Support

For issues, questions, or suggestions, please open an issue on [GitHub](https://github.com/anshulkahar2729/react-native-network-quality/issues).
