#pragma once

#include <QtCore/QObject>
#include <QtCore/QElapsedTimer>
#include <QtCore/QPointer>
#include <QtCore/QTimer>
#include <QtCore/QString>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtQmlIntegration/QtQmlIntegration>

#include <mavlink.h>
#include "AeroTHONSettings.h"

class Vehicle;
class QJSEngine;
class QQmlEngine;
Q_MOC_INCLUDE("Vehicle.h")

/// Central manager for the AeroTHON companion-computer integration.
///
/// Responsibilities:
///  - Receive custom MAVLink messages 61000–61006 forwarded by AerothonPlugin
///  - Poll the Axon Flask REST endpoint at 1 Hz for health/status JSON
///  - Maintain Axon state machine (Online / Degraded / Lost)
///  - Expose all telemetry via Q_PROPERTY for QML binding
///  - Emit displayUpdateReady() at 1 Hz as a paint-gate signal
class AeroTHONManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    // -----------------------------------------------------------------------
    // AeroTHON MAVLink custom message IDs
    // -----------------------------------------------------------------------
    static constexpr quint32 MSG_AEROTHON_STATUS            = 61000;
    static constexpr quint32 MSG_AEROTHON_DETECTION         = 61001;
    static constexpr quint32 MSG_AEROTHON_QR_RESULT         = 61002;
    static constexpr quint32 MSG_AEROTHON_HEALTH            = 61003;
    static constexpr quint32 MSG_AEROTHON_COMMAND           = 61004;
    static constexpr quint32 MSG_AEROTHON_COMMAND_ACK       = 61005;
    
    // -----------------------------------------------------------------------
    // Enums exposed to QML
    // -----------------------------------------------------------------------

    /// Overall connectivity state of the Axon companion computer.
    enum class AxonState {
        Unknown  = 0, ///< Initial / not yet determined
        Online   = 1, ///< Flask responded within the last 5 s
        Degraded = 2, ///< No Flask response for 5–10 s
        Lost     = 3  ///< No Flask response for > 10 s
    };
    Q_ENUM(AxonState)

    /// Wireless-for-FPV link quality state.
    enum class WFBState {
        Normal   = 0, ///< packetLossPct < 10 %
        Warning  = 1, ///< 10 % ≤ packetLossPct < 30 %
        Critical = 2, ///< packetLossPct ≥ 30 %
        Unknown  = 3  ///< no fresh packet-loss source
    };
    Q_ENUM(WFBState)

    // -----------------------------------------------------------------------
    // Singleton access
    // -----------------------------------------------------------------------

    static AeroTHONManager *instance();
    static AeroTHONManager *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // -----------------------------------------------------------------------
    // Axon connection state
    // -----------------------------------------------------------------------

    Q_PROPERTY(AxonState axonState READ axonState NOTIFY axonStateChanged)
    AxonState axonState() const { return _axonState; }

    Q_PROPERTY(quint64 axonUptimeSec READ axonUptimeSec NOTIFY axonUptimeSecChanged)
    quint64 axonUptimeSec() const { return _axonUptimeSec; }
    Q_PROPERTY(bool reduceMotion READ reduceMotion NOTIFY reduceMotionChanged)
    Q_PROPERTY(bool voiceAvailable READ voiceAvailable NOTIFY voiceAvailableChanged)
    bool reduceMotion() { return _settings.reduceMotion()->rawValue().toBool(); }
    bool voiceAvailable() const;

    // Persistent AeroTHON application settings. Exposing the backing Facts
    // keeps the native QGC settings controls and validation path authoritative.
    Q_PROPERTY(Fact* axonHostFact READ axonHostFact CONSTANT)
    Q_PROPERTY(Fact* axonPortFact READ axonPortFact CONSTANT)
    Q_PROPERTY(Fact* axonConnectTimeoutFact READ axonConnectTimeoutFact CONSTANT)
    Q_PROPERTY(Fact* axonReadTimeoutFact READ axonReadTimeoutFact CONSTANT)
    Q_PROPERTY(Fact* axonPollIntervalFact READ axonPollIntervalFact CONSTANT)
    Q_PROPERTY(Fact* reduceMotionFact READ reduceMotionFact CONSTANT)
    Q_PROPERTY(Fact* altitudeAnnouncementsFact READ altitudeAnnouncementsFact CONSTANT)
    Q_PROPERTY(Fact* altitudeAnnouncementIntervalFact READ altitudeAnnouncementIntervalFact CONSTANT)
    Q_PROPERTY(Fact* telemetryWindowAltitudeFact READ telemetryWindowAltitudeFact CONSTANT)
    Q_PROPERTY(Fact* telemetryWindowSpeedFact READ telemetryWindowSpeedFact CONSTANT)
    Q_PROPERTY(Fact* telemetryWindowBatteryFact READ telemetryWindowBatteryFact CONSTANT)
    Q_PROPERTY(Fact* telemetryWindowWfbFact READ telemetryWindowWfbFact CONSTANT)
    Q_PROPERTY(Fact* droneNameFact READ droneNameFact CONSTANT)
    Q_PROPERTY(Fact* camera1NameFact READ camera1NameFact CONSTANT)
    Q_PROPERTY(Fact* camera2NameFact READ camera2NameFact CONSTANT)

    Fact *axonHostFact() { return _settings.axonHost(); }
    Fact *axonPortFact() { return _settings.axonPort(); }
    Fact *axonConnectTimeoutFact() { return _settings.axonConnectTimeout(); }
    Fact *axonReadTimeoutFact() { return _settings.axonReadTimeout(); }
    Fact *axonPollIntervalFact() { return _settings.axonPollInterval(); }
    Fact *reduceMotionFact() { return _settings.reduceMotion(); }
    Fact *altitudeAnnouncementsFact() { return _settings.altitudeAnnouncements(); }
    Fact *altitudeAnnouncementIntervalFact() { return _settings.altitudeAnnouncementInterval(); }
    Fact *telemetryWindowAltitudeFact() { return _settings.telemetryWindowAltitude(); }
    Fact *telemetryWindowSpeedFact() { return _settings.telemetryWindowSpeed(); }
    Fact *telemetryWindowBatteryFact() { return _settings.telemetryWindowBattery(); }
    Fact *telemetryWindowWfbFact() { return _settings.telemetryWindowWFB(); }
    Fact *droneNameFact() { return _settings.droneName(); }
    Fact *camera1NameFact() { return _settings.camera1Name(); }
    Fact *camera2NameFact() { return _settings.camera2Name(); }

    // -----------------------------------------------------------------------
    // Axon system health (from AEROTHON_HEALTH MAVLink + Flask)
    // -----------------------------------------------------------------------

    Q_PROPERTY(float   cpuPct        READ cpuPct        NOTIFY cpuPctChanged)
    Q_PROPERTY(float   ramPct        READ ramPct        NOTIFY ramPctChanged)
    Q_PROPERTY(float   tempC         READ tempC         NOTIFY tempCChanged)
    Q_PROPERTY(float   storageMib    READ storageMib    NOTIFY storageMibChanged)
    Q_PROPERTY(float   fpvFps        READ fpvFps        NOTIFY fpvFpsChanged)
    Q_PROPERTY(float   nadirFps      READ nadirFps      NOTIFY nadirFpsChanged)
    Q_PROPERTY(float   inferenceFps  READ inferenceFps  NOTIFY inferenceFpsChanged)
    Q_PROPERTY(QString gstreamerState READ gstreamerState NOTIFY gstreamerStateChanged)
    Q_PROPERTY(QString wfbTxState    READ wfbTxState    NOTIFY wfbTxStateChanged)

    float   cpuPct()        const { return _cpuPct; }
    float   ramPct()        const { return _ramPct; }
    float   tempC()         const { return _tempC; }
    float   storageMib()    const { return _storageMib; }
    float   fpvFps()        const { return _fpvFps; }
    float   nadirFps()      const { return _nadirFps; }
    float   inferenceFps()  const { return _inferenceFps; }
    QString gstreamerState() const { return _gstreamerState; }
    QString wfbTxState()    const { return _wfbTxState; }

    // -----------------------------------------------------------------------
    // WFB (Wireless for FPV) link telemetry
    // -----------------------------------------------------------------------

    Q_PROPERTY(int      rssiDbm       READ rssiDbm       NOTIFY rssiDbmChanged)
    Q_PROPERTY(float    snrDb         READ snrDb         NOTIFY snrDbChanged)
    Q_PROPERTY(float    packetLossPct READ packetLossPct NOTIFY packetLossPctChanged)
    Q_PROPERTY(float    bitrateMbps   READ bitrateMbps   NOTIFY bitrateMbpsChanged)
    Q_PROPERTY(WFBState wfbState      READ wfbState      NOTIFY wfbStateChanged)
    Q_PROPERTY(bool wfbAvailable READ wfbAvailable NOTIFY wfbAvailabilityChanged)
    Q_PROPERTY(bool rssiAvailable READ rssiAvailable NOTIFY wfbAvailabilityChanged)
    Q_PROPERTY(bool snrAvailable READ snrAvailable NOTIFY wfbAvailabilityChanged)
    Q_PROPERTY(bool packetLossAvailable READ packetLossAvailable NOTIFY wfbAvailabilityChanged)
    Q_PROPERTY(bool bitrateAvailable READ bitrateAvailable NOTIFY wfbAvailabilityChanged)

    int      rssiDbm()       const { return _rssiDbm; }
    float    snrDb()         const { return _snrDb; }
    float    packetLossPct() const { return _packetLossPct; }
    float    bitrateMbps()   const { return _bitrateMbps; }
    WFBState wfbState()      const { return _wfbState; }
    bool wfbAvailable() const { return _rssiAvailable || _snrAvailable || _packetLossAvailable || _bitrateAvailable; }
    bool rssiAvailable() const { return _rssiAvailable; }
    bool snrAvailable() const { return _snrAvailable; }
    bool packetLossAvailable() const { return _packetLossAvailable; }
    bool bitrateAvailable() const { return _bitrateAvailable; }

    // -----------------------------------------------------------------------
    // Mission state (from AEROTHON_STATUS MAVLink)
    // -----------------------------------------------------------------------

    Q_PROPERTY(QString missionState    READ missionState    NOTIFY missionStateChanged)
    Q_PROPERTY(float   missionProgress READ missionProgress NOTIFY missionProgressChanged)
    Q_PROPERTY(quint64 stageElapsedMs  READ stageElapsedMs  NOTIFY stageElapsedMsChanged)
    Q_PROPERTY(QString activeTarget    READ activeTarget    NOTIFY activeTargetChanged)
    Q_PROPERTY(quint32 missionChecksum READ missionChecksum NOTIFY missionChecksumChanged)
    Q_PROPERTY(int missionResult READ missionResult NOTIFY missionResultChanged)
    Q_PROPERTY(int routeProgress READ routeProgress NOTIFY routeProgressChanged)
    Q_PROPERTY(QString transitionReason READ transitionReason NOTIFY transitionReasonChanged)
    Q_PROPERTY(bool missionTimingActive READ missionTimingActive NOTIFY missionTimingActiveChanged)
    Q_PROPERTY(quint64 missionElapsedSeconds READ missionElapsedSeconds NOTIFY missionElapsedSecondsChanged)

    QString missionState()    const { return _missionState; }
    float   missionProgress() const { return _missionProgress; }
    quint64 stageElapsedMs()  const { return _stageElapsedMs; }
    QString activeTarget()    const { return _activeTarget; }
    quint32 missionChecksum() const { return _missionChecksum; }
    int missionResult() const { return _missionResult; }
    int routeProgress() const { return _routeProgress; }
    QString transitionReason() const { return _transitionReason; }
    bool missionTimingActive() const { return _missionTimingActive; }
    quint64 missionElapsedSeconds() const { return _missionElapsedSeconds; }

    // Latest perception and command events. The current dialect intentionally
    // contains no geographic position; consumers must not infer one.
    Q_PROPERTY(quint32 detectionId READ detectionId NOTIFY detectionChanged)
    Q_PROPERTY(int detectionType READ detectionType NOTIFY detectionChanged)
    Q_PROPERTY(int detectionCamera READ detectionCamera NOTIFY detectionChanged)
    Q_PROPERTY(float detectionConfidence READ detectionConfidence NOTIFY detectionChanged)
    Q_PROPERTY(float detectionDistance READ detectionDistance NOTIFY detectionChanged)
    Q_PROPERTY(quint64 detectionTimeUsec READ detectionTimeUsec NOTIFY detectionChanged)
    Q_PROPERTY(QString qrPayload READ qrPayload NOTIFY qrResultChanged)
    Q_PROPERTY(bool qrValid READ qrValid NOTIFY qrResultChanged)
    Q_PROPERTY(bool qrDuplicate READ qrDuplicate NOTIFY qrResultChanged)
    Q_PROPERTY(quint32 acknowledgedRequestId READ acknowledgedRequestId NOTIFY commandAcknowledged)
    Q_PROPERTY(int acknowledgementResult READ acknowledgementResult NOTIFY commandAcknowledged)
    Q_PROPERTY(QString acknowledgementMessage READ acknowledgementMessage NOTIFY commandAcknowledged)

    quint32 detectionId() const { return _detectionId; }
    int detectionType() const { return _detectionType; }
    int detectionCamera() const { return _detectionCamera; }
    float detectionConfidence() const { return _detectionConfidence; }
    float detectionDistance() const { return _detectionDistance; }
    quint64 detectionTimeUsec() const { return _detectionTimeUsec; }
    QString qrPayload() const { return _qrPayload; }
    bool qrValid() const { return _qrValid; }
    bool qrDuplicate() const { return _qrDuplicate; }
    quint32 acknowledgedRequestId() const { return _acknowledgedRequestId; }
    int acknowledgementResult() const { return _acknowledgementResult; }
    QString acknowledgementMessage() const { return _acknowledgementMessage; }

    Q_INVOKABLE void startFlaskPolling();
    Q_INVOKABLE void stopFlaskPolling();
    Q_INVOKABLE void startNativeMission();
    Q_INVOKABLE QString getAppDirPath() const;

signals:
    // --- paint-gate --- //
    void displayUpdateReady();

    // --- axon state --- //
    void axonStateChanged();
    void axonUptimeSecChanged();
    void reduceMotionChanged();
    void voiceAvailableChanged();

    // --- health --- //
    void cpuPctChanged();
    void ramPctChanged();
    void tempCChanged();
    void storageMibChanged();
    void fpvFpsChanged();
    void nadirFpsChanged();
    void inferenceFpsChanged();
    void gstreamerStateChanged();
    void wfbTxStateChanged();

    // --- WFB --- //
    void rssiDbmChanged();
    void snrDbChanged();
    void packetLossPctChanged();
    void bitrateMbpsChanged();
    void wfbStateChanged();
    void wfbAvailabilityChanged();

    // --- mission --- //
    void missionStateChanged();
    void missionProgressChanged();
    void stageElapsedMsChanged();
    void activeTargetChanged();
    void missionChecksumChanged();
    void missionResultChanged();
    void routeProgressChanged();
    void transitionReasonChanged();
    void missionCompleted();
    void missionTimingActiveChanged();
    void missionElapsedSecondsChanged();

    void detectionChanged();
    void detectionReceived(quint32 detectionId, int detectionType, int cameraId,
                           float confidence, float distance, quint64 timeUsec);
    void qrResultChanged();
    void qrResultReceived(quint32 detectionId, const QString &payload, bool valid, bool duplicate,
                          int cameraId, quint64 timeUsec);
    void commandReceived(quint32 requestId, int command, float param1, float param2,
                         int targetSystem, int targetComponent);
    void commandAcknowledged();
    void commandAckReceived(quint32 requestId, int command, int result, int progress,
                            int reasonCode, const QString &message);
    void preflightResultReceived(quint32 requestId, uint8_t seq, uint8_t total,
                                 const QString &checkId, const QString &group,
                                 uint8_t status, float value, const QString &detail);

public slots:
    /// Called by AerothonPlugin for every MAVLink message in range [61000,61006].
    void handleAerothonMessage(Vehicle *vehicle, const mavlink_message_t &message);

    /// Send AEROTHON_COMMAND (START_PREFLIGHT) to the Axon via the active vehicle link.

private:
    explicit AeroTHONManager(QObject *parent = nullptr);

    // Internal helpers
    void _handleAerothonHealth(const mavlink_message_t &message);
    void _handleAerothonStatus(const mavlink_message_t &message);
    void _handleAerothonDetection(const mavlink_message_t &message);
    void _handleAerothonQrResult(const mavlink_message_t &message);
    void _handleAerothonCommand(const mavlink_message_t &message, const Vehicle *vehicle);
    void _handleAerothonCommandAck(const mavlink_message_t &message);
        void _parseFlaskJson(const QByteArray &data);
    void _updateAxonState();
    void _updateWfbState();
    void _markWfbMetricAvailable(bool &field);
    void _expireStaleWfb();
    void _setActiveVehicle(Vehicle *vehicle);
    void _updateMissionTiming();
    void _updateAltitudeAnnouncement();

    // Setters with change-notify
    template<typename T>
    bool _setAndNotify(T &field, T value, void (AeroTHONManager::*signal)());

private slots:
    void _onDisplayTimer();
    void _onFlaskPollTimer();
    void _onFlaskReplyFinished();

private:
    // --- Axon state ---
    AxonState _axonState{AxonState::Unknown};
    quint64   _axonUptimeSec{0};
    qint64    _lastFlaskResponseMs{0}; // epoch ms of last successful reply

    // --- Health ---
    float   _cpuPct{0.0f};
    float   _ramPct{0.0f};
    float   _tempC{0.0f};
    float   _storageMib{0.0f};
    float   _fpvFps{0.0f};
    float   _nadirFps{0.0f};
    float   _inferenceFps{0.0f};
    QString _gstreamerState;
    QString _wfbTxState;

    // --- WFB ---
    int      _rssiDbm{0};
    float    _snrDb{0.0f};
    float    _packetLossPct{0.0f};
    float    _bitrateMbps{0.0f};
    WFBState _wfbState{WFBState::Unknown};
    bool _rssiAvailable{false};
    bool _snrAvailable{false};
    bool _packetLossAvailable{false};
    bool _bitrateAvailable{false};
    qint64 _lastWfbUpdateMs{0};

    // --- Mission ---
    QString _missionState;
    float   _missionProgress{0.0f};
    quint64 _stageElapsedMs{0};
    QString _activeTarget;
    quint32 _missionChecksum{0};
    int _missionResult{0};
    int _routeProgress{0};
    QString _transitionReason;
    QPointer<Vehicle> _activeVehicle;
    bool _missionTimingActive{false};
    bool _missionTimingStarted{false};
    quint64 _missionElapsedSeconds{0};
    qint64 _missionAccumulatedMs{0};
    QElapsedTimer _missionActiveClock;
    QElapsedTimer _altitudeAnnouncementClock;

    quint32 _detectionId{0};
    int _detectionType{0};
    int _detectionCamera{0};
    float _detectionConfidence{0.0f};
    float _detectionDistance{0.0f};
    quint64 _detectionTimeUsec{0};
    QString _qrPayload;
    bool _qrValid{false};
    bool _qrDuplicate{false};
    quint32 _acknowledgedRequestId{0};
    int _acknowledgementResult{0};
    QString _acknowledgementMessage;

    // --- Timers & networking ---
    QTimer               _displayTimer;   ///< 1 Hz paint-gate
    QTimer               _pollTimer;      ///< 1 Hz Flask poll
    QNetworkAccessManager _nam;
    QNetworkReply        *_pendingReply{nullptr};
    AeroTHONSettings _settings;
};
