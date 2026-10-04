#pragma once

#include <QtCore/QObject>
#include <QtCore/QElapsedTimer>
#include <QtCore/QString>
#include <QtCore/QQueue>
#include <QtCore/QHash>
#include <QtCore/QProcess>

#include <chrono>

class QTextToSpeech;
class Fact;
class AudioOutputTest;

struct SpeechQueueItem {
    QString text;
    bool isAlert = false;
    qint64 enqueueTimeMs = 0;
};

/// \brief The AudioOutput class provides functionality for audio output using text-to-speech.
///
class AudioOutput : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

    friend AudioOutputTest;

public:
    /// Enumeration for text modification options.
    enum class TextMod {
        None = 0,
        Translate = 1 << 0,
    };
    Q_FLAG(TextMod)
    Q_DECLARE_FLAGS(TextMods, TextMod)

    /// Constructs an AudioOutput object.
    ///     @param parent The parent QObject.
    explicit AudioOutput(QObject *parent = nullptr);

    /// Destructor for the AudioOutput class.
    ~AudioOutput();

    /// Gets the singleton instance of AudioOutput.
    ///     @return The singleton instance.
    static AudioOutput *instance();

    /// True when the selected text-to-speech engine can synthesize speech.
    bool available() const { return _available; }

    /// Initialize the Singleton
    void init(Fact *volumeFact, Fact *mutedFact);

    /// Reads the specified text with optional text modifications.
    ///     @param text The text to be read.
    ///     @param textMods The text modifications to apply.
    void say(const QString &text, TextMods textMods = TextMod::None);

    /// Speaks an operational alert immediately, preempting lower-priority queued
    /// speech. Identical alerts are suppressed for a short cooldown.
    void sayAlert(const QString &text);

    /// Speaks replaceable periodic information only when the engine is idle.
    /// This is used for altitude callouts so stale values never form a backlog.
    void sayPeriodic(const QString &text);

    /// Tests the audio output. Will stop current output before test
    void testAudioOutput();

signals:
    void availableChanged();

private slots:
    void _processNextQueueItem();
    void _onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    QTextToSpeech *_engine = nullptr;
    qsizetype _textQueueSize = 0;
    bool _initialized = false;
    bool _speakCapable = false;
    bool _available = false;
    Fact *_volumeFact = nullptr;
    Fact *_mutedFact = nullptr;
    double _lastVolume = -1.0;
    QString _lastAlertText;
    QElapsedTimer _lastAlertTimer;

    // Sequential audio queue & deduplication
    QQueue<SpeechQueueItem> _speechQueue;
    QHash<QString, qint64> _recentSpeechTimestamps;
    QProcess *_currentProcess = nullptr;
    bool _isSpeaking = false;

    bool _isDuplicate(const QString &text, qint64 cooldownMs = 8000);
    void _cleanupOldTimestamps();

    /// Returns the current volume (0.0 - 100.0) from the settings Fact.
    double _volumeSetting() const;

    /// Returns the current muted state from the settings Fact.
    bool _mutedSetting() const;

    /// Sets the TTS engine volume from the current Fact value.
    void _setVolume();

    /// Applies engine-dependent settings (locale, cached capabilities) for the current engine.
    void _applyEngineSettings();

    /// Finalizes initialization once the engine is Ready: applies settings, wires Facts, sets volume.
    void _finishInit();

    static const QHash<QString, QString> _textHash;

    static constexpr qsizetype kMaxTextQueueSize = 20;
    static constexpr std::chrono::seconds kAlertRepeatCooldown{8};

    /// Grace period for async TTS backends (e.g. Android service binding) to reach Ready before warning.
    static constexpr std::chrono::seconds kEngineInitWarnTimeout{10};

    /// Fixes text messages for audio output.
    ///     @param string The text message to fix.
    ///     @return The fixed text message.
    static QString _fixTextMessageForAudio(const QString &string);

    /// Replaces predefined abbreviations with their corresponding full forms.
    ///     @param input The input string containing abbreviations.
    ///     @return A string with abbreviations replaced by their full forms.
    static QString _replaceAbbreviations(const QString &input);

    /// Replaces negative signs with the word "negative".
    static QString _replaceNegativeSigns(const QString &input);

    /// Replaces decimal points with the word "point".
    static QString _replaceDecimalPoints(const QString &input);

    /// Replaces "m" (meters) with the word "meters" following numbers.
    static QString _replaceMeters(const QString &input);

    /// Converts millisecond values to a more readable format (seconds and minutes).
    static QString _convertMilliseconds(const QString &input);

    /// Extracts a millisecond value from the given string.
    ///     @param string The string to extract from.
    ///     @param match The extracted millisecond string.
    ///     @param number The extracted number.
    ///     @return True if extraction is successful, false otherwise.
    static bool _getMillisecondString(const QString &string, QString &match, int &number);
};
Q_DECLARE_OPERATORS_FOR_FLAGS(AudioOutput::TextMods)
