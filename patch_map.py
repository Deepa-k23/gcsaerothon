with open("src/FlyView/FlyViewMap.qml", "r") as f:
    content = f.read()

content = content.replace("Item { id: _pipState }", """Item { id: _pipState }

    Connections {
        target: _planMasterController ? _planMasterController.missionController : null
        function onVisualItemsChanged() { _updateMissionItems(); }
    }

    function _updateMissionItems() {
        if (!_planMasterController || !_planMasterController.missionController) return;
        var items = _planMasterController.missionController.visualItems;
        if (!items) return;
        var jsonItems = [];
        for (var i = 0; i < items.count; i++) {
            var item = items.get(i);
            if (item && item.coordinate && item.coordinate.isValid) {
                jsonItems.push({lat: item.coordinate.latitude, lon: item.coordinate.longitude});
            }
        }
        webEngineView.runJavaScript("if (window.updateMissionItems) { window.updateMissionItems('" + JSON.stringify(jsonItems) + "'); }");
    }""")

content = content.replace("_updateVehiclePosition();", "_updateVehiclePosition(); _updateMissionItems();")

with open("src/FlyView/FlyViewMap.qml", "w") as f:
    f.write(content)
