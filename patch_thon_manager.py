import re

with open('custom/src/AeroTHONManager.h', 'r') as f:
    h = f.read()

h = re.sub(r'static constexpr quint32 MSG_AEROTHON_PREFLIGHT_RESULT\s*=\s*61006;\n', '', h)
h = re.sub(r'void _handleAerothonPreflightResult\(const mavlink_message_t &message\);\n', '', h)
h = re.sub(r'/// Send AEROTHON_COMMAND \(START_PREFLIGHT\) to the Axon via the active vehicle link\.\n\s*quint32 sendPreflightRequest\(\);\n', '', h)

with open('custom/src/AeroTHONManager.h', 'w') as f:
    f.write(h)

with open('custom/src/AeroTHONManager.cc', 'r') as f:
    cc = f.read()

cc = re.sub(r'\s*case MSG_AEROTHON_PREFLIGHT_RESULT:\n\s*_handleAerothonPreflightResult\(message\);\n\s*break;\n', '\n', cc)
cc = re.sub(r'void AeroTHONManager::_handleAerothonPreflightResult\(const mavlink_message_t &message\)\s*\{\s*mavlink_aerothon_preflight_result_t r\{\};\s*mavlink_msg_aerothon_preflight_result_decode\(&message, &r\);\s*// AeroPreflightManager hooks this directly in its onPreflightResultReceived\.\s*\}\n', '', cc)
cc = re.sub(r'quint32 AeroTHONManager::sendPreflightRequest\(\)\s*\{[^\}]+\}\n', '', cc)

with open('custom/src/AeroTHONManager.cc', 'w') as f:
    f.write(cc)
