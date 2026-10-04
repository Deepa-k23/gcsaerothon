#include "AudioOutput.h"
#include "Fact.h"
#include "AppMessages.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QRegularExpression>
#include <QtCore/QApplicationStatic>
#include <QtCore/QTimer>
#include <QtCore/QDateTime>
#include <QtTextToSpeech/QTextToSpeech>
#include <QtTextToSpeech/QVoice>

#include <algorithm>

QGC_LOGGING_CATEGORY(AudioOutputLog, "Utilities.AudioOutput");

const QHash<QString, QString> AudioOutput::_textHash = {
    { "ERR",            "error" },
    { "POSCTL",         "Position Control" },
    { "ALTCTL",         "Altitude Control" },
    { "AUTO_RTL",       "auto return to launch" },
    { "RTL",            "return To launch" },
    { "ACCEL",          "accelerometer" },
    { "RC_MAP_MODE_SW", "RC mode switch" },
    { "REJ",            "rejected" },
    { "WP",             "waypoint" },
    { "CMD",            "command" },
    { "COMPID",         "component eye dee" },
    { "PARAMS",         "parameters" },
    { "ID",             "I.D." },
    { "ADSB",           "A.D.S.B." },
    { "EKF",            "E.K.F." },
    { "PREARM",         "pre arm" },
    { "PITOT",          "pee toe" },
    { "SERVOX_FUNCTION","Servo X Function" },
};

Q_APPLICATION_STATIC(AudioOutput, _audioOutput);

AudioOutput::AudioOutput(QObject *parent)
    : QObject(parent)
    , _engine(QGC::runningUnitTests()
                  ? new QTextToSpeech(QStringLiteral("none"), this)
                  : new QTextToSpeech(this))
{
}

AudioOutput::~AudioOutput()
{
    if (_currentProcess) {
        _currentProcess->kill();
        _currentProcess->deleteLater();
        _currentProcess = nullptr;
    }
}

AudioOutput *AudioOutput::instance()
{
    return _audioOutput();
}

void AudioOutput::init(Fact* volumeFact, Fact* mutedFact)
{
    Q_CHECK_PTR(volumeFact);
    Q_CHECK_PTR(mutedFact);

    if (_initialized) {
        return;
    }

    _volumeFact = volumeFact;
    _mutedFact = mutedFact;

    (void) connect(_engine, &QTextToSpeech::stateChanged, this, [this](QTextToSpeech::State state) {
        if (state == QTextToSpeech::State::Ready) {
            _textQueueSize = 0;
            if (!_initialized) {
                _finishInit();
            }
        } else if (_available) {
            _available = false;
            emit availableChanged();
        }
        qCDebug(AudioOutputLog) << "TTS State changed to:" << state;
    });

    (void) connect(_engine, &QTextToSpeech::errorOccurred, this, [this](QTextToSpeech::ErrorReason reason, const QString &errorString) {
        qCWarning(AudioOutputLog) << "TTS error occurred. Reason:" << reason << ", Message:" << errorString;
        _textQueueSize = 0;
        if (_available) {
            _available = false;
            emit availableChanged();
        }
    });

    if (_engine->state() == QTextToSpeech::State::Ready) {
        _finishInit();
    } else {
        QTimer::singleShot(kEngineInitWarnTimeout, this, [this]() {
            if (!_initialized && _engine->state() != QTextToSpeech::State::Ready) {
                qCWarning(AudioOutputLog) << "Engine init timed out. Engine state:" << _engine->state();
                _finishInit();
            }
        });
    }
}

void AudioOutput::_finishInit()
{
    if (_initialized) {
        return;
    }

    _applyEngineSettings();

    (void) connect(_volumeFact, &Fact::rawValueChanged, this, &AudioOutput::_setVolume);
    (void) connect(_mutedFact, &Fact::rawValueChanged, this, &AudioOutput::_setVolume);
    _setVolume();

    _initialized = true;
    _available = _speakCapable;
    emit availableChanged();
}

void AudioOutput::_applyEngineSettings()
{
    const QVector<QVoice> voices = _engine->availableVoices();
    _speakCapable = !voices.isEmpty() || _engine->state() == QTextToSpeech::State::Ready;

    if (_speakCapable) {
        _engine->setLocale(QLocale(QLocale::English));
    }
}

double AudioOutput::_volumeSetting() const
{
    if (!_volumeFact) {
        return 100.0;
    }
    return _volumeFact->rawValue().toDouble();
}

bool AudioOutput::_mutedSetting() const
{
    if (!_mutedFact) {
        return false;
    }
    return _mutedFact->rawValue().toBool();
}

void AudioOutput::_setVolume()
{
    if (!_initialized) {
        return;
    }

    const double volume = _mutedSetting() ? 0.0 : _volumeSetting();
    if (qFuzzyCompare(1.0 + volume, 1.0 + _lastVolume)) {
        return;
    }
    _lastVolume = volume;

    const double normalizedVolume = volume / 100.0;
    (void) QMetaObject::invokeMethod(_engine, [this, volume, normalizedVolume]() {
        if (volume == 0.0) {
            _engine->stop(QTextToSpeech::BoundaryHint::Immediate);
            _textQueueSize = 0;
        }
        _engine->setVolume(normalizedVolume);
    });
}

bool AudioOutput::_isDuplicate(const QString &text, qint64 cooldownMs)
{
    _cleanupOldTimestamps();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (_recentSpeechTimestamps.contains(text)) {
        const qint64 lastSpoken = _recentSpeechTimestamps.value(text);
        if (now - lastSpoken < cooldownMs) {
            qCDebug(AudioOutputLog) << "Duplicate speech suppressed:" << text << "(elapsed ms:" << (now - lastSpoken) << ")";
            return true;
        }
    }
    return false;
}

void AudioOutput::_cleanupOldTimestamps()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    auto it = _recentSpeechTimestamps.begin();
    while (it != _recentSpeechTimestamps.end()) {
        if (now - it.value() > 30000) {
            it = _recentSpeechTimestamps.erase(it);
        } else {
            ++it;
        }
    }
}

void AudioOutput::say(const QString &text, TextMods textMods)
{
    if (!_initialized || _volumeSetting() <= 0.0 || _mutedSetting() || !_speakCapable) {
        return;
    }

    QString outText = _fixTextMessageForAudio(text);
    if (textMods.testFlag(TextMod::Translate)) {
        outText = tr("%1").arg(outText);
    }
    outText = outText.trimmed();
    if (outText.isEmpty()) {
        return;
    }

    if (_isDuplicate(outText, 8000)) {
        return;
    }

    if (_speechQueue.size() >= kMaxTextQueueSize) {
        qCWarning(AudioOutputLog) << "Speech queue full, dropping oldest item";
        _speechQueue.dequeue();
    }

    SpeechQueueItem item;
    item.text = outText;
    item.isAlert = false;
    item.enqueueTimeMs = QDateTime::currentMSecsSinceEpoch();
    _speechQueue.enqueue(item);

    if (!_isSpeaking) {
        _processNextQueueItem();
    }
}

void AudioOutput::sayAlert(const QString &text)
{
    if (!_initialized || _volumeSetting() <= 0.0 || _mutedSetting() || !_speakCapable) {
        return;
    }

    const QString normalizedText = text.simplified();
    if (normalizedText.isEmpty()) {
        return;
    }

    const QString outText = _fixTextMessageForAudio(normalizedText);
    if (outText.isEmpty()) {
        return;
    }

    if (_isDuplicate(outText, 6000)) {
        return;
    }

    SpeechQueueItem item;
    item.text = outText;
    item.isAlert = true;
    item.enqueueTimeMs = QDateTime::currentMSecsSinceEpoch();

    // Critical Alert: Preempt or insert at front of queue
    if (_isSpeaking && _currentProcess) {
        // Preempt current non-alert speaking process
        _speechQueue.prepend(item);
        _currentProcess->kill();
    } else {
        _speechQueue.prepend(item);
        _processNextQueueItem();
    }
}

void AudioOutput::sayPeriodic(const QString &text)
{
    if (!_initialized || _volumeSetting() <= 0.0 || _mutedSetting() || !_speakCapable) {
        return;
    }

    // Periodic announcements (altitude callouts) are only spoken if queue is completely idle
    if (_isSpeaking || !_speechQueue.isEmpty()) {
        return;
    }

    const QString outText = _fixTextMessageForAudio(text.trimmed());
    if (outText.isEmpty()) {
        return;
    }

    if (_isDuplicate(outText, 5000)) {
        return;
    }

    SpeechQueueItem item;
    item.text = outText;
    item.isAlert = false;
    item.enqueueTimeMs = QDateTime::currentMSecsSinceEpoch();
    _speechQueue.enqueue(item);

    _processNextQueueItem();
}

void AudioOutput::_processNextQueueItem()
{
    if (_speechQueue.isEmpty()) {
        _isSpeaking = false;
        return;
    }

    SpeechQueueItem item = _speechQueue.dequeue();
    _isSpeaking = true;
    _recentSpeechTimestamps[item.text] = QDateTime::currentMSecsSinceEpoch();

#ifdef Q_OS_LINUX
    _currentProcess = new QProcess(this);
    connect(_currentProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &AudioOutput::_onProcessFinished);
    _currentProcess->start("sh", QStringList() << "-c" << "espeak-ng -s 150 --stdout | pw-play -");
    _currentProcess->write(item.text.toUtf8());
    _currentProcess->closeWriteChannel();
#else
    (void) QMetaObject::invokeMethod(_engine, [this, item]() {
        _engine->say(item.text);
    });
#endif
}

void AudioOutput::_onProcessFinished(int, QProcess::ExitStatus)
{
    if (_currentProcess) {
        _currentProcess->deleteLater();
        _currentProcess = nullptr;
    }
    _isSpeaking = false;

    // Small 150ms natural cadence pause between successive queue items
    QTimer::singleShot(150, this, &AudioOutput::_processNextQueueItem);
}

void AudioOutput::testAudioOutput()
{
    if (!_initialized) {
        qCWarning(AudioOutputLog) << "AudioOutput not initialized. Call init() before using testAudioOutput().";
        return;
    }

    if (_currentProcess) {
        _currentProcess->kill();
    }
    _speechQueue.clear();
    _isSpeaking = false;

    const QString testText = tr("Audio test. Volume is %1 percent").arg(_volumeSetting(), 0, 'f', 1);
    say(testText);
}

QString AudioOutput::_fixTextMessageForAudio(const QString &string)
{
    QString result = string;
    result = _replaceAbbreviations(result);
    result = _replaceNegativeSigns(result);
    result = _replaceDecimalPoints(result);
    result = _replaceMeters(result);
    result = _convertMilliseconds(result);
    return result;
}

QString AudioOutput::_replaceAbbreviations(const QString &input)
{
    QStringList words = input.split(' ');
    for (QString &word : words) {
        const auto it = _textHash.constFind(word.toUpper());
        if (it != _textHash.constEnd()) {
            word = it.value();
        }
    }

    return words.join(' ');
}

QString AudioOutput::_replaceNegativeSigns(const QString &input)
{
    static const QRegularExpression negNumRegex(QStringLiteral("-\\s*(?=\\d)"));
    Q_ASSERT(negNumRegex.isValid());

    QString output = input;
    (void) output.replace(negNumRegex, "negative ");
    return output;
}

QString AudioOutput::_replaceDecimalPoints(const QString &input)
{
    static const QRegularExpression realNumRegex(QStringLiteral("([0-9]+)(\\.)([0-9]+)"));
    Q_ASSERT(realNumRegex.isValid());

    QString output = input;
    QRegularExpressionMatch realNumRegexMatch = realNumRegex.match(output);
    while (realNumRegexMatch.hasMatch()) {
        if (!realNumRegexMatch.captured(2).isNull()) {
            (void) output.replace(realNumRegexMatch.capturedStart(2), realNumRegexMatch.capturedEnd(2) - realNumRegexMatch.capturedStart(2), QStringLiteral(" point "));
        }
        realNumRegexMatch = realNumRegex.match(output);
    }

    return output;
}

QString AudioOutput::_replaceMeters(const QString &input)
{
    static const QRegularExpression realNumMeterRegex(QStringLiteral("[0-9]*\\.?[0-9]\\s?(m)([^A-Za-z]|$)"));
    Q_ASSERT(realNumMeterRegex.isValid());

    QString output = input;
    QRegularExpressionMatch realNumMeterRegexMatch = realNumMeterRegex.match(output);
    while (realNumMeterRegexMatch.hasMatch()) {
        if (!realNumMeterRegexMatch.captured(1).isNull()) {
            (void) output.replace(realNumMeterRegexMatch.capturedStart(1), realNumMeterRegexMatch.capturedEnd(1) - realNumMeterRegexMatch.capturedStart(1), QStringLiteral(" meters"));
        }
        realNumMeterRegexMatch = realNumMeterRegex.match(output);
    }

    return output;
}

QString AudioOutput::_convertMilliseconds(const QString &input)
{
    QString result = input;

    QString match;
    int number;
    if (_getMillisecondString(input, match, number) && (number >= 1000)) {
        QString newNumber;
        if (number < 60000) {
            const int seconds = number / 1000;
            const int ms = number - (seconds * 1000);
            newNumber = QStringLiteral("%1 second%2").arg(seconds).arg(seconds > 1 ? "s" : "");
            if (ms > 0) {
                (void) newNumber.append(QStringLiteral(" and %1 millisecond").arg(ms));
            }
        } else {
            const int minutes = number / 60000;
            const int seconds = (number - (minutes * 60000)) / 1000;
            newNumber = QStringLiteral("%1 minute%2").arg(minutes).arg(minutes > 1 ? "s" : "");
            if (seconds > 0) {
                (void) newNumber.append(QStringLiteral(" and %1 second%2").arg(seconds).arg(seconds > 1 ? "s" : ""));
            }
        }
        (void) result.replace(match, newNumber);
    }

    return result;
}

bool AudioOutput::_getMillisecondString(const QString &string, QString &match, int &number)
{
    static const QRegularExpression msRegex("((?<number>[0-9]+)ms)");
    Q_ASSERT(msRegex.isValid());

    bool result = false;

    QRegularExpressionMatch regexpMatch = msRegex.match(string);
    if (regexpMatch.hasMatch()) {
        match = regexpMatch.captured(0);
        const QString numberStr = regexpMatch.captured("number");
        number = numberStr.toInt();
        result = true;
    }

    return result;
}
