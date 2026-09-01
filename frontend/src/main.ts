import "./components/instruments/rov-battery.js";
import "./components/instruments/rov-network-status.js";
import "./components/instruments/rov-depth.js";
import "./components/instruments/rov-hud.js";
import { connectTelemetry } from "./transport/telemetry-websocket.js";
import { mountStatusInstruments } from "./vue/status-instruments.js";

connectTelemetry();
mountStatusInstruments();
