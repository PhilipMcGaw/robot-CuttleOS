import { TelemetryInstrument } from "./telemetry-instrument.js";

export class RovBattery extends TelemetryInstrument {
  protected render(): void {
    const value = this.value("input/analog/battery/percentage");
    const percentage = typeof value === "number" && Number.isFinite(value) ? value : null;
    const clamped = percentage === null ? null : Math.max(0, Math.min(100, percentage));
    const emptyIcon = "fa-battery-empty";
    const icon = clamped === null ? emptyIcon : clamped >= 75 ? "fa-battery-full" : clamped >= 50 ? "fa-battery-three-quarters" : clamped >= 25 ? "fa-battery-half" : "fa-battery-quarter";
    this.innerHTML = `<span class="rov-instrument__icon"><i class="fa-solid ${icon}" aria-hidden="true"></i></span><output>${clamped === null ? "-- %" : `${clamped} %`}</output>`;
  }
}

customElements.define("rov-battery", RovBattery);
