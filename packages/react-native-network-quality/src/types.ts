/**
 * react-native-network-quality/types.ts
 *
 * Complete TypeScript type definitions for the public JavaScript API.
 * This is what users import and use in their apps.
 */

/**
 * The five possible network quality states.
 *
 * - 'offline': No connectivity at all
 * - 'poor': <1 Mbps, high latency (>200ms), or frequent timeouts
 * - 'fair': 1–5 Mbps, moderate latency (100–200ms), occasional failures
 * - 'good': 5–20 Mbps, low latency (<100ms), rare failures
 * - 'excellent': >20 Mbps, very low latency (<50ms), no failures
 *
 * (Thresholds defined in scoring model; see step 5)
 */
export type NetworkQuality = 'offline' | 'poor' | 'fair' | 'good' | 'excellent';

/**
 * The underlying network type.
 * - 'none': Airplane mode or no connectivity
 * - 'wifi': Wi-Fi connection
 * - 'cellular': Cellular (2G–5G)
 * - 'unknown': Could not determine (rare)
 */
export type NetworkType = 'none' | 'wifi' | 'cellular' | 'unknown';

/**
 * Cellular generation (Android only; iOS always 'unknown').
 */
export type CellularGeneration = '2G' | '3G' | '4G' | '5G' | 'unknown';

/**
 * Raw measurement data from the native layer.
 *
 * Used internally to compute the NetworkQuality score.
 * Exposed for advanced use cases (logging, debugging, custom scoring).
 */
export interface NetworkMeasurement {
  /** Timestamp when this measurement was taken (milliseconds since epoch) */
  timestamp: number;

  /** Current network type */
  networkType: NetworkType;

  /** Cellular generation (Android only) */
  cellularGeneration: CellularGeneration;

  /**
   * Wi-Fi signal strength in dBm (Received Signal Strength Indicator).
   * Range: typically -30 (excellent) to -90 (poor).
   * null if not on Wi-Fi or unavailable.
   */
  wifiRssi: number | null;

  /**
   * Cellular signal strength in dBm (Android only).
   * Range: varies by technology (LTE: -140 to -44).
   * null if on Wi-Fi or unavailable.
   */
  cellularRssi: number | null;

  /**
   * Round-trip time (RTT) in milliseconds for a TCP connection.
   * Measured via native socket handshake to a reliable endpoint.
   * null if measurement failed or timed out (>500ms).
   */
  latencyMs: number | null;

  /**
   * Jitter (RTT variance) in milliseconds.
   * Computed as standard deviation of multiple RTT samples.
   * null if <2 samples collected.
   */
  jitterMs: number | null;

  /**
   * Downlink throughput in Mbps.
   * Measured by timing a native download for 1–2 seconds.
   * null if download failed or took 0 bytes.
   */
  downlinkMbps: number | null;

  /**
   * Packet loss approximation as a percentage (0–100).
   * Estimated from timeout rate during measurement.
   * null if cannot be estimated.
   */
  packetLossPercent: number | null;

  /**
   * Whether the device is currently connected to the network.
   * Determined by OS API (not based on successful measurements).
   */
  isConnected: boolean;

  /**
   * Optional: Reason why measurement failed (if quality = 'offline' or partial failure).
   * Useful for debugging.
   */
  failureReason?: string;
}

/**
 * The complete network quality result.
 */
export interface NetworkQualityResult {
  /**
   * The normalized quality estimate: offline | poor | fair | good | excellent
   */
  quality: NetworkQuality;

  /**
   * Raw measurement data used to compute the quality score.
   * Useful for logging, analytics, or custom logic.
   */
  measurement: NetworkMeasurement;
}

/**
 * Options for one-shot measurement.
 */
export interface MeasureOptions {
  /**
   * If true, include extended measurements (jitter, packet loss).
   * This may take slightly longer (~2–3 seconds).
   * Default: true
   */
  extended?: boolean;

  /**
   * Timeout in milliseconds for the entire measurement.
   * If exceeded, returns partial result with available data.
   * Default: 3000 (3 seconds)
   */
  timeoutMs?: number;
}

/**
 * Return type of useNetworkQuality hook.
 */
export interface UseNetworkQualityReturn {
  /**
   * Current network quality estimate (from last measurement).
   * Initially null until first measurement completes.
   */
  quality: NetworkQuality | null;

  /**
   * Full measurement data from the last check.
   * Initially null until first measurement completes.
   */
  measurement: NetworkMeasurement | null;

  /**
   * True while a measurement is in progress.
   * Use to show loading state.
   */
  isLoading: boolean;

  /**
   * Error message if the last measurement failed.
   * null if successful.
   */
  error: string | null;

  /**
   * Manually trigger a measurement right now.
   * Respects the timeout and options from hook initialization.
   * Returns the new result or throws on timeout.
   */
  refresh: () => Promise<NetworkQualityResult>;

  /**
   * Timestamp of the last successful measurement (ms since epoch).
   * null if never measured.
   */
  lastMeasuredAt: number | null;
}

/**
 * Options for useNetworkQuality hook.
 */
export interface UseNetworkQualityOptions {
  /**
   * Whether to measure on app resume (when AppState changes to 'active').
   * Default: true
   */
  measureOnResume?: boolean;

  /**
   * Whether to measure once on hook mount.
   * Default: true
   */
  measureOnMount?: boolean;

  /**
   * Include extended measurements (jitter, packet loss).
   * Default: true
   */
  extended?: boolean;

  /**
   * Timeout for each measurement in milliseconds.
   * Default: 3000
   */
  timeoutMs?: number;

  /**
   * Callback fired when a measurement completes (success or error).
   */
  onMeasure?: (result: NetworkQualityResult | null, error: string | null) => void;
}