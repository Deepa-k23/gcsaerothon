import re

with open('custom/src/AeroTelemetryRail.qml', 'r') as f:
    c = f.read()

# I will replace the TelemetryCell definition.
new_cell_qml = r'''    component TelemetryCell: Item {
        id: cell
        property string cellLabel:    ""
        property string cellValue:    "—"
        property real   cellValueNum: 0.0
        property bool   isNumeric:    false
        property int    precision:    1
        property string cellUnit:     ""
        property bool   showSparkline: false
        property var    sparklineData: []
        property color  valueColor:   AeroColors.textPrimary
        property string diagnosticId: ""

        implicitWidth:  60
        Layout.fillHeight: true

        Behavior on valueColor {
            ColorAnimation { duration: AeroMotion.color }
        }

        // Animated numeric value
        property real _animValue: cellValueNum
        Behavior on _animValue {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        // Subtle update effect
        Rectangle {
            id: updateFlash
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: AeroColors.accent
            opacity: 0.0
        }
        
        onCellValueChanged: if (!isNumeric) flashAnim.restart()
        onCellValueNumChanged: if (isNumeric) flashAnim.restart()

        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: updateFlash; property: "opacity"; from: 1.0; to: 0.0; duration: 300 }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           cell.cellLabel
                color:          AeroColors.textMuted
                font.family:    AeroTypography.family
                font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Text {
                    text:           cell.isNumeric ? cell._animValue.toFixed(cell.precision) : cell.cellValue
                    color:          cell.valueColor
                    font.family:    AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.telemetry
                    font.features:  {"tnum": 1}
                }
                Text {
                    text:           cell.cellUnit
                    color:          AeroColors.textMuted
                    font.family:    AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    anchors.bottom: parent.bottom
                    bottomPadding:  3
                }
            }

            AeroSparkline {
                visible:           cell.showSparkline
                model:             cell.sparklineData
                width:             40
                height:            16
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        TapHandler {
            enabled: cell.diagnosticId.length > 0
            onTapped: root.diagnosticRequested(cell.diagnosticId)
        }
    }'''

c = re.sub(r'    // ── Inline TelemetryCell component ──────────────────────────────────────────\n.*?    \}\n\n    // ── Cell row ────────────────────────────────────────────────────────────────', 
    '    // ── Inline TelemetryCell component ──────────────────────────────────────────\n' + new_cell_qml + '\n\n    // ── Cell row ────────────────────────────────────────────────────────────────', 
    c, flags=re.DOTALL)

# Now modify the usages
c = re.sub(r'cellValue:\s*root.groundSpeed.toFixed\(1\)', 'isNumeric: true\n            cellValueNum: root.groundSpeed\n            precision: 1', c)
c = re.sub(r'cellValue:\s*root.altitudeRelative.toFixed\(1\)', 'isNumeric: true\n            cellValueNum: root.altitudeRelative\n            precision: 1', c)
c = re.sub(r'cellValue:\s*root._displayHeading.toFixed\(0\)', 'isNumeric: true\n            cellValueNum: root._displayHeading\n            precision: 0', c)
c = re.sub(r'cellValue:\s*root.battery.toFixed\(0\)', 'isNumeric: true\n            cellValueNum: root.battery\n            precision: 0', c)

# WFB SNR might be NaN, so handle it
c = re.sub(r'cellValue:\s*isNaN\(root.wfbSnr\) \? "N/A" : root.wfbSnr.toFixed\(1\)', 'isNumeric: !isNaN(root.wfbSnr)\n            cellValueNum: isNaN(root.wfbSnr) ? 0 : root.wfbSnr\n            cellValue: "N/A"\n            precision: 1', c)

# For vertical speed, it's manually crafted inline, I should add the effect there as well, or just replace it with TelemetryCell. 
# But it has an AeroTrendIndicator and a +/- sign.
# Let's add the updateFlash to Vertical Speed Item as well.

vs_anim_block = r'''
        // 2. Vertical Speed
        Item {
            implicitWidth:  68
            Layout.fillHeight: true
            
            property real _animVS: root.verticalSpeed
            Behavior on _animVS { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            on_AnimVSChanged: vsFlashAnim.restart()
            
            Rectangle {
                id: vsUpdateFlash
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                color: AeroColors.accent
                opacity: 0.0
            }
            SequentialAnimation {
                id: vsFlashAnim
                NumberAnimation { target: vsUpdateFlash; property: "opacity"; from: 1.0; to: 0.0; duration: 300 }
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "VS"
                    color:          AeroColors.textMuted
                    font.family:    AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    font.capitalization: Font.AllUppercase
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Text {
                        text: {
                            var v = parent.parent.parent._animVS
                            return (v >= 0 ? "+" : "") + v.toFixed(1)
                        }
                        color:          AeroColors.textPrimary
                        font.family:    AeroTypography.dataFamily
                        font.pixelSize: AeroTypography.telemetry
                        font.features:  {"tnum": 1}
                    }
'''

c = re.sub(r'        // 2\. Vertical Speed\n        Item \{.*?Text \{\n                        text: \{\n                            var v = root\.verticalSpeed\n                            return \(v >= 0 \? "\+" : ""\) \+ v\.toFixed\(1\)\n                        \}', 
    vs_anim_block, c, flags=re.DOTALL)

with open('custom/src/AeroTelemetryRail.qml', 'w') as f:
    f.write(c)

