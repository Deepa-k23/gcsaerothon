import QtQuick
import QtQuick.Layouts
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root
    anchors.fill: parent
    z: 999999

    // State machine
    property bool isPlaying: true
    property bool reduceMotion: false // respect QGC/system setting if possible, but keep simple

    // Animation progress values (0.0 to 1.0)
    property real phaseFadeIn: 0.0
    property real phaseZoom: 0.0
    property real phaseMove: 0.0
    property real phaseFadeOut: 0.0
    property real overlayFadeOut: 0.0

    // Final Logo metrics (Top-Left)
    readonly property real finalX: 8
    readonly property real finalY: (AeroMetrics.topBarHeight - 28) / 2
    readonly property real finalW: (root.width < 1500 ? 42 : 54) * 1.80
    readonly property real finalH: 28 * 1.80

    // Center Logo metrics
    readonly property real centerW: 240 * 1.80
    readonly property real centerH: 124 * 1.80

    // Center base coordinates
    readonly property real cx: (root.width - centerW) / 2
    readonly property real cy: (root.height - centerH) / 2

    // Zoom base coordinates (+5%)
    readonly property real zoomW: centerW * 1.05
    readonly property real zoomH: centerH * 1.05
    readonly property real zx: (root.width - zoomW) / 2
    readonly property real zy: (root.height - zoomH) / 2

    // Current calculated dimensions before move
    readonly property real currentStartW: centerW + (zoomW - centerW) * phaseZoom
    readonly property real currentStartH: centerH + (zoomH - centerH) * phaseZoom
    readonly property real currentStartX: cx + (zx - cx) * phaseZoom
    readonly property real currentStartY: cy + (zy - cy) * phaseZoom

    // Final blended coordinates for the Image
    property real logoW: currentStartW + (finalW - currentStartW) * phaseMove
    property real logoH: currentStartH + (finalH - currentStartH) * phaseMove
    property real logoX: currentStartX + (finalX - currentStartX) * phaseMove
    property real logoY: currentStartY + (finalY - currentStartY) * phaseMove

    // Opacities
    property real logoOpacity: phaseFadeIn - phaseFadeOut
    
    visible: isPlaying

    // Mouse area to block input safely
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false
        onClicked: {}
        onPressed: {}
        onReleased: {}
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: AeroColors.background
        opacity: 1.0 - overlayFadeOut
    }

    Image {
        id: animatedLogo
        source: "qrc:/Custom/AeroTHON/assets/gcslogo.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        
        x: logoX
        y: logoY
        width: logoW
        height: logoH
        opacity: logoOpacity
    }

    // Cinematic Animation Sequence
    SequentialAnimation {
        id: startupAnimation
        running: true

        // 0.0s - 1.0s: Fade In
        NumberAnimation {
            target: root
            property: "phaseFadeIn"
            from: 0.0; to: 1.0
            duration: 1000
            easing.type: Easing.InOutQuad
        }

        // 1.0s - 2.0s: Zoom IN (+5%)
        NumberAnimation {
            target: root
            property: "phaseZoom"
            from: 0.0; to: 1.0
            duration: 1000
            easing.type: Easing.InOutSine
        }

        // 2.0s - 6.8s: Travel and scale to Top-Left
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "phaseMove"
                from: 0.0; to: 1.0
                duration: 4800
                easing.type: Easing.InOutCubic
            }
            
            // Start fading out the background overlay late in the move (at 5.0s total, which is 3000ms into this 4800ms phase)
            // So the main UI reveals subtly while logo is traveling.
            SequentialAnimation {
                PauseAnimation { duration: 3000 }
                NumberAnimation {
                    target: root
                    property: "overlayFadeOut"
                    from: 0.0; to: 1.0
                    duration: 1800 // 5.0s to 6.8s total
                    easing.type: Easing.InOutQuad
                }
            }
        }

        // 6.8s - 7.6s: Hold at destination
        PauseAnimation {
            duration: 800
        }

        // 7.6s - 8.0s: Logo fades out
        NumberAnimation {
            target: root
            property: "phaseFadeOut"
            from: 0.0; to: 1.0
            duration: 400
            easing.type: Easing.InOutQuad
        }

        // Final cleanup
        ScriptAction {
            script: {
                root.isPlaying = false;
            }
        }
    }

    // Handle Reduced Motion
    Component.onCompleted: {
        if (root.reduceMotion) {
            startupAnimation.stop();
            phaseFadeIn = 1.0;
            phaseZoom = 1.0;
            phaseMove = 1.0;
            phaseFadeOut = 1.0;
            overlayFadeOut = 1.0;
            root.isPlaying = false;
        }
    }
}
