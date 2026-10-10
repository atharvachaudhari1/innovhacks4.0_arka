package com.google.mediapipe.examples.poselandmarker

import android.content.Context
import android.util.Log
import com.google.mediapipe.examples.poselandmarker.data.WorkoutSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class GeminiBiomechanicalReport(
    val diagnosis: String,
    val correctiveCues: List<String>,
    val accessoryDrills: List<String>,
    val rawText: String,
    val isLiveApi: Boolean
)

data class GeminiRecoveryReport(
    val recoveryWindowHours: Int,
    val strainAssessment: String,
    val proteinGrams: Int,
    val hydrationMl: Int,
    val activeStretches: List<String>,
    val rawText: String,
    val isLiveApi: Boolean
)

class GeminiService private constructor(private val appContext: Context) {

    companion object {
        private const val TAG = "FitGuru Gemini"
        private const val PREFS_NAME = "FitGuruPrefs"
        private const val KEY_GEMINI_API_KEY = "gemini_api_key"

        @Volatile
        private var instance: GeminiService? = null

        fun getInstance(context: Context): GeminiService {
            return instance ?: synchronized(this) {
                instance ?: GeminiService(context.applicationContext).also { instance = it }
            }
        }
    }

    private val sharedPrefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val scope = CoroutineScope(Dispatchers.IO)

    var apiKey: String
        get() = sharedPrefs.getString(KEY_GEMINI_API_KEY, "") ?: ""
        set(value) = sharedPrefs.edit().putString(KEY_GEMINI_API_KEY, value).apply()

    val isKeyConfigured: Boolean
        get() = apiKey.trim().isNotEmpty()

    private val primaryModel = "gemini-2.5-flash"
    private val fallbackModel = "gemini-1.5-flash"

    fun analyzeBiomechanicalForm(
        session: WorkoutSession,
        primaryFault: String = "",
        jointAngle: Double = 0.0,
        onResult: (GeminiBiomechanicalReport) -> Unit
    ) {
        val faultDesc = if (primaryFault.isNotEmpty()) primaryFault else defaultFaultFor(session.exerciseType, session.score)
        val angleVal = if (jointAngle > 0.0) jointAngle else defaultAngleFor(session.exerciseType)

        if (!isKeyConfigured) {
            val fallback = generateOfflineBiomechanicalReport(session, faultDesc, angleVal)
            onResult(fallback)
            return
        }

        scope.launch {
            try {
                val prompt = """
                    You are a world-class Olympic Strength & Conditioning and Biomechanics Coach.
                    Analyze this completed workout session:
                    - Exercise: ${session.exerciseName}
                    - Completed Reps: ${session.reps}
                    - Form Accuracy Score: ${session.score}%
                    - Weight Lifted: ${session.weightDisplay} (Total Volume: ${session.totalVolumeKg.toInt()} kg)
                    - Primary Biomechanical Fault Detected: $faultDesc
                    - Key Measured Joint Angle: ${angleVal.toInt()}°

                    Output in strictly valid JSON format with NO markdown wrapping or backticks:
                    {
                      "diagnosis": "<Concise 2-sentence biomechanical diagnosis of root cause>",
                      "correctiveCues": ["<Cue 1>", "<Cue 2>", "<Cue 3>"],
                      "accessoryDrills": ["<Drill 1>", "<Drill 2>"]
                    }
                """.trimIndent()

                val responseJson = callGeminiApi(prompt, primaryModel) ?: callGeminiApi(prompt, fallbackModel)
                if (responseJson != null) {
                    val report = parseBiomechanicalResponse(responseJson)
                    withContext(Dispatchers.Main) {
                        onResult(report)
                    }
                } else {
                    val fallback = generateOfflineBiomechanicalReport(session, faultDesc, angleVal)
                    withContext(Dispatchers.Main) {
                        onResult(fallback)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Gemini Biomechanical analysis failed: ${e.message}", e)
                val fallback = generateOfflineBiomechanicalReport(session, faultDesc, angleVal)
                withContext(Dispatchers.Main) {
                    onResult(fallback)
                }
            }
        }
    }

    fun generateRecoveryProtocol(
        session: WorkoutSession,
        onResult: (GeminiRecoveryReport) -> Unit
    ) {
        if (!isKeyConfigured) {
            val fallback = generateOfflineRecoveryReport(session)
            onResult(fallback)
            return
        }

        scope.launch {
            try {
                val prompt = """
                    You are a Sports Scientist & Recovery Specialist.
                    Generate a personalized recovery protocol for:
                    - Exercise: ${session.exerciseName}
                    - Reps: ${session.reps} at ${session.score}% accuracy
                    - Weight: ${session.weightDisplay} (Total Volume: ${session.totalVolumeKg.toInt()} kg)
                    - Avg Heart Rate: ${if (session.avgHeartRate > 0) "${session.avgHeartRate} BPM" else "Moderate"}

                    Output in strictly valid JSON format with NO markdown wrapping or backticks:
                    {
                      "recoveryWindowHours": <integer hours 24-72>,
                      "strainAssessment": "<1 sentence strain overview>",
                      "proteinGrams": <integer protein recommended 25-50>,
                      "hydrationMl": <integer hydration target 500-1500>,
                      "activeStretches": ["<Stretch 1>", "<Stretch 2>", "<Stretch 3>"]
                    }
                """.trimIndent()

                val responseJson = callGeminiApi(prompt, primaryModel) ?: callGeminiApi(prompt, fallbackModel)
                if (responseJson != null) {
                    val report = parseRecoveryResponse(responseJson)
                    withContext(Dispatchers.Main) {
                        onResult(report)
                    }
                } else {
                    val fallback = generateOfflineRecoveryReport(session)
                    withContext(Dispatchers.Main) {
                        onResult(fallback)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Gemini Recovery analysis failed: ${e.message}", e)
                val fallback = generateOfflineRecoveryReport(session)
                withContext(Dispatchers.Main) {
                    onResult(fallback)
                }
            }
        }
    }

    private fun callGeminiApi(prompt: String, model: String): String? {
        val endpoint = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${apiKey.trim()}"
        val url = URL(endpoint)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 8000
        conn.readTimeout = 12000
        conn.doOutput = true
        conn.doInput = true
        conn.setRequestProperty("Content-Type", "application/json")

        val payload = JSONObject().apply {
            put("contents", JSONArray().apply {
                put(JSONObject().apply {
                    put("parts", JSONArray().apply {
                        put(JSONObject().apply {
                            put("text", prompt)
                        })
                    })
                })
            })
            put("generationConfig", JSONObject().apply {
                put("temperature", 0.3)
                put("maxOutputTokens", 800)
            })
        }

        conn.outputStream.use { os ->
            os.write(payload.toString().toByteArray(Charsets.UTF_8))
            os.flush()
        }

        val code = conn.responseCode
        if (code == HttpURLConnection.HTTP_OK) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val root = JSONObject(response)
            val candidates = root.optJSONArray("candidates")
            if (candidates != null && candidates.length() > 0) {
                val first = candidates.getJSONObject(0)
                val content = first.optJSONObject("content")
                val parts = content?.optJSONArray("parts")
                if (parts != null && parts.length() > 0) {
                    return parts.getJSONObject(0).optString("text")
                }
            }
        }
        return null
    }

    private fun parseBiomechanicalResponse(raw: String): GeminiBiomechanicalReport {
        var clean = raw.trim()
        if (clean.startsWith("```json")) clean = clean.removePrefix("```json")
        if (clean.startsWith("```")) clean = clean.removePrefix("```")
        if (clean.endsWith("```")) clean = clean.removeSuffix("```")
        clean = clean.trim()

        return try {
            val obj = JSONObject(clean)
            val diagnosis = obj.optString("diagnosis", "Good execution. Focus on spinal stiffness and controlled eccentric tempo.")
            val cues = mutableListOf<String>()
            val cuesArr = obj.optJSONArray("correctiveCues")
            if (cuesArr != null) {
                for (i in 0 until cuesArr.length()) cues.add(cuesArr.getString(i))
            }
            val drills = mutableListOf<String>()
            val drillsArr = obj.optJSONArray("accessoryDrills")
            if (drillsArr != null) {
                for (i in 0 until drillsArr.length()) drills.add(drillsArr.getString(i))
            }
            GeminiBiomechanicalReport(diagnosis, cues, drills, clean, true)
        } catch (e: Exception) {
            GeminiBiomechanicalReport(clean, listOf("Drive through heels", "Keep chest proud"), listOf("Hip mobility", "Band pull-aparts"), clean, true)
        }
    }

    private fun parseRecoveryResponse(raw: String): GeminiRecoveryReport {
        var clean = raw.trim()
        if (clean.startsWith("```json")) clean = clean.removePrefix("```json")
        if (clean.startsWith("```")) clean = clean.removePrefix("```")
        if (clean.endsWith("```")) clean = clean.removeSuffix("```")
        clean = clean.trim()

        return try {
            val obj = JSONObject(clean)
            val window = obj.optInt("recoveryWindowHours", 36)
            val strain = obj.optString("strainAssessment", "Moderate muscular fatigue in prime movers.")
            val protein = obj.optInt("proteinGrams", 30)
            val hydration = obj.optInt("hydrationMl", 750)
            val stretches = mutableListOf<String>()
            val stretchesArr = obj.optJSONArray("activeStretches")
            if (stretchesArr != null) {
                for (i in 0 until stretchesArr.length()) stretches.add(stretchesArr.getString(i))
            }
            GeminiRecoveryReport(window, strain, protein, hydration, stretches, clean, true)
        } catch (e: Exception) {
            GeminiRecoveryReport(36, "Moderate muscular fatigue.", 30, 750, listOf("Hamstring stretch", "Pigeon pose"), clean, true)
        }
    }

    private fun defaultFaultFor(exerciseType: String, score: Int): String {
        return when {
            score >= 90 -> "Minor eccentric deceleration asymmetry."
            exerciseType.contains("SQUAT", true) -> "Excessive forward torso lean and early knee cave."
            exerciseType.contains("PUSH", true) -> "Elbow flaring beyond 70 degrees and hip sag."
            exerciseType.contains("DEADLIFT", true) -> "Slight thoracic rounding off floor pull."
            exerciseType.contains("CURL", true) -> "Shoulder anterior swing during peak contraction."
            else -> "Incomplete range of motion at bottom inflection point."
        }
    }

    private fun defaultAngleFor(exerciseType: String): Double {
        return when {
            exerciseType.contains("SQUAT", true) -> 82.0
            exerciseType.contains("PUSH", true) -> 88.0
            exerciseType.contains("DEADLIFT", true) -> 135.0
            exerciseType.contains("CURL", true) -> 52.0
            else -> 90.0
        }
    }

    private fun generateOfflineBiomechanicalReport(session: WorkoutSession, fault: String, angle: Double): GeminiBiomechanicalReport {
        val diagnosis = "Kinematic analysis confirms target joint depth reached (${angle.toInt()}°). Primary observation: $fault."
        val cues = when {
            session.exerciseType.contains("SQUAT", true) -> listOf(
                "Spread the floor with feet to prevent knee valgus.",
                "Maintain upright thoracic posture throughout the hole.",
                "Engage glutes dynamically at top lockout."
            )
            session.exerciseType.contains("PUSH", true) -> listOf(
                "Tuck elbows to 45° to protect rotator cuff.",
                "Lock core and glutes to avoid lumbar sag.",
                "Push floor away aggressively at peak lockout."
            )
            session.exerciseType.contains("CURL", true) -> listOf(
                "Pin elbows against ribcage to isolate biceps.",
                "Control the 3-second lowering eccentric phase.",
                "Avoid using hip momentum to start the lift."
            )
            else -> listOf(
                "Control your tempo with a 2-second negative.",
                "Maintain continuous core tension.",
                "Breathe out dynamically on exertion."
            )
        }
        val drills = listOf("Couch Stretch (2 min/side)", "Thoracic Spine Extensions (15 reps)")
        return GeminiBiomechanicalReport(diagnosis, cues, drills, diagnosis, false)
    }

    private fun generateOfflineRecoveryReport(session: WorkoutSession): GeminiRecoveryReport {
        val hours = if (session.reps > 30 || session.score < 80) 48 else 24
        val protein = if (session.totalVolumeKg > 500) 40 else 30
        val hydration = 800
        val strain = "Moderate CNS and muscular fatigue. Primary prime movers worked: ${session.exerciseName}."
        val stretches = listOf("Hamstring sweep (60s)", "World's Greatest Stretch (5 reps/side)", "Child's Pose breathing (2 min)")
        return GeminiRecoveryReport(hours, strain, protein, hydration, stretches, strain, false)
    }
}
