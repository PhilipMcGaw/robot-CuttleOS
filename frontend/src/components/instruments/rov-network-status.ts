import { TelemetryInstrument } from "./telemetry-instrument.js";

export class RovNetworkStatus extends TelemetryInstrument {
  protected render(): void {
    const value = this.value("system/network/status");
    this.textContent = value == null ? "Network unavailable" : String(value);
  }
}

customElements.define("rov-network-status", RovNetworkStatus);
