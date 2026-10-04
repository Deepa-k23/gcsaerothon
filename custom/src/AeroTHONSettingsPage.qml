import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import AeroTHON 1.0

SettingsPage {
    objectName: "settingsPage_AeroTHON"

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Axon Companion")

        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.axonHostFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.axonPortFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.axonConnectTimeoutFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.axonReadTimeoutFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.axonPollIntervalFact
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Vehicle / Identity")

        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.droneNameFact
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Camera Names")

        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.camera1NameFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.camera2NameFact
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Interface")

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: fact.label
            fact: AeroTHONManager.reduceMotionFact
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Voice")

        FactCheckBoxSlider {
            Layout.fillWidth: true
            text: fact.label
            fact: AeroTHONManager.altitudeAnnouncementsFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.altitudeAnnouncementIntervalFact
        }
        QGCButton {
            text: qsTr("Test Voice")
            onClicked: QGroundControl.testAudioOutput()
        }
        QGCLabel {
            text: AeroTHONManager.voiceAvailable ? qsTr("Voice: Available") : qsTr("Voice: Unavailable")
            color: AeroTHONManager.voiceAvailable ? qgcPal.colorGreen : qgcPal.colorOrange
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Telemetry History")

        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.telemetryWindowAltitudeFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.telemetryWindowSpeedFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.telemetryWindowBatteryFact
        }
        LabelledFactTextField {
            Layout.fillWidth: true
            label: fact.label
            fact: AeroTHONManager.telemetryWindowWfbFact
        }
    }
}
