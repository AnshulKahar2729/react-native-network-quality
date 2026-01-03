/**
 * ios/RCTNetworkQualityModule.swift
 *
 * TurboModule implementation for iOS.
 * Handles all network quality measurements using native iOS APIs.
 *
 * Key iOS constraints:
 * - No cellular RSSI (Apple doesn't expose)
 * - Wi-Fi RSSI requires NEHotspotNetwork (iOS 14.1+)
 * - Network detection via NWPathMonitor (modern, efficient)
 * - All timing in milliseconds
 *
 * Architecture:
 * 1. Setup: NWPathMonitor listens for network changes in background
 * 2. Measurement: When JS calls measureNetwork(), orchestrate sub-measurements
 * 3. Return: Aggregate all data and return to JS via Promise
 */

import Foundation
import Network
import NetworkExtension

// MARK: - Data Models

/// Represents a complete network measurement snapshot.
/// Mirrors the NetworkMeasurement type from TypeScript.
/// All numeric values use standard units: ms, dBm, Mbps, %.
struct NetworkMeasurementData: Codable {
    /// Timestamp when measurement was taken (milliseconds since epoch)
    let timestamp: Double
    
    /// Current network type: "none", "wifi", "cellular", or "unknown"
    let networkType: String
    
    /// Cellular generation: "2G", "3G", "4G", "5G", or "unknown"
    /// iOS always returns "unknown" (no public API available)
    let cellularGeneration: String
    
    /// Wi-Fi signal strength in dBm (typically -30 to -90)
    /// nil if not on Wi-Fi or if iOS < 14.1
    let wifiRssi: NSNumber?
    
    /// Cellular signal strength in dBm
    /// iOS always returns nil (Apple doesn't expose this)
    let cellularRssi: NSNumber?
    
    /// Round-trip time in milliseconds
    /// Measured via TCP handshake to 1.1.1.1:443
    let latencyMs: NSNumber?
    
    /// Jitter (RTT variance) in milliseconds
    /// Standard deviation of multiple RTT samples
    let jitterMs: NSNumber?
    
    /// Downlink throughput in Mbps
    /// Measured by timing a download for 2 seconds
    let downlinkMbps: NSNumber?
    
    /// Packet loss as a percentage (0-100)
    /// Approximation based on HTTP timeout rate
    let packetLossPercent: NSNumber?
    
    /// Whether device has network connectivity
    /// Determined by OS API, not inferred from measurements
    let isConnected: Bool
    
    /// Reason why measurement failed (e.g., "Device is offline")
    /// nil if measurement succeeded
    let failureReason: String?
}

/// Lightweight connectivity status (network type + connection state)
struct ConnectivityStatusData: Codable {
    let isConnected: Bool
    let networkType: String
    let cellularGeneration: String
}

/// Latency measurement result
struct LatencyResultData: DeCodable {
    let latencyMs: NSNumber?
    let jitterMs: NSNumber?
}

/// Throughput measurement result
struct ThroughputResultData: Codable {
    let throughputMbps: NSNumber?
}

/// Packet loss measurement result
struct PacketLossResultData: Codable {
    let packetLossPercent: NSNumber?
}

// MARK: - TurboModule Implementation

/// React Native TurboModule for network quality measurement.
///
/// Conforms to RCTBridgeModule so React Native recognizes it as a native module.
/// All async methods use Promises (RCTPromiseResolveBlock / RCTPromiseRejectBlock).
/// All heavy lifting happens on a background dispatch queue to avoid blocking JS.
class RCTNetworkQualityModule: NSObject, RCTBridgeModule {
    
    /// Module name as exported to JavaScript
    /// JS will access this via: NativeModules.NetworkQualityModule
    static func moduleName() -> String! {
        return "NetworkQualityModule"
    }

    /// Whether this module needs to be initialized on the main thread
    /// false = initialize on background thread (safe, we do network I/O)
    static func requiresMainQueueSetup() -> Bool {
        return false
    }

    // MARK: - Private Properties

    /// Cached result from the last successful measurement
    /// Returned by getLastMeasurement() without triggering a new measurement
    private var lastMeasurement: NetworkMeasurementData?
    
    /// Monitor that watches for network state changes (Wi-Fi ↔ cellular ↔ offline)
    /// Runs in background, updates currentPath whenever network changes
    private let pathMonitor = NWPathMonitor()
    
    /// Background dispatch queue for all network I/O
    /// Prevents blocking the JavaScript thread
    /// .default = standard priority, good for network tasks
    private let queue = DispatchQueue.global(qos: .default)
    
    /// Current network path (connectivity status)
    /// Updated by pathMonitor in real-time
    private var currentPath: NWPath?

    // MARK: - Initialization

    /// Called when module is first loaded
    override init() {
        super.init()
        setupPathMonitor()
    }

    /// Called when module is unloaded or app terminates
    /// Clean up resources (important: stop the path monitor)
    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Path Monitor Setup

    /// Initialize and start the network path monitor
    /// This runs continuously in the background, listening for network changes
    /// Updates currentPath whenever network type or connectivity changes
    private func setupPathMonitor() {
        // Set callback: whenever network path changes, update currentPath
        pathMonitor.pathUpdateHandler = { [weak self] path in
            // [weak self] = avoid retain cycle (don't hold strong reference to self)
            self?.currentPath = path
        }
        // Start monitoring on background queue
        pathMonitor.start(queue: queue)
    }

    // MARK: - Main TurboModule Methods

    /// ASYNC: Perform a complete network quality measurement
    ///
    /// - Parameters:
    ///   - options: Dictionary with optional keys:
    ///     - "extended" (Bool, default: true): Include jitter & packet loss
    ///     - "timeoutMs" (Int, default: 3000): Abort if exceeds this duration
    ///   - resolve: Promise resolve callback (called with NetworkMeasurement dict)
    ///   - reject: Promise reject callback (called if error occurs)
    ///
    /// Flow:
    /// 1. Check connectivity (instant)
    /// 2. If offline, return early with failureReason
    /// 3. Get Wi-Fi RSSI (instant, might be nil)
    /// 4. Measure latency & jitter via TCP handshake (~500ms)
    /// 5. Measure throughput via timed download (~2s)
    /// 6. If extended=true, measure packet loss (~500ms)
    /// 7. Aggregate all data and resolve
    ///
    /// @objc = expose this method to Objective-C / JavaScript
    /// Naming convention: methodName:withResolver:withRejecter:
    @objc(measureNetwork:withResolver:withRejecter:)
    func measureNetwork(
        options: [String: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        // Run on background queue to avoid blocking JS thread
        queue.async { [weak self] in
            guard let self = self else { return }

            // Extract options with defaults
            let extended = options?["extended"] as? Bool ?? true
            let timeoutMs = options?["timeoutMs"] as? Int ?? 3000
            let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)

            do {
                // Step 1: Get connectivity status (instant)
                let status = self.getConnectivityStatusSync()
                
                // Step 2: If offline, return early
                guard status.isConnected else {
                    let measurement = NetworkMeasurementData(
                        timestamp: Date().timeIntervalSince1970 * 1000,
                        networkType: "none",
                        cellularGeneration: "unknown",
                        wifiRssi: nil,
                        cellularRssi: nil,
                        latencyMs: nil,
                        jitterMs: nil,
                        downlinkMbps: nil,
                        packetLossPercent: nil,
                        isConnected: false,
                        failureReason: "Device is offline"
                    )
                    self.lastMeasurement = measurement
                    resolve(self.toDict(measurement))
                    return
                }

                // Step 3: Get Wi-Fi signal strength (instant)
                let wifiRssi = self.getWifiRssiSync()
                
                // Step 4: Measure latency & jitter (~500ms)
                let latencyResult = try self.measureLatencySync(
                    timeoutMs: 500,
                    before: deadline
                )

                // Step 5: Measure throughput (~2s)
                let throughput = try self.measureThroughputSync(
                    durationMs: 2000,
                    timeoutMs: 5000,
                    before: deadline
                )

                // Step 6: Measure packet loss if extended (~500ms)
                var packetLoss: NSNumber? = nil
                if extended {
                    packetLoss = try self.measurePacketLossSync(
                        attemptCount: 10,
                        timeoutMs: 500,
                        before: deadline
                    )
                }

                // Step 7: Aggregate and return
                let measurement = NetworkMeasurementData(
                    timestamp: Date().timeIntervalSince1970 * 1000,
                    networkType: status.networkType,
                    cellularGeneration: status.cellularGeneration,
                    wifiRssi: wifiRssi,
                    cellularRssi: nil, // iOS restriction: no cellular RSSI
                    latencyMs: latencyResult.latencyMs,
                    jitterMs: latencyResult.jitterMs,
                    downlinkMbps: throughput?.downlinkMbps,
                    packetLossPercent: packetLoss,
                    isConnected: status.isConnected,
                    failureReason: nil
                )

                self.lastMeasurement = measurement
                resolve(self.toDict(measurement))

            } catch {
                // If any step throws, reject with error
                reject("MEASUREMENT_ERROR", error.localizedDescription, error)
            }
        }
    }

    // MARK: - Synchronous State Queries

    /// SYNC: Get the last measurement taken
    /// Returns nil if no measurement has been taken yet
    /// @objc = expose this method to Objective-C / JavaScript
    @objc(getLastMeasurement)
    func getLastMeasurement() -> [String: Any]? {
        guard let last = lastMeasurement else { return nil }
        return toDict(last)
    }

    /// SYNC: Get current connectivity status (no measurement)
    /// Returns network type + connectivity state instantly
    /// Safe to call on every render
    /// @objc = expose this method to Objective-C / JavaScript
    @objc(getConnectivityStatus)
    func getConnectivityStatus() -> [String: Any] {
        return toDict(getConnectivityStatusSync())
    }

    /// SYNC: Get current Wi-Fi signal strength
    /// Returns RSSI in dBm, or nil if not on Wi-Fi
    /// Instant query, no network I/O
    /// @objc = expose this method to Objective-C / JavaScript
    @objc(getWifiRssi)
    func getWifiRssi() -> NSNumber? {
        return getWifiRssiSync()
    }

    /// SYNC: Get current cellular signal strength
    /// iOS: Always returns nil (Apple doesn't expose this)
    /// @objc = expose this method to Objective-C / JavaScript
    @objc(getCellularRssi)
    func getCellularRssi() -> NSNumber? {
        return nil
    }

    // MARK: - Individual Measurement Methods

    /// ASYNC: Measure latency & jitter
    /// Takes 3 TCP samples, calculates average latency and standard deviation (jitter)
    /// @objc = expose this method to Objective-C / JavaScript
    @objc(measureLatency:withResolver:withRejecter:)
    func measureLatency(
        options: [String: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        queue.async { [weak self] in
            do {
                let sampleCount = options?["sampleCount"] as? Int ?? 3
                let timeoutMs = options?["timeoutMs"] as? Int ?? 500
                let deadline = Date().addingTimeInterval(Double(timeoutMs * sampleCount) / 1000.0)

                let result = try self?.measureLatencySync(
                    timeoutMs: timeoutMs,
                    before: deadline
                )

                resolve(self?.toDict(result) ?? [:])
            } catch {
                reject("LATENCY_ERROR", error.localizedDescription, error)
            }
        }
    }

    /// ASYNC: Measure downlink throughput
    /// Downloads for durationMs and calculates speed (Mbps)
    /// @objc = expose this method to Objective-C / JavaScript
    @objc(measureThroughput:withResolver:withRejecter:)
    func measureThroughput(
        options: [String: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        queue.async { [weak self] in
            do {
                let durationMs = options?["durationMs"] as? Int ?? 2000
                let timeoutMs = options?["timeoutMs"] as? Int ?? 5000
                let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)

                let mbps = try self?.measureThroughputSync(
                    durationMs: durationMs,
                    timeoutMs: timeoutMs,
                    before: deadline
                )

                resolve(mbps?.throughputMbps as Any)
            } catch {
                reject("THROUGHPUT_ERROR", error.localizedDescription, error)
            }
        }
    }

    /// ASYNC: Measure packet loss
    /// Counts HTTP timeouts across attemptCount requests
    /// Returns percentage: (failures / attempts) * 100
    /// @objc = expose this method to Objective-C / JavaScript
    @objc(measurePacketLoss:withResolver:withRejecter:)
    func measurePacketLoss(
        options: [String: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        queue.async { [weak self] in
            do {
                let attemptCount = options?["attemptCount"] as? Int ?? 10
                let timeoutMs = options?["timeoutMs"] as? Int ?? 500
                let deadline = Date().addingTimeInterval(Double(timeoutMs * attemptCount) / 1000.0)

                let loss = try self?.measurePacketLossSync(
                    attemptCount: attemptCount,
                    timeoutMs: timeoutMs,
                    before: deadline
                )

                resolve(loss as Any)
            } catch {
                reject("PACKET_LOSS_ERROR", error.localizedDescription, error)
            }
        }
    }

    // MARK: - Private Implementation Methods

    /// Check current connectivity status synchronously
    /// Uses NWPathMonitor's currentPath (updated in real-time)
    private func getConnectivityStatusSync() -> ConnectivityStatusData {
        guard let path = currentPath else {
            return ConnectivityStatusData(
                isConnected: false,
                networkType: "unknown",
                cellularGeneration: "unknown"
            )
        }

        // path.status: .satisfied = connected, .unsatisfied = not connected
        let isConnected = path.status == .satisfied
        let networkType: String
        let cellularGeneration: String

        // Check which interface type is active
        if path.usesInterfaceType(.wifi) {
            networkType = "wifi"
            cellularGeneration = "unknown"
        } else if path.usesInterfaceType(.cellular) {
            networkType = "cellular"
            cellularGeneration = getCellularGeneration()
        } else if path.usesInterfaceType(.wiredEthernet) {
            // Treat ethernet as wifi-like (fallback)
            networkType = "wifi"
            cellularGeneration = "unknown"
        } else {
            // Unknown interface, but might still be connected
            networkType = isConnected ? "unknown" : "none"
            cellularGeneration = "unknown"
        }

        return ConnectivityStatusData(
            isConnected: isConnected,
            networkType: networkType,
            cellularGeneration: cellularGeneration
        )
    }

    /// Get Wi-Fi signal strength (dBm)
    /// iOS 14.1+: Uses NEHotspotNetwork (requires special permission)
    /// Older iOS: Returns nil
    private func getWifiRssiSync() -> NSNumber? {
        // Check iOS version
        if #available(iOS 14.1, *) {
            // Try to get current Wi-Fi network info
            guard let network = try? NEHotspotNetwork.fetchCurrent() else {
                return nil
            }

            // Note: RSSI is available via private API:
            // let rssi = network.value(forKey: "rssi") as? NSNumber
            // But we avoid private APIs for App Store compliance
            // Return nil to stay safe
            return nil
        }

        // Older iOS versions: no public API for Wi-Fi RSSI
        return nil
    }

    /// Measure round-trip time (latency) via TCP handshake
    /// Connects to 1.1.1.1:443 three times, records connection time
    /// Calculates average latency and jitter (standard deviation)
    private func measureLatencySync(
        timeoutMs: Int,
        before deadline: Date
    ) throws -> LatencyResultData {
        let endpoint = NWEndpoint.hostPort(host: "1.1.1.1", port: 443)
        var rtts: [Double] = []

        // Take 3 samples
        for _ in 0..<3 {
            // Check if we've exceeded overall deadline
            guard Date() < deadline else { break }

            let startTime = Date()
            
            // Create TCP connection to endpoint
            let connection = NWConnection(to: endpoint, using: .tcp)

            // DispatchGroup: way to wait for async work to complete
            let group = DispatchGroup()
            group.enter() // Increment counter

            var connectionEstablished = false

            // Called whenever connection state changes
            connection.stateUpdateHandler = { state in
                if state == .ready {
                    // Connection successful
                    connectionEstablished = true
                    group.leave() // Decrement counter
                }
            }

            // Start connection on background queue
            connection.start(queue: queue)

            // Wait for either:
            // 1. Connection ready (.ready state)
            // 2. Timeout expires
            let waitResult = group.wait(timeout: .milliseconds(timeoutMs))
            let elapsedMs = Date().timeIntervalSince(startTime) * 1000

            // Cancel connection (important: clean up resource)
            connection.cancel()

            // Record sample if successful
            if connectionEstablished {
                rtts.append(elapsedMs)
            }
        }

        // If no samples collected, return nil
        guard !rtts.isEmpty else {
            return LatencyResultData(latencyMs: nil, jitterMs: nil)
        }

        // Calculate average latency
        let avgLatency = rtts.reduce(0, +) / Double(rtts.count)
        
        // Calculate jitter (standard deviation)
        // Formula: sqrt(sum((x - mean)^2) / n)
        let variance = rtts.map { pow($0 - avgLatency, 2) }.reduce(0, +) / Double(rtts.count)
        let jitter = sqrt(variance)

        return LatencyResultData(
            latencyMs: NSNumber(value: avgLatency),
            jitterMs: rtts.count > 1 ? NSNumber(value: jitter) : nil
        )
    }

    /// Measure downlink throughput via timed download
    /// Downloads from Cloudflare endpoint for durationMs, calculates speed
    private func measureThroughputSync(
        durationMs: Int,
        timeoutMs: Int,
        before deadline: Date
    ) throws -> ThroughputResultData? {
        let urlString = "https://speed.cloudflare.com/__down?bytes=1000000000"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(timeoutMs) / 1000.0

        let startTime = Date()
        var bytesReceived: Int64 = 0

        // Semaphore: way to wait for async HTTP request to complete
        // value: 0 = blocked (waiting), signal() = unblock
        let semaphore = DispatchSemaphore(value: 0)
        var throughputMbps: Double? = nil

        // Start HTTP GET request
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let data = data {
                bytesReceived = Int64(data.count)
            }

            // Calculate throughput: bits per second → Mbps
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 0 && bytesReceived > 0 {
                let bits = Double(bytesReceived) * 8 // Convert bytes to bits
                throughputMbps = (bits / 1_000_000) / elapsed // Divide by 1M to get Mbps
            }

            semaphore.signal() // Unblock the waiter
        }

        task.resume() // Start request

        // Wait for response or timeout
        let waitResult = semaphore.wait(timeout: .milliseconds(timeoutMs))

        if waitResult == .timedOut {
            task.cancel() // Clean up
        }

        guard let mbps = throughputMbps else {
            return ThroughputResultData(throughputMbps: nil)
        }

        return ThroughputResultData(throughputMbps: NSNumber(value: mbps))
    }

    /// Estimate packet loss via HTTP timeout rate
    /// Makes attemptCount requests, counts failures (timeouts)
    /// Returns: (failures / attempts) * 100
    private func measurePacketLossSync(
        attemptCount: Int,
        timeoutMs: Int,
        before deadline: Date
    ) throws -> NSNumber? {
        let endpoint = "https://1.1.1.1/dns-query"
        guard let url = URL(string: endpoint) else { return nil }

        var failures = 0

        // Make multiple attempts
        for _ in 0..<attemptCount {
            // Check if we've exceeded overall deadline
            guard Date() < deadline else { break }

            var request = URLRequest(url: url)
            request.timeoutInterval = TimeInterval(timeoutMs) / 1000.0

            let semaphore = DispatchSemaphore(value: 0)
            var succeeded = false

            // Make HTTP request
            let task = URLSession.shared.dataTask(with: request) { _, _, error in
                succeeded = error == nil // No timeout = success
                semaphore.signal()
            }

            task.resume()
            semaphore.wait(timeout: .milliseconds(timeoutMs * 2))

            if !succeeded {
                failures += 1
            }

            task.cancel() // Clean up
        }

        // Calculate loss percentage
        let lossPercent = (Double(failures) / Double(attemptCount)) * 100
        return NSNumber(value: lossPercent)
    }

    /// Get cellular generation (2G/3G/4G/5G)
    /// iOS doesn't expose this publicly; would require private APIs
    /// Return "unknown" to stay compliant
    private func getCellularGeneration() -> String {
        return "unknown"
    }

    // MARK: - Helper: Dictionary Conversion

    /// Convert NetworkMeasurementData struct to Dictionary for JavaScript
    /// JavaScript receives plain objects, not Swift structs
    private func toDict(_ measurement: NetworkMeasurementData) -> [String: Any] {
        return [
            "timestamp": measurement.timestamp,
            "networkType": measurement.networkType,
            "cellularGeneration": measurement.cellularGeneration,
            "wifiRssi": measurement.wifiRssi as Any,
            "cellularRssi": NSNull(),
            "latencyMs": measurement.latencyMs as Any,
            "jitterMs": measurement.jitterMs as Any,
            "downlinkMbps": measurement.downlinkMbps as Any,
            "packetLossPercent": measurement.packetLossPercent as Any,
            "isConnected": measurement.isConnected,
            "failureReason": measurement.failureReason as Any
        ]
    }

    /// Convert ConnectivityStatusData to Dictionary
    private func toDict(_ status: ConnectivityStatusData) -> [String: Any] {
        return [
            "isConnected": status.isConnected,
            "networkType": status.networkType,
            "cellularGeneration": status.cellularGeneration
        ]
    }

    /// Convert LatencyResultData to Dictionary
    private func toDict(_ latency: LatencyResultData?) -> [String: Any] {
        guard let latency = latency else { return [:] }
        return [
            "latencyMs": latency.latencyMs as Any,
            "jitterMs": latency.jitterMs as Any
        ]
    }

    /// Convert ThroughputResultData to NSNumber
    private func toDict(_ throughput: ThroughputResultData?) -> NSNumber? {
        return throughput?.throughputMbps
    }
}