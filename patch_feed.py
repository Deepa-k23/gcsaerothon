import re

with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageFeed.qml', 'r') as f:
    content = f.read()

replacement = '''
            AeroMessageRow {
                id: msgRow
                width:     parent.width
                priority:  model.direction === "TX" ? "MISSION" : (model.messageName === "STATUSTEXT" ? "WARNING" : "INFO")
                source:    model.direction + " " + model.sysId
                message:   model.summary !== "" ? model.messageName + " \u2014 " + model.summary : model.messageName
                detail:    "Direction: " + model.direction + "\\n" +
                           "System ID: " + model.sysId + "\\n" +
                           "Component ID: " + model.compId + "\\n" +
                           "Message ID: " + model.msgId + "\\n" +
                           "Message: " + model.messageName + "\\n" +
                           "Summary: " + model.summary
                alertId:   model.id
                acknowledged: true
                active: false
                timestamp: Qt.formatTime(new Date(model.timestamp), "HH:mm:ss")
            }
'''
content = re.sub(r'AeroMessageRow \{[\s\S]*?timestamp: Qt\.formatTime\(new Date\(model\.timestamp\), "HH:mm:ss"\)\n\s*\}', replacement.strip(), content)

with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageFeed.qml', 'w') as f:
    f.write(content)
