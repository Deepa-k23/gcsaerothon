pragma Singleton
import QtQuick

QtObject {
    readonly property string family:      "Rosarivo"
    readonly property string dataFamily:  "Rosarivo"
    readonly property string fallback:    "Rosarivo, Open Sans, Roboto, system-ui, sans-serif"
    readonly property string dataFallback:"Rosarivo, 'Courier New', monospace"

    readonly property int micro:          16
    readonly property int caption:        16
    readonly property int label:          16
    readonly property int body:           16
    readonly property int section:        18
    readonly property int value:          20
    readonly property int heading:        22
    readonly property int display:        28
    readonly property int telemetry:      22
    readonly property int telemetryLarge: 28
    readonly property int hudValue:       22

    readonly property int monoCaption:    16
    readonly property int monoMicro:      12
    readonly property string monoMicroFont:  dataFamily + " " + monoMicro + "px"
    readonly property string monoCaptionFont: dataFamily + " " + monoCaption + "px"

    readonly property real labelSpacing:     0.5
    readonly property real sectionSpacing:   0.8
    readonly property real headingSpacing:   1.2

    readonly property int weightNormal:   Font.Normal
    readonly property int weightMedium:   Font.Medium
    readonly property int weightBold:     Font.Bold
    readonly property int weightDemiBold: Font.DemiBold
}
