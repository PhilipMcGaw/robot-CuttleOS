import "./components/instruments/rov-hud.js";
import { updateTelemetry } from "./telemetry/store.js";

const started = performance.now();
const output = (id: string): HTMLOutputElement | null => document.getElementById(id) as HTMLOutputElement | null;

function animate(now: number): void {
  const seconds = (now - started) / 1000;
  const heading = (117 + seconds * 5) % 360;
  const pitch = Math.sin(seconds * 0.55) * 14;
  const roll = Math.sin(seconds * 0.8) * 18;
  const depth = -12 - Math.sin(seconds * 0.35) * 8;
  const battery = 78 - (seconds % 80) * 0.35;
  const lights = 68 + Math.sin(seconds * 0.6) * 12;
  const cameraPitch = Math.sin(seconds * 0.45) * 10;
  const temperature = 10 + Math.sin(seconds * 0.2) * 0.4;

  updateTelemetry("sensor/ahrs/imu/heading", heading);
  updateTelemetry("sensor/ahrs/imu/pitch", pitch);
  updateTelemetry("sensor/ahrs/imu/roll", roll);
  updateTelemetry("sensor/water/depth", depth);
  updateTelemetry("input/analog/battery/percentage", battery);
  updateTelemetry("input/analog/battery/voltage", 15.9 - (78 - battery) * 0.025);
  output("lightLevel")!.value = `${lights.toFixed(0)} %`;
  output("cameraPitch")!.value = `${cameraPitch >= 0 ? "+" : ""}${cameraPitch.toFixed(1)} °`;
  output("temperature")!.value = `${temperature.toFixed(1)} °C`;
  document.querySelector<HTMLElement>("[data-demo-time]")!.textContent = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false });
  window.requestAnimationFrame(animate);
}

window.requestAnimationFrame(animate);
