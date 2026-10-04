import re

with open('custom/src/AeroAlertModel.cc', 'r') as f:
    content = f.read()

content = re.sub(r'connect\(AeroPreflightManager::instance\(\).*?\}\);', '', content, flags=re.DOTALL)

with open('custom/src/AeroAlertModel.cc', 'w') as f:
    f.write(content)

with open('custom/src/AeroSessionRecorder.cc', 'r') as f:
    content2 = f.read()

content2 = re.sub(r'connect\(AeroPreflightManager::instance\(\).*?\}\);', '', content2, flags=re.DOTALL)

with open('custom/src/AeroSessionRecorder.cc', 'w') as f:
    f.write(content2)
