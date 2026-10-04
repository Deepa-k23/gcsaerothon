import re

with open('custom/src/AeroTHONManager.cc', 'r') as f:
    cc = f.read()

cc = re.sub(r'void AeroTHONManager::sendPreflightRequest.*?\}\n\n', '', cc, flags=re.DOTALL)
cc = re.sub(r'quint32 AeroTHONManager::sendPreflightRequest.*?\}\n\n', '', cc, flags=re.DOTALL)
cc = re.sub(r'void AeroTHONManager::sendPreflightRequest.*?\n\}', '', cc, flags=re.DOTALL)
cc = re.sub(r'quint32 AeroTHONManager::sendPreflightRequest.*?\n\}', '', cc, flags=re.DOTALL)

with open('custom/src/AeroTHONManager.cc', 'w') as f:
    f.write(cc)
