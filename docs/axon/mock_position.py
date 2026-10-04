import time
import math
from pymavlink import mavutil

def main():
    conn = mavutil.mavlink_connection('udpout:127.0.0.1:14550', source_system=1, source_component=1)
    print("Mock Position Sender Started")

    lat_start = 37.7749
    lon_start = -122.4194
    
    t = 0
    while True:
        # Heartbeat
        conn.mav.heartbeat_send(
            mavutil.mavlink.MAV_TYPE_QUADROTOR,
            mavutil.mavlink.MAV_AUTOPILOT_PX4,
            mavutil.mavlink.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
            0,
            mavutil.mavlink.MAV_STATE_ACTIVE
        )
        
        # Position
        lat = lat_start + 0.0001 * math.sin(t)
        lon = lon_start + 0.0001 * math.cos(t)
        hdg = (t * 10) % 360
        
        conn.mav.global_position_int_send(
            int(time.time() * 1000),
            int(lat * 1e7),
            int(lon * 1e7),
            50000,
            50000,
            0,
            0,
            0,
            int(hdg * 100) # centidegrees
        )
        
        # Statustext
        if t % 50 == 0:
            conn.mav.statustext_send(mavutil.mavlink.MAV_SEVERITY_WARNING, b"Test Warning from Mock Vehicle")
            
        t += 0.5
        time.sleep(0.1)

if __name__ == '__main__':
    main()
