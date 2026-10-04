path = '/home/deepa/AeroTHON-GCS-V2/custom/src/AeroTopBar.qml'
with open(path, 'r') as f:
    content = f.read()

# I will add the logo to the right-most part of the RowLayout in AeroTopBar.
insertion_point = content.find('            Rectangle {\n                id: modeChip')
if insertion_point == -1:
    print("Could not find modeChip")
else:
    # Find the end of the RowLayout
    end_of_row = content.find('        }\n    }\n\n    Component {', insertion_point)
    
    new_logo = '''
            Rectangle {
                visible: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: AeroColors.border
            }

            Image {
                source: "qrc:/Custom/AeroTHON/assets/top_right_logo.png"
                Layout.preferredHeight: 28
                Layout.preferredWidth: 28
                fillMode: Image.PreserveAspectFit
                smooth: true
                Layout.alignment: Qt.AlignVCenter
            }
'''
    # We will insert it just before the closing brace of the RowLayout
    # Wait, the RowLayout ends before the Component { ... } block.
    # Let's just insert it after the modeChip block ends.
    end_of_modeChip = content.find('            }\n        }\n    }', insertion_point)
    if end_of_modeChip != -1:
        content = content[:end_of_modeChip+13] + new_logo + content[end_of_modeChip+13:]
        with open(path, 'w') as f:
            f.write(content)
        print("Success")
