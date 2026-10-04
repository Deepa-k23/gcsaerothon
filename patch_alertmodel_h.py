import re

with open('custom/src/AeroAlertModel.h', 'r') as f:
    content = f.read()

content = content.replace('#include <QtCore/QTimer>', '')
content = re.sub(r'    QList<AeroAlert> m_pendingAlerts;\n    QTimer m_batchTimer;\n    void flushPendingAlerts\(\);\n', '', content)

with open('custom/src/AeroAlertModel.h', 'w') as f:
    f.write(content)
