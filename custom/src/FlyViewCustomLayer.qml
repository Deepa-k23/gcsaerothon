import QtQuick
import QGroundControl.Controls

Item {
    property var parentToolInsets
    property var totalToolInsets: shellInsets
    property var mapControl

    QGCToolInsets { id: shellInsets }

    UavDashboard {
        anchors.fill: parent
        mapControl: parent.mapControl
    }
}
