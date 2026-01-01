# react-native-network-quality

A **cross-platform React Native library** to **estimate real-world network quality**
using **native measurements + lightweight heuristics**, designed for **modern RN apps**
and **New Architecture (TurboModules)**.

> This library does **not** rely on raw ICMP ping or privileged APIs.
> It focuses on **practical, privacy-safe network quality signals** that apps can
> actually use in production.

---

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
| Wi-Fi RSSI | Native APIs | iOS / Android |
| Cellular signal strength | Native APIs | Android only |
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

> iOS does **not** expose cellular RSSI — this library respects that.

---

## How It Works

Native Layer (TurboModule)
├─ Signal strength (Android)
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

- Full signal strength access

- More accurate radio data

- Best overall quality estimation

### iOS

- No cellular RSSI (Apple restriction)

- Wi-Fi RSSI only (limited)

- Quality derived mainly from RTT & throughput

- This library normalizes output so your app logic stays consistent.

## Performance & Battery

- No polling by default

- No background loops

- Native timing (not JS timers)

- Designed for on-demand checks
 
- You control when and how often measurements run.