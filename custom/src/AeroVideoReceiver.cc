#include "AeroVideoReceiver.h"

#include <algorithm>

#include <QtCore/QLoggingCategory>
#include <QtQuick/QQuickItem>

#include "VideoBackend.h"
#include "VideoManager.h"
#include "VideoReceiver.h"

#ifdef QGC_GST_STREAMING
#include "QGCQVideoSinkController.h"
#endif

Q_LOGGING_CATEGORY(AeroVideoReceiverLog, "AeroTHON.VideoReceiver")

AeroVideoReceiver::AeroVideoReceiver(QObject *parent)
    : QObject(parent)
{
    _retryTimer.setSingleShot(true);
    connect(&_retryTimer, &QTimer::timeout, this, &AeroVideoReceiver::start);
    connect(VideoManager::instance(), &VideoManager::backendReadyChanged, this, [this]() {
        if (!_stopRequested && VideoManager::instance()->backendReady()) {
            start();
        }
    });
}

AeroVideoReceiver::~AeroVideoReceiver()
{
    _destroyReceiver();
}

QObject *AeroVideoReceiver::videoOutput() const
{
    return _videoOutput;
}

void AeroVideoReceiver::setSource(const QString &source)
{
    if (_source == source) {
        return;
    }

    const bool restart = _receiver && !_stopRequested;
    if (_receiver) {
        _receiver->stop();
        _receiver->setUri(source);
    }
    _source = source;
    emit sourceChanged();

    if (restart) {
        _retryAttempt = 0;
        _scheduleStartRetry();
    }
}

void AeroVideoReceiver::setVideoOutput(QObject *videoOutput)
{
    QQuickItem *item = qobject_cast<QQuickItem *>(videoOutput);
    if (_videoOutput == item) {
        return;
    }

    const bool restart = _receiver && !_stopRequested;
    _destroyReceiver();
    _videoOutput = item;
    emit videoOutputChanged();

    if (restart) {
        start();
    }
}

void AeroVideoReceiver::start()
{
    _retryTimer.stop();
    _stopRequested = false;

    if (_source.isEmpty() || !_videoOutput) {
        _setVideoState(QStringLiteral("NO SIGNAL"));
        return;
    }

    // QGC registers its static GStreamer sink asynchronously. Defer receiver
    // construction until that authoritative backend is ready; probing the sink
    // factory early produces a false critical error during normal startup.
    if (!VideoManager::instance()->backendReady()) {
        _setVideoState(QStringLiteral("INITIALIZING"));
        _scheduleStartRetry();
        return;
    }

    _ensureReceiver();
    if (!_receiver) {
        _setVideoState(QStringLiteral("FAILED"));
        _scheduleStartRetry();
        return;
    }

    if (_receiver->started()) {
        return;
    }

    _setVideoState(_retryAttempt == 0 ? QStringLiteral("CONNECTING") : QStringLiteral("RECONNECTING"));
    _receiver->start(3U);
}

void AeroVideoReceiver::stop()
{
    _stopRequested = true;
    _retryTimer.stop();
    _retryAttempt = 0;
    _setRecentFrames(false);
    if (_currentFPS != 0.0) {
        _currentFPS = 0.0;
        emit currentFPSChanged();
    }
    if (_receiver) {
        _receiver->stop();
    }
    _setVideoState(QStringLiteral("NO SIGNAL"));
}

void AeroVideoReceiver::_ensureReceiver()
{
    if (_receiver || !_videoOutput) {
        return;
    }

    _receiver = VideoBackend::createReceiver(this);
    if (!_receiver) {
        qCWarning(AeroVideoReceiverLog) << "Unable to create QGC video receiver" << _source;
        return;
    }

    _receiver->setName(objectName().isEmpty() ? QStringLiteral("aerothonVideo") : objectName());
    _receiver->setUri(_source);
    _receiver->setLowLatency(true);
    // Keep retry ownership in this wrapper. This avoids two independent backoff
    // loops racing when an initial UDP bind/start fails before a pipeline exists.
    _receiver->setAutoReconnect(false);
    _receiver->setWidget(_videoOutput);

    _sink = VideoBackend::createSink(_videoOutput, _receiver);
    if (!_sink) {
        qCWarning(AeroVideoReceiverLog) << "Unable to create video sink" << _source;
        delete _receiver;
        _receiver = nullptr;
        return;
    }

    _receiver->setSink(_sink);
    VideoBackend::attachSink(_receiver, _sink, _videoOutput);
    _connectFrameCounter();

    connect(_receiver, &VideoReceiver::onStartComplete, this, [this](VideoReceiver::STATUS status) {
        if (status == VideoReceiver::STATUS_OK) {
            _receiver->setStarted(true);
            _setVideoState(QStringLiteral("INITIALIZING"));
            _receiver->startDecoding(_sink);
            return;
        }
        if (!_stopRequested) {
            _setVideoState(QStringLiteral("FAILED"));
            _scheduleStartRetry();
        }
    });
    connect(_receiver, &VideoReceiver::onStopComplete, this, [this](VideoReceiver::STATUS) {
        if (_receiver) {
            _receiver->setStarted(false);
        }
        if (!_stopRequested && !_retryTimer.isActive()) {
            _setVideoState(QStringLiteral("RECONNECTING"));
            _scheduleStartRetry();
        }
    });
    connect(_receiver, &VideoReceiver::streamingChanged, this, [this](bool active) {
        if (active && _videoState != QStringLiteral("LIVE")) {
            _setVideoState(QStringLiteral("INITIALIZING"));
        } else if (!active && !_stopRequested) {
            _setRecentFrames(false);
            _setVideoState(QStringLiteral("RECONNECTING"));
        }
    });
    connect(_receiver, &VideoReceiver::decodingChanged, this, [this](bool active) {
        _setRecentFrames(active);
        if (active) {
            _retryAttempt = 0;
            _setVideoState(QStringLiteral("LIVE"));
        } else if (!_stopRequested) {
            _setVideoState(QStringLiteral("DEGRADED"));
        }
    });
    connect(_receiver, &VideoReceiver::timeout, this, [this]() {
        _setRecentFrames(false);
        _setVideoState(QStringLiteral("RECONNECTING"));
    });
    connect(_receiver, &VideoReceiver::videoSizeChanged, this, [this](const QSize &size) {
        if (_videoSize != size) {
            _videoSize = size;
            emit videoSizeChanged();
        }
    });
}

void AeroVideoReceiver::_destroyReceiver()
{
    _retryTimer.stop();
    if (_receiver) {
        delete _receiver;
        _receiver = nullptr;
    }
    if (_sink) {
        VideoBackend::releaseSink(_sink);
        _sink = nullptr;
    }
}

void AeroVideoReceiver::_setVideoState(const QString &state)
{
    if (_videoState != state) {
        _videoState = state;
        emit videoStateChanged();
    }
}

void AeroVideoReceiver::_setRecentFrames(bool recentFrames)
{
    if (_recentFrames != recentFrames) {
        _recentFrames = recentFrames;
        emit recentFramesChanged();
    }
}

void AeroVideoReceiver::_scheduleStartRetry()
{
    if (_stopRequested || _source.isEmpty() || !_videoOutput) {
        return;
    }
    _retryAttempt = std::min(_retryAttempt + 1, 30);
    const int delaySeconds = std::min(1 << std::min(_retryAttempt - 1, 5), 30);
    _setVideoState(QStringLiteral("RECONNECTING"));
    _retryTimer.start(delaySeconds * 1000);
}

void AeroVideoReceiver::_connectFrameCounter()
{
#ifdef QGC_GST_STREAMING
    const auto controllers = QGCQVideoSinkController::controllersOf(_receiver);
    if (controllers.isEmpty()) {
        return;
    }
    QGCQVideoSinkController *controller = controllers.constFirst();
    connect(controller, &QGCQVideoSinkController::frameCountsChanged, this, [this, controller]() {
        const quint64 count = controller->frameCount();
        const quint64 delta = count >= _lastFrameCount ? count - _lastFrameCount : 0;
        _lastFrameCount = count;
        const qreal fps = static_cast<qreal>(delta);
        if (!qFuzzyCompare(_currentFPS + 1.0, fps + 1.0)) {
            _currentFPS = fps;
            emit currentFPSChanged();
        }
        _setRecentFrames(delta > 0);
        if (delta > 0) {
            _setVideoState(QStringLiteral("LIVE"));
        } else if (_videoState == QStringLiteral("LIVE")) {
            _setVideoState(QStringLiteral("DEGRADED"));
        }
    });
#endif
}
