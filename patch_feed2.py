import re

with open('custom/src/AeroMessageFeed.qml', 'r') as f:
    content = f.read()

# I see an extra } at line 173 and 174!
# The original code was:
#            AeroMessageRow {
#                // ...
#                opacity: model.active ? 1.0 : 0.55
#                onAcknowledgeRequested: function(alertId) { AeroAlertModel.acknowledge(alertId) }
#            }
#        }
# Wait, my regex `re.sub(r'            AeroMessageRow \{[\s\S]*?\}', msg_row, content)` replaced ONLY the `AeroMessageRow { ... }` block! But `msg_row` string didn't have extra braces.
# Ah, `re.sub` `[\s\S]*?\}` matched up to the FIRST `}`! But `AeroMessageRow` had nested braces? No: `onAcknowledgeRequested: function(alertId) { AeroAlertModel.acknowledge(alertId) }` HAS BRACES!
# So it left `\n        }`!

content = re.sub(r'            AeroMessageRow \{[\s\S]*?timestamp: Qt.formatTime\(new Date\(model.timestamp\), "HH:mm:ss"\)\n            \}\n            \}\n        \}', 
                 '''            AeroMessageRow {
                id: msgRow
                width:     parent.width
                priority:  "INFO"
                source:    "SYS " + model.sysId + " COMP " + model.compId
                message:   model.messageName
                detail:    "Msg ID: " + model.msgId
                alertId:   model.id
                acknowledged: true
                active: false
                timestamp: Qt.formatTime(new Date(model.timestamp), "HH:mm:ss")
            }
        }''', content)

with open('custom/src/AeroMessageFeed.qml', 'w') as f:
    f.write(content)
