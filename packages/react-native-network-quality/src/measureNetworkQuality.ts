import type { NetworkQuality, NetworkQualityResult, MeasureOptions, NetworkMeasurement } from './types';
import NativeNetworkQualityModule from './NativeNetworkQualityModule';

function scoreNetworkQuality(measurement: NetworkMeasurement): NetworkQuality {
  if (!measurement.isConnected) {
    return 'offline';
  }

  const latencyMs = measurement.latencyMs ?? 999;
  const downlinkMbps = measurement.downlinkMbps ?? 0;
  const packetLossPercent = measurement.packetLossPercent ?? 100;

  if (latencyMs < 50 && downlinkMbps > 20 && packetLossPercent < 1) {
    return 'excellent';
  }
  if (latencyMs < 100 && downlinkMbps >= 5 && packetLossPercent < 5) {
    return 'good';
  }
  if (latencyMs < 200 && downlinkMbps >= 1 && packetLossPercent < 10) {
    return 'fair';
  }

  return 'poor';
}

export async function measureNetworkQuality(
  options?: MeasureOptions
): Promise<NetworkQualityResult> {
  const measurement = await NativeNetworkQualityModule.measureNetwork(options);

  const typedMeasurement: NetworkMeasurement = {
    timestamp: measurement.timestamp,
    networkType: measurement.networkType as any,
    cellularGeneration: measurement.cellularGeneration as any,
    wifiRssi: measurement.wifiRssi,
    cellularRssi: measurement.cellularRssi,
    latencyMs: measurement.latencyMs,
    jitterMs: measurement.jitterMs,
    downlinkMbps: measurement.downlinkMbps,
    packetLossPercent: measurement.packetLossPercent,
    isConnected: measurement.isConnected,
    failureReason: measurement.failureReason,
  };

  return {
    quality: scoreNetworkQuality(typedMeasurement),
    measurement: typedMeasurement,
  };
}