import { TelemetryInstrument } from "./telemetry-instrument.js";
export class RovDepth extends TelemetryInstrument {
    render() {
        const update = { state: { depth: this.value("depth") } };
        const output = document.createElement("output");
        output.textContent = typeof update.state.depth === "number" ? `${update.state.depth} m` : "Depth unavailable";
        this.replaceChildren(output);
    }
}
customElements.define("rov-depth", RovDepth);
//# sourceMappingURL=rov-depth.js.map