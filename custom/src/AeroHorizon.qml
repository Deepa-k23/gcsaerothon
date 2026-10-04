import QtQuick
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    // ── Properties ────────────────────────────────────────────────────────────
    property var vehicle

    // Null-safe telemetry bindings
    property real rollDeg:  vehicle && vehicle.roll ? Number(vehicle.roll.value) : 0
    property real pitchDeg: vehicle && vehicle.pitch ? Number(vehicle.pitch.value) : 0
    property real yawDeg:   vehicle && vehicle.heading ? Number(vehicle.heading.value) : 0
    property real speedVal: vehicle && vehicle.groundSpeed ? Number(vehicle.groundSpeed.value) : NaN
    property real altVal:   vehicle && vehicle.altitudeRelative ? Number(vehicle.altitudeRelative.value) : NaN

    property bool showBorder: false

    // ── Appearance ────────────────────────────────────────────────────────────
    color:        showBorder ? AeroColors.surface : "transparent"
    border.color: AeroColors.border
    border.width: showBorder ? 1 : 0
    radius:       showBorder ? AeroMetrics.radiusPanel : 0

    // ── Header ────────────────────────────────────────────────────────────────
    Text {
        id:    attitudeHeader
        text:  "ATTITUDE"
        color: AeroColors.textPrimary
        font.pixelSize: AeroTypography.section
        font.weight:    Font.DemiBold
        anchors {
            left: parent.left
            top:  parent.top
            leftMargin: 10
            topMargin:  8
        }
    }

    // ── Top-right corner accent clip aesthetic ─────────────────────────────
    Canvas {
        id:      cornerCanvas
        width:   36
        height:  36
        anchors { top: parent.top; right: parent.right }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.beginPath()
            ctx.moveTo(width, 0)
            ctx.lineTo(width, height)
            ctx.lineTo(0, 0)
            ctx.closePath()
            ctx.strokeStyle = AeroColors.accent
            ctx.lineWidth   = 1.5
            ctx.stroke()
        }
    }

    // ── Horizon area ──────────────────────────────────────────────────────────
    Item {
        id: horizonArea
        anchors {
            top:    attitudeHeader.bottom
            left:   parent.left
            right:  parent.right
            topMargin: 6
        }
        height: root.height - attitudeHeader.height - rpyRow.height - 24

        // Speed tape (left)
        Rectangle {
            id:    speedTape
            width: 48
            anchors {
                left:   parent.left
                top:    parent.top
                bottom: parent.bottom
                leftMargin: 4
            }
            color:  AeroColors.hudTape
            radius: 2

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text:  isNaN(root.speedVal) ? "--" : root.speedVal.toFixed(2)
                    color: AeroColors.textPrimary
                    font.family: AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                    font.weight:    Font.DemiBold
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text:  "SPD"
                    color: AeroColors.textMuted
                    font.family: AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Altitude tape (right)
        Rectangle {
            id:    altTape
            width: 48
            anchors {
                right:  parent.right
                top:    parent.top
                bottom: parent.bottom
                rightMargin: 4
            }
            color:  AeroColors.hudTape
            radius: 2

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text:  isNaN(root.altVal) ? "--" : root.altVal.toFixed(2)
                    color: AeroColors.textPrimary
                    font.family: AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                    font.weight:    Font.DemiBold
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text:  "ALT"
                    color: AeroColors.textMuted
                    font.family: AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Horizon clip area (between tapes)
        Item {
            id:  horizonClip
            clip: true
            anchors {
                left:  speedTape.right
                right: altTape.left
                top:   parent.top
                bottom: parent.bottom
                leftMargin:  2
                rightMargin: 2
            }

            // Heading readout at top center
            Rectangle {
                id:    headingBox
                z:     10
                width: 60
                height: 20
                radius: 3
                color:  AeroColors.hudTape
                anchors {
                    top:              parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin:        4
                }

                Text {
                    text:  root.yawDeg.toFixed(2) + "°"
                    color: AeroColors.textPrimary
                    font.family: AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                    anchors.centerIn: parent
                }
            }

            // Rotating horizon
            Item {
                id:       horizonRotator
                width:    parent.width  * 2.5
                height:   parent.height * 2.5
                x:        (parent.width  - width)  / 2
                y:        (parent.height - height) / 2
                rotation: -root.rollDeg
                transformOrigin: Item.Center

                Behavior on rotation {
                    NumberAnimation {
                        duration:    AeroMotion.hud
                        easing.type: Easing.OutQuad
                    }
                }

                // Sky
                Rectangle {
                    id:     skyRect
                    color:  AeroColors.hudSky
                    width:  parent.width
                    anchors.top: parent.top
                    height: parent.height / 2 + root.pitchDeg * 1.8

                    Behavior on height {
                        NumberAnimation { duration: AeroMotion.hud }
                    }
                }

                // Ground
                Rectangle {
                    id:     groundRect
                    color:  AeroColors.hudGround
                    width:  parent.width
                    anchors.bottom: parent.bottom
                    height: parent.height / 2 - root.pitchDeg * 1.8

                    Behavior on height {
                        NumberAnimation { duration: AeroMotion.hud }
                    }
                }

                // Horizon line
                Rectangle {
                    x:      0
                    y:      parent.height / 2 + root.pitchDeg * 1.8 - 1
                    width:  parent.width
                    height: 2
                    color:  AeroColors.hudHorizon

                    Behavior on y {
                        NumberAnimation { duration: AeroMotion.hud }
                    }
                }

                // Pitch ladder lines
                Repeater {
                    model: [-20, -15, -10, -5, 5, 10, 15, 20]

                    delegate: Item {
                        required property int modelData
                        x:      (horizonRotator.width  - ladderLine.width)  / 2
                        y:      horizonRotator.height  / 2 + modelData * 1.8 - 1

                        Behavior on y {
                            NumberAnimation { duration: AeroMotion.hud }
                        }

                        Rectangle {
                            id:     ladderLine
                            width:  Math.abs(modelData) % 10 === 0 ? 60 : 36
                            height: 1
                            color:  AeroColors.textPrimary
                            opacity: 0.7
                        }

                        Text {
                            text:  Math.abs(modelData).toString()
                            color: AeroColors.textPrimary
                            font.family: AeroTypography.dataFamily
                            font.pixelSize: AeroTypography.caption
                            opacity: 0.7
                            anchors {
                                right:          ladderLine.left
                                verticalCenter: ladderLine.verticalCenter
                                rightMargin:    4
                            }
                            visible: Math.abs(modelData) % 10 === 0
                        }
                    }
                }
            }

            // Fixed aircraft center-wings
            Item {
                z:     5
                anchors.centerIn: parent

                // Left wing
                Rectangle {
                    x:      -46
                    y:      -2
                    width:  36
                    height: 4
                    color:  "white"
                    radius: 2
                }
                // Center dot
                Rectangle {
                    x:      -5
                    y:      -5
                    width:  10
                    height: 10
                    radius: 5
                    color:  "white"
                }
                // Right wing
                Rectangle {
                    x:      10
                    y:      -2
                    width:  36
                    height: 4
                    color:  "white"
                    radius: 2
                }
            }
        }
    }

    // ── Roll/Pitch/Yaw row ────────────────────────────────────────────────────
    Row {
        id:     rpyRow
        anchors {
            bottom:      parent.bottom
            left:        parent.left
            right:       parent.right
            bottomMargin: 8
        }
        height:  44
        spacing: 0

        Repeater {
            model: [
                { label: "ROLL",  value: root.rollDeg  },
                { label: "PITCH", value: root.pitchDeg },
                { label: "YAW",   value: root.yawDeg   }
            ]

            delegate: Item {
                required property var modelData
                width:  rpyRow.width / 3
                height: rpyRow.height

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text:  modelData.value.toFixed(2) + "°"
                        color: AeroColors.textPrimary
                        font.pixelSize: AeroTypography.value
                        font.family:    AeroTypography.dataFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text:  modelData.label
                        color: AeroColors.textMuted
                        font.pixelSize: AeroTypography.caption
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
