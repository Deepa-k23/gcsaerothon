with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageModel.h', 'r') as f:
    content = f.read()

content = content.replace('    QString messageName;', '    QString messageName;\n    QString direction;\n    QString summary;')
content = content.replace('        MessageNameRole,', '        MessageNameRole,\n        DirectionRole,\n        SummaryRole,')

with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroMessageModel.h', 'w') as f:
    f.write(content)
