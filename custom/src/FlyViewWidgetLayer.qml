import QtQuick
import QGroundControl.Controls

Item {
    property var parentToolInsets
    property var mapControl
    property var viewer3DCameraController
    property var totalToolInsets: emptyInsets

    QGCToolInsets { id: emptyInsets }
}
