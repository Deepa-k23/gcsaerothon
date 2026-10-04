import re

with open('custom/src/AerothonPlugin.cc', 'r') as f:
    content = f.read()

reg = '''
    qmlRegisterSingletonInstance<AeroMessageModel>(
        "AeroTHON", 1, 0, "AeroMessageModel", AeroMessageModel::instance());
'''

# Find the place where AeroAlertModel is registered and insert before it
content = content.replace('    qmlRegisterSingletonInstance<AeroAlertModel>(', reg + '    qmlRegisterSingletonInstance<AeroAlertModel>(')

with open('custom/src/AerothonPlugin.cc', 'w') as f:
    f.write(content)
