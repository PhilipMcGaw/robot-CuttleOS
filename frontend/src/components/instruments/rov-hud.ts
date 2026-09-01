import { TelemetryInstrument } from "./telemetry-instrument.js";

export const DEPTH_SCALE = { min: -150, max: 10, step: 10 } as const;

export class RovHud extends TelemetryInstrument {
  protected render(): void {
    const numberValue = (topic: string): number | null => {
      const value = this.value(topic);
      return typeof value === "number" && Number.isFinite(value) ? value : null;
    };
    const heading = numberValue("sensor/ahrs/imu/heading");
    const roll = numberValue("sensor/ahrs/imu/roll");
    const pitch = numberValue("sensor/ahrs/imu/pitch");
    const depth = numberValue("sensor/water/depth");
    const rollAngle = roll ?? 0;
    const pitchOffset = (pitch ?? 0) * 1.8;
    const ticks = Array.from({ length: 121 }, (_, index) => index * 3 - 180).map(angle => {
      const major = angle % 15 === 0, north = angle === 0;
      return `<span class="${major ? "major" : "minor"} ${north ? "north" : ""}"><i></i>${angle === 0 ? "N" : angle}</span>`;
    }).join("");
    this.innerHTML = `
      <div class="rov-hud__attitude" aria-label="Attitude">
        <svg viewBox="0 0 400 400" role="img" aria-label="Artificial horizon">
          <g transform="rotate(${rollAngle} 200 200) translate(0 ${pitchOffset})">
            <path class="rov-hud__arc" d="M118 286 A122 122 0 0 1 118 114" />
            <path class="rov-hud__arc" d="M282 114 A122 122 0 0 1 282 286" />
            <g class="rov-hud__marks">
              <path d="M42 170h72m70 0h72M56 140h42m204 0h42M72 230h34m188 0h34M88 260h24m176 0h24" />
            </g>
          </g>
          <path class="rov-hud__reference" d="M116 200h68l16-10 16 10h68M200 190v20" />
          <circle class="rov-hud__centre" cx="200" cy="200" r="4" />
        </svg>
        <span class="rov-hud__roll">Roll ${roll === null ? "--" : roll.toFixed(1)}°</span>
        <span class="rov-hud__pitch">Pitch ${pitch === null ? "--" : pitch.toFixed(1)}°</span>
      </div>
      <div class="rov-hud__depth-scale" aria-label="Depth scale">
        ${[-10, -5, 0].map(value => `<span class="${value === 0 ? "zero" : ""}">${value} m <i></i></span>`).join("")}
        <strong>${depth === null ? "--" : depth.toFixed(2)} m</strong>
      </div>
      <div class="rov-hud__heading">
        <strong>${heading === null ? "--" : heading.toFixed(1)}°</strong>
        <div data-heading-scale>${ticks}</div>
        <b aria-hidden="true"></b>
      </div>`;
  }
}

customElements.define("rov-hud", RovHud);
