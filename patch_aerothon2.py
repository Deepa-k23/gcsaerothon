import re

with open('custom/src/AerothonPlugin.cc', 'r') as f:
    content = f.read()

reg = '''    qmlRegisterSingletonType<AeroMessageModel>("AeroTHON", 1, 0, "AeroMessageModel",
        [](QQmlEngine*, QJSEngine*) -> QObject* {
            return AeroMessageModel::instance();
        });
'''
content = content.replace('    qmlRegisterSingletonType<AeroAlertModel>("AeroTHON", 1, 0, "AeroAlertModel",', reg + '    qmlRegisterSingletonType<AeroAlertModel>("AeroTHON", 1, 0, "AeroAlertModel",')

with open('custom/src/AerothonPlugin.cc', 'w') as f:
    f.write(content)
