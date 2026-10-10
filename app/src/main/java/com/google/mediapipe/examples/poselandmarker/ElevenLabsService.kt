package com.google.mediapipe.examples.poselandmarker

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale

enum class CoachPersona(
    val id: String,
    val displayName: String,
    val subtitle: String,
    val icon: String,
    val voiceId: String,
    val samplePhrase: String
) {
    DRILL_SERGEANT(
        "marcus",
        "Coach Marcus",
        "Drill Sergeant • High Intensity & Grit",
        "🔥",
        "onwK4e9ZLuTAKqWW03F9", // Daniel
        "Let's go! Chest up, drive through your heels, don't quit on me!"
    ),
    MINDFUL_MAYA(
        "maya",
        "Coach Maya",
        "Mindful Guide • Calm, Form & Breath",
        "🧘",
        "EXAVITQu4vr4xnSDxMaL", // Sarah
        "Breathe in deeply, find your balance, and maintain a calm, steady rhythm."
    ),
    OLYMPIAN_ALEX(
        "alex",
        "Coach Alex",
        "The Olympian • Biomechanical Precision",
        "🏆",
        "ErXwobaYiN019PkySvjV", // Antoni
        "Excellent bar path. Lock your hips out at the peak of each repetition."
    );

    companion object {
        fun fromId(id: String): CoachPersona {
            return values().firstOrNull { it.id == id } ?: DRILL_SERGEANT
        }
    }
}

class ElevenLabsService private constructor(private val appContext: Context) : TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "FitGuru ElevenLabs"
        private const val PREFS_NAME = "FitGuruPrefs"
        private const val KEY_ELEVENLABS_ENABLED = "elevenlabs_enabled"
        private const val KEY_ELEVENLABS_API_KEY = "elevenlabs_api_key"
        private const val KEY_ELEVENLABS_PERSONA = "elevenlabs_persona"

        @Volatile
        private var instance: ElevenLabsService? = null

        fun getInstance(context: Context): ElevenLabsService {
            return instance ?: synchronized(this) {
                instance ?: ElevenLabsService(context.applicationContext).also { instance = it }
            }
        }
    }

    private val sharedPrefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val scope = CoroutineScope(Dispatchers.IO)
    private val cacheDir = File(appContext.cacheDir, "elevenlabs_cache").apply { if (!exists()) mkdirs() }

    private var mediaPlayer: MediaPlayer? = null
    private var textToSpeech: TextToSpeech? = null
    private var isTtsReady = false

    var isSpeaking: Boolean = false
        private set

    var isEnabled: Boolean
        get() = sharedPrefs.getBoolean(KEY_ELEVENLABS_ENABLED, true)
        set(value) = sharedPrefs.edit().putBoolean(KEY_ELEVENLABS_ENABLED, value).apply()

    var apiKey: String
        get() = sharedPrefs.getString(KEY_ELEVENLABS_API_KEY, "") ?: ""
        set(value) = sharedPrefs.edit().putString(KEY_ELEVENLABS_API_KEY, value).apply()

    var selectedPersona: CoachPersona
        get() {
            val id = sharedPrefs.getString(KEY_ELEVENLABS_PERSONA, CoachPersona.DRILL_SERGEANT.id)
            return CoachPersona.fromId(id ?: CoachPersona.DRILL_SERGEANT.id)
        }
        set(value) = sharedPrefs.edit().putString(KEY_ELEVENLABS_PERSONA, value.id).apply()

    val isConfigured: Boolean
        get() = isEnabled && apiKey.trim().isNotEmpty()

    init {
        textToSpeech = TextToSpeech(appContext, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = textToSpeech?.setLanguage(Locale.US)
            isTtsReady = (result != TextToSpeech.LANG_MISSING_DATA && result != TextToSpeech.LANG_NOT_SUPPORTED)
        }
    }

    fun speak(text: String, onComplete: (() -> Void)? = null) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return

        if (!isEnabled || apiKey.trim().isEmpty()) {
            speakFallback(trimmed, onComplete)
            return
        }

        val persona = selectedPersona
        val cacheKey = hashString("${persona.voiceId}_$trimmed")
        val cachedFile = File(cacheDir, "$cacheKey.mp3")

        if (cachedFile.exists() && cachedFile.length() > 0) {
            playAudioFile(cachedFile, onComplete)
            return
        }

        scope.launch {
            try {
                val downloadedFile = fetchElevenLabsAudio(trimmed, persona, cachedFile)
                if (downloadedFile != null && downloadedFile.exists()) {
                    withContext(Dispatchers.Main) {
                        playAudioFile(downloadedFile, onComplete)
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        speakFallback(trimmed, onComplete)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "ElevenLabs API fetch failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    speakFallback(trimmed, onComplete)
                }
            }
        }
    }

    private fun fetchElevenLabsAudio(text: String, persona: CoachPersona, targetFile: File): File? {
        val endpoint = "https://api.elevenlabs.io/v1/text-to-speech/${persona.voiceId}?output_format=mp3_44100_128"
        val url = URL(endpoint)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 8000
        conn.readTimeout = 12000
        conn.doOutput = true
        conn.doInput = true
        conn.setRequestProperty("xi-api-key", apiKey.trim())
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("Accept", "audio/mpeg")

        val payload = JSONObject().apply {
            put("text", text)
            put("model_id", "eleven_turbo_v2_5")
            put("voice_settings", JSONObject().apply {
                put("stability", 0.5)
                put("similarity_boost", 0.75)
            })
        }

        conn.outputStream.use { os ->
            os.write(payload.toString().toByteArray(Charsets.UTF_8))
            os.flush()
        }

        val responseCode = conn.responseCode
        if (responseCode == HttpURLConnection.HTTP_OK) {
            conn.inputStream.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            return targetFile
        } else {
            val errText = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
            Log.w(TAG, "ElevenLabs error code $responseCode: $errText")
            return null
        }
    }

    private fun playAudioFile(file: File, onComplete: (() -> Void)?) {
        try {
            stopAudio()
            isSpeaking = true
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .build()
                )
                setDataSource(file.absolutePath)
                setOnCompletionListener {
                    isSpeaking = false
                    onComplete?.invoke()
                }
                setOnErrorListener { _, _, _ ->
                    isSpeaking = false
                    true
                }
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaPlayer error: ${e.message}", e)
            isSpeaking = false
            speakFallback(file.nameWithoutExtension, onComplete)
        }
    }

    private fun speakFallback(text: String, onComplete: (() -> Void)?) {
        if (!isTtsReady || textToSpeech == null) return
        isSpeaking = true
        val params = android.os.Bundle()
        textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "FitGuru_TTS")
        // Android TTS utterance listener or short delay reset
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            isSpeaking = false
            onComplete?.invoke()
        }, 1200)
    }

    fun stopAudio() {
        try {
            if (mediaPlayer?.isPlaying == true) {
                mediaPlayer?.stop()
            }
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.w(TAG, "stopAudio exception: ${e.message}")
        }
        textToSpeech?.stop()
        isSpeaking = false
    }

    fun shutdown() {
        stopAudio()
        textToSpeech?.shutdown()
        textToSpeech = null
    }

    private fun hashString(input: String): String {
        val bytes = MessageDigest.getInstance("MD5").digest(input.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
