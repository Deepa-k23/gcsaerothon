pragma Singleton
import QtQuick

QtObject {
    // Line weights
    readonly property real lineWidth:      1.5
    readonly property real gridLineWidth:  0.5
    readonly property real axisLineWidth:  1.0

    // Area fill opacity under line
    readonly property real fillOpacity:    0.15
    readonly property real gridOpacity:    0.08

    // Default rolling window sizes (samples at 1Hz)
    readonly property int windowAltitude:  25
    readonly property int windowSpeed:     25
    readonly property int windowBattery:   45
    readonly property int windowWFB:       25

    // Colors (from AeroColors — reference by string for singleton independence)
    // Components should use AeroColors.chartLine etc. directly

    // Dot at latest data point
    readonly property real dotRadius:      2.5
    readonly property bool showDot:        true
}
