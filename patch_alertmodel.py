import re

with open('custom/src/AeroAlertModel.cc', 'r') as f:
    content = f.read()

# Revert flushPendingAlerts
content = re.sub(r'\nvoid AeroAlertModel::flushPendingAlerts\(\) \{[\s\S]*', '\n', content)

# Revert m_batchTimer and MAVLink connection
mavlink_conn = r'''    m_batchTimer\.setInterval\(250\);[\s\S]*?m_pendingAlerts\.removeFirst\(\);\n        \}\n    \}\);'''
content = re.sub(mavlink_conn, '', content)

# Revert 1000 back to 200
content = content.replace('if (m_alerts.size() > 1000) {', 'if (m_alerts.size() > 200) {')

with open('custom/src/AeroAlertModel.cc', 'w') as f:
    f.write(content)
