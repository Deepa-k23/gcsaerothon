import re
with open('custom/src/UavDashboard.qml', 'r') as f:
    c = f.read()

# Remove 'systems' case
c = re.sub(r'\s*case "systems":.*?break\n', '\n', c, flags=re.DOTALL)
# Remove 'preflight' case
c = re.sub(r'\s*case "preflight":.*?break\n', '\n', c, flags=re.DOTALL)

with open('custom/src/UavDashboard.qml', 'w') as f:
    f.write(c)
