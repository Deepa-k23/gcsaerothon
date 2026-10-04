import re
with open('custom/src/AeroTHONManager.cc', 'r') as f:
    c = f.read()

c = re.sub(r'void AeroTHONManager::_handleAerothonPreflightResult\(const mavlink_message_t &message\)\n\{.*?\}\n\n', '\n', c, flags=re.DOTALL)

with open('custom/src/AeroTHONManager.cc', 'w') as f:
    f.write(c)

