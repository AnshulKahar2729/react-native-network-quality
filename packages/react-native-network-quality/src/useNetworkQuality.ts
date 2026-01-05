import { useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';
import type { NetworkQuality, NetworkQualityResult, UseNetworkQualityReturn, UseNetworkQualityOptions } from './types';
import { measureNetworkQuality } from './measureNetworkQuality';

export function useNetworkQuality(
  options?: UseNetworkQualityOptions
): UseNetworkQualityReturn {
  const [quality, setQuality] = useState<NetworkQuality | null>(null);
  const [measurement, setMeasurement] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastMeasuredAt, setLastMeasuredAt] = useState<number | null>(null);

  const isMeasuringRef = useRef(false);

  const performMeasurement = async (): Promise<NetworkQualityResult | void> => {
    if (isMeasuringRef.current) return;

    isMeasuringRef.current = true;
    setIsLoading(true);
    setError(null);

    try {
      const result = await measureNetworkQuality({
        extended: options?.extended ?? true,
        timeoutMs: options?.timeoutMs ?? 3000,
      });

      setQuality(result.quality);
      setMeasurement(result.measurement);
      setLastMeasuredAt(Date.now());
      options?.onMeasure?.(result, null);
      return result;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      setError(errorMsg);
      setQuality(null);
      options?.onMeasure?.(null, errorMsg);
    } finally {
      setIsLoading(false);
      isMeasuringRef.current = false;
    }
  };

  const refresh = (): Promise<NetworkQualityResult | void> => {
    return performMeasurement();
  };

  useEffect(() => {
    if (options?.measureOnMount !== false) {
      performMeasurement();
    }
  }, []);

  useEffect(() => {
    if (!options?.measureOnResume) return;

    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        performMeasurement();
      }
    });

    return () => {
      subscription.remove();
    };
  }, [options?.measureOnResume]);

  return {
    quality,
    measurement,
    isLoading,
    error,
    refresh,
    lastMeasuredAt,
  };
}