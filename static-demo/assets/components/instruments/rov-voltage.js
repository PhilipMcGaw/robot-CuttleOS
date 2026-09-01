import { TelemetryInstrument } from "./telemetry-instrument.js";
export class RovVoltage extends TelemetryInstrument {
    render() {
        const value = this.value("input/analog/battery/voltage");
        const voltage = typeof value === "number" && Number.isFinite(value) ? value : null;
        this.innerHTML = `<i class="fa-solid fa-bolt" aria-hidden="true"></i><output>${voltage === null ? "-- V" : `${voltage.toFixed(2)} V`}</output>`;
    }
}
customElements.define("rov-voltage", RovVoltage);
//# sourceMappingURL=rov-voltage.js.map