import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
  StyleSheet,
} from 'react-native';
import { useNetworkQuality, measureNetworkQuality } from 'react-native-network-quality';

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  section: { marginBottom: 20, backgroundColor: '#fff', padding: 16, borderRadius: 8 },
  title: { fontSize: 18, fontWeight: 'bold', marginBottom: 12 },
  label: { fontSize: 14, fontWeight: '600', color: '#666', marginTop: 8 },
  value: { fontSize: 16, marginTop: 4 },
  button: { backgroundColor: '#007AFF', padding: 12, borderRadius: 6, alignItems: 'center', marginTop: 8 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  badge: { padding: 12, borderRadius: 6, alignItems: 'center', marginTop: 8 },
  badgeText: { color: '#fff', fontSize: 16, fontWeight: 'bold' },
});

const getColor = (quality: string | null) => {
  switch (quality) {
    case 'excellent': return '#4caf50';
    case 'good': return '#8bc34a';
    case 'fair': return '#ff9800';
    case 'poor': return '#f44336';
    default: return '#999';
  }
};

function HookExample() {
  const { quality, measurement, isLoading, refresh } = useNetworkQuality();

  return (
    <View style={styles.section}>
      <Text style={styles.title}>Hook API</Text>
      {isLoading && <ActivityIndicator size="small" color="#007AFF" />}
      {quality && (
        <>
          <View style={[styles.badge, { backgroundColor: getColor(quality) }]}>
            <Text style={styles.badgeText}>{quality.toUpperCase()}</Text>
          </View>
          {measurement && (
            <>
              <Text style={styles.label}>Latency</Text>
              <Text style={styles.value}>{measurement.latencyMs ? `${measurement.latencyMs.toFixed(0)} ms` : 'N/A'}</Text>
              <Text style={styles.label}>Throughput</Text>
              <Text style={styles.value}>{measurement.downlinkMbps ? `${measurement.downlinkMbps.toFixed(1)} Mbps` : 'N/A'}</Text>
            </>
          )}
        </>
      )}
      <TouchableOpacity style={styles.button} onPress={refresh} disabled={isLoading}>
        <Text style={styles.buttonText}>{isLoading ? 'Measuring...' : 'Refresh'}</Text>
      </TouchableOpacity>
    </View>
  );
}

function OneShotExample() {
  const [quality, setQuality] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleMeasure = async () => {
    setIsLoading(true);
    try {
      const result = await measureNetworkQuality();
      setQuality(result.quality);
    } catch (error) {
      console.error(error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <View style={styles.section}>
      <Text style={styles.title}>One-Shot API</Text>
      <TouchableOpacity style={styles.button} onPress={handleMeasure} disabled={isLoading}>
        <Text style={styles.buttonText}>{isLoading ? 'Measuring...' : 'Measure Now'}</Text>
      </TouchableOpacity>
      {quality && (
        <View style={[styles.badge, { backgroundColor: getColor(quality) }]}>
          <Text style={styles.badgeText}>{quality.toUpperCase()}</Text>
        </View>
      )}
    </View>
  );
}

export default function TestNetworkQuality() {
  return (
    <ScrollView style={styles.container}>
      <Text style={{ fontSize: 24, fontWeight: 'bold', marginBottom: 20 }}>Network Quality</Text>
      <HookExample />
      <OneShotExample />
    </ScrollView>
  );
}