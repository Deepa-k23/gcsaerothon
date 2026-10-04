with open('custom/CMakeLists.txt', 'r') as f:
    content = f.read()

if 'src/AeroMessageModel.cc' not in content:
    content = content.replace('src/AeroAlertModel.cc', 'src/AeroAlertModel.cc\n    src/AeroMessageModel.cc')
    with open('custom/CMakeLists.txt', 'w') as f:
        f.write(content)

