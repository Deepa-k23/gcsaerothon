# AeroTHON MAVLink Preflight Agent

## Overview
MAVLink-only preflight agent for Vicharak Axon RK3588.
Receives `AEROTHON_COMMAND` (START_PREFLIGHT) over MAVLink/WFB-ng,
executes fixed read-only health checks, and emits `AEROTHON_PREFLIGHT_RESULT`
messages (sequenced 0..total-1) sharing a single `request_id`.

**SECURITY**: No arbitrary command execution. Only predefined diagnostics.

## Files
- `mavlink_preflight_agent.py` — Production agent (pymavlink + psutil)
- `mock_mavlink_preflight.py` — Mock provider for PROTOCOL TESTING
- `requirements.txt` — Python dependencies
- `aerothon-preflight.service` — systemd unit
- `install.sh` — Installation script (run as root on Axon)

## MAVLink Protocol

### Request: GCS → Axon
Message: `AEROTHON_COMMAND` (61004)
- `command` = `AEROTHON_COMMAND_START_PREFLIGHT` (1)
- `request_id` = GCS-generated session-unique uint32
- `param1` = mission_checksum (optional, float)
- `target_system` = Axon system ID (255)
- `target_component` = Axon component ID (190)

### Acknowledgement: Axon → GCS
Message: `AEROTHON_COMMAND_ACK` (61005)
- `request_id` = echoed from request
- `result` = `ACK_ACCEPTED` (0) on start, `ACK_IN_PROGRESS` (5) on completion

### Results: Axon → GCS (one per check)
Message: `AEROTHON_PREFLIGHT_RESULT` (61006)
- `request_id` = same as request
- `seq` = 0..total-1
- `total` = 9 (number of checks)
- `check_id` = stable key: `cpu|ram|temp|storage|vision|fpv|nadir|wfb_link|wfb_video`
- `group` = functional group: `AXON|VISION|CAMERAS|LINK`
- `status` = `CHECK_PASS`(0) | `CHECK_ADVISORY`(1) | `CHECK_FAIL`(2) | `CHECK_UNKNOWN`(3)
- `value` = numeric detail (NaN if N/A)
- `detail` = human-readable string

### Check Definitions
| check_id | group | label | mandatory |
|----------|-------|-------|-----------|
| cpu | AXON | AXON CPU | ✓ |
| ram | AXON | AXON RAM | ✓ |
| temp | AXON | AXON Temperature | ✓ |
| storage | AXON | AXON Storage | ✗ |
| vision | VISION | AXON Vision | ✓ |
| fpv | CAMERAS | FPV Camera | ✓ |
| nadir | CAMERAS | Nadir Camera | ✓ |
| wfb_link | LINK | WFB Link | ✓ |
| wfb_video | LINK | WFB Video | ✓ |

## Installation on Axon

```bash
# As root
cd docs/axon
chmod +x install.sh
./install.sh
```

This:
1. Creates `/opt/aerothon`
2. Sets up Python venv with `pymavlink`, `psutil`
3. Installs systemd service `aerothon-preflight.service`
4. Enables auto-start on boot

### Service Management
```bash
systemctl start aerothon-preflight      # start now
systemctl status aerothon-preflight     # check status
journalctl -u aerothon-preflight -f     # follow logs
systemctl restart aerothon-preflight    # restart
systemctl stop aerothon-preflight       # stop
```

### Configuration (via service environment)
- `AEROTHON_MAVLINK_URI` — MAVLink endpoint (default: `udp:0.0.0.0:14550`)
- `AEROTHON_OWN_SYSTEM_ID` — Agent system ID (default: 255)
- `AEROTHON_OWN_COMPONENT_ID` — Agent component ID (default: 190)
- `AEROTHON_TARGET_SYSTEM` — GCS system ID (default: 1)
- `AEROTHON_TARGET_COMPONENT` — GCS component ID (default: 1)

## Testing

### PROTOCOL TEST (no hardware)
Tests the MAVLink request/result protocol with a local mock provider.

```bash
# Terminal 1: Start mock provider (simulates Axon)
cd docs/axon
pip install -r requirements.txt
python mock_mavlink_preflight.py --port 14550

# Terminal 2: Launch GCS
cd /home/deepa
./Applications/AeroTHON-GCS-x86_64_5e1346902bcf7fb2d9606e0c17373c3f.AppImage \
  --appimage-extract-and-run

# In GCS: Open Pre-Flight Check panel → Click PRE-FLIGHT CHECK
# Observe: PRE-FLIGHT RUNNING... → results populate → READY/ADVISORY
```

**Expected behavior**:
- Mock emits 9 results with mixed PASS/ADVISORY/UNKNOWN
- GCS panel shows check groups AXON/CAMERAS/LINK/VISION
- Stale request IDs are ignored (only current request_id honored)

### REAL AXON TEST (requires Vicharak Axon + WFB-ng)
```bash
# On Axon (after install.sh):
systemctl start aerothon-preflight
journalctl -u aerothon-preflight -f

# On GCS laptop (connected via WFB-ng):
./Applications/AeroTHON-GCS-x86_64_5e1346902bcf7fb2d9606e0c17373c3f.AppImage \
  --appimage-extract-and-run
# Click PRE-FLIGHT CHECK → observe live results over WFB-ng MAVLink
```

**Prerequisites**:
- WFB-ng link established (ground ↔ air)
- MAVLink telemetry flowing (heartbeat visible in GCS)
- Axon MAVLink endpoint reachable at `udp:0.0.0.0:14550`

### REAL WFB TEST (full integration)
Same as REAL AXON TEST but with actual radio link. Validates:
- MAVLink survives packet loss/reordering
- 60s timeout works correctly
- Stale results rejected on re-run

## Local Status Files (for real Axon checks)
The agent reads local status files for camera/WFB data. These must be
written by the respective Axon pipelines:

```
/tmp/aerothon/camera_fpv_status.json    {"fps": 29.5, "status": "live"}
/tmp/aerothon/camera_nadir_status.json  {"fps": 24.8, "status": "live"}
/tmp/aerothon/wfb_status.json           {"packet_loss_pct": 0.4, "rssi_dbm": -62, "snr_db": 22, "bitrate_mbps": 7.8, "status": "running"}
```

If files missing → check returns `CHECK_UNKNOWN` (never fake PASS).

## Security Notes
- Agent only listens for `AEROTHON_COMMAND` with `command=START_PREFLIGHT`
- No shell command execution, no eval, no dynamic code
- Fixed check list — cannot be extended remotely
- Runs as root only for hardware sensor access (psutil)

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Connection refused" | MAVLink port not open | Check WFB-ng, firewall, `AEROTHON_MAVLINK_URI` |
| No results received | Axon agent not running | `systemctl status aerothon-preflight` |
| All checks UNKNOWN | Status files missing | Deploy camera/WFB status writers |
| Stale results appear | Old request_id cached | GCS auto-ignores; click PRE-FLIGHT CHECK again |
| Timeout → Incomplete | Agent too slow / no link | Check MAVLink throughput, increase timeout |

## GCS Integration
The AeroTHON-GCS `AeroPreflightManager`:
1. Generates fresh `request_id` on each `startPreflight()`
2. Sends `AEROTHON_COMMAND` via active vehicle link
3. Receives `AEROTHON_PREFLIGHT_RESULT` via `AeroTHONManager`
4. Matches `request_id` → ignores stale
5. Updates check states → computes overall READY/ADVISORY/NOT_READY/TIMEOUT
6. Emits certificate on READY/ADVISORY

No Flask, no HTTP, no SSH, no hard-coded Axon IP.