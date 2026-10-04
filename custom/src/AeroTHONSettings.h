#pragma once

#include <QtQmlIntegration/QtQmlIntegration>

#include "SettingsGroup.h"

/// Persistent settings for the AeroTHON GCS overlay.
///
/// Backed by a QSettings JSON file at
///   :/json/AeroTHON.SettingsGroup.json
/// which declares the type, default and (optionally) min/max for each Fact.
class AeroTHONSettings : public SettingsGroup
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")

public:
    explicit AeroTHONSettings(QObject *parent = nullptr);

    DEFINE_SETTING_NAME_GROUP()

    // ----- Axon connection -----
    /// Hostname / IP of the Axon companion computer Flask endpoint.
    DEFINE_SETTINGFACT(axonHost)
    /// Port of the Axon Flask endpoint (default 5080).
    DEFINE_SETTINGFACT(axonPort)
    /// TCP connect timeout in milliseconds (default 2000 ms).
    DEFINE_SETTINGFACT(axonConnectTimeout)
    /// HTTP read timeout in milliseconds (default 5000 ms).
    DEFINE_SETTINGFACT(axonReadTimeout)
    /// Flask polling interval in milliseconds (default 1000 ms = 1 Hz).
    DEFINE_SETTINGFACT(axonPollInterval)

    // ----- UI preferences -----
    /// Reduce animation/motion in the UI (accessibility).
    DEFINE_SETTINGFACT(reduceMotion)
    /// Enable periodic in-flight altitude voice callouts.
    DEFINE_SETTINGFACT(altitudeAnnouncements)
    /// Interval between altitude callouts in seconds.
    DEFINE_SETTINGFACT(altitudeAnnouncementInterval)

    // ----- Telemetry gauge windows (rolling-average depth) -----
    /// Sample window depth for the altitude gauge (default 25).
    DEFINE_SETTINGFACT(telemetryWindowAltitude)
    /// Sample window depth for the speed gauge (default 25).
    DEFINE_SETTINGFACT(telemetryWindowSpeed)
    /// Sample window depth for the battery gauge (default 45).
    DEFINE_SETTINGFACT(telemetryWindowBattery)
    /// Sample window depth for the WFB gauge (default 25).
    DEFINE_SETTINGFACT(telemetryWindowWFB)

    // ----- Vehicle / Identity -----
    /// Configurable drone name displayed in the header (default "AeroTHON-01").
    DEFINE_SETTINGFACT(droneName)

    // ----- Camera Names -----
    /// Display name for camera 1 (default "OAK D Lite").
    DEFINE_SETTINGFACT(camera1Name)
    /// Display name for camera 2 (default "Arducam").
    DEFINE_SETTINGFACT(camera2Name)
};
