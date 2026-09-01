import { TelemetryInstrument } from "./telemetry-instrument.js";
export class RovNetworkStatus extends TelemetryInstrument {
    poll;
    connectedCallback() {
        super.connectedCallback();
        this.refreshStatus();
        this.poll = window.setInterval(() => this.refreshStatus(), 2_000);
    }
    disconnectedCallback() {
        super.disconnectedCallback();
        if (this.poll !== undefined)
            window.clearInterval(this.poll);
    }
    async refreshStatus() {
        try {
            const response = await fetch("/api/system/status", { cache: "no-store" });
            const status = await response.json();
            this.dataset.connected = String(status.nats_connected === true);
            this.render();
        }
        catch {
            this.dataset.connected = "false";
            this.render();
        }
    }
    render() {
        const connected = this.dataset.connected === "true";
        this.setAttribute("aria-label", connected ? "NATS connected" : "NATS offline");
        this.innerHTML = `<i class="fa-solid ${connected ? "fa-link" : "fa-link-slash"}" aria-hidden="true"></i><span class="rov-instrument__value">NATS</span>`;
    }
}
customElements.define("rov-network-status", RovNetworkStatus);
//# sourceMappingURL=rov-network-status.js.map