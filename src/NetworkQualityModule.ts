/**
 * react-native-network-quality/src/NetworkQualityModule.ts
 *
 * TurboModule interface specification.
 *
 * This defines the contract between JavaScript and native code (iOS/Android).
 * Native implementations MUST satisfy this interface.
 *
 * Exported as `NativeModules.NetworkQualityModule` on both platforms.
 */

import type {
  NetworkMeasurement,
  // TODO: Remove this once we have a proper result type
  NetworkQualityResult,
  MeasureOptions,
} from "./types";

/**
 * TurboModule for network quality measurement.
 *
 * Design philosophy:
 * - Heavy lifting happens in native code (no JS overhead)
 * - Measurement is async (don't block JS thread)
 * - State queries are sync (instant, cached results)
 * - All numeric values normalized to standard units (ms, Mbps, dBm, %)
 */
export interface NetworkQualityModule {
  /**
   * ASYNC: Perform a full network quality measurement.
   *
   * This is the main entry point. Triggers:
   * 1. Network type detection (WiFi / cellular / none)
   * 2. Signal strength queries (RSSI)
   * 3. TCP handshake timing (latency + jitter if extended=true)
   * 4. Download throughput test (1–2 seconds)
   * 5. Packet loss approximation (if extended=true)
   *
   * @param options Optional: { extended?, timeoutMs? }
   *   - extended: boolean (default: true)
   *     Include jitter and packet loss measurements.
   *     Adds ~500ms to measurement time.
   *   - timeoutMs: number (default: 3000)
   *     Abort entire measurement if it exceeds this duration.
   *     Returns partial result with available data.
   *
   * @returns Promise<NetworkMeasurement>
   *   Complete measurement data (see types.ts for fields).
   *   Resolves even if some fields are null (e.g., on offline).
   *
   * @throws Error
   *   Only thrown if:
   *   - timeoutMs exceeded (measurement took too long)
   *   - Unrecoverable native error (very rare)
   *   Partial measurements (e.g., latency failed but throughput succeeded)
   *   DO NOT throw; instead return with null fields.
   *
   * Platform notes:
   * - Android: Full signal strength available
   * - iOS: Cellular RSSI unavailable (Apple restriction)
   *
   * Battery impact:
   * - One measurement: ~2–3 seconds of sustained native work
   * - Call sparingly; do not call in loops or on every render
   *
   * Example:
   *   const measurement = await NetworkQualityModule.measureNetwork({
   *     extended: true,
   *     timeoutMs: 3000
   *   });
   */
  measureNetwork(options?: MeasureOptions): Promise<NetworkMeasurement>;

  /**
   * SYNC: Retrieve the last successful measurement.
   *
   * Returns cached result from the most recent call to measureNetwork().
   * Useful for querying state without triggering a new measurement.
   *
   * @returns NetworkMeasurement | null
   *   Last measurement if one exists, null if never measured.
   *   Timestamp field indicates staleness.
   *
   * Performance:
   * - Instant (no I/O, no native work)
   * - Safe to call on every render
   *
   * Use case:
   *   const last = NetworkQualityModule.getLastMeasurement();
   *   if (last && Date.now() - last.timestamp < 5000) {
   *     // Data is fresh, use it
   *   } else {
   *     // Data is stale, trigger new measurement
   *   }
   */
  getLastMeasurement(): NetworkMeasurement | null;

  /**
   * SYNC: Check current connectivity status (without full measurement).
   *
   * Returns only:
   * - isConnected: boolean
   * - networkType: NetworkType
   * - cellularGeneration: CellularGeneration (Android only)
   *
   * This is a lightweight check using OS APIs only.
   * Does NOT measure latency, throughput, or signal strength.
   *
   * @returns { isConnected: boolean; networkType: NetworkType; cellularGeneration: CellularGeneration }
   *
   * Performance:
   * - Very fast (milliseconds)
   * - Safe to call frequently
   *
   * Use case:
   *   if (NetworkQualityModule.getConnectivityStatus().isConnected) {
   *     // Device has network access, safe to make requests
   *   }
   */
  getConnectivityStatus(): {
    isConnected: boolean;
    networkType: "none" | "wifi" | "cellular" | "unknown";
    cellularGeneration: "2G" | "3G" | "4G" | "5G" | "unknown";
  };

  /**
   * SYNC: Get the current Wi-Fi signal strength (dBm).
   *
   * Queries OS API for Wi-Fi RSSI only.
   * Returns null if not on Wi-Fi or unavailable.
   *
   * @returns number | null
   *   RSSI in dBm. Typical range: -30 (excellent) to -90 (poor).
   *   null if not on Wi-Fi.
   *
   * Performance: Instant (OS API call)
   *
   * Platform notes:
   * - iOS: Requires network change notification permission (iOS 14.1+)
   * - Android: Requires ACCESS_WIFI_STATE permission
   *
   * Use case:
   *   const rssi = NetworkQualityModule.getWifiRssi();
   *   if (rssi && rssi < -80) {
   *     // Weak Wi-Fi signal, show warning
   *   }
   */
  getWifiRssi(): number | null;

  /**
   * SYNC: Get the current cellular signal strength (dBm).
   *
   * Android only. Returns null on iOS or if not on cellular.
   *
   * @returns number | null
   *   Signal strength in dBm. Range varies by technology:
   *   - LTE: -140 to -44 (lower = worse)
   *   - 5G NR: -170 to -44
   *   null if on Wi-Fi or unavailable.
   *
   * Performance: Instant (OS API call)
   *
   * Platform notes:
   * - iOS: Always returns null (Apple does not expose this)
   * - Android: Requires READ_PHONE_STATE permission
   *
   * Use case:
   *   const rssi = NetworkQualityModule.getCellularRssi();
   *   if (rssi === null) {
   *     // Not on cellular, or platform doesn't support it
   *   }
   */
  getCellularRssi(): number | null;

  /**
   * ASYNC: Measure round-trip time (latency) via TCP handshake.
   *
   * Connects to a reliable endpoint (e.g., 1.1.1.1:443) and times the
   * socket connection. Measures application-layer latency, not raw ICMP.
   *
   * @param options Optional: { sampleCount?, timeoutMs? }
   *   - sampleCount: number (default: 3)
   *     Number of RTT samples to collect (for jitter calculation)
   *   - timeoutMs: number (default: 500)
   *     Timeout per sample
   *
   * @returns Promise<{ latencyMs: number | null; jitterMs: number | null }>
   *   - latencyMs: Average RTT in milliseconds (null if all samples failed)
   *   - jitterMs: Standard deviation of samples (null if <2 samples)
   *
   * Endpoint selection:
   * - Use a fast, reliable public endpoint (e.g., Cloudflare DNS: 1.1.1.1:443)
   * - Avoid endpoints that may be blocked in some regions
   * - Consider latency to endpoint (adds to measured value)
   *
   * Notes:
   * - This is NOT raw ICMP ping (compliant with App Store)
   * - Measures TCP + TLS handshake time (realistic for app traffic)
   * - Single call is fast (~500ms for 3 samples)
   *
   * Use case:
   *   const { latencyMs, jitterMs } = await NetworkQualityModule.measureLatency({
   *     sampleCount: 3,
   *     timeoutMs: 500
   *   });
   */
  measureLatency(options?: {
    sampleCount?: number;
    timeoutMs?: number;
  }): Promise<{
    latencyMs: number | null;
    jitterMs: number | null;
  }>;

  /**
   * ASYNC: Measure downlink throughput via timed download.
   *
   * Downloads data from a reliable endpoint for a fixed duration (1–2 seconds).
   * Calculates throughput = bytes received / time elapsed.
   *
   * @param options Optional: { durationMs?, timeoutMs? }
   *   - durationMs: number (default: 2000)
   *     How long to download for (in milliseconds)
   *   - timeoutMs: number (default: 5000)
   *     Timeout for the entire download attempt
   *
   * @returns Promise<number | null>
   *   Throughput in Mbps. null if download failed or returned 0 bytes.
   *
   * Server selection:
   * - Use a CDN endpoint geographically close to users
   * - Serve large (>100MB) binary file to avoid caching issues
   * - Measure actual app-layer throughput
   *
   * Example endpoint:
   *   https://speed.cloudflare.com/__down?bytes=1000000000
   *   (or your own CDN endpoint)
   *
   * Notes:
   * - Respects device data saver modes (if enabled)
   * - Does NOT use VPN bypass (compliant with App Store)
   * - Real-world throughput (includes TCP overhead, not raw bandwidth)
   *
   * Use case:
   *   const mbps = await NetworkQualityModule.measureThroughput({
   *     durationMs: 2000,
   *     timeoutMs: 5000
   *   });
   */
  measureThroughput(options?: {
    durationMs?: number;
    timeoutMs?: number;
  }): Promise<number | null>;

  /**
   * ASYNC: Estimate packet loss via connection failures.
   *
   * Attempts multiple small connections (e.g., 10 requests) and counts failures.
   * Packet loss % = (failures / attempts) * 100.
   *
   * @param options Optional: { attemptCount?, timeoutMs? }
   *   - attemptCount: number (default: 10)
   *     Number of requests to attempt
   *   - timeoutMs: number (default: 500 per attempt)
   *     Timeout per request
   *
   * @returns Promise<number | null>
   *   Packet loss as percentage (0–100). null if cannot estimate.
   *
   * Notes:
   * - This is an approximation (counts HTTP timeouts, not raw packet loss)
   * - Real packet loss may differ if timeouts are due to server latency
   * - Lightweight (small HTTP requests, not large downloads)
   *
   * Use case:
   *   const lossPercent = await NetworkQualityModule.measurePacketLoss({
   *     attemptCount: 10,
   *     timeoutMs: 500
   *   });
   */
  measurePacketLoss(options?: {
    attemptCount?: number;
    timeoutMs?: number;
  }): Promise<number | null>;
}

/**
 * How the TurboModule is Used in JavaScript
 * ==========================================
 *
 * 1. IMPORT:
 *    import { NativeModules } from 'react-native';
 *    const NetworkQualityModule = NativeModules.NetworkQualityModule;
 *
 * 2. FULL MEASUREMENT (most common):
 *    const measurement = await NetworkQualityModule.measureNetwork({
 *      extended: true,
 *      timeoutMs: 3000
 *    });
 *
 * 3. QUICK CONNECTIVITY CHECK:
 *    const status = NetworkQualityModule.getConnectivityStatus();
 *    if (status.isConnected) { ... }
 *
 * 4. INDIVIDUAL MEASUREMENTS (advanced):
 *    const { latencyMs } = await NetworkQualityModule.measureLatency();
 *    const mbps = await NetworkQualityModule.measureThroughput();
 *    const loss = await NetworkQualityModule.measurePacketLoss();
 *
 * 5. STATE QUERIES (no performance impact):
 *    const last = NetworkQualityModule.getLastMeasurement();
 *    const rssi = NetworkQualityModule.getWifiRssi();
 *    const cellRssi = NetworkQualityModule.getCellularRssi();
 */

/**
 * Implementation Checklist (for native developers)
 * ================================================
 *
 * ANDROID (Kotlin):
 * - [ ] measureNetwork() orchestrates all sub-measurements
 * - [ ] getConnectivityStatus() queries ConnectivityManager
 * - [ ] getWifiRssi() queries WifiManager
 * - [ ] getCellularRssi() queries TelephonyManager
 * - [ ] measureLatency() implements TCP handshake timing (3 samples)
 * - [ ] measureThroughput() times binary download (2 sec default)
 * - [ ] measurePacketLoss() counts HTTP timeout failures (10 attempts)
 * - [ ] All times normalized to milliseconds
 * - [ ] All signal strengths normalized to dBm
 * - [ ] All throughputs normalized to Mbps
 * - [ ] Permissions: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, READ_PHONE_STATE
 *
 * iOS (Swift):
 * - [ ] measureNetwork() orchestrates all sub-measurements
 * - [ ] getConnectivityStatus() queries NEHotspotNetwork or NWPathMonitor
 * - [ ] getWifiRssi() queries NEHotspotNetwork.fetchCurrent() (iOS 14.1+)
 * - [ ] getCellularRssi() returns null (Apple restriction)
 * - [ ] measureLatency() implements TCP handshake timing (3 samples)
 * - [ ] measureThroughput() times binary download (2 sec default)
 * - [ ] measurePacketLoss() counts HTTP timeout failures (10 attempts)
 * - [ ] All times normalized to milliseconds
 * - [ ] All signal strengths normalized to dBm
 * - [ ] All throughputs normalized to Mbps
 * - [ ] Permissions: NSLocalNetworkUsageDescription, NSBonjourServices
 */
