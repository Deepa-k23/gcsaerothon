# Telemetry & MAVLink Integration Report

## 1. Exact QGC files inspected
- `src/Comms/MAVLinkProtocol.h` / `.cc`
- `src/Comms/LinkInterface.h` / `.cc`
- `src/Vehicle/Vehicle.h` / `.cc`
- `src/FlyView/FlyViewMap.qml`
- `custom/src/AeroMessageModel.h` / `.cc`
- `custom/src/AeroMessageFeed.qml`
- `custom/src/gods-eye-view-dist/assets/index-CSHkOiP6.js` (compiled God's Eye UI)

## 2. Existing activeVehicle coordinate path
`QGroundControl.multiVehicleManager.activeVehicle` broadcasts property changes when the MAVLink backend decodes a new `GLOBAL_POSITION_INT` message. We bound a connection in `FlyViewMap.qml` to listen for `onCoordinateChanged` and `onHeadingChanged` to bridge the latest values to WebEngine instantly.

## 3. Existing MAVLink receive path
All incoming MAVLink packets hit `MAVLinkProtocol::receiveBytes`, which eventually broadcasts the `messageReceived(LinkInterface*, mavlink_message_t)` signal across QGC.

## 4. Existing MAVLink transmit path
Every MAVLink message sent by QGC (from `Vehicle`, `FirmwarePlugin`, `ParameterManager`, etc.) flows through the single chokepoint `LinkInterface::sendMessageThreadSafe()`.

## 5. How AeroMessageModel now receives RX messages
The model binds directly to `MAVLinkProtocol::instance()->messageReceived` to capture all inbound packets.

## 6. How AeroMessageModel now receives TX messages
I injected a new signal into `MAVLinkProtocol.h`: `void messageSent(LinkInterface* link, const mavlink_message_t& message);` and patched `LinkInterface.cc` to emit it immediately after serializing and writing the bytes to the thread-safe socket. The model binds to this signal to capture all outbound packets.

## 7. How COMMAND_LONG/COMMAND_ACK are represented
`AeroMessageModel.cc` was expanded with a static `extractSummary(const mavlink_message_t&)` helper. When it detects `MAVLINK_MSG_ID_COMMAND_LONG`, it parses the `mavlink_command_long_t` struct to extract the command enum ID. When it detects `COMMAND_ACK`, it extracts both the command and maps the result (e.g., `ACCEPTED`). The UI displays these dynamically formatted strings (e.g., `COMMAND_LONG — CMD: 400`).

## 8. How STATUSTEXT/errors remain handled
`STATUSTEXT` is fully parsed by `extractSummary` and retained in the telemetry feed. It falls into the normal MAVLink pipeline. The `AeroAlertModel` remains entirely intact and untouched for critical severity visual alerts.

## 9. How the God's Eye vehicle marker receives coordinates
`FlyViewMap.qml` evaluates `activeVehicle.coordinate`, maps the values, and executes `window.updateAeroTHONTelemetry(payload)` inside WebEngine.

## 10. How heading is applied
The `Cce()` function in `index-CSHkOiP6.js` calculates `headingRad` using `Cesium.Math.toRadians(heading)`. The cyan aviation marker is attached as a `Cesium.Billboard` and dynamically mapped using `rotation: -headingRad`. 

## 11. How vehicle-follow behavior works
The first valid coordinate triggers `viewer.trackedEntity = entity`, which forces Cesium to lock the camera dead-center onto the marker smoothly. A `moveStart` event listener is permanently attached to the Cesium camera—if the user clicks and drags the map (manual pan), it instantly clears `viewer.trackedEntity = undefined` to allow free-flight inspection while the marker continues to move independently underneath.

## 12. Files changed
- `src/Comms/MAVLinkProtocol.h`
- `src/Comms/LinkInterface.cc`
- `src/FlyView/FlyViewMap.qml`
- `custom/src/AeroMessageModel.h`
- `custom/src/AeroMessageModel.cc`
- `custom/src/AeroMessageFeed.qml`
- `custom/src/gods-eye-view-dist/assets/index-CSHkOiP6.js`

## 13. Build result
Ninja compilation of `Release/AeroTHON-GCS` completed perfectly with `0` errors.

## 14. Runtime verification result
Ran headlessly mapping Chromium verbose logging. The injected JS bootstrapper correctly resolved the fallback logic when tiles were unavailable due to missing credentials, throwing zero syntax errors and retaining the `window.updateAeroTHONTelemetry` hook exactly as designed. The `messageSent` and `messageReceived` pipeline successfully initialized.
