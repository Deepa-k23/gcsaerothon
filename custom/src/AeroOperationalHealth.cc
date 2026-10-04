#include "AeroOperationalHealth.h"

#include "AeroAlertModel.h"
#include "BatteryFactGroupListModel.h"
#include "Fact.h"
#include "FactGroup.h"
#include "MultiVehicleManager.h"
#include "QmlObjectListModel.h"
#include "Vehicle.h"

#include <QtCore/QGlobalStatic>
#include <QtCore/QtMath>

Q_GLOBAL_STATIC(AeroOperationalHealth, s_operationalHealth)

AeroOperationalHealth *AeroOperationalHealth::instance() { return s_operationalHealth(); }
AeroOperationalHealth *AeroOperationalHealth::create(QQmlEngine *, QJSEngine *) { return instance(); }

AeroOperationalHealth::AeroOperationalHealth(QObject *parent)
    : QObject(parent)
{
    MultiVehicleManager *manager = MultiVehicleManager::instance();
    connect(manager, &MultiVehicleManager::activeVehicleChanged, this, &AeroOperationalHealth::setVehicle);
    setVehicle(manager->activeVehicle());
}

void AeroOperationalHealth::setVehicle(Vehicle *vehicle)
{
    if (_vehicle == vehicle) return;
    if (_vehicle) disconnect(_vehicle, nullptr, this, nullptr);
    if (_gpsGroup) disconnect(_gpsGroup, nullptr, this, nullptr);
    if (_ekfGroup) disconnect(_ekfGroup, nullptr, this, nullptr);
    if (_battery) disconnect(_battery, nullptr, this, nullptr);
    _vehicle = vehicle;
    _gpsGroup = nullptr;
    _ekfGroup = nullptr;
    _battery = nullptr;
    _hadGpsFix = false;
    resetUnknown();
    if (!_vehicle) {
        emit healthChanged();
        return;
    }

    _gpsGroup = _vehicle->gpsFactGroup();
    _ekfGroup = _vehicle->estimatorStatusFactGroup();
    for (FactGroup *group : {_gpsGroup, _ekfGroup}) {
        if (group) connect(group, &FactGroup::telemetryAvailableChanged, this, &AeroOperationalHealth::evaluate);
    }
    if (_gpsGroup) {
        connectFact(_gpsGroup->getFact(QStringLiteral("lock")));
        connectFact(_gpsGroup->getFact(QStringLiteral("count")));
        connectFact(_gpsGroup->getFact(QStringLiteral("hdop")));
    }
    if (_ekfGroup) {
        for (const QString &name : {QStringLiteral("goodAttitudeEsimate"), QStringLiteral("goodHorizPosAbsEstimate"),
                                    QStringLiteral("goodVertPosAbsEstimate"), QStringLiteral("gpsGlitch"),
                                    QStringLiteral("accelError"), QStringLiteral("horizPosRatio"),
                                    QStringLiteral("vertPosRatio")}) {
            if (_ekfGroup->factExists(name)) connectFact(_ekfGroup->getFact(name));
        }
    }
    connect(_vehicle->batteries(), &QAbstractItemModel::rowsInserted, this, [this]() { refreshBatteryBinding(); });
    connect(_vehicle->batteries(), &QAbstractItemModel::modelReset, this, [this]() { refreshBatteryBinding(); });
    refreshBatteryBinding();
    evaluate();
}

void AeroOperationalHealth::connectFact(Fact *fact)
{
    if (fact) connect(fact, &Fact::rawValueChanged, this, &AeroOperationalHealth::evaluate);
}

void AeroOperationalHealth::refreshBatteryBinding()
{
    BatteryFactGroup *next = nullptr;
    if (_vehicle && _vehicle->batteries()->count() > 0)
        next = qobject_cast<BatteryFactGroup *>(_vehicle->batteries()->get(0));
    if (_battery == next) return;
    if (_battery) disconnect(_battery, nullptr, this, nullptr);
    _battery = next;
    if (_battery) {
        connect(_battery, &FactGroup::telemetryAvailableChanged, this, &AeroOperationalHealth::evaluate);
        connectFact(_battery->percentRemaining());
        connectFact(_battery->voltage());
        connectFact(_battery->chargeState());
    }
    evaluate();
}

void AeroOperationalHealth::evaluate()
{
    evaluateGps();
    evaluateEkf();
    evaluateBattery();
    emit healthChanged();
}

void AeroOperationalHealth::evaluateGps()
{
    _gpsAvailable = _gpsGroup && _gpsGroup->telemetryAvailable();
    if (!_gpsAvailable) {
        _gpsStatus = QStringLiteral("UNKNOWN");
        AeroAlertModel::instance()->resolveAlert(QStringLiteral("GPS:fix"));
        return;
    }
    _gpsFix = _gpsGroup->getFact(QStringLiteral("lock"))->rawValue().toInt();
    _gpsSatellites = _gpsGroup->getFact(QStringLiteral("count"))->rawValue().toInt();
    _gpsHdop = _gpsGroup->getFact(QStringLiteral("hdop"))->rawValue().toDouble();
    if (_gpsFix >= 3) {
        _gpsStatus = QStringLiteral("NORMAL");
        _hadGpsFix = true;
        AeroAlertModel::instance()->resolveAlert(QStringLiteral("GPS:fix"));
    } else if (_gpsFix == 2) {
        _gpsStatus = QStringLiteral("WARNING");
        AeroAlertModel::instance()->raiseAlert(QStringLiteral("GPS:fix"), QStringLiteral("WARNING"), QStringLiteral("GPS"),
                                               QStringLiteral("GPS has 2D fix only"), QStringLiteral("Altitude is not constrained by GNSS"));
    } else {
        _gpsStatus = _hadGpsFix ? QStringLiteral("CRITICAL") : QStringLiteral("WARNING");
        AeroAlertModel::instance()->raiseAlert(QStringLiteral("GPS:fix"), _hadGpsFix ? QStringLiteral("CRITICAL") : QStringLiteral("WARNING"),
                                               QStringLiteral("GPS"), _hadGpsFix ? QStringLiteral("GPS fix lost") : QStringLiteral("No GPS fix"),
                                               QStringLiteral("Fix %1, satellites %2").arg(_gpsFix).arg(_gpsSatellites), _hadGpsFix);
    }
}

void AeroOperationalHealth::evaluateEkf()
{
    _ekfAvailable = _ekfGroup && _ekfGroup->telemetryAvailable();
    if (!_ekfAvailable) {
        _ekfStatus = QStringLiteral("UNKNOWN");
        AeroAlertModel::instance()->resolveAlert(QStringLiteral("EKF:health"));
        return;
    }
    auto booleanFact = [this](const QString &name) { return _ekfGroup->getFact(name)->rawValue().toBool(); };
    _ekfGpsGlitch = booleanFact(QStringLiteral("gpsGlitch"));
    _ekfAccelError = booleanFact(QStringLiteral("accelError"));
    const bool goodAttitude = booleanFact(QStringLiteral("goodAttitudeEsimate"));
    const bool goodHorizontal = booleanFact(QStringLiteral("goodHorizPosAbsEstimate"));
    const bool goodVertical = booleanFact(QStringLiteral("goodVertPosAbsEstimate"));
    _ekfHorizontalPositionRatio = _ekfGroup->getFact(QStringLiteral("horizPosRatio"))->rawValue().toDouble();
    _ekfVerticalPositionRatio = _ekfGroup->getFact(QStringLiteral("vertPosRatio"))->rawValue().toDouble();
    const bool critical = _ekfGpsGlitch || _ekfAccelError || !goodAttitude;
    const bool warning = !goodHorizontal || !goodVertical || _ekfHorizontalPositionRatio >= 1. || _ekfVerticalPositionRatio >= 1.;
    if (critical) {
        _ekfStatus = QStringLiteral("CRITICAL");
        AeroAlertModel::instance()->raiseAlert(QStringLiteral("EKF:health"), QStringLiteral("CRITICAL"), QStringLiteral("EKF"),
                                               QStringLiteral("Estimator health failure"),
                                               QStringLiteral("GPS glitch %1, accelerometer error %2, attitude valid %3")
                                                   .arg(_ekfGpsGlitch).arg(_ekfAccelError).arg(goodAttitude), true);
    } else if (warning) {
        _ekfStatus = QStringLiteral("WARNING");
        AeroAlertModel::instance()->raiseAlert(QStringLiteral("EKF:health"), QStringLiteral("WARNING"), QStringLiteral("EKF"),
                                               QStringLiteral("Estimator position degraded"),
                                               QStringLiteral("Horizontal ratio %1, vertical ratio %2")
                                                   .arg(_ekfHorizontalPositionRatio, 0, 'f', 2).arg(_ekfVerticalPositionRatio, 0, 'f', 2));
    } else {
        _ekfStatus = QStringLiteral("NORMAL");
        AeroAlertModel::instance()->resolveAlert(QStringLiteral("EKF:health"));
    }
}

void AeroOperationalHealth::evaluateBattery()
{
    _batteryAvailable = _battery && _battery->telemetryAvailable();
    if (!_batteryAvailable) {
        _batteryStatus = QStringLiteral("UNKNOWN");
        AeroAlertModel::instance()->resolveAlert(QStringLiteral("BATTERY:level"));
        return;
    }
    _batteryPercent = _battery->percentRemaining()->rawValue().toDouble();
    _batteryVoltage = _battery->voltage()->rawValue().toDouble();
    _batteryChargeState = _battery->chargeState()->rawValue().toInt();
    if (!qIsFinite(_batteryPercent) || _batteryPercent < 0.) {
        _batteryAvailable = false;
        _batteryStatus = QStringLiteral("UNKNOWN");
        AeroAlertModel::instance()->resolveAlert(QStringLiteral("BATTERY:level"));
    } else if (_batteryPercent < 20.) {
        _batteryStatus = QStringLiteral("CRITICAL");
        AeroAlertModel::instance()->raiseAlert(QStringLiteral("BATTERY:level"), QStringLiteral("CRITICAL"), QStringLiteral("BAT"),
                                               QStringLiteral("Battery critically low"), QStringLiteral("%1% remaining").arg(_batteryPercent, 0, 'f', 0), true);
    } else if (_batteryPercent < 40.) {
        _batteryStatus = QStringLiteral("WARNING");
        AeroAlertModel::instance()->raiseAlert(QStringLiteral("BATTERY:level"), QStringLiteral("WARNING"), QStringLiteral("BAT"),
                                               QStringLiteral("Battery below 40%"), QStringLiteral("%1% remaining").arg(_batteryPercent, 0, 'f', 0));
    } else {
        _batteryStatus = QStringLiteral("NORMAL");
        AeroAlertModel::instance()->resolveAlert(QStringLiteral("BATTERY:level"));
    }
}

void AeroOperationalHealth::resetUnknown()
{
    _gpsAvailable = _ekfAvailable = _batteryAvailable = false;
    _gpsFix = _gpsSatellites = _batteryChargeState = 0;
    _gpsHdop = _ekfHorizontalPositionRatio = _ekfVerticalPositionRatio = _batteryPercent = _batteryVoltage = 0.;
    _ekfGpsGlitch = _ekfAccelError = false;
    _gpsStatus = _ekfStatus = _batteryStatus = QStringLiteral("UNKNOWN");
    for (const QString &key : {QStringLiteral("GPS:fix"), QStringLiteral("EKF:health"), QStringLiteral("BATTERY:level")})
        AeroAlertModel::instance()->resolveAlert(key);
}
