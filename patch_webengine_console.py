with open("src/FlyView/FlyViewMap.qml", "r") as f:
    c = f.read()
if "onConsoleMessage" not in c:
    c = c.replace("onLoadingChanged:", "onLoadingChanged:").replace("webEngineView {", "webEngineView {")
    # Actually just append it if not there
    c = c.replace("onLoadingChanged: function(loadRequest) {", "onConsoleMessage: function(level, message, lineNumber, sourceID) { console.log(\"WEBENGINE_CONSOLE:\", message); }\n        onLoadingChanged: function(loadRequest) {")
    with open("src/FlyView/FlyViewMap.qml", "w") as f:
        f.write(c)
