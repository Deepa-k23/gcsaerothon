import QtQuick
import QtQuick.Layouts
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    property bool showBorder: false

    color:        showBorder ? AeroColors.surface : "transparent"
    border.color: AeroColors.border
    border.width: showBorder ? AeroMetrics.borderThin : 0
    radius:       showBorder ? AeroMetrics.radiusPanel : 0

    // ── Properties ────────────────────────────────────────────────────────────
    property var  vehicle

    signal actionRequested(string actionId)

    // ── Implicit size ─────────────────────────────────────────────────────────
    implicitHeight: AeroMetrics.gap + sectionLabel.height + AeroMetrics.gapSmall
                    + actionGrid.implicitHeight + AeroMetrics.gap
    implicitWidth:  actionGrid.implicitWidth + (AeroMetrics.gap * 2)

    // ── Section label ─────────────────────────────────────────────────────────
    Text {
        id:    sectionLabel
        text:  "QUICK ACTIONS"
        color: AeroColors.textSecondary
        font.family: AeroTypography.family
        font.pixelSize: AeroTypography.caption
        font.weight:    Font.Medium
        anchors {
            top:       parent.top
            left:      parent.left
            topMargin: AeroMetrics.gap
            leftMargin: AeroMetrics.gap
        }
    }

    // ── Action grid ───────────────────────────────────────────────────────────
    RowLayout {
        id:      actionGrid
        
        spacing: AeroMetrics.gapSmall
        anchors {
            top:    sectionLabel.bottom
            left:   parent.left
            right:  parent.right
            topMargin: AeroMetrics.gapSmall
            leftMargin: AeroMetrics.gap
            rightMargin: AeroMetrics.gap
        }

        readonly property var actions: [
            { id: "reboot",  label: "REBOOT",  buttonState: "critical", buttonStyle: "secondary" },
            { id: "rtl",     label: "RTL",     buttonState: "default",  buttonStyle: "secondary" },
            { id: "land",    label: "LAND",    buttonState: "default",  buttonStyle: "secondary" },
            { id: "mission", label: "MISSION", buttonState: "default",  buttonStyle: "secondary" }
        ]

        Repeater {
            model: actionGrid.actions

            delegate: AeroButton {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.minimumWidth: 10
                
                label:       modelData.label
                buttonState: root.vehicle !== null ? modelData.buttonState : "disabled"
                buttonStyle: modelData.buttonStyle

                onClicked: {
                    root.actionRequested(modelData.id)
                }
            }
        }
    }
}
