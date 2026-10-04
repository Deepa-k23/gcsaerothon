import re

with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageModel.cc', 'r') as f:
    content = f.read()

helper = '''
#include "QGCMAVLink.h"
#include <QDebug>
#include <QEnumMetaType>

static QString extractSummary(const mavlink_message_t& message) {
    switch (message.msgid) {
    case MAVLINK_MSG_ID_COMMAND_LONG: {
        mavlink_command_long_t cmd;
        mavlink_msg_command_long_decode(&message, &cmd);
        return QString("CMD: %1").arg(cmd.command);
    }
    case MAVLINK_MSG_ID_COMMAND_INT: {
        mavlink_command_int_t cmd;
        mavlink_msg_command_int_decode(&message, &cmd);
        return QString("CMD: %1").arg(cmd.command);
    }
    case MAVLINK_MSG_ID_COMMAND_ACK: {
        mavlink_command_ack_t ack;
        mavlink_msg_command_ack_decode(&message, &ack);
        return QString("CMD: %1 -> %2").arg(ack.command).arg(ack.result == MAV_RESULT_ACCEPTED ? "ACCEPTED" : "FAILED/OTHER");
    }
    case MAVLINK_MSG_ID_STATUSTEXT: {
        mavlink_statustext_t status;
        mavlink_msg_statustext_decode(&message, &status);
        return QString(QByteArray(status.text, strnlen(status.text, sizeof(status.text))));
    }
    case MAVLINK_MSG_ID_MISSION_ITEM:
    case MAVLINK_MSG_ID_MISSION_ITEM_INT:
        return QString("Mission Item");
    case MAVLINK_MSG_ID_HEARTBEAT:
        return QString(""); // Too spammy to summarize
    case MAVLINK_MSG_ID_SYS_STATUS:
        return QString("System Status");
    default:
        return QString("");
    }
}

'''

content = content.replace('#include "MAVLinkProtocol.h"\n', '#include "MAVLinkProtocol.h"\n' + helper)

new_connections = '''
    auto processMessage = [this](const mavlink_message_t& message, const QString& direction) {
        const mavlink_message_info_t* msgInfo = mavlink_get_message_info(&message);
        QString msgName = msgInfo ? QString(msgInfo->name) : QString("RAW_%1").arg(message.msgid);
        
        AeroMavlinkMessage msg;
        msg.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        msg.messageName = msgName;
        msg.direction = direction;
        msg.summary = extractSummary(message);
        msg.msgId = message.msgid;
        msg.sysId = message.sysid;
        msg.compId = message.compid;
        msg.timestamp = QDateTime::currentDateTimeUtc();
        
        m_pending.append(msg);
        
        if (m_pending.size() > 1000) {
            m_pending.removeFirst();
        }
    };

    connect(MAVLinkProtocol::instance(), &MAVLinkProtocol::messageReceived, this, [processMessage](LinkInterface*, const mavlink_message_t& message) {
        processMessage(message, "RX");
    });
    connect(MAVLinkProtocol::instance(), &MAVLinkProtocol::messageSent, this, [processMessage](LinkInterface*, const mavlink_message_t& message) {
        processMessage(message, "TX");
    });
'''

# We need to replace the old connect block
import re
content = re.sub(r'connect\(MAVLinkProtocol::instance\(\), &MAVLinkProtocol::messageReceived, this, \[this\]\(LinkInterface\*, const mavlink_message_t& message\) \{.*?\}\);', new_connections, content, flags=re.DOTALL)

with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageModel.cc', 'w') as f:
    f.write(content)
