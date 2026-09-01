export const telemetryState = {};
const listeners = new Set();
export function updateTelemetry(topic, value) {
    telemetryState[topic] = value;
    if (topic === "sensor/water/depth")
        telemetryState.depth = value;
    listeners.forEach(listener => listener());
}
export function subscribeTelemetry(listener) {
    listeners.add(listener);
    return () => listeners.delete(listener);
}
//# sourceMappingURL=store.js.map