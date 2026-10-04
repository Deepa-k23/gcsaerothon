#include "AeroTHONSettings.h"

// ---------------------------------------------------------------------------
// Registers the settings group name and QSettings sub-group, and
// generates the constructor body.  The JSON file
//   :/json/AeroTHON.SettingsGroup.json
// must list all Facts with their types and defaults.
// ---------------------------------------------------------------------------

DECLARE_SETTINGGROUP(AeroTHON, "AeroTHON")
{
    // Additional constructor logic can go here if needed.
}

// ----- Axon connection -----
DECLARE_SETTINGSFACT(AeroTHONSettings, axonHost)
DECLARE_SETTINGSFACT(AeroTHONSettings, axonPort)
DECLARE_SETTINGSFACT(AeroTHONSettings, axonConnectTimeout)
DECLARE_SETTINGSFACT(AeroTHONSettings, axonReadTimeout)
DECLARE_SETTINGSFACT(AeroTHONSettings, axonPollInterval)

// ----- UI preferences -----
DECLARE_SETTINGSFACT(AeroTHONSettings, reduceMotion)
DECLARE_SETTINGSFACT(AeroTHONSettings, altitudeAnnouncements)
DECLARE_SETTINGSFACT(AeroTHONSettings, altitudeAnnouncementInterval)

// ----- Telemetry gauge windows -----
DECLARE_SETTINGSFACT(AeroTHONSettings, telemetryWindowAltitude)
DECLARE_SETTINGSFACT(AeroTHONSettings, telemetryWindowSpeed)
DECLARE_SETTINGSFACT(AeroTHONSettings, telemetryWindowBattery)
DECLARE_SETTINGSFACT(AeroTHONSettings, telemetryWindowWFB)

// ----- Vehicle / Identity -----
DECLARE_SETTINGSFACT(AeroTHONSettings, droneName)

// ----- Camera Names -----
DECLARE_SETTINGSFACT(AeroTHONSettings, camera1Name)
DECLARE_SETTINGSFACT(AeroTHONSettings, camera2Name)
