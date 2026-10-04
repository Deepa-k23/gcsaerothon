#!/usr/bin/env python3
"""
AeroTHON Mock MAVLink Preflight Provider
=========================================

For PROTOCOL TESTING only (no real Axon/WFB hardware required).

This script simulates an Axon that:
1. Listens for AEROTHON_COMMAND START_PREFLIGHT on a local UDP port
2. Responds with AEROTHON_COMMAND_ACK
3. Emits AEROTHON_PREFLIGHT_RESULT messages (sequenced) with simulated check results

Usage:
    python mock_mavlink_preflight.py [--port 14550]

The GCS should connect to udp:127.0.0.1:<port> for testing.

This is a PROTOCOL TEST, not a real Axon test.
"""

import sys
import time
import math
import threading
from datetime import datetime, timezone
from pymavlink import mavutil, mavlink

# Message IDs (must match aerothon.xml)
MSG_AEROTHON_COMMAND         = 61004
MSG_AEROTHON_COMMAND_ACK     = 61005
MSG_AEROTHON_PREFLIGHT_RESULT = 61006

CMD_START_PREFLIGHT = 1
ACK_ACCEPTED = 0
ACK_IN_PROGRESS = 5

CHECK_PASS = 0
CHECK_ADVISORY = 1
CHECK_FAIL = 2
CHECK_UNKNOWN = 3

CHECKS = [
    {"check_id": "cpu",         "group": "AXON",    "status": CHECK_PASS,       "value": 25.0, "detail": "CPU 25%"},
    {"check_id": "ram",         "group": "AXON",    "status": CHECK_PASS,       "value": 42.0, "detail": "RAM 42%"},
    {"check_id": "temp",        "group": "AXON",    "status": CHECK_PASS,       "value": 51.5, "detail": "51.5°C"},
    {"check_id": "storage",     "group": "AXON",    "status": CHECK_ADVISORY,   "value": 1024.0, "detail": "1.0 GiB free"},
    {"check_id": "vision",      "group": "VISION",  "status": CHECK_PASS,       "value": 14.2, "detail": "14.2 fps"},
    {"check_id": "fpv",         "group": "CAMERAS", "status": CHECK_PASS,       "value": 29.5, "detail": "29.5 fps"},
    {"check_id": "nadir",       "group": "CAMERAS", "status": CHECK_ADVISORY,   "value": 0.0, "detail": "No frames"},
    {"check_id": "wfb_link",    "group": "LINK",    "status": CHECK_PASS,       "value": 0.4, "detail": "Loss 0.4% RSSI -62 dBm"},
    {"check_id": "wfb_video",   "group": "LINK",    "status": CHECK_PASS,       "value": 7.8, "detail": "Loss 0.4% Bitrate 7.8 Mbps"},
]

TOTAL_CHECKS = len(CHECKS)
OWN_SYSTEM_ID = 255
OWN_COMPONENT_ID = 190

def encode_check_id(cid: str) -> bytes:
    return cid[:19].encode().ljust(20, b'\x00')

def encode_group(g: str) -> bytes:
    return g[:15].encode().ljust(16, b'\x00')

def encode_detail(d: str) -> bytes:
    return d[:63].encode().ljust(64, b'\x00')

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=14550, help='UDP port to listen on')
    args = parser.parse_args()

    uri = f"udp:0.0.0.0:{args.port}"
    print(f"=== AeroTHON Mock MAVLink Preflight Provider ===")
    print(f"Listening on {uri}")
    print(f"Own system/component: {OWN_SYSTEM_ID}/{OWN_COMPONENT_ID}")

    conn = mavutil.mavlink_connection(uri, source_system=OWN_SYSTEM_ID, source_component=OWN_COMPONENT_ID)
    print("Waiting for heartbeat...")
    conn.wait_heartbeat(timeout=10)
    print(f"Connected to GCS system {conn.target_system}, component {conn.target_component}")

    while True:
        try:
            msg = conn.recv_match(type=['AEROTHON_COMMAND'], blocking=True, timeout=1.0)
            if msg is None:
                continue

            if msg.get_type() != 'AEROTHON_COMMAND':
                continue

            req_id = msg.request_id
            cmd = msg.command
            target_sys = msg.target_system

            if target_sys != 0 and target_sys != OWN_SYSTEM_ID:
                continue

            if cmd == CMD_START_PREFLIGHT:
                print(f"\n[Mock] Received START_PREFLIGHT request_id={req_id}")

                # Send ACK: accepted
                ack_msg = conn.mav.aerothon_command_ack_encode(
                    request_id=req_id,
                    reason_code=0,
                    command=cmd,
                    result=ACK_ACCEPTED,
                    progress_pct=0,
                    message=b"Preflight started"
                )
                conn.mav.send(ack_msg)
                print(f"[Mock] Sent COMMAND_ACK (accepted)")

                # Simulate check execution delay
                time.sleep(0.5)

                # Emit results
                for seq, check in enumerate(CHECKS):
                    result_msg = conn.mav.aerothon_preflight_result_encode(
                        time_usec=int(time.time() * 1_000_000),
                        request_id=req_id,
                        seq=seq,
                        total=TOTAL_CHECKS,
                        check_id=encode_check_id(check["check_id"]),
                        group=encode_group(check["group"]),
                        status=check["status"],
                        value=check["value"],
                        detail=encode_detail(check["detail"])
                    )
                    conn.mav.send(result_msg)
                    print(f"[Mock] Result {seq+1}/{TOTAL_CHECKS}: {check['check_id']} ({check['group']}) -> {check['detail']}")

                # Send ACK: completed
                ack_msg = conn.mav.aerothon_command_ack_encode(
                    request_id=req_id,
                    reason_code=0,
                    command=cmd,
                    result=ACK_IN_PROGRESS,
                    progress_pct=100,
                    message=b"Preflight completed"
                )
                conn.mav.send(ack_msg)
                print(f"[Mock] Sent COMMAND_ACK (completed)\n")

        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"[Mock] Error: {e}")
            time.sleep(0.1)

    conn.close()
    print("Mock provider stopped")

if __name__ == '__main__':
    main()