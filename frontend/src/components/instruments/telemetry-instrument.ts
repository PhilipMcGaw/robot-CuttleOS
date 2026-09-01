import { telemetryState, subscribeTelemetry } from "../../telemetry/store.js";

export abstract class TelemetryInstrument extends HTMLElement {
  private unsubscribe?: () => void;

  connectedCallback(): void {
    this.unsubscribe = subscribeTelemetry(() => this.render());
    this.render();
  }

  disconnectedCallback(): void {
    this.unsubscribe?.();
  }

  protected value(topic: string): unknown {
    return telemetryState[topic];
  }

  protected abstract render(): void;
}
