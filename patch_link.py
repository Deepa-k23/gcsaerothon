import re

with open('/home/deepa/AeroTHON-GCS-V2/src/Comms/LinkInterface.cc', 'r') as f:
    content = f.read()

# Add include
content = content.replace('#include "LinkInterface.h"\n', '#include "LinkInterface.h"\n#include "MAVLinkProtocol.h"\n')

# Add emit
replacement = '''
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    const int len = mavlink_msg_to_send_buffer(buffer, &message);
    writeBytesThreadSafe(reinterpret_cast<const char *>(buffer), len);
    
    emit MAVLinkProtocol::instance()->messageSent(this, message);
'''
content = content.replace('''
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    const int len = mavlink_msg_to_send_buffer(buffer, &message);
    writeBytesThreadSafe(reinterpret_cast<const char *>(buffer), len);
''', replacement)

with open('/home/deepa/AeroTHON-GCS-V2/src/Comms/LinkInterface.cc', 'w') as f:
    f.write(content)

