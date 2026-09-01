import { telemetryState, subscribeTelemetry } from "../../telemetry/store.js";
export class TelemetryInstrument extends HTMLElement {
    unsubscribe;
    connectedCallback() {
        this.unsubscribe = subscribeTelemetry(() => this.render());
        this.render();
    }
    disconnectedCallback() {
        this.unsubscribe?.();
    }
    value(topic) {
        return telemetryState[topic];
    }
}
//# sourceMappingURL=telemetry-instrument.js.map