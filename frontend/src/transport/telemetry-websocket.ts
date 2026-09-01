import { updateTelemetry } from "../telemetry/store.js";

export function connectTelemetry(): WebSocket {
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const socket = new WebSocket(`${protocol}//${window.location.host}/ws/telemetry`);
  socket.addEventListener("message", event => {
    try {
      const update = JSON.parse(event.data) as { topic?: string; value?: unknown };
      if (typeof update.topic !== "string") return;
      const value = ["string", "number", "boolean"].includes(typeof update.value)
        ? (update.value as string | number | boolean)
        : null;
      updateTelemetry(update.topic, value);
    } catch {
      // Ignore malformed telemetry; the operator shell must remain available.
    }
  });
  return socket;
}
