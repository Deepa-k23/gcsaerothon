import re

with open('custom/src/AeroLeftPanel.qml', 'r') as f:
    content = f.read()

# Use regex to remove everything from PRE-FLIGHT CHECK button up to Quick action buttons
content = re.sub(r'// ── PRE-FLIGHT CHECK button.*?// Quick action buttons \(REBOOT', '// Quick action buttons (REBOOT', content, flags=re.DOTALL)

with open('custom/src/AeroLeftPanel.qml', 'w') as f:
    f.write(content)
