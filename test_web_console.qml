import QtQuick
import QtWebEngine

WebEngineView {
    id: webEngineView
    url: "data:text/html,<html><body><script>console.log('HELLO_WORLD_TEST');</script></body></html>"
    onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceID) {
        console.log("QML CONSOLE: " + message);
    }
}
