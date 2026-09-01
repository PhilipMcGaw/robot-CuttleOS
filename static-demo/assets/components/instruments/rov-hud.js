import { TelemetryInstrument } from "./telemetry-instrument.js";
export const DEPTH_SCALE = { min: -150, max: 10, step: 10 };
export class RovHud extends TelemetryInstrument {
    render() {
        const numberValue = (topic) => {
            const value = this.value(topic);
            return typeof value === "number" && Number.isFinite(value) ? value : null;
        };
        const heading = numberValue("sensor/ahrs/imu/heading");
        const roll = numberValue("sensor/ahrs/imu/roll");
        const pitch = numberValue("sensor/ahrs/imu/pitch");
        const depth = numberValue("sensor/water/depth");
        const rollAngle = roll ?? 0;
        const pitchOffset = (pitch ?? 0) * 6;
        const depthCentre = depth === null ? 0 : Math.round(depth / 5) * 5;
        const depthScaleValues = [2, 1, 0, -1, -2].map(offset => depthCentre + offset * 5);
        const pitchLadder = [50, 40, 30, 20, 10, 0, -10, -20, -30, -40, -50].map(value => {
            const y = 200 - value * 6 + pitchOffset;
            const major = value === 0;
            const label = String(value);
            return { y, major, label };
        });
        const leftLadder = pitchLadder.map(({ y, major, label }) => `<g class="${major ? "zero" : "dashed"}"><text x="18" y="${y + 4}" text-anchor="end">${label}</text><line x1="28" y1="${y}" x2="92" y2="${y}" /></g>`).join("");
        const rightLadder = pitchLadder.map(({ y, major, label }) => `<g class="${major ? "zero" : "dashed"}"><line x1="308" y1="${y}" x2="372" y2="${y}" /><text x="382" y="${y + 4}">${label}</text></g>`).join("");
        const ticks = Array.from({ length: 121 }, (_, index) => index * 3 - 180).map(angle => {
            const major = angle % 15 === 0, north = angle === 0;
            return `<span class="${major ? "major" : "minor"} ${north ? "north" : ""}"><i></i>${angle === 0 ? "N" : angle}</span>`;
        }).join("");
        this.innerHTML = `
      <div class="rov-hud__attitude" aria-label="Attitude">
        <svg viewBox="0 0 400 400" role="img" aria-label="Artificial horizon">
          <g transform="rotate(${rollAngle} 200 200)">
            <path class="rov-hud__arc" d="M118 286 A122 122 0 0 1 118 114" />
            <path class="rov-hud__arc" d="M282 114 A122 122 0 0 1 282 286" />
            <path class="rov-hud__reference" d="M80 200H20M320 200H380" />
            <g class="rov-hud__ladder">
              <g transform="translate(-110 0)">
                ${leftLadder}
              </g>
              <g transform="translate(110 0)">
                ${rightLadder}
              </g>
            </g>
          </g>
        </svg>
        <span class="rov-hud__roll">r: ${roll === null ? "--" : roll.toFixed(2)}</span>
        <span class="rov-hud__pitch">p: ${pitch === null ? "--" : pitch.toFixed(2)}</span>
      </div>
      <div class="rov-hud__depth-scale" aria-label="Depth scale">
        ${depthScaleValues.map((value, index) => `<span class="${index === 2 ? "zero" : ""}">${value} m <i></i></span>`).join("")}
      </div>
      <strong class="rov-hud__depth-current">${depth === null ? "--" : depth.toFixed(2)} m</strong>
      <div class="rov-hud__heading">
        <strong>${heading === null ? "--" : heading.toFixed(1)}°</strong>
        <div data-heading-scale>${ticks}</div>
        <b aria-hidden="true"></b>
      </div>`;
    }
}
customElements.define("rov-hud", RovHud);
//# sourceMappingURL=rov-hud.js.map