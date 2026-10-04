#!/usr/bin/env python3
"""AeroTHON Health Service
Runs on Vicharak Axon RK3588. Exposes companion health data to the GCS.
Start: systemd via aerothon-health.service
"""
import time
import os
import json
import threading
import subprocess
import psutil  # pip install psutil
from flask import Flask, jsonify, request, abort
from datetime import datetime, timezone

APP_VERSION = "1.0.0"
START_TIME = time.time()

app = Flask(__name__)

# --- Configuration ---
PORT = int(os.environ.get("AEROTHON_PORT", 5080))
HOST = os.environ.get("AEROTHON_HOST", "0.0.0.0")

# State cache (updated by background collectors)
_state = {
    "fpv_fps": 0.0,
    "nadir_fps": 0.0,
    "fpv_status": "unknown",
    "nadir_status": "unknown",
    "vision_status": "unknown",
    "vision_model": "unknown",
    "inference_fps": 0.0,
    "wfb_rssi": 0,
    "wfb_snr": 0,
    "wfb_loss_pct": 0.0,
    "wfb_bitrate_mbps": 0.0,
    "wfb_status": "unknown",
    "mission_state": "idle",
    "mission_active": False,
    "mission_elapsed_s": 0,
}
_state_lock = threading.Lock()


def get_system_info():
    """Collect CPU/RAM/temp/storage from psutil."""
    cpu = psutil.cpu_percent(interval=None)
    ram = psutil.virtual_memory().percent
    storage_free = psutil.disk_usage('/').free / (1024**3)  # GiB
    temps = psutil.sensors_temperatures() if hasattr(psutil, 'sensors_temperatures') else {}
    temp_c = 0.0
    for key in ('cpu_thermal', 'thermal_zone0', 'soc_thermal'):
        if key in temps and temps[key]:
            temp_c = max(t.current for t in temps[key])
            break
    return {
        "cpu_pct": round(cpu, 1),
        "ram_pct": round(ram, 1),
        "temp_c": round(temp_c, 1),
        "storage_free_gib": round(storage_free, 2),
    }


@app.route('/api/v1/heartbeat')
def heartbeat():
    """Lightweight liveness check."""
    return jsonify({"status": "ok", "ts": datetime.now(timezone.utc).isoformat()})


@app.route('/api/v1/health')
def health():
    """Full health snapshot."""
    sys = get_system_info()
    with _state_lock:
        s = dict(_state)
    uptime = int(time.time() - START_TIME)
    return jsonify({
        "status": "online",
        "version": APP_VERSION,
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "uptime_s": uptime,
        "system": sys,
        "cameras": {
            "fpv":   {"status": s["fpv_status"],   "fps": s["fpv_fps"]},
            "nadir": {"status": s["nadir_status"], "fps": s["nadir_fps"]},
        },
        "vision": {
            "status": s["vision_status"],
            "model": s["vision_model"],
            "inference_fps": s["inference_fps"],
        },
        "wfb": {
            "status":          s["wfb_status"],
            "rssi_dbm":        s["wfb_rssi"],
            "snr_db":          s["wfb_snr"],
            "packet_loss_pct": s["wfb_loss_pct"],
            "bitrate_mbps":    s["wfb_bitrate_mbps"],
        },
        "mission": {
            "state":     s["mission_state"],
            "active":    s["mission_active"],
            "elapsed_s": s["mission_elapsed_s"],
        },
    })


@app.route('/api/v1/system')
def system():
    return jsonify(get_system_info())


@app.route('/api/v1/cameras')
def cameras():
    with _state_lock:
        return jsonify({
            "fpv":   {"status": _state["fpv_status"],   "fps": _state["fpv_fps"]},
            "nadir": {"status": _state["nadir_status"], "fps": _state["nadir_fps"]},
        })


@app.route('/api/v1/vision')
def vision():
    with _state_lock:
        return jsonify({
            "status":        _state["vision_status"],
            "model":         _state["vision_model"],
            "inference_fps": _state["inference_fps"],
        })


@app.route('/api/v1/wfb')
def wfb():
    with _state_lock:
        return jsonify({
            "status":          _state["wfb_status"],
            "rssi_dbm":        _state["wfb_rssi"],
            "snr_db":          _state["wfb_snr"],
            "packet_loss_pct": _state["wfb_loss_pct"],
            "bitrate_mbps":    _state["wfb_bitrate_mbps"],
        })


@app.route('/api/v1/mission')
def mission():
    with _state_lock:
        return jsonify({
            "state":     _state["mission_state"],
            "active":    _state["mission_active"],
            "elapsed_s": _state["mission_elapsed_s"],
        })


# Preflight sessions
_preflight_sessions = {}

@app.route('/api/v1/preflight', methods=['POST'])
def preflight_start():
    import uuid
    sid = "pf-" + uuid.uuid4().hex[:8]
    mission_checksum = request.json.get('mission_checksum', 0) if request.is_json else 0
    session = {
        "session_id": sid,
        "status": "running",
        "started_at": time.time(),
        "elapsed_s": 0.0,
        "mission_checksum": mission_checksum,
        "checks": {
            "cpu_ok": None,
            "ram_ok": None,
            "temp_ok": None,
            "storage_ok": None,
            "fpv_camera": None,
            "nadir_camera": None,
            "vision_model": None,
            "wfb_tx": None,
        },
        "result": None,
    }
    _preflight_sessions[sid] = session
    # Run checks in background
    threading.Thread(target=_run_preflight_checks, args=(sid,), daemon=True).start()
    return jsonify({"session_id": sid, "status": "started"})


def _run_preflight_checks(sid: str):
    """Background preflight checker."""
    time.sleep(0.1)  # small delay to let response be sent
    s = _preflight_sessions[sid]
    sys = get_system_info()
    with _state_lock:
        state = dict(_state)
    checks = s["checks"]
    checks["cpu_ok"] = {"status": "pass" if sys["cpu_pct"] < 80 else "advisory", "value": sys["cpu_pct"]}
    checks["ram_ok"] = {"status": "pass" if sys["ram_pct"] < 80 else "advisory", "value": sys["ram_pct"]}
    checks["temp_ok"] = {"status": "pass" if sys["temp_c"] < 75 else "advisory", "value": sys["temp_c"]}
    checks["storage_ok"] = {"status": "pass" if sys["storage_free_gib"] > 1.0 else "advisory", "value": sys["storage_free_gib"]}
    checks["fpv_camera"] = {"status": "pass" if state["fpv_fps"] > 1.0 else "fail", "fps": state["fpv_fps"]}
    checks["nadir_camera"] = {"status": "pass" if state["nadir_fps"] > 1.0 else "fail", "fps": state["nadir_fps"]}
    checks["vision_model"] = {"status": "pass" if state["vision_status"] == "running" else "fail"}
    checks["wfb_tx"] = {"status": "pass" if state["wfb_status"] == "running" else "fail"}
    mandatory_fail = any(
        v.get("status") == "fail"
        for k, v in checks.items()
        if v is not None and k not in ("cpu_ok", "ram_ok", "temp_ok", "storage_ok")
    )
    s["result"] = "not_ready" if mandatory_fail else "ready"
    s["status"] = "completed"
    s["elapsed_s"] = time.time() - s["started_at"]


@app.route('/api/v1/preflight/<session_id>')
def preflight_status(session_id: str):
    s = _preflight_sessions.get(session_id)
    if s is None:
        abort(404)
    s["elapsed_s"] = time.time() - s["started_at"]
    return jsonify(s)


if __name__ == '__main__':
    print(f"AeroTHON Health Service v{APP_VERSION} starting on {HOST}:{PORT}")
    app.run(host=HOST, port=PORT, threaded=True)
