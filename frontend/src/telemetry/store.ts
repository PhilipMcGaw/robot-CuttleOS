export type TelemetryValue = string | number | boolean | null;

export type TelemetryState = Record<string, TelemetryValue>;

export const telemetryState: TelemetryState = {};

const listeners = new Set<() => void>();

export function updateTelemetry(topic: string, value: TelemetryValue): void {
  telemetryState[topic] = value;
  if (topic === "sensor/water/depth") telemetryState.depth = value;
  listeners.forEach(listener => listener());
}

export function subscribeTelemetry(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
