#!/usr/bin/env python3
"""
AeroTHON MAVLink Preflight Agent
================================

Runs on Vicharak Axon RK3588. Listens for AEROTHON_COMMAND START_PREFLIGHT
over MAVLink, executes fixed read-only health checks, and emits one
AEROTHON_PREFLIGHT_RESULT per check (sequenced 0..total-1) sharing a single
request_id.

SECURITY:
- NEVER executes arbitrary commands received over MAVLink
- Only runs predefined diagnostic functions
- MAVLink-only communication (no HTTP/SSH/IP dependencies)

DEPENDENCIES:
- pymavlink (pip install pymavlink)
- psutil (pip install psutil)

MAVLink Messages Used:
- Incoming:  AEROTHON_COMMAND (61004) with command=AEROTHON_COMMAND_START_PREFLIGHT (1)
- Outgoing:  AEROTHON_COMMAND_ACK (61005) for request acknowledgement
- Outgoing:  AEROTHON_PREFLIGHT_RESULT (61006) per check (sequenced)

The agent connects to the local MAVLink UDP endpoint (typically udp:127.0.0.1:14550
or udp:0.0.0.0:14550) which is bridged to the GCS via WFB-ng.
"""

import os
import sys
import time
import math
import json
import threading
import subprocess
import psutil
from datetime import datetime, timezone
from pymavlink import mavutil, mavlink
from typing import Optional, Dict, List, Tuple, Any

# -----------------------------------------------------------------------------
# Configuration (environment override)
# -----------------------------------------------------------------------------
MAVLINK_URI = os.environ.get("AEROTHON_MAVLINK_URI", "udp:0.0.0.0:14550")
TARGET_SYSTEM = int(os.environ.get("AEROTHON_TARGET_SYSTEM", "1"))      # GCS system ID
TARGET_COMPONENT = int(os.environ.get("AEROTHON_TARGET_COMPONENT", "1"))  # GCS component ID
OWN_SYSTEM_ID = int(os.environ.get("AEROTHON_OWN_SYSTEM_ID", "255"))   # This agent's system ID
OWN_COMPONENT_ID = int(os.environ.get("AEROTHON_OWN_COMPONENT_ID", "190"))  # MAV_COMP_ID_AXON

# Timing
PREFLIGHT_TIMEOUT_SEC = 60
CHECK_POLL_INTERVAL = 0.5

# -----------------------------------------------------------------------------
# MAVLink message IDs (must match aerothon.xml)
# -----------------------------------------------------------------------------
MSG_AEROTHON_STATUS          = 61000
MSG_AEROTHON_DETECTION       = 61001
MSG_AEROTHON_QR_RESULT       = 61002
MSG_AEROTHON_HEALTH          = 61003
MSG_AEROTHON_COMMAND         = 61004
MSG_AEROTHON_COMMAND_ACK     = 61005
MSG_AEROTHON_PREFLIGHT_RESULT = 61006

# AEROTHON_COMMAND_TYPE enum
CMD_NOP                      = 0
CMD_START_PREFLIGHT          = 1
CMD_START_MISSION            = 2
CMD_PAUSE_MISSION            = 3
CMD_RESUME_MISSION           = 4
CMD_ABORT_MISSION            = 5
CMD_AUTHORIZE_PAYLOAD        = 6
CMD_RELEASE_PAYLOAD          = 7
CMD_RESET_SESSION            = 8

# AEROTHON_ACK_RESULT enum
ACK_ACCEPTED                 = 0
ACK_TEMPORARILY_REJECTED     = 1
ACK_DENIED                   = 2
ACK_UNSUPPORTED              = 3
ACK_FAILED                   = 4
ACK_IN_PROGRESS              = 5

# AEROTHON_CHECK_STATUS enum
CHECK_PASS                   = 0
CHECK_ADVISORY               = 1
CHECK_FAIL                   = 2
CHECK_UNKNOWN                = 3

# -----------------------------------------------------------------------------
# Check definitions (stable check_id, group, label)
# -----------------------------------------------------------------------------
CHECKS = [
    # AXON
    {"check_id": "cpu",         "group": "AXON", "label": "AXON CPU",       "mandatory": True},
    {"check_id": "ram",         "group": "AXON", "label": "AXON RAM",       "mandatory": True},
    {"check_id": "temp",        "group": "AXON", "label": "AXON Temperature","mandatory": True},
    {"check_id": "storage",     "group": "AXON", "label": "AXON Storage",   "mandatory": False},
    {"check_id": "vision",      "group": "VISION", "label": "AXON Vision",    "mandatory": True},
    # CAMERAS
    {"check_id": "fpv",         "group": "CAMERAS", "label": "FPV Camera",    "mandatory": True},
    {"check_id": "nadir",       "group": "CAMERAS", "label": "Nadir Camera",  "mandatory": True},
    # LINK
    {"check_id": "wfb_link",    "group": "LINK",   "label": "WFB Link",      "mandatory": True},
    {"check_id": "wfb_video",   "group": "LINK",   "label": "WFB Video",     "mandatory": True},
]

TOTAL_CHECKS = len(CHECKS)

# -----------------------------------------------------------------------------
# MAVLink connection
# -----------------------------------------------------------------------------
class MavlinkAgent:
    def __init__(self, uri: str):
        self.uri = uri
        self.conn: Optional[mavutil.mavlink_connection] = None
        self.running = False
        self._lock = threading.Lock()
        self._pending_request: Optional[Dict] = None

    def connect(self) -> bool:
        try:
            self.conn = mavutil.mavlink_connection(self.uri, autoreconnect=True, source_system=OWN_SYSTEM_ID, source_component=OWN_COMPONENT_ID)
            # Wait for heartbeat to confirm link
            self.conn.wait_heartbeat(timeout=10)
            print(f"[MAVLink] Connected to {self.uri}, heartbeat from system {self.conn.target_system}")
            return True
        except Exception as e:
            print(f"[MAVLink] Connection failed: {e}")
            return False

    def send_command_ack(self, request_id: int, command: int, result: int, progress: int = 0, reason: int = 0, message: str = ""):
        if not self.conn:
            return
        msg = self.conn.mav.aerothon_command_ack_encode(
            request_id=request_id,
            reason_code=reason,
            command=command,
            result=result,
            progress_pct=progress,
            message=message[:47].encode()  # max 48 chars
        )
        self._send(msg)
        print(f"[MAVLink] Sent COMMAND_ACK request_id={request_id} result={result}")

    def send_preflight_result(self, request_id: int, seq: int, total: int,
                               check_id: str, group: str, status: int, value: float, detail: str):
        if not self.conn:
            return
        # Encode strings to fixed-width char arrays
        check_id_bytes = check_id[:19].encode().ljust(20, b'\x00')
        group_bytes = group[:15].encode().ljust(16, b'\x00')
        detail_bytes = detail[:63].encode().ljust(64, b'\x00')

        # Handle NaN for value
        if math.isnan(value):
            value = float('nan')

        msg = self.conn.mav.aerothon_preflight_result_encode(
            time_usec=int(time.time() * 1_000_000),
            request_id=request_id,
            seq=seq,
            total=total,
            check_id=check_id_bytes,
            group=group_bytes,
            status=status,
            value=value,
            detail=detail_bytes
        )
        self._send(msg)

    def _send(self, msg: mavlink.MAVLink_message):
        with self._lock:
            if self.conn:
                self.conn.mav.send(msg)

    def close(self):
        self.running = False
        if self.conn:
            self.conn.close()

# -----------------------------------------------------------------------------
# Check implementations (read-only, no side effects)
# -----------------------------------------------------------------------------
def get_system_info() -> Dict[str, Any]:
    """Collect CPU/RAM/temp/storage from psutil."""
    cpu = psutil.cpu_percent(interval=None)
    ram = psutil.virtual_memory().percent
    storage_free = psutil.disk_usage('/').free / (1024**2)  # MiB
    temps = psutil.sensors_temperatures() if hasattr(psutil, 'sensors_temperatures') else {}
    temp_c = 0.0
    for key in ('cpu_thermal', 'thermal_zone0', 'soc_thermal', 'coretemp'):
        if key in temps and temps[key]:
            temp_c = max(t.current for t in temps[key])
            break
    return {
        "cpu_pct": round(cpu, 1),
        "ram_pct": round(ram, 1),
        "temp_c": round(temp_c, 1),
        "storage_mib": round(storage_free, 0),
    }

def check_cpu(sys: Dict) -> Tuple[int, float, str]:
    cpu = sys["cpu_pct"]
    if cpu < 80.0:
        return CHECK_PASS, cpu, f"CPU {cpu}%"
    elif cpu < 95.0:
        return CHECK_ADVISORY, cpu, f"High CPU {cpu}%"
    else:
        return CHECK_FAIL, cpu, f"Critical CPU {cpu}%"

def check_ram(sys: Dict) -> Tuple[int, float, str]:
    ram = sys["ram_pct"]
    if ram < 80.0:
        return CHECK_PASS, ram, f"RAM {ram}%"
    elif ram < 95.0:
        return CHECK_ADVISORY, ram, f"High RAM {ram}%"
    else:
        return CHECK_FAIL, ram, f"Critical RAM {ram}%"

def check_temp(sys: Dict) -> Tuple[int, float, str]:
    temp = sys["temp_c"]
    if temp < 70.0:
        return CHECK_PASS, temp, f"{temp}°C"
    elif temp <= 80.0:
        return CHECK_ADVISORY, temp, f"{temp}°C — elevated"
    else:
        return CHECK_FAIL, temp, f"{temp}°C — overheating"

def check_storage(sys: Dict) -> Tuple[int, float, str]:
    storage_mib = sys["storage_mib"]
    if storage_mib >= 1024.0:
        return CHECK_PASS, storage_mib, f"{storage_mib/1024:.1f} GiB free"
    elif storage_mib >= 256.0:
        return CHECK_ADVISORY, storage_mib, f"{storage_mib:.0f} MiB free"
    else:
        return CHECK_FAIL, storage_mib, f"{storage_mib:.0f} MiB free — critically low"

def check_vision() -> Tuple[int, float, str]:
    """Check if vision inference pipeline is running.
    This probes for a running inference process or open GPU context.
    Returns UNKNOWN if undeterminable (no fake PASS)."""
    # Try common vision process names / ports
    # This is environment-specific; return UNKNOWN if not detectable
    try:
        # Check for common vision services (e.g., v4l2, gstreamer, python inference)
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                cmd = " ".join(proc.info['cmdline'] or [])
                name = proc.info['name'] or ""
                if any(kw in cmd.lower() or kw in name.lower()
                       for kw in ('inference', 'yolo', 'detect', 'vision', 'triton', 'tensorrt')):
                    return CHECK_PASS, 1.0, "Vision process detected"
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except Exception:
        pass
    return CHECK_UNKNOWN, float('nan'), "Vision status undetermined (no detector found)"

def check_camera_fps(camera: str) -> Tuple[int, float, str]:
    """Check if camera frames are being received.
    This reads from a local status file / shared memory if available,
    otherwise returns UNKNOWN.
    Expected camera: 'fpv' or 'nadir'"""
    # In a real deployment, this would read from a local status file
    # written by the camera capture pipeline (e.g., /tmp/aerothon/camera_status.json)
    # For now, return UNKNOWN - the real Axon integration would populate this
    status_file = f"/tmp/aerothon/camera_{camera}_status.json"
    if os.path.exists(status_file):
        try:
            with open(status_file) as f:
                data = json.load(f)
            fps = data.get("fps", 0.0)
            if fps > 1.0:
                return CHECK_PASS, fps, f"{fps:.1f} fps"
            else:
                return CHECK_FAIL, fps, f"No frames ({fps:.1f} fps)"
        except Exception:
            pass
    return CHECK_UNKNOWN, float('nan'), f"{camera.upper()} camera status unavailable (no local status file)"

def check_wfb_link() -> Tuple[int, float, str]:
    """Check WFB telemetry link health from local WFB stats.
    Reads from local status file written by WFB monitor."""
    status_file = "/tmp/aerothon/wfb_status.json"
    if os.path.exists(status_file):
        try:
            with open(status_file) as f:
                data = json.load(f)
            loss = data.get("packet_loss_pct", 100.0)
            rssi = data.get("rssi_dbm", -100)
            if loss < 10.0:
                return CHECK_PASS, loss, f"Loss {loss:.1f}% RSSI {rssi} dBm"
            elif loss < 30.0:
                return CHECK_ADVISORY, loss, f"Loss {loss:.1f}% RSSI {rssi} dBm — degraded"
            else:
                return CHECK_FAIL, loss, f"Loss {loss:.1f}% RSSI {rssi} dBm — link degraded"
        except Exception:
            pass
    return CHECK_UNKNOWN, float('nan'), "WFB telemetry stats unavailable"

def check_wfb_video() -> Tuple[int, float, str]:
    """Check WFB video link health."""
    status_file = "/tmp/aerothon/wfb_status.json"
    if os.path.exists(status_file):
        try:
            with open(status_file) as f:
                data = json.load(f)
            loss = data.get("packet_loss_pct", 100.0)
            bitrate = data.get("bitrate_mbps", 0.0)
            if loss < 10.0:
                return CHECK_PASS, loss, f"Loss {loss:.1f}% Bitrate {bitrate:.1f} Mbps"
            elif loss < 30.0:
                return CHECK_ADVISORY, loss, f"Loss {loss:.1f}% Bitrate {bitrate:.1f} Mbps — degraded"
            else:
                return CHECK_FAIL, loss, f"Loss {loss:.1f}% Bitrate {bitrate:.1f} Mbps — link degraded"
        except Exception:
            pass
    return CHECK_UNKNOWN, float('nan'), "WFB video stats unavailable"

# -----------------------------------------------------------------------------
# Preflight runner
# -----------------------------------------------------------------------------
class PreflightRunner:
    def __init__(self, mav: MavlinkAgent):
        self.mav = mav
        self.running = False

    def run(self, request_id: int, mission_checksum: int = 0):
        """Execute all checks and emit results."""
        if self.running:
            print("[Preflight] Already running, ignoring")
            return

        self.running = True
        print(f"[Preflight] Starting request_id={request_id}")

        # Send ACK: accepted
        self.mav.send_command_ack(request_id, CMD_START_PREFLIGHT, ACK_ACCEPTED, progress=0)

        sys_info = get_system_info()

        # Execute checks
        check_fns = {
            "cpu": lambda: check_cpu(sys_info),
            "ram": lambda: check_ram(sys_info),
            "temp": lambda: check_temp(sys_info),
            "storage": lambda: check_storage(sys_info),
            "vision": check_vision,
            "fpv": lambda: check_camera_fps("fpv"),
            "nadir": lambda: check_camera_fps("nadir"),
            "wfb_link": check_wfb_link,
            "wfb_video": check_wfb_video,
        }

        for seq, check_def in enumerate(CHECKS):
            cid = check_def["check_id"]
            group = check_def["group"]
            fn = check_fns.get(cid)
            if fn:
                try:
                    status, value, detail = fn()
                except Exception as e:
                    print(f"[Preflight] Check {cid} raised: {e}")
                    status, value, detail = CHECK_UNKNOWN, float('nan'), f"Check error: {e}"
            else:
                status, value, detail = CHECK_UNKNOWN, float('nan'), "No check implementation"

            # Emit result
            self.mav.send_preflight_result(request_id, seq, TOTAL_CHECKS,
                                           cid, group, status, value, detail)
            print(f"[Preflight] Check {seq+1}/{TOTAL_CHECKS} {cid} ({group}) -> status={status} value={value}")

        # Send ACK: completed
        self.mav.send_command_ack(request_id, CMD_START_PREFLIGHT, ACK_IN_PROGRESS, progress=100)
        self.running = False
        print(f"[Preflight] Completed request_id={request_id}")

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
def main():
    print(f"AeroTHON MAVLink Preflight Agent v1.0")
    print(f"MAVLink URI: {MAVLINK_URI}")
    print(f"Own system/component: {OWN_SYSTEM_ID}/{OWN_COMPONENT_ID}")
    print(f"Target system/component: {TARGET_SYSTEM}/{TARGET_COMPONENT}")

    mav = MavlinkAgent(MAVLINK_URI)
    if not mav.connect():
        print("Failed to connect to MAVLink, exiting")
        sys.exit(1)

    runner = PreflightRunner(mav)

    # Main receive loop
    mav.running = True
    while mav.running:
        try:
            msg = mav.conn.recv_match(type=['AEROTHON_COMMAND'], blocking=True, timeout=1.0)
            if msg is None:
                continue

            if msg.get_type() != 'AEROTHON_COMMAND':
                continue

            cmd = msg.command
            req_id = msg.request_id
            target_sys = msg.target_system
            target_comp = msg.target_component

            # Validate target
            if target_sys != 0 and target_sys != OWN_SYSTEM_ID:
                print(f"[MAVLink] Ignoring command for system {target_sys}")
                continue

            if cmd == CMD_START_PREFLIGHT:
                # Acknowledge immediately
                mav.send_command_ack(req_id, cmd, ACK_ACCEPTED, progress=0)

                # Run preflight in background thread
                thread = threading.Thread(target=runner.run, args=(req_id, int(msg.param1) if not math.isnan(msg.param1) else 0))
                thread.daemon = True
                thread.start()
            else:
                print(f"[MAVLink] Unsupported command: {cmd}")
                mav.send_command_ack(req_id, cmd, ACK_UNSUPPORTED, message="Unsupported command")

        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"[MAVLink] Error: {e}")
            time.sleep(0.1)

    mav.close()
    print("Agent stopped")

if __name__ == '__main__':
    main()