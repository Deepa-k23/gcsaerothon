#!/usr/bin/env python3
"""AeroTHON Mock Health Server
For GCS development without a real Axon. Returns realistic static data.
Usage: python mock_server.py [--port 5080]
"""
import time, math, random, argparse
from flask import Flask, jsonify
from datetime import datetime, timezone

START = time.time()
app = Flask(__name__)

@app.route('/api/v1/heartbeat')
def hb(): return jsonify({"status":"ok","ts":datetime.now(timezone.utc).isoformat()})

@app.route('/api/v1/health')
def health():
    t = time.time()-START
    return jsonify({
        "status":"online","version":"1.0.0-mock",
        "timestamp_utc":datetime.now(timezone.utc).isoformat(),
        "uptime_s":int(t),
        "system":{"cpu_pct":round(25+10*math.sin(t/20),1),"ram_pct":42.0,"temp_c":51.5,"storage_free_gib":14.2},
        "cameras":{
            "fpv":  {"status":"live","fps":round(29.5+random.uniform(-0.5,0.5),1)},
            "nadir":{"status":"live","fps":round(24.8+random.uniform(-0.5,0.5),1)},
        },
        "vision":{"status":"running","model":"yolov8n","inference_fps":14.2},
        "wfb":{"status":"running","rssi_dbm":-62,"snr_db":22,"packet_loss_pct":0.4,"bitrate_mbps":7.8},
        "mission":{"state":"area_search","active":True,"elapsed_s":int(t)},
    })

for ep in ('/api/v1/system','/api/v1/cameras','/api/v1/vision','/api/v1/wfb','/api/v1/mission'):
    app.add_url_rule(ep, ep, health)  # reuse same data for simplicity in mock

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5080)
    args = parser.parse_args()
    print(f"AeroTHON Mock Server running on port {args.port}")
    app.run(host='0.0.0.0', port=args.port, threaded=True)
