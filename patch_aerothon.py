import re

with open('custom/src/AerothonPlugin.cc', 'r') as f:
    content = f.read()

# include
if 'AeroMessageModel.h' not in content:
    content = content.replace('#include "AeroAlertModel.h"', '#include "AeroAlertModel.h"\n#include "AeroMessageModel.h"')

# qmlRegisterSingletonType
if 'AeroMessageModel' not in content:
    reg = '''    qmlRegisterSingletonType<AeroMessageModel>("AeroTHON", 1, 0, "AeroMessageModel",
        [](QQmlEngine*, QJSEngine*) -> QObject* {
            return AeroMessageModel::instance();
        });
'''
    content = content.replace('    qmlRegisterSingletonType<AeroAlertModel>("AeroTHON", 1, 0, "AeroAlertModel",', reg + '\n    qmlRegisterSingletonType<AeroAlertModel>("AeroTHON", 1, 0, "AeroAlertModel",')

with open('custom/src/AerothonPlugin.cc', 'w') as f:
    f.write(content)

