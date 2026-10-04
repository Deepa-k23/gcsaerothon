import re

with open('custom/src/UavDashboard.qml', 'r') as f:
    content = f.read()

# Remove case "systems" block
content = re.sub(r'\s*case "systems":\s*root\.activeScreen = screenId\s*mainWindow\.showTool\(qsTr\("AeroTHON Systems"\),\s*"qrc:/qml/QGroundControl/FlyView/AeroSystemsScreen\.qml",\s*"/qmlimages/Analyze\.svg"\)\s*break', '', content)

# Remove case "preflight" block
content = re.sub(r'\s*case "preflight":\s*root\.activeScreen = screenId\s*mainWindow\.showTool\(qsTr\("AeroTHON Preflight"\),\s*"qrc:/qml/QGroundControl/FlyView/AeroPreflightPanel\.qml",\s*"/check\.svg"\)\s*break', '', content)

# Remove telemetry rails
content = re.sub(r'    // ── Telemetry rail \(bottom\) ──+.*?AeroTelemetryRail \{.*?\n    }', '', content, flags=re.DOTALL)
content = re.sub(r'    // ── Mission graph strip ──+.*?AeroMissionGraphStrip \{.*?\n    }', '', content, flags=re.DOTALL)

# Fix anchors
content = content.replace('bottom: missionGraphStrip.top', 'bottom: parent.bottom')
content = content.replace('anchors.bottom: telemetryRail.top', 'anchors.bottom: parent.bottom')

# Remove onPreflightRequested
content = re.sub(r'\s*onPreflightRequested: \{ root\.navigateTo\("preflight"\) \}', '', content)

with open('custom/src/UavDashboard.qml', 'w') as f:
    f.write(content)
