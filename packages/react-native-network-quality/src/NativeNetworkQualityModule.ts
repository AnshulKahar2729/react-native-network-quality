import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

// This is required for codegen to recognize this as a TurboModule spec
// @ts-ignore
export interface Spec extends TurboModule {
  measureNetwork(options?: { extended?: boolean; timeoutMs?: number }): Promise<{
    timestamp: number;
    networkType: string;
    cellularGeneration: string;
    wifiRssi: number | null;
    cellularRssi: number | null;
    latencyMs: number | null;
    jitterMs: number | null;
    downlinkMbps: number | null;
    packetLossPercent: number | null;
    isConnected: boolean;
    failureReason?: string;
  }>;
  
  getLastMeasurement(): {
    timestamp: number;
    networkType: string;
    cellularGeneration: string;
    wifiRssi: number | null;
    cellularRssi: number | null;
    latencyMs: number | null;
    jitterMs: number | null;
    downlinkMbps: number | null;
    packetLossPercent: number | null;
    isConnected: boolean;
    failureReason?: string;
  } | null;
  
  getConnectivityStatus(): {
    isConnected: boolean;
    networkType: string;
    cellularGeneration: string;
  };
  
  getWifiRssi(): number | null;
  getCellularRssi(): number | null;
  
  measureLatency(options?: { sampleCount?: number; timeoutMs?: number }): Promise<{
    latencyMs: number | null;
    jitterMs: number | null;
  }>;
  
  measureThroughput(options?: { durationMs?: number; timeoutMs?: number }): Promise<number | null>;
  
  measurePacketLoss(options?: { attemptCount?: number; timeoutMs?: number }): Promise<number | null>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RCTNetworkQualityModule');