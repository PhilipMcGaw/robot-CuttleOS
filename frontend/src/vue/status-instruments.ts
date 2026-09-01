import { createApp, h, reactive } from "vue";
import { telemetryState, subscribeTelemetry } from "../telemetry/store.js";

const state = reactive(telemetryState);
subscribeTelemetry(() => Object.assign(state, telemetryState));

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
    const render = () => {
      if (kind === "battery") {
        const [icon, ...value] = batteryText().split(" ");
        return h("span", { class: "rov-instrument rov-battery" }, [
          h("i", { class: `fa-solid ${icon}`, ariaHidden: "true" }),
          h("span", { class: "rov-instrument__value" }, value.join(" ")),
        ]);
      }
      if (kind === "voltage") {
        return h("span", { class: "rov-instrument" }, [
          h("i", { class: "fa-solid fa-bolt", ariaHidden: "true" }),
          h("span", { class: "rov-instrument__value" }, `${state["input/analog/battery/voltage"] ?? "--"} V`),
        ]);
      }
      return h("span", { class: "rov-instrument rov-link-status" }, [
        h("i", { class: "fa-solid fa-link", ariaHidden: "true" }),
        h("span", { class: "rov-instrument__value" }, "NATS"),
      ]);
    };
    const app = createApp({ render });
    app.mount(element);
  });
}
