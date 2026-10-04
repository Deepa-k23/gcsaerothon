import QtQuick
import QGroundControl.Controls 1.0
import QtQuick.Effects
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

// AeroNavRail.qml
// Fixed compact navigation sidebar — icons only, never expands.
// Active icon is technical cyan; inactive icons are white/off-white.
// Hover shows a subtle background highlight only.
//
// Route items:
//   Flight, Plan, Vehicle, Parameters, Logs, Application Settings

Item {
    id: root

    property string activeScreen: "flight"
    signal screenRequested(string screenId)

    // ── Geometry: fixed width, never changes ───────────────────────────────────
    width: AeroMetrics.navRailWidth

    // ── Nav model ───────────────────────────────────────────────────────────────
    readonly property var navItems: [
        { iconSource: "qrc:/InstrumentValueIcons/airplane.svg",             label: "Flight",               id: "flight"   },
        { iconSource: "qrc:/InstrumentValueIcons/edit-pencil.svg",          label: "Plan",                 id: "plan"     },
        { iconSource: "qrc:/Custom/AeroTHON/assets/drone_top_view.svg",     label: "Vehicle",              id: "vehicle"  },
        { iconSource: "qrc:/InstrumentValueIcons/wrench.svg",               label: "Parameters",            id: "params"   },
        { iconSource: "qrc:/InstrumentValueIcons/chart-bar.svg",            label: "Logs",                 id: "logs"     },
        { iconSource: "qrc:/InstrumentValueIcons/cog.svg",                  label: "Application Settings", id: "settings" }
    ]

    // ── Background ──────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: AeroColors.surface

        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1
            color: AeroColors.border
        }
    }

    // ── Gliding active indicator ────────────────────────────────────────────────
    readonly property int _topPad: 4
    readonly property int _itemH:  52
    readonly property int _activeIdx: {
        for (let i = 0; i < navItems.length; ++i)
            if (navItems[i].id === root.activeScreen) return i
        return -1
    }

    Rectangle {
        id: activeIndicator
        x: 0
        y: root._topPad + root._activeIdx * root._itemH
        width: 3
        height: root._itemH
        radius: 1.5
        color: AeroColors.accent
        opacity: root._activeIdx >= 0 ? 1.0 : 0.0

        Behavior on y {
            NumberAnimation {
                duration: AeroMotion.nav
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: AeroMotion.fast }
        }
    }

    // ── Column of delegates ─────────────────────────────────────────────────────
    Column {
        id: navColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root._topPad
        }
        spacing: 0

        Repeater {
            model: root.navItems

            delegate: NavDelegate {
                required property var modelData
                required property int index

                navData:  modelData
                isActive: root.activeScreen === modelData.id
                onTap: root.screenRequested(modelData.id)
            }
        }
    }

    // ── Inline delegate: fixed compact, floating expanded label on hover ───────
    component NavDelegate: Item {
        id: nav
        z: nav._hovered ? 100 : 1

        property var navData
        property bool isActive: false
        signal tap()

        width: root.width
        height: root._itemH

        readonly property bool _hovered: hoverHandler.hovered
        HoverHandler { id: hoverHandler }

        // Floating wrapper that expands to the right on hover
        Rectangle {
            id: floatingBg
            x: 0
            y: 0
            width: root.width + (nav._hovered ? (navLabel.implicitWidth + 24) : 0)
            height: root._itemH
            radius: AeroMetrics.radiusSmall
            
            // Only clip during animation or when not hovered, but we want the text to fade in
            clip: true

            color: {
                if (nav.isActive)  return AeroColors.accentSubtle
                if (nav._hovered)  return AeroColors.surfaceHover
                return "transparent"
            }
            border.color: nav._hovered && !nav.isActive ? AeroColors.borderStrong : "transparent"
            border.width: 1

            Behavior on width {
                NumberAnimation {
                    duration: AeroMotion.fast
                    easing.type: AeroMotion.easingStandard
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: AeroMotion.fast
                    easing.type: AeroMotion.easingStandard
                }
            }

            // ── Icon centered in the original rail ──────────────────────────────
            readonly property int _iconX: (root.width - 22) / 2

            QGCColoredImage {
                id: _icon
                source: nav.navData ? nav.navData.iconSource : ""
                x: floatingBg._iconX
                y: (floatingBg.height - 22) / 2
                width: 22; height: 22
                sourceSize.width: 22; sourceSize.height: 22
                fillMode: Image.PreserveAspectFit
                color: nav.isActive ? AeroColors.accent : "#F4F7FA"
                opacity: nav.isActive ? 1.0 : (nav._hovered ? 1.0 : 0.9)
                Behavior on color {
                    ColorAnimation {
                        duration: AeroMotion.fast
                        easing.type: AeroMotion.easingStandard
                    }
                }
            }
            
            // Label
            Text {
                id: navLabel
                x: root.width
                anchors.verticalCenter: parent.verticalCenter
                text: nav.navData ? nav.navData.label : ""
                color: nav.isActive ? AeroColors.accent : "#F4F7FA"
                font.family: AeroTypography.family
                font.pixelSize: 14
                font.weight: Font.DemiBold
                opacity: (floatingBg.width > root.width + 10) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: AeroMotion.fast }
                }
            }
        }

        TapHandler { onTapped: nav.tap() }
    }
}