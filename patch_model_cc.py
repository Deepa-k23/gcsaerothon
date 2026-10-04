with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageModel.cc', 'r') as f:
    content = f.read()

# Replace roles block
content = content.replace('roles[MessageNameRole] = "messageName";', 'roles[MessageNameRole] = "messageName";\n    roles[DirectionRole] = "direction";\n    roles[SummaryRole] = "summary";')

# Replace data block
content = content.replace('case MessageNameRole: return msg.messageName;', 'case MessageNameRole: return msg.messageName;\n    case DirectionRole: return msg.direction;\n    case SummaryRole: return msg.summary;')

with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageModel.cc', 'w') as f:
    f.write(content)
