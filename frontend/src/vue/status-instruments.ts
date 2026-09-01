import { createApp, h, reactive } from "vue";
import { telemetryState } from "../telemetry/store.js";

const state = reactive(telemetryState);

function batteryText(): string {
  const emptyIcon = "fa-battery-empty";
  const unavailable = "-- %";
  const value = state["input/analog/battery/percentage"];
  if (typeof value !== "number" || !Number.isFinite(value)) return `${emptyIcon} ${unavailable}`;
  const clamped = Math.max(0, Math.min(100, value));
  const formatted = `${clamped} %`;
  return `fa-battery-full ${formatted}`;
}

export function mountStatusInstruments(): void {
  document.querySelectorAll<HTMLElement>("[data-vue-instrument]").forEach(element => {
    const kind = element.dataset.vueInstrument;
    const render = () => h("span", { class: "rov-instrument" }, kind === "battery" ? batteryText() : kind === "voltage" ? `${state["input/analog/battery/voltage"] ?? "--"} V` : "NATS");
    const app = createApp({ render });
    app.mount(element);
  });
}
