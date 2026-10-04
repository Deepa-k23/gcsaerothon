import QtQuick
import QtLocation
import QtPositioning
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"

MapItemView {
    id: root
    model: AeroDetectionEventModel.positionedEvents

    delegate: MapQuickItem {
        id: marker
        required property var modelData
        coordinate: QtPositioning.coordinate(modelData.latitude, modelData.longitude, modelData.altitude)
        anchorPoint.x: markerBody.width / 2
        anchorPoint.y: markerBody.height / 2
        z: 50

        sourceItem: Item {
            id: markerBody
            width: details.visible ? 196 : 28
            height: details.visible ? 108 : 28

            Rectangle {
                anchors.fill: parent
                radius: details.visible ? AeroMetrics.radiusSmall : width / 2
                color: AeroColors.surfaceRaised
                border.width: 2
                border.color: marker.modelData.eventType === "OBSTACLE" ? AeroColors.detectionObstacle
                              : marker.modelData.eventType === "QR" ? AeroColors.detectionQR
                              : AeroColors.detectionBanner
            }

            Text {
                visible: !details.visible
                anchors.centerIn: parent
                text: marker.modelData.eventType === "QR" ? "QR" : "!"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily
                font.pixelSize: AeroTypography.caption
                font.bold: true
            }

            Column {
                id: details
                visible: false
                anchors.fill: parent
                anchors.margins: 8
                spacing: 3

                Text { text: marker.modelData.eventType; color: AeroColors.textPrimary; font.pixelSize: AeroTypography.caption; font.bold: true }
                Text { text: marker.modelData.missionNodeLabel || "No mission task"; color: AeroColors.textSecondary; font.pixelSize: AeroTypography.caption }
                Text {
                    text: marker.modelData.source + (marker.modelData.hasConfidence ? "  " + Math.round(marker.modelData.confidence * 100) + "%" : "  N/A")
                    color: AeroColors.textSecondary; font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
                }
                Text {
                    visible: marker.modelData.qrPayload !== ""
                    text: marker.modelData.qrPayload
                    color: AeroColors.textSecondary; font.pixelSize: AeroTypography.caption; elide: Text.ElideRight; width: parent.width
                }
                Text {
                    text: Qt.formatDateTime(new Date(marker.modelData.timestamp), "HH:mm:ss")
                    color: AeroColors.textMuted; font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
                }
            }

            TapHandler { onTapped: details.visible = !details.visible }
        }
    }
}
