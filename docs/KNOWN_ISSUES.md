# AeroTHON-GCS V2 Known Issues

Last updated: 2026-09-11.

## Active

- The verified WFB feeds are MPEG-TS/H.264 rather than RTP/H.264. AeroTHON now uses QGC's native `mpegts://` path for UDP 5600 FPV and UDP 5604 OAK-D/Nadir. The streams were not active during this GCS desktop validation, so simultaneous in-app LIVE/decode/reconnect validation remains required.
- `AEROTHON_DETECTION` has no latitude/longitude fields. Detection records must remain positionless until a verified coordinate source/association is defined; the UI must not place inferred markers.
- Preflight checks now use real QGC/AeroTHON sources but have not been validated against target PX4, Axon, camera, or WFB hardware and must not be treated as arming authority. QGC exposes no single cross-firmware failsafe boolean here, so that row is an explicit advisory and PX4 remains final authority.
- The current Ninja build reports `premature end of file; recovering` and consequently rebuilds substantially more than expected. The build succeeds, but incremental-build correctness/performance needs investigation.
- Actual-desktop inspection passed at full 1920x1080 and at a 960x1027 tiled application width, including the unified toolbar's priority-collapse behavior. The remaining 1366x768, 1920x1200, and 2560x1440 target geometries have static responsive constraints/offscreen loading validation only; interactive clipping and camera aspect-ratio checks still require those display modes.
- Stage statistics and ETA require multiple valid completed sessions with matching mission identity. The journal preserves the required transitions/timings but no synthetic history is generated.
- The canonical lint gate could not run in the current environment because `just` and `pre-commit` are not installed.
- Hardware payload output remains intentionally unconfigured pending verified hardware mapping.
- Native route behavior with a live target PX4 (parameter download, firmware-specific setup components, mission upload/download, reconnect, and command enablement) remains hardware/simulation dependent. Software routing and no-Vehicle behavior are verified; this is not a flight validation claim.
- Vehicle-affecting keyboard shortcuts and the QGC current-flight timer's arm/disarm/re-arm transition are source- and runtime-load verified but still require a safe SITL or bench Vehicle test. No live command was sent during disconnected desktop validation.
- Voice routing, warning priority/deduplication, the 4-second altitude scheduler, native mute handling, and the QGC ARM→DISARM Flight Time binding are source/build/runtime-load verified but still require safe SITL/bench state-transition validation. PipeWire/PulseAudio is healthy and its current default is the laptop `Ryzen HD Audio Controller Speaker`; the current Arch host still cannot produce speech because Qt's `speechd` backend reports `Found no modules in speech-dispatcher` and neither `espeak-ng` nor `flite` is installed. No system audio package, service, or default device was changed during this work.

## Environment-only smoke-test limitations

- The restricted offscreen run cannot write QSettings/tile-cache state, bind UDP 14550, create an OpenGL context, or access map tiles. These warnings do not validate or invalidate behavior in a normal desktop session.

## Resolved

- Custom `aerothon.xml` was not available to the pinned MAVLink generator.
- The initial dialect inherited too little of QGC's normal message surface and removed ArduPilot calibration definitions.
- AeroTHON STATUS and HEALTH handlers decoded payload layouts that did not match the dialect XML; they now use generated mavgen decode functions.
- Qt 6.11 QML singleton registration, incomplete `Vehicle` metatype, and MAVLink typedef integration errors prevented compilation.
- Initial AeroTHON QML load failures in status, telemetry, message, mission-strip, and toolbar components were corrected through runtime smoke testing.
- The guided-action controller now tolerates its confirmation dialog being unassigned during custom-shell startup.
- GStreamer failed-start teardown no longer races a queued error-driven stop against released pipeline children.
- Detection, QR, command, and acknowledgement messages are decoded with generated functions and exposed as typed state/signals.
- Preflight no longer compiles into an all-simulation advisory path; actual Vehicle Facts, mission/link state, Axon health, and WFB data are evaluated.
- Detection events now persist in a shared model and synchronize with graph emphasis and operational messages. The map layer creates items only for explicitly valid coordinates; the current dialect therefore creates none.
- The operational alert store now deduplicates unchanged conditions and supports acknowledgement plus active/resolved lifecycle instead of treating dismissal as resolution.
- GPS/EKF/battery Facts, WFB freshness/thresholds, and preflight results now feed the shared alert lifecycle with explicit unknown states.
- AeroTHON session JSONL persistence, replay/preflight-history APIs, coordinate-gated route-quality samples, bookmarks, and mission-summary JSON are implemented without changing QGC logging.
- Reduce Motion is now driven by the persistent AeroTHON setting; the compact mission ribbon is automatically selected for 1366x768-class layouts.
- The 16 px minimum operational typography and AeroMotion token audits are complete for the current AeroTHON QML surface; hosted native QGC controls use a minimum 12-point base (approximately 16 px at 96 DPI).
- AeroTHON shortcuts are persistent application-scope registrations rather than a focus-dependent Flight item handler. They share the same safe command functions as Quick Actions, ignore normal text-entry focus, and route unavailable feedback into Messages.
- Ordinary vehicle status text no longer has a duplicate top-bar/native-message-list presentation. It continues through QGC status-text handling into `AeroAlertModel` and the Flight Messages panel; blocking critical dialogs remain available.
- The Flight telemetry clock now reads QGC's authoritative `Vehicle.flightTime` Fact, whose arm/disarm lifecycle starts a fresh current-flight cycle independently of QML navigation.
- AeroTHON settings metadata is packaged as a valid QGC FactMetaData resource; persistent Reduce Motion loading passes in build-tree and AppImage smoke tests.
- The session recorder no longer iterates dangling `roleNames()` temporaries when serializing newly raised alerts.
- AppImage staging excludes unavailable optional qt6ct/qgtk3/Flite plugins. The final `build/AeroTHON-GCS-x86_64.AppImage` passes actual Hyprland/XWayland desktop startup/visual inspection with the QGC satellite map visible and a 30-second isolated offscreen test.
- Live desktop validation found and resolved two Flight-screen clipping defects: message text now reserves actual ACK/detail/source widths, and mission graph labels remain inside both vertical and horizontal canvas bounds above the telemetry rail.
- The AeroTHON dashboard no longer paints an opaque full-screen background above `FlyViewMap`; only its real panels paint surfaces, leaving the center transparent and preserving native map hit testing.
- Quick Actions no longer fade their whole control when disabled. Their fill remains visible over satellite imagery, and the section now has its own technical surface.
- AeroTHON navigation now calls the actual QGC `MainWindow` Fly/Plan/Vehicle/Parameters/Analyze/Settings routes rather than changing only an AeroTHON tab string.
- Native `ParameterEditor.qml` no longer dereferences `activeVehicle` while disconnected.
- Native Settings now contains an additive AeroTHON page backed by the existing persistent Axon, Reduce Motion, and telemetry-history Facts.
- AeroTHON video receivers now defer construction until QGC's asynchronous `VideoManager` backend is ready, so normal startup no longer emits a false critical `qgcvideosinkbin` factory error.
- AeroTHON now owns one persistent global navigation rail and a Flight-only operational top bar. The top bar contains no page navigation, non-Flight pages reserve no header gap, the stock Fly toolbar and tool-page product chrome remain suppressed, and the native Plan operational action strip remains inside Plan content.
- Standalone Map navigation is removed from both AeroTHON navigation surfaces; the real QGC Flight and Plan maps remain visible and interactive beneath transparent AeroTHON overlays.
- Native QGC pages inherit the AeroTHON visual system through the centralized `QGCCorePlugin::paletteOverride` bridge rather than page-by-page backend copies.
- The refreshed AppImage is `build/AeroTHON-GCS-x86_64.AppImage`, SHA-256 `2464c1d475b49a395da1281c3b310825686263e287ff991a89fc932347ef2b0d`; it passed a 30-second isolated offscreen run. Direct FUSE mounting is unavailable in this host environment.
- AppImage staging excludes optional Qt platform-theme plugins (`qgtk3`, `qt6ct`, and `qtengine`). The host's newly installed `qtengine` binary has no writable RPATH entry and caused Qt deployment to fail despite not being an AeroTHON dependency; excluding the optional plugin type restores deterministic packaging.
- `AeroCameraColumn.qml` threw `ReferenceError: AeroTHONManager is not defined` at runtime because it was the only custom QML using `AeroTHONManager` without `import AeroTHON 1.0`. Fixed by adding the import; verified clean in the running build.
- `AeroNavRail.qml` referenced nav icons as `qrc:/res/InstrumentValueIcons/*.svg`, but those icons are embedded as `qrc:/InstrumentValueIcons/*.svg` (there is no `/res` prefix). Fixed the prefix for all seven icons; the `Cannot open` warnings are gone in the running build.
- All previously packaged AppImages in `~/Applications` (including the ones dated 2026-09-11, e.g. `f708e1a8`, `5e38acab`) contained a stale 2026-09-06 09:43 binary lacking `AeroAudioCoordinator` and the later changes; the packaging step had re-wrapped the old `AppDir` without re-running the install. Fixed by re-running `cmake --install build` (fresh staging) and the `appimage` component. The current packaged AppImage now embeds the fresh binary (contains `AeroAudioCoordinator`, `startNativeMission`, `droneName`, `camera1Name`, `camera2Name`) and passed a desktop AppImage smoke run. Note: `appimagelauncherd` auto-integrated the artifact into `~/Applications` as `AeroTHON-GCS-x86_64_5e1346902bcf7fb2d9606e0c17373c3f.AppImage`.
