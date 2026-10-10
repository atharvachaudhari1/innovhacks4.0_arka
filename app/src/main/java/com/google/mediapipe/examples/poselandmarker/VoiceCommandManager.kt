package com.google.mediapipe.examples.poselandmarker

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log

interface VoiceCommandListener {
    fun onFinishSetCommand()
    fun onSmartRestCommand()
    fun onCoachHelpCommand()
    fun onSwitchExerciseCommand(newType: String)
    fun onAdjustWeightCommand(weightKg: Double)
    fun onCommandRecognized(commandText: String)
    fun onMicLevelChanged(levelPct: Float)
    fun onListeningStateChanged(isListening: Boolean, status: String)
}

class VoiceCommandManager private constructor(private val appContext: Context) : RecognitionListener {

    companion object {
        private const val TAG = "FitGuru VoiceCmd"
        private const val PREFS_NAME = "FitGuruPrefs"
        private const val KEY_VOICE_COMMANDS_ENABLED = "voice_commands_enabled"

        @Volatile
        private var instance: VoiceCommandManager? = null

        fun getInstance(context: Context): VoiceCommandManager {
            return instance ?: synchronized(this) {
                instance ?: VoiceCommandManager(context.applicationContext).also { instance = it }
            }
        }
    }

    private val sharedPrefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null
    private var recognizerIntent: Intent? = null

    var isListening: Boolean = false
        private set

    var isEnabled: Boolean
        get() = sharedPrefs.getBoolean(KEY_VOICE_COMMANDS_ENABLED, true)
        set(value) {
            sharedPrefs.edit().putBoolean(KEY_VOICE_COMMANDS_ENABLED, value).apply()
        }

    private var listener: VoiceCommandListener? = null
    private var lastCommandTime: Long = 0L
    private var shouldRestart = false

    fun setListener(listener: VoiceCommandListener?) {
        this.listener = listener
    }

    fun startListening() {
        if (!isEnabled) {
            listener?.onListeningStateChanged(false, "Voice commands disabled")
            return
        }

        if (!SpeechRecognizer.isRecognitionAvailable(appContext)) {
            listener?.onListeningStateChanged(false, "Speech recognition unavailable")
            return
        }

        shouldRestart = true
        mainHandler.post {
            initRecognizerIfNeeded()
            try {
                speechRecognizer?.startListening(recognizerIntent)
                isListening = true
                listener?.onListeningStateChanged(true, "Listening: say 'finish set' or 'smart rest'...")
            } catch (e: Exception) {
                Log.e(TAG, "startListening error: ${e.message}")
                isListening = false
                scheduleRestart(1000)
            }
        }
    }

    fun stopListening() {
        shouldRestart = false
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.cancel()
            } catch (e: Exception) {
                Log.w(TAG, "stopListening error: ${e.message}")
            }
            isListening = false
            listener?.onListeningStateChanged(false, "Voice idle")
        }
    }

    private fun initRecognizerIfNeeded() {
        if (speechRecognizer == null) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(appContext).apply {
                setRecognitionListener(this@VoiceCommandManager)
            }
            recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            }
        }
    }

    private fun scheduleRestart(delayMs: Long) {
        if (!shouldRestart || !isEnabled) return
        mainHandler.postDelayed({
            if (shouldRestart && isEnabled) {
                try {
                    speechRecognizer?.cancel()
                    speechRecognizer?.startListening(recognizerIntent)
                    isListening = true
                } catch (e: Exception) {
                    Log.w(TAG, "restart error: ${e.message}")
                    scheduleRestart(1500)
                }
            }
        }, delayMs)
    }

    override fun onReadyForSpeech(params: Bundle?) {
        isListening = true
        listener?.onListeningStateChanged(true, "Listening for commands...")
    }

    override fun onBeginningOfSpeech() {}

    override fun onRmsChanged(rmsdB: Float) {
        val level = ((rmsdB + 2f) / 12f).coerceIn(0.1f, 1.0f)
        listener?.onMicLevelChanged(level)
    }

    override fun onBufferReceived(buffer: ByteArray?) {}

    override fun onEndOfSpeech() {
        isListening = false
    }

    override fun onError(error: Int) {
        isListening = false
        Log.d(TAG, "Speech recognition error code: $error")
        // Auto-restart on timeout, no speech, or server busy
        scheduleRestart(600)
    }

    override fun onResults(results: Bundle?) {
        isListening = false
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            val spokenText = matches[0].lowercase().trim()
            parseCommand(spokenText)
        }
        scheduleRestart(400)
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if (!matches.isNullOrEmpty()) {
            val partialText = matches[0].lowercase().trim()
            parseCommand(partialText)
        }
    }

    override fun onEvent(eventType: Int, params: Bundle?) {}

    private fun parseCommand(text: String) {
        // Prevent speech feedback while coach is speaking (avoid echo loops)
        if (ElevenLabsService.getInstance(appContext).isSpeaking) return

        // Debounce triggers (min 2 seconds between commands)
        val now = System.currentTimeMillis()
        if (now - lastCommandTime < 2000L) return

        Log.i(TAG, "Parsing voice candidate: $text")

        // 1. FINISH SET
        if (text.contains("finish set") || text.contains("end set") ||
            text.contains("finish workout") || text.contains("end workout") ||
            text.contains("stop workout") || text.contains("complete set")
        ) {
            lastCommandTime = now
            listener?.onCommandRecognized("Finish Set")
            listener?.onFinishSetCommand()
            return
        }

        // 2. SMART REST
        if (text.contains("smart rest") || text.contains("start rest") ||
            text.contains("rest timer") || text.contains("rest time") ||
            text.contains("take a break") || text.contains("need a rest")
        ) {
            lastCommandTime = now
            listener?.onCommandRecognized("Smart Rest")
            listener?.onSmartRestCommand()
            return
        }

        // 3. COACH HELP
        if (text.contains("coach help") || text.contains("how is my form") ||
            text.contains("check my form") || text.contains("coach advice") ||
            text.contains("form check")
        ) {
            lastCommandTime = now
            listener?.onCommandRecognized("Form Check")
            listener?.onCoachHelpCommand()
            return
        }

        // 4. EXERCISE SWITCHING
        val matchedExercise = when {
            text.contains("squat") -> "SQUAT"
            text.contains("push up") || text.contains("pushup") -> "PUSH_UP"
            text.contains("lunge") -> "LUNGE"
            text.contains("curl") || text.contains("bicep") -> "BICEP_CURL"
            text.contains("deadlift") -> "DEADLIFT"
            text.contains("bench press") -> "BENCH_PRESS"
            text.contains("shoulder press") -> "SHOULDER_PRESS"
            text.contains("leg press") -> "LEG_PRESS"
            text.contains("lat pulldown") -> "LAT_PULLDOWN"
            text.contains("plank") -> "PLANK"
            else -> null
        }

        if (matchedExercise != null && (text.contains("switch to") || text.contains("start") || text.contains("change to"))) {
            lastCommandTime = now
            listener?.onCommandRecognized("Switch to $matchedExercise")
            listener?.onSwitchExerciseCommand(matchedExercise)
            return
        }

        // 5. WEIGHT ADJUSTMENT ("weight 20", "set weight to 50")
        if (text.contains("weight") || text.contains("kg")) {
            val digits = text.filter { it.isDigit() }
            if (digits.isNotEmpty()) {
                val parsedWeight = digits.toDoubleOrNull()
                if (parsedWeight != null && parsedWeight in 1.0..300.0) {
                    lastCommandTime = now
                    listener?.onCommandRecognized("Weight: ${parsedWeight.toInt()} kg")
                    listener?.onAdjustWeightCommand(parsedWeight)
                    return
                }
            }
        }
    }

    fun destroy() {
        stopListening()
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }
}
