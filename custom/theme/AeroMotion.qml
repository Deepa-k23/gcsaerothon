pragma Singleton
import QtQuick

QtObject {
    property bool reduceMotion: false

    // ── Duration tokens ──────────────────────────────────────────────────────
    readonly property int instant:    0
    readonly property int micro:      reduceMotion ? 0 : 80
    readonly property int fast:       reduceMotion ? 0 : 120
    readonly property int normal:     reduceMotion ? 0 : 180
    readonly property int panel:      reduceMotion ? 0 : 250
    readonly property int camera:     reduceMotion ? 0 : 320
    readonly property int major:      reduceMotion ? 0 : 420
    readonly property int chart:      reduceMotion ? 0 : 280
    readonly property int telemetry:  reduceMotion ? 0 : 220  // number tween
    readonly property int color:      reduceMotion ? 0 : 180  // semantic color change
    readonly property int alert:      reduceMotion ? 0 : 150
    readonly property int heading:    reduceMotion ? 0 : 200  // angular interpolation
    readonly property int hud:        reduceMotion ? 0 : 60   // attitude (fast)
    readonly property int nav:        reduceMotion ? 0 : 160  // sidebar expand / active glide
    readonly property int statusSync: reduceMotion ? 0 : 220  // connection/LIVE state transition

    // ── Easing presets ───────────────────────────────────────────────────────
    readonly property int easingStandard:  Easing.OutCubic
    readonly property int easingEnter:     Easing.OutQuart
    readonly property int easingExit:      Easing.InCubic
    readonly property int easingSpring:    Easing.OutBack
}
