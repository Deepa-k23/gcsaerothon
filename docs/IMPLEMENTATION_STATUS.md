# AeroTHON-GCS V2 Implementation Status

Last verified: 2026-09-11 on branch `aerothon-v2`.

Status means runtime integration was checked, not merely that source files exist.

## Build foundation

| Subsystem | Status | Verification |
| --- | --- | --- |
| QGC configure | Complete and verified | Existing Release configuration regenerates successfully with Qt 6.11.2. |
| Custom MAVLink dialect | Complete and verified | Source-controlled `custom/mavlink/aerothon.xml` is staged by the pinned MAVLink CMake build, mavgen generates the `aerothon` headers, and QGC enum/instance-field generators consume it. The dialect extends QGC's normal `all.xml` message surface. |
| Incremental application build | Complete and verified | `cmake --build build --parallel 4` links `build/Release/AeroTHON-GCS`. |
| Clean configure and dialect generation | Complete and verified | A separate `/tmp` build configured successfully and its fresh `generate_c_headers` target generated 397 message types from the AeroTHON include closure. A complete second application compile was not repeated. |
| Packaging/AppImage | Complete and software-verified | `cmake --install build` stages the Qt/QML/GStreamer/Qt TextToSpeech runtime (fresh binary) and the `appimage` component creates `build/AeroTHON-GCS-x86_64.AppImage`. On 2026-09-11 the updated package (embedding `AeroAudioCoordinator`, `startNativeMission`, `droneName`, and the camera-name Facts) passed a desktop AppImage smoke run (no custom QML errors; the `AeroCameraColumn` import and `AeroNavRail` icon-prefix defects were fixed and verified). appimagetool SHA-256: `2c5512ca6251ec297f21338495583aaed6a8c0ec86afba5635f207554e6a8cbb`. AppImageLauncher auto-integrated it into `~/Applications` as `AeroTHON-GCS-x86_64_5e1346902bcf7fb2d9606e0c17373c3f.AppImage`. Earlier packaged AppImages (2026-09-11, e.g. `f708e1a8`, `5e38acab`) were re-wrapped with a stale 2026-09-06 binary and are superseded. |

## AeroTHON C++ layer

| Subsystem | Status | Notes |
| --- | --- | --- |
| `AerothonPlugin` | Partial | Builds, installs the QML override interceptor, and forwards AeroTHON MAVLink IDs. Broader lifecycle/runtime review remains. |
| `AeroTHONManager` | Partial | All six dialect messages use generated decoders. WFB metrics now have independent availability/freshness and cannot default to a synthetic healthy link; thresholds remain <10/10–30/>=30%. Axon polling uses persistent settings and rejects overlapping requests. The persistent manager owns 4-second relative-altitude speech scheduling; current Flight Time is directly bound to QGC's authoritative `Vehicle.flightTime` Fact. Live Axon/vehicle validation remains. |
| `AeroTHONSettings` | Complete and software-verified | Configurable Axon host/port/connect and read timeouts/poll interval, Reduce Motion, altitude-announcement enable/interval, and telemetry-history Facts use a source-controlled, schema-valid QGC FactMetaData resource. A native Settings entry edits those same persistent Facts; it is additive to QGC's generated settings pages. |
| `AeroPreflightManager` | Partial | Real QGC/AeroTHON checks are compiled in. Vehicle link, GPS Fact, sensor health, battery Fact, mission, Axon resources, camera freshness proxy, and WFB thresholds are asynchronous; unavailable/stale WFB now fails rather than producing false READY. Results feed the shared alert lifecycle. Target hardware validation and direct receiver-state injection remain. |
| `AeroMissionGraphModel` | Partial | The strip now owns a real model rather than fallback telemetry, follows confirmed AeroTHON mission-state changes, exposes timing accessors, and blocks structural edits while active. Persistence and live-event tests remain. |
| `AeroDetectionEventModel` | Complete, hardware-unverified | Shared session model records detection ID, receive/source time, mission time when available, type, active-node association, camera, confidence, QR payload, metadata, optional snapshot, and explicitly absent/valid position. Custom detection and QR signals are connected. Live source validation remains. |
| `AeroAlertModel` | Complete, hardware-unverified | Shared singleton has stable-key deduplication, acknowledgement separate from active/resolved lifecycle, occurrence counts, and critical latching. AeroTHON detections/ACKs/mission, Axon, cameras, PX4 status text, event-driven GPS/EKF/battery Facts, WFB freshness/thresholds, and preflight results are connected. Live source validation remains. |
| `AeroOperationalHealth` | Complete, hardware-unverified | Null-safe Vehicle GPS, estimator, and primary-battery Fact groups drive explicit NORMAL/WARNING/CRITICAL/UNKNOWN typed state and immediate alert transitions. GPS loss latches critical only after a previously valid fix. |
| `AeroSessionRecorder` | Complete, software-verified foundation | Separate JSONL operator journal records mission/graph transitions, detections, alerts, ACKs, preflight, 1 Hz Axon/WFB/position health, and bookmarks without changing QGC logs. Session/replay/preflight-history and coordinate-gated route-quality APIs exist. Structured mission summary JSON includes explicit nulls and WFB statistics. A smoke run produced a non-empty journal; alert-row serialization was also exercised and its temporary-iterator lifetime defect was fixed. |
| `AeroVideoReceiver` | Complete but hardware-unverified | Two independent persistent QGC backend receivers use QGC's native `mpegts://` source path: UDP 5600 MPEG-TS/H.264 → FPV and UDP 5604 MPEG-TS/H.264 → NADIR/OAK-D. The native source factory builds `udpsrc → tsdemux → parsebin/decoder → QGC sink`; LIVE remains gated by decoded frames, with FPS/health/retry independent per stream. The supplied standalone pipelines prove transport on the ground unit; simultaneous in-app decoded-frame validation still requires both producers running during GCS launch. |
| `AeroAudioCoordinator` | Complete, desktop-verified software | QML-singleton C++ coordinator bridges QGC `AudioOutput` with AeroTHON requirements: speaks WARNING/ERROR/CRITICAL `Vehicle.textMessageReceived` events using `sayAlert()`, announces altitude every 4 seconds while armed using `sayPeriodic()`, survives page navigation, and handles missing TTS gracefully. Uses real QGC `Vehicle.altitudeRelative` Fact and arm state. Desktop Qt TextToSpeech/espeak verification remains. |

## QML/application layer

| Subsystem | Status | Notes |
| --- | --- | --- |
| Application shell / Flight View override | Complete, software-verified | `AeroGlobalShell` is a persistent `MainWindow` overlay. Its navigation rail remains global, while the navigation-free operational `AeroTopBar` is painted only for Flight. Native `PlanView` and tool content use the released top-bar space without restoring stock QGC product chrome. Flight and native Plan were visually inspected at 1920 and 960 px application widths; map dominance, compact navigation, safety status, cameras, telemetry, messages, and mission strip remain intact. |
| Theme and component library | Complete, software-verified | AeroTHON resources resolve, loaded views use a 16 px minimum operational baseline, and motion uses centralized tokens. `ScreenTools` also establishes a minimum 12-point native QGC base (approximately 16 px at 96 DPI). `AerothonPlugin::paletteOverride` centrally bridges native QGC controls/pages to AeroTHON surfaces, text, borders, and semantic colors without replacing their controllers. |
| HUD | Complete but unverified | Present and loads; live high-rate attitude behavior has not been tested with a Vehicle. |
| Telemetry rail | Partial | Loads, uses native Vehicle Facts and 1 Hz history sampling. The final cell is `FLIGHT TIME`, bound directly to QGC `Vehicle.flightTime`, which QGC resets on each confirmed arm transition and stops on disarm. It is formatted `MM:SS`/`HH:MM:SS` and is not affected by page navigation. WFB unknown renders N/A and is not charted. Safe arm/disarm validation remains. |
| Map | Partial, visibility verified | Stock QGC `FlyViewMap` is retained and was visually verified with real satellite tiles in the center workspace. The opaque full-dashboard paint layer was removed; AeroTHON side/top/bottom controls remain above the map, while the center and its keyboard-only focus item are transparent and install no pointer handler. `AeroDetectionMapLayer` remains a transparent `MapItemView` parented to the existing map and consumes input only on actual marker delegates. Coordinate-less dialect events create no marker; live geographic correlation remains unavailable. |
| Quick actions / messages | Complete, hardware-unverified | Quick Actions retain a dark filled surface and border in disabled/no-vehicle state, with a separate technical group panel and AeroMotion hover/press transitions. The `MISSION` action is a navigation-only entry to the existing native QGC `MainWindow.showPlanView()` workflow; it creates no second mission backend. Commands still use null-guarded QGC `Vehicle` guided/flight-mode methods; payload remains confirmation-gated. Messages use the shared model and real event sources. |
| Context diagnostics | Complete, hardware-unverified | Anchored Flight View panel exposes GPS, EKF, battery, WFB, Axon, FPV, and Nadir values from actual available state, with N/A/UNKNOWN semantics and advisory-only wording. |
| Responsive/motion foundation | Complete, software-audited | Width constraints keep the map dominant at target sizes; graph is forced into its horizontal compact ribbon below 1500 px or 850 px height. The actual 1920x1080 desktop was inspected: message ACK controls now reserve their real width, mission labels stay above the telemetry rail, and graph endpoints leave room for edge labels. The 12 px baseline and persistent Reduce Motion tokens remain. Other target resolutions still need physical/virtual display validation. |
| Mission graph strip/editor | Partial | The strip uses real model data and maps confirmed custom mission states to active/completed nodes; completion/reset and edit locking are connected. Mission editor integration and live mission validation remain. |
| FPV / Nadir | Complete but hardware-unverified | Independent MPEG-TS/H.264 UDP receiver/decoder objects remain alive across NORMAL/EXPANDED/FULLSCREEN reparenting; Escape restores normal layout. FPV is UDP 5600 and OAK-D/Nadir is UDP 5604. The exact GStreamer elements (`tsdemux`, `h264parse`, and `avdec_h264`) are present; in-app live-frame validation remains pending a run with the WFB producers active. |

## QGC BACKEND INTEGRATION AUDIT

Audited against QGC commit `80c91d91d5f1fb2609e6c2763e8fd563669d53bc` (`v5.0.3-1273-g80c91d91d`). AeroTHON navigation now invokes the checkout's real `MainWindow.qml` routes instead of only changing a local tab string.

| Feature | UI route / target | Authoritative backend/controller | Status |
| --- | --- | --- | --- |
| Flight | `UavDashboard.navigateTo("flight")` → `MainWindow.showFlyView()` → persistent `FlyView`/`FlyViewMap` | `MultiVehicleManager.activeVehicle`, `Vehicle`, FlyView `PlanMasterController`/`MissionController`, `MissionManager` | Connected + verified; packaged satellite map and null-vehicle Flight UI inspected. |
| Embedded maps | No standalone route; Flight → `FlyViewMap`, Plan → native planning map | QGC FlightMap/QtLocation map, shared flight-map position/zoom, native vehicle/mission map items | Connected + verified; global Map navigation is removed, both real maps remain, and the Aero detection `MapItemView` stays transparent. |
| Plan | AeroTHON Plan entry → `MainWindow.showPlanView()` → `PlanView.qml` | `PlanMasterController`, `MissionController`, `GeoFenceController`, `RallyPointController`, vehicle `MissionManager` | Connected + verified; native waypoint/map/editor, `.plan` load/save, upload checks and complex-item templates rendered in desktop test. |
| Mission | No standalone side-navigation destination; mission operations remain in native Plan/Flight and the Flight mission strip | Native `MissionManager`/FlyView `MissionController` remain authoritative; `AeroMissionGraphModel` is an additional high-level task association | Connected + verified separation; removing the button did not remove mission state, transfer, graph, reporting, or history services. |
| Vehicle / Config | AeroTHON Vehicle entry → `MainWindow.showVehicleConfig()` → `VehicleConfigView.qml` | `Vehicle.autopilotPlugin`, `AutoPilotPlugin`, firmware-specific `VehicleComponent` models | Connected + source-verified; disconnected summary is native and component pages remain firmware-plugin driven. |
| Parameters | AeroTHON Params entry → `MainWindow.showVehicleConfigParametersPage()` → `SetupParameterEditor.qml` | `ParameterEditorController` → `FactPanelController` → `Vehicle.parameterManager`/`ParameterManager` → `Fact` metadata | Connected + verified; no fake database. Two native null-Vehicle bindings found by runtime audit were guarded. |
| Settings | AeroTHON Settings entry → `MainWindow.showSettingsTool()` → native `AppSettings.qml` | Generated `SettingsPagesModel`, `SettingsManager` Facts; additive `AeroTHONSettingsPage.qml` binds the existing `AeroTHONSettings` Facts | Connected + verified by generated model/build and packaged native settings resources. Native General, Comm Links, Maps, Logging, Telemetry and Video pages remain present. |
| Analyze / Logs | AeroTHON Logs entry → `MainWindow.showAnalyzeTool()` → `AnalyzeView.qml` | `QGCCorePlugin.analyzePages`: `LogViewerController`, `OnboardLogController`, GeoTag, MAVLink Console/Inspector and Vibration pages | Connected + source-verified; AeroTHON JSONL/session history remains additive and does not replace QGC logs. |
| Systems | AeroTHON Systems entry → QGC tool drawer → `AeroSystemsScreen.qml` | singleton `AeroTHONManager`, `AeroOperationalHealth`, `AeroAlertModel`, `AeroPreflightManager` | Connected + runtime-loaded with explicit unknown values when sources are absent. |
| Mission Graph | Persistent FlyView overlay | `AeroMissionGraphModel` plus confirmed `AeroTHONManager` mission state; QGC mission remains authoritative | Connected + verified separation. |

The communications path is unchanged: `LinkManager` owns configured links, `MAVLinkProtocol.messageReceived` feeds `Vehicle::_mavlinkMessageReceived`, and the normal `Vehicle` managers process telemetry. `AerothonPlugin::mavlinkMessage` only observes the six custom IDs and returns `true`, so it neither creates a second link manager nor consumes standard QGC messages.

`FlyView`, `PlanView`, and the tool drawer are persistent children of `MainWindow`; switching views changes visibility. AeroTHON manager, alert, detection, operational-health, preflight, and session-recorder services are registered singleton instances. The mission graph and video receivers remain children of the persistent FlyView overlay, so ordinary native navigation does not recreate them.

## GLOBAL AEROTHON SHELL AUDIT

- `MainWindow.qml` owns one persistent `AeroGlobalShell`; the shell holds `AeroTopBar` and `AeroNavRail`. The rail stays visible globally, while `AeroTopBar` is visible only when `aeroActiveRoute === "flight"`.
- The custom `FlyViewToolBar.qml` remains zero-height, the product/logo row was removed from the tool drawer, and the QGC logo button was removed from `PlanViewToolBar.qml`. Plan's Open/Save/Upload/Clear/mission indicators remain as an in-page planning tool strip.
- The former Flight-local top bar and rail were removed from `UavDashboard.qml`, preventing duplication and view-local service/chrome recreation.
- The global shell is transparent outside its painted top and side controls, so it neither covers the Flight/Plan maps nor installs a full-screen pointer handler.
- Desktop inspection found the AeroTHON operational bar only in Flight. Native Plan uses its page-local Open/Save/Upload strip at the top of its released content area; it has no AeroTHON Flight bar, stock QGC product logo/home button, or second global application toolbar.

## QGC TOP TOOLBAR FEATURE MIGRATION

| Feature | Original QGC component | Original backend/property | New AeroTHON component | Status |
| --- | --- | --- | --- | --- |
| Vehicle/link state | `MainStatusIndicator`, `FlyViewToolBarIndicators` | `MultiVehicleManager.activeVehicle`; `Vehicle.vehicleLinkManager.commLost` | `AeroTopBar` PX4 status | Verified, null-safe |
| Flight mode | `FlightModeIndicator` | `Vehicle.flightMode`, `Vehicle.flightModes`, `FlightModeSettings.requireModeChangeConfirmation` | `AeroTopBar` mode chip and native-backed selector | Verified, no unsupported mapping |
| Arm/disarm | `ArmedIndicator` | `MainWindow.armVehicleRequest`/`disarmVehicleRequest` handled by persistent `GuidedActionsController`; confirmed state from `Vehicle.armed` | `AeroTopBar` ARM/DISARM control | Verified safe command path; no optimistic armed state |
| GPS | `VehicleGPSIndicator` / `GPSIndicator` | `Vehicle.gps.count` `Fact` | `AeroTopBar` GPS chip | Verified, `N/A` without a Vehicle |
| Battery | `BatteryIndicator` | `Vehicle.batteries` / `BatteryFactGroup.percentRemaining` | `AeroTopBar` battery chip | Verified, `N/A` when unavailable |
| Vehicle messages | `MainStatusIndicator`, `VehicleMessageList` | `Vehicle.textMessageReceived` / QGC status-text handling | `AeroMessageFeed` → shared `AeroAlertModel` → Flight Messages panel | Verified software path; duplicate top-bar message text/list removed |
| Axon/WFB | AeroTHON Flight status | `AeroTHONManager.axonState`, `wfbAvailable`, `wfbState` | `AeroTopBar` compact status dots | Verified software path; hardware-unverified |

The toolbar intentionally does not duplicate the bottom Flight telemetry rail. It presents global connectivity, safety, mode, GPS/battery summary, and notifications only.

## NAVIGATION AUDIT

The persistent side rail destinations are **Flight, Plan, Application Settings, Vehicle, Parameters, Logs, and Systems**. **Application Settings** occupies the former Mission position and routes through `MainWindow.showSettingsTool()` to native `AppSettings.qml`; the redundant bottom Settings item was removed. This changes navigation only: QGC mission planning/management and the AeroTHON mission graph/reporting services remain intact. The standalone **Map** entry remains absent. `AeroTopBar` contains no page routes and appears only in Flight; non-Flight views reserve no top-bar height or hit area.

Routing continues through the native `MainWindow` functions documented in the backend audit above. Flight and Plan retain `FlyViewMap` and the native Plan map respectively; removing the route did not remove map providers, map controls, mission overlays, or AeroTHON detection overlays.

## THEME AUDIT

`QGCCorePlugin::paletteOverride` is implemented by `AerothonPlugin` as the centralized native-page bridge. It maps QGC window, shade, toolbar, group, field, button, map-button, mission-editor, text, border, and semantic palette roles onto AeroTHON navy/cyan/green/amber/red tokens. Native Plan controls were visually inspected in the desktop build and keep their operational QGC layout while matching the AeroTHON shell. No backend page was copied or replaced for styling.

## SHORTCUT AUDIT

The former shortcuts were a view-local `Keys.onPressed` handler in `UavDashboard`; child focus prevented delivery and its lifetime was tied to Flight content. They are now `Qt.ApplicationShortcut` registrations owned by persistent `MainWindow`, disabled while a `TextField` or `TextArea` has active focus. Buttons and shortcuts both call `MainWindow.triggerAeroVehicleAction`, retaining QGC guided actions and confirmation behavior.

| Key | Action | Backend path | Verification |
| --- | --- | --- | --- |
| Ctrl+Shift+A / D | Arm / disarm | `MainWindow.armVehicleRequest` / `disarmVehicleRequest` → `GuidedActionsController` | Connected; live command requires SITL/bench |
| Ctrl+Shift+R | RTL | `Vehicle.guidedModeRTL(false)` | Connected; unavailable feedback uses Messages |
| Ctrl+Shift+L | Land | `Vehicle.guidedModeLand()` | Connected; live command requires SITL/bench |
| Ctrl+Shift+P | Payload confirmation | Existing `AeroPayloadConfirmation` | Connected and safety-gated; physical output remains unconfigured |
| Ctrl+1 / 2 / 3 | Manual / Stabilized / Acro | Exact supported entry from `Vehicle.flightModes` → `Vehicle.flightMode` | Connected; no unsupported mapping |
| Ctrl+5 / 6 / 7 | Altitude / Position / Mission | Exact supported entry from `Vehicle.flightModes` → `Vehicle.flightMode` | Connected; no unsupported mapping |
| Ctrl+4 | Reserved | None | Intentionally unbound |
| Escape | Exit expanded/fullscreen camera | `aeroEscapeRequest` → persistent Flight dashboard | Connected |

## MESSAGE ROUTING

PX4/QGC status text remains received through `Vehicle.textMessageReceived`. `AeroMessageFeed` feeds the shared `AeroAlertModel`, whose Flight Messages panel below Quick Actions is the ordinary visible destination and whose records remain available to session history. The `AeroTopBar` native-message-list badge/drawer was removed. QGC's genuinely blocking critical dialog remains intact.

## VOICE SYSTEM

- AeroTHON reuses QGC's singleton `AudioOutput`, backed by Qt `QTextToSpeech`; initialization continues to use native `AppSettings.audioVolume` and `AppSettings.audioMuted`, so application mute and volume remain authoritative.
- Actual `StatusTextHandler` output reaches `Vehicle::_textMessageReceived`. MAVLink WARNING and more severe messages are spoken through the priority path, with `Warning`/`Critical` prefixes; INFO/NOTICE remain visual unless the sender explicitly marks text for speech with QGC's existing `#` convention.
- Priority alerts stop lower-priority speech and clear its pending queue. Identical spoken alert text has a 10-second cooldown, independent of the visual alert occurrence count and history.
- The packaged runtime includes `libQt6TextToSpeech`, the Speech Dispatcher Qt plugin, and `libspeechd`. `AudioOutput.available` drives an explicit `Voice: Available`/`Voice: Unavailable` line in AeroTHON Application Settings rather than silently claiming speech works.
- The desktop audio stack is PipeWire/PulseAudio, with the default sink `Ryzen HD Audio Controller Speaker` (`alsa_output.pci-0000_05_00.6.HiFi__Speaker__sink`). QGC will use this normal default speaker path when a synthesizer is available. Software initialization was exercised, but audible output is environment-blocked because Speech Dispatcher reports that it has no synthesizer modules.

## ALTITUDE ANNOUNCEMENT

- The persistent `AeroTHONManager` samples `Vehicle::altitudeRelative()` at the existing 1 Hz presentation tick and uses the Fact's cooked value and cooked units. It rounds to operational whole units and rejects non-finite data.
- Periodic speech is enabled by default only while `Vehicle::flying` is true and `VehicleLinkManager::communicationLost` is false. It stops immediately when either condition fails and is independent of Flight QML/page lifetime.
- The default interval is 4 seconds and is editable with an enable toggle in native Application Settings → AeroTHON. Periodic callouts enqueue only while the speech engine is idle, preventing stale altitude backlog and allowing warnings to preempt them.

## TIMER SEMANTICS

The bottom rail now reads QGC's authoritative `Vehicle.flightTime` Fact. In this checkout `Vehicle::_updateArmed(true)` calls `_flightTimerStart()`, which starts `QElapsedTimer` and clears the Fact to zero; `_updateFlightTime()` presents it every second; `Vehicle::_updateArmed(false)` stops it. The display is therefore current ARM → DISARM Flight Time, starts fresh on each new arm, and survives Flight/Plan/Settings navigation because Vehicle—not QML—owns it. Mission, stage, execution, and recorder clocks remain independent. Safe arm/disarm/re-arm validation remains.

## TYPOGRAPHY AUDIT

`AeroTypography` establishes 16 px as its micro/caption/label/body minimum and retains larger section, heading, telemetry, and HUD levels. AeroTHON literals below 16 px were migrated to the central tokens. `ScreenTools` uses a minimum 12-point native base and no longer scales its small font below that base, extending the readable baseline to hosted Plan, Vehicle, Parameter, Analyze, and Application Settings controls.

## Next verified-work order

1. Validate dual H.264 input, geographic correlation, Fact thresholds, and preflight on target hardware/network.
2. Add full Logs/Replay visualization over the completed session-history APIs and accumulate enough matching missions for stage statistics/ETA.
3. Complete normal-display responsive visual inspection and interactive diagnostics testing.
4. Validate the AppImage on the target desktop distribution with real video/network inputs.
