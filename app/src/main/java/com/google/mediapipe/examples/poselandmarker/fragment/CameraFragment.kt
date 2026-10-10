package com.google.mediapipe.examples.poselandmarker.fragment

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.lifecycleScope
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import androidx.navigation.Navigation
import com.google.mediapipe.examples.poselandmarker.ElevenLabsService
import com.google.mediapipe.examples.poselandmarker.MainViewModel
import com.google.mediapipe.examples.poselandmarker.PoseLandmarkerHelper
import com.google.mediapipe.examples.poselandmarker.R
import com.google.mediapipe.examples.poselandmarker.SmartRestTimerBottomSheet
import com.google.mediapipe.examples.poselandmarker.VoiceCommandListener
import com.google.mediapipe.examples.poselandmarker.VoiceCommandManager
import com.google.mediapipe.examples.poselandmarker.WorkoutSummaryBottomSheet
import com.google.mediapipe.examples.poselandmarker.data.AppDatabase
import com.google.mediapipe.examples.poselandmarker.data.WorkoutSession
import com.google.mediapipe.examples.poselandmarker.databinding.FragmentCameraBinding
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class CameraFragment : Fragment(), PoseLandmarkerHelper.LandmarkerListener, TextToSpeech.OnInitListener, VoiceCommandListener {

    companion object {
        private const val TAG = "FitGuru Camera"
    }

    private var _fragmentCameraBinding: FragmentCameraBinding? = null
    private val fragmentCameraBinding get() = _fragmentCameraBinding!!

    private lateinit var heartRateReceiver: BroadcastReceiver
    private lateinit var poseLandmarkerHelper: PoseLandmarkerHelper
    private val viewModel: MainViewModel by activityViewModels()
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraFacing = CameraSelector.LENS_FACING_FRONT
    private lateinit var backgroundExecutor: ExecutorService
    private lateinit var textToSpeech: TextToSpeech
    private lateinit var elevenLabsService: ElevenLabsService
    private lateinit var voiceCommandManager: VoiceCommandManager

    private var currentWorkoutType: String = "SQUAT"
    private var repCount = 0
    private var goodFormReps = 0
    private var workoutState = "ready"
    private var lastFeedbackTime = 0L
    private var isGenerativeAiEnabled = true
    private var isAiThinking = false
    private var currentWeightKg = 0.0
    private var currentHeartRateBpm = 0
    private var lastMeasuredAngle = 0.0
    private var lastFaultDetected = ""

    // Plank Hold Timer
    private var plankTimerHandler: Handler? = null
    private var plankSeconds = 0
    private var isHoldingPlank = false
    private var plankGoodSeconds = 0

    // Running Cadence Tracker (vision-demos gait engine)
    private var runningStepCount = 0
    private var lastStepTime = 0L
    private val stepIntervals = LinkedList<Long>()
    private var currentCadenceSpm = 0
    private var lastLeadingFoot = ""

    override fun onResume() {
        super.onResume()
        if (!PermissionsFragment.hasPermissions(requireContext())) {
            Navigation.findNavController(requireActivity(), R.id.fragment_container)
                .navigate(R.id.action_camera_to_permissions)
        }
        if (this::backgroundExecutor.isInitialized) {
            backgroundExecutor.execute {
                if (this::poseLandmarkerHelper.isInitialized) {
                    poseLandmarkerHelper.resume()
                }
            }
        }
        if (this::voiceCommandManager.isInitialized) {
            voiceCommandManager.startListening()
        }
    }

    override fun onPause() {
        super.onPause()
        stopPlankTimer()
        if (this::voiceCommandManager.isInitialized) {
            voiceCommandManager.stopListening()
        }
        if (this::poseLandmarkerHelper.isInitialized) {
            viewModel.setMinPoseDetectionConfidence(poseLandmarkerHelper.minPoseDetectionConfidence)
            viewModel.setMinPoseTrackingConfidence(poseLandmarkerHelper.minPoseTrackingConfidence)
            viewModel.setMinPosePresenceConfidence(poseLandmarkerHelper.minPosePresenceConfidence)
            viewModel.setDelegate(poseLandmarkerHelper.currentDelegate)
            backgroundExecutor.execute {
                poseLandmarkerHelper.clearPoseLandmarker()
            }
        }
    }

    override fun onDestroyView() {
        stopPlankTimer()
        if (this::voiceCommandManager.isInitialized) {
            voiceCommandManager.setListener(null)
            voiceCommandManager.stopListening()
        }
        _fragmentCameraBinding = null
        super.onDestroyView()
        if (this::heartRateReceiver.isInitialized) {
            LocalBroadcastManager.getInstance(requireContext()).unregisterReceiver(heartRateReceiver)
        }
        if (this::backgroundExecutor.isInitialized) {
            backgroundExecutor.shutdown()
            backgroundExecutor.awaitTermination(500, TimeUnit.MILLISECONDS)
        }
        if (this::textToSpeech.isInitialized) {
            textToSpeech.stop()
            textToSpeech.shutdown()
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?
    ): View {
        _fragmentCameraBinding = FragmentCameraBinding.inflate(inflater, container, false)
        currentWorkoutType = activity?.intent?.getStringExtra("WORKOUT_TYPE") ?: "SQUAT"
        return fragmentCameraBinding.root
    }

    @SuppressLint("MissingPermission")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        elevenLabsService = ElevenLabsService.getInstance(requireContext())
        voiceCommandManager = VoiceCommandManager.getInstance(requireContext())
        voiceCommandManager.setListener(this)

        setupExerciseHeader()
        updateCoachPersonaBadge()
        updateWeightUI()

        heartRateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val bpm = intent?.getIntExtra("BPM_EXTRA", 0) ?: 0
                if (_fragmentCameraBinding != null && bpm > 0) {
                    currentHeartRateBpm = bpm
                    fragmentCameraBinding.heartRateText.text = "$bpm BPM"
                }
            }
        }
        LocalBroadcastManager.getInstance(requireContext()).registerReceiver(
            heartRateReceiver, IntentFilter("heart-rate-update")
        )

        backgroundExecutor = Executors.newSingleThreadExecutor()
        fragmentCameraBinding.viewFinder.post { setUpCamera() }

        backgroundExecutor.execute {
            poseLandmarkerHelper = PoseLandmarkerHelper(
                context = requireContext(),
                minPoseDetectionConfidence = viewModel.currentMinPoseDetectionConfidence,
                minPoseTrackingConfidence = viewModel.currentMinPoseTrackingConfidence,
                minPosePresenceConfidence = viewModel.currentMinPosePresenceConfidence,
                currentDelegate = viewModel.currentDelegate,
                poseLandmarkerHelperListener = this
            )
        }

        textToSpeech = TextToSpeech(requireContext(), this)

        fragmentCameraBinding.finishWorkoutButton.setOnClickListener {
            finishAndSaveSession()
        }

        fragmentCameraBinding.smartRestButton.setOnClickListener {
            showSmartRestTimer()
        }

        fragmentCameraBinding.btnWeightPlus.setOnClickListener {
            currentWeightKg += 2.5
            updateWeightUI()
        }

        fragmentCameraBinding.btnWeightMinus.setOnClickListener {
            currentWeightKg = maxOf(0.0, currentWeightKg - 2.5)
            updateWeightUI()
        }

        fragmentCameraBinding.voiceStatusPill.setOnClickListener {
            voiceCommandManager.isEnabled = !voiceCommandManager.isEnabled
            if (voiceCommandManager.isEnabled) {
                voiceCommandManager.startListening()
                Toast.makeText(requireContext(), "Voice Commands Activated", Toast.LENGTH_SHORT).show()
            } else {
                voiceCommandManager.stopListening()
                Toast.makeText(requireContext(), "Voice Commands Deactivated", Toast.LENGTH_SHORT).show()
            }
        }

        if (currentWorkoutType == "PLANK") {
            startPlankTimer()
        }
    }

    private fun setupExerciseHeader() {
        resetSubjectLock()
        val (icon, title) = when (currentWorkoutType) {
            "SQUAT" -> "🏋️" to "FitGuru AI • Squats"
            "PUSH_UP" -> "🤸" to "FitGuru AI • Push-ups"
            "BICEP_CURL" -> "💪" to "FitGuru AI • Bicep Curls"
            "LUNGE" -> "🦵" to "FitGuru AI • Lunges"
            "PLANK" -> "🧘" to "FitGuru AI • Plank Hold"
            "DEADLIFT" -> "🏋️" to "FitGuru AI • Barbell Deadlift"
            "PULL_UP" -> "🧗" to "FitGuru AI • Pull-Up"
            "CHIN_UP" -> "💪" to "FitGuru AI • Chin-Up"
            "RUNNING" -> "🏃" to "FitGuru AI • Running Cadence"
            "BENCH_PRESS" -> "🛏️" to "FitGuru AI • Bench Press"
            "SHOULDER_PRESS" -> "🙌" to "FitGuru AI • Shoulder Press"
            "LEG_PRESS" -> "🦵" to "FitGuru AI • Leg Press"
            "LAT_PULLDOWN" -> "⬇️" to "FitGuru AI • Lat Pulldown"
            "CHEST_PRESS" -> "💪" to "FitGuru AI • Chest Press"
            "SEATED_ROW" -> "🚣" to "FitGuru AI • Seated Row"
            "LEG_EXTENSION" -> "🦿" to "FitGuru AI • Leg Extension"
            "LEG_CURL" -> "🦵" to "FitGuru AI • Leg Curl"
            "TRICEPS_PUSHDOWN" -> "🔗" to "FitGuru AI • Triceps Pushdown"
            else -> "⚡" to "FitGuru AI Coach"
        }

        fragmentCameraBinding.exerciseIconBadge.text = icon
        fragmentCameraBinding.exerciseTitleText.text = title

        if (currentWorkoutType == "PLANK") {
            fragmentCameraBinding.repCountText.text = "Hold: 0s"
        } else if (currentWorkoutType == "RUNNING") {
            fragmentCameraBinding.repCountText.text = "0 SPM | 0 Steps"
        } else {
            fragmentCameraBinding.repCountText.text = "Reps: 0"
        }
    }

    private fun startPlankTimer() {
        plankTimerHandler = Handler(Looper.getMainLooper())
        plankTimerHandler?.postDelayed(object : Runnable {
            override fun run() {
                if (isHoldingPlank) {
                    plankSeconds++
                    fragmentCameraBinding.repCountText.text = "Hold: ${plankSeconds}s"
                }
                plankTimerHandler?.postDelayed(this, 1000)
            }
        }, 1000)
    }

    private fun stopPlankTimer() {
        plankTimerHandler?.removeCallbacksAndMessages(null)
        plankTimerHandler = null
    }

    // Gym Multi-Person Shield & Lifter Lock
    data class SubjectAnchor(
        var centerX: Float,
        var centerY: Float,
        var torsoHeight: Float,
        var isLocked: Boolean = false,
        var lockConfirmFrames: Int = 0,
        var occlusionFrames: Int = 0
    )

    private var subjectAnchor: SubjectAnchor? = null
    private val maxJumpDistance: Float = 0.35f
    private val maxOcclusionGraceFrames: Int = 45

    fun resetSubjectLock() {
        subjectAnchor = null
    }

    private fun findPrimarySubjectLandmarks(allLandmarks: List<List<NormalizedLandmark>>): Pair<Int, List<NormalizedLandmark>?> {
        if (allLandmarks.isEmpty()) return Pair(-1, null)
        
        // Evaluate all candidate bodies in frame
        val candidates = allLandmarks.mapIndexedNotNull { index, landmarks ->
            if (landmarks.size < 25) return@mapIndexedNotNull null
            val leftHip = landmarks[23]; val rightHip = landmarks[24]
            val leftShoulder = landmarks[11]; val rightShoulder = landmarks[12]
            val hipX = (leftHip.x() + rightHip.x()) / 2f
            val hipY = (leftHip.y() + rightHip.y()) / 2f
            val shoulderX = (leftShoulder.x() + rightShoulder.x()) / 2f
            val shoulderY = (leftShoulder.y() + rightShoulder.y()) / 2f
            val centerX = (hipX + shoulderX) / 2f
            val centerY = (hipY + shoulderY) / 2f
            val torsoHeight = Math.hypot((hipX - shoulderX).toDouble(), (hipY - shoulderY).toDouble()).toFloat()
            val centerDist = Math.hypot((centerX - 0.5f).toDouble(), (centerY - 0.5f).toDouble()).toFloat()
            val prominence = (torsoHeight * 2.0f) + Math.max(0.0f, 1.0f - centerDist * 1.4f)
            Triple(index, centerX to centerY, torsoHeight to prominence)
        }
        
        if (candidates.isEmpty()) return Pair(0, allLandmarks.first())
        
        val anchor = subjectAnchor
        if (anchor == null || !anchor.isLocked) {
            val best = candidates.maxByOrNull { it.third.second } ?: candidates.first()
            val (idx, center, heightProm) = best
            if (subjectAnchor == null) {
                subjectAnchor = SubjectAnchor(center.first, center.second, heightProm.first)
            } else {
                subjectAnchor!!.lockConfirmFrames++
                if (subjectAnchor!!.lockConfirmFrames >= 5) {
                    subjectAnchor!!.isLocked = true
                }
            }
            return Pair(idx, allLandmarks[idx])
        }
        
        // Tracking mode: match candidate closest to locked anchor & scale
        var bestIdx = -1
        var lowestCost = Float.MAX_VALUE
        
        for (candidate in candidates) {
            val (idx, center, heightProm) = candidate
            val dist = Math.hypot((center.first - anchor.centerX).toDouble(), (center.second - anchor.centerY).toDouble()).toFloat()
            val scaleDiff = Math.abs(heightProm.first - anchor.torsoHeight) / Math.max(0.05f, anchor.torsoHeight)
            val cost = dist + (scaleDiff * 0.4f)
            if (cost < lowestCost) {
                lowestCost = cost
                bestIdx = idx
            }
        }
        
        if (bestIdx != -1 && lowestCost < maxJumpDistance) {
            val match = candidates.first { it.first == bestIdx }
            anchor.centerX = anchor.centerX * 0.82f + match.second.first * 0.18f
            anchor.centerY = anchor.centerY * 0.82f + match.second.second * 0.18f
            anchor.torsoHeight = anchor.torsoHeight * 0.85f + match.third.first * 0.15f
            anchor.occlusionFrames = 0
            return Pair(bestIdx, allLandmarks[bestIdx])
        } else {
            // Passerby walking in front: Hold workout state without disruption
            anchor.occlusionFrames++
            if (anchor.occlusionFrames <= maxOcclusionGraceFrames) {
                return Pair(-1, null)
            } else {
                subjectAnchor = null
                val fallback = candidates.maxByOrNull { it.third.second } ?: candidates.first()
                return Pair(fallback.first, allLandmarks[fallback.first])
            }
        }
    }

    override fun onResults(resultBundle: PoseLandmarkerHelper.ResultBundle) {
        activity?.runOnUiThread {
            if (_fragmentCameraBinding == null || isAiThinking) return@runOnUiThread

            val poseLandmarkerResult = resultBundle.results.first()
            val (primaryIdx, primaryLandmarks) = findPrimarySubjectLandmarks(poseLandmarkerResult.landmarks())

            fragmentCameraBinding.overlay.primarySubjectIndex = if (primaryIdx >= 0) primaryIdx else 0
            fragmentCameraBinding.overlay.setResults(
                poseLandmarkerResult,
                resultBundle.inputImageHeight,
                resultBundle.inputImageWidth,
                RunningMode.LIVE_STREAM
            )

            if (primaryLandmarks != null) {
                val feedbackMessage = analyzePose(primaryLandmarks)

                if (feedbackMessage == "GOOD_FORM") {
                    fragmentCameraBinding.aiFeedbackText.visibility = View.GONE
                } else {
                    val currentTime = System.currentTimeMillis()
                    if (currentTime - lastFeedbackTime > 2500) {
                        lastFeedbackTime = currentTime
                        fragmentCameraBinding.aiFeedbackText.text = feedbackMessage
                        fragmentCameraBinding.aiFeedbackText.visibility = View.VISIBLE

                        if (isGenerativeAiEnabled) {
                            triggerGenerativeFeedback(feedbackMessage)
                        } else {
                            speak(feedbackMessage)
                        }
                    }
                }
            } else {
                // Gym crowd / passerby passing: Hold state smoothly without fake rep increments
                fragmentCameraBinding.aiFeedbackText.text = "Gym Shield: Passerby Filtered • Holding Rep State"
                fragmentCameraBinding.aiFeedbackText.visibility = View.VISIBLE
            }
            fragmentCameraBinding.overlay.invalidate()
        }
    }

    private fun triggerGenerativeFeedback(feedbackType: String) {
        if (isAiThinking) return
        isAiThinking = true

        lifecycleScope.launch(Dispatchers.Main) {
            fragmentCameraBinding.aiThinkingIndicator.visibility = View.VISIBLE

            delay(750)

            val generativeFeedback = when {
                feedbackType.contains("hips", true) -> "Gemma AI: Align your pelvis with your spine. Keep your core braced throughout the repetition."
                feedbackType.contains("chest", true) -> "Gemma AI: Avoid leaning too far forward. Drive your chest upward and keep your gaze straight ahead."
                feedbackType.contains("elbow", true) -> "Gemma AI: Pin your upper arms securely to your sides to maximize isolation on the target muscles."
                feedbackType.contains("knee", true) -> "Gemma AI: Watch knee alignment over your mid-foot to protect your joints and maintain power transfer."
                feedbackType.contains("spine", true) || feedbackType.contains("back", true) -> "Gemma AI: Maintain a neutral spine. Avoid lumbar hyperextension under load."
                else -> "Gemma AI: $feedbackType"
            }

            speak(generativeFeedback)
            fragmentCameraBinding.aiFeedbackText.text = generativeFeedback
            fragmentCameraBinding.aiFeedbackText.visibility = View.VISIBLE

            fragmentCameraBinding.aiThinkingIndicator.visibility = View.GONE
            isAiThinking = false
        }
    }

    private fun analyzePose(landmarks: List<NormalizedLandmark>): String {
        return when (currentWorkoutType) {
            "SQUAT" -> checkSquatFormAndCountReps(landmarks)
            "PUSH_UP" -> checkPushupFormAndCountReps(landmarks)
            "DEADLIFT" -> checkDeadliftFormAndCountReps(landmarks)
            "PULL_UP", "CHIN_UP" -> checkPullUpFormAndCountReps(landmarks)
            "RUNNING" -> checkRunningCadence(landmarks)
            "BICEP_CURL" -> checkBicepCurlFormAndCountReps(landmarks)
            "LUNGE" -> checkLungeFormAndCountReps(landmarks)
            "PLANK" -> checkPlankForm(landmarks)
            "BENCH_PRESS", "CHEST_PRESS" -> checkBenchPressFormAndCountReps(landmarks)
            "SHOULDER_PRESS" -> checkShoulderPressFormAndCountReps(landmarks)
            "LEG_PRESS", "LEG_EXTENSION", "LEG_CURL" -> checkLegPressFormAndCountReps(landmarks)
            "LAT_PULLDOWN", "SEATED_ROW", "TRICEPS_PUSHDOWN" -> checkLatPulldownFormAndCountReps(landmarks)
            else -> checkPushupFormAndCountReps(landmarks)
        }
    }

    private fun analyzePose(poseLandmarkerResult: PoseLandmarkerResult): String {
        val landmarks = poseLandmarkerResult.landmarks().firstOrNull() ?: return "GOOD_FORM"
        return analyzePose(landmarks)
    }

    // --- DEADLIFT (vision-demos hip hinge & back posture guard) ---
    private fun checkDeadliftFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftHip = landmarks[23]; val leftKnee = landmarks[25]; val leftAnkle = landmarks[27]

        val hipAngle = calculateAngle(leftShoulder, leftHip, leftKnee)
        val kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle)

        fragmentCameraBinding.angleDebugText.text = "Hip Hinge: ${hipAngle.toInt()}° | Knee: ${kneeAngle.toInt()}°"

        if (hipAngle < 115 && kneeAngle < 125) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (hipAngle > 165 && kneeAngle > 165) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Solid deadlift lockout!")
            }
        }

        if (workoutState == "down" && hipAngle < 85 && kneeAngle > 140) {
            return "Hips rising too fast! Drive chest up."
        }
        val isLeaningBack = (leftShoulder.x() < leftHip.x() && leftHip.x() < leftKnee.x()) ||
                            (leftShoulder.x() > leftHip.x() && leftHip.x() > leftKnee.x())
        if (workoutState == "up" && isLeaningBack && (Math.abs(leftShoulder.x() - leftHip.x()) > 0.06f)) {
            return "Don't hyperextend lower back at lockout!"
        }

        return "GOOD_FORM"
    }

    // --- PULL-UP & CHIN-UP (vision-demos chin-over-bar & dead-hang ROM) ---
    private fun checkPullUpFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftElbow = landmarks[13]; val leftWrist = landmarks[15]
        val nose = landmarks[0]

        val elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist)
        fragmentCameraBinding.angleDebugText.text = "Elbow Flexion: ${elbowAngle.toInt()}°"

        if (elbowAngle < 75 || (nose.y() < leftWrist.y() && elbowAngle < 90)) {
            if (workoutState == "ready" || workoutState == "down") {
                workoutState = "up"
            }
        } else if (elbowAngle > 155) {
            if (workoutState == "up") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "down"
                speak("Great pull-up! Full extension.")
            }
        }

        if (workoutState == "up" && elbowAngle > 85 && elbowAngle < 140) {
            return "Lower all the way to dead hang!"
        }

        return "GOOD_FORM"
    }

    // --- RUNNING CADENCE & GAIT TRACKER (vision-demos cadence engine) ---
    private fun checkRunningCadence(landmarks: List<NormalizedLandmark>): String {
        val leftAnkle = landmarks[27]; val rightAnkle = landmarks[28]
        val leftKnee = landmarks[25]; val leftHip = landmarks[23]

        val now = System.currentTimeMillis()
        val leadingFoot = if (leftAnkle.y() > rightAnkle.y()) "LEFT" else "RIGHT"

        if (leadingFoot != lastLeadingFoot && (now - lastStepTime) > 220) {
            runningStepCount++
            if (lastStepTime > 0) {
                val interval = now - lastStepTime
                stepIntervals.add(interval)
                if (stepIntervals.size > 8) stepIntervals.removeFirst()
                val avgIntervalMs = stepIntervals.average()
                if (avgIntervalMs > 0) {
                    currentCadenceSpm = (60000.0 / avgIntervalMs).toInt().coerceIn(120, 220)
                }
            }
            lastStepTime = now
            lastLeadingFoot = leadingFoot

            val kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle)
            fragmentCameraBinding.repCountText.text = "${currentCadenceSpm} SPM | $runningStepCount Steps"
            fragmentCameraBinding.angleDebugText.text = "Strike Knee: ${kneeAngle.toInt()}° | Cadence: ${currentCadenceSpm} SPM"
        }

        if (currentCadenceSpm in 1..154) {
            return "Increase cadence! Aim for 170+ SPM."
        }

        return "GOOD_FORM"
    }

    // --- SQUAT ---
    private fun checkSquatFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftHip = landmarks[23]; val leftKnee = landmarks[25]; val leftAnkle = landmarks[27]
        val rightShoulder = landmarks[12]; val rightHip = landmarks[24]; val rightKnee = landmarks[26]; val rightAnkle = landmarks[28]

        val kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle)
        val hipAngle = calculateAngle(leftShoulder, leftHip, leftKnee)

        fragmentCameraBinding.angleDebugText.text = "Knee: ${kneeAngle.toInt()}° | Hip: ${hipAngle.toInt()}°"

        if (kneeAngle < 105 && hipAngle < 115) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (kneeAngle > 155 && hipAngle > 155) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Great squat depth!")
            }
        }

        if (workoutState == "down" && hipAngle < 75) {
            return "Keep your chest up!"
        }

        return "GOOD_FORM"
    }

    // --- PUSH-UP ---
    private fun checkPushupFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftElbow = landmarks[13]; val leftWrist = landmarks[15]
        val leftHip = landmarks[23]; val leftKnee = landmarks[25]

        val elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist)
        val hipAngle = calculateAngle(leftShoulder, leftHip, leftKnee)

        fragmentCameraBinding.angleDebugText.text = "Elbow: ${elbowAngle.toInt()}° | Body: ${hipAngle.toInt()}°"

        if (elbowAngle < 95) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (elbowAngle > 155) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Good push-up!")
            }
        }

        if (hipAngle < 145) return "Lift your hips!"
        if (hipAngle > 195) return "Lower your hips!"

        return "GOOD_FORM"
    }

    // --- BICEP CURL ---
    private fun checkBicepCurlFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftElbow = landmarks[13]; val leftWrist = landmarks[15]; val leftHip = landmarks[23]

        val elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist)
        val upperArmSwing = calculateAngle(leftHip, leftShoulder, leftElbow)

        fragmentCameraBinding.angleDebugText.text = "Elbow: ${elbowAngle.toInt()}° | Arm: ${upperArmSwing.toInt()}°"

        if (elbowAngle < 65) {
            if (workoutState == "ready" || workoutState == "down") {
                workoutState = "up"
            }
        } else if (elbowAngle > 145) {
            if (workoutState == "up") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "down"
                speak("Great bicep squeeze!")
            }
        }

        if (upperArmSwing > 35) {
            return "Keep elbows pinned to your sides!"
        }

        return "GOOD_FORM"
    }

    // --- LUNGE ---
    private fun checkLungeFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftHip = landmarks[23]; val leftKnee = landmarks[25]; val leftAnkle = landmarks[27]; val leftShoulder = landmarks[11]

        val kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle)
        val torsoAngle = calculateAngle(leftShoulder, leftHip, leftKnee)

        fragmentCameraBinding.angleDebugText.text = "Knee: ${kneeAngle.toInt()}° | Torso: ${torsoAngle.toInt()}°"

        if (kneeAngle < 100) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (kneeAngle > 155) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Strong lunge!")
            }
        }

        if (workoutState == "down" && torsoAngle < 85) {
            return "Keep your upper body upright!"
        }

        return "GOOD_FORM"
    }

    // --- PLANK ---
    private fun checkPlankForm(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftHip = landmarks[23]; val leftAnkle = landmarks[27]

        val bodyLineAngle = calculateAngle(leftShoulder, leftHip, leftAnkle)
        fragmentCameraBinding.angleDebugText.text = "Spine Angle: ${bodyLineAngle.toInt()}°"

        if (bodyLineAngle in 155.0..195.0) {
            isHoldingPlank = true
            plankGoodSeconds++
            return "GOOD_FORM"
        } else {
            isHoldingPlank = false
            if (bodyLineAngle < 155) {
                return "Hips are sagging! Lift your hips."
            } else {
                return "Hips are too high! Lower to straight line."
            }
        }
    }

    // --- BENCH PRESS & CHEST PRESS ---
    private fun checkBenchPressFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftElbow = landmarks[13]; val leftWrist = landmarks[15]

        val elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist)
        fragmentCameraBinding.angleDebugText.text = "Elbow: ${elbowAngle.toInt()}°"

        if (elbowAngle < 90) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (elbowAngle > 155) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Clean press!")
            }
        }

        return "GOOD_FORM"
    }

    // --- SHOULDER PRESS ---
    private fun checkShoulderPressFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftElbow = landmarks[13]; val leftWrist = landmarks[15]

        val elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist)
        fragmentCameraBinding.angleDebugText.text = "Elbow: ${elbowAngle.toInt()}°"

        if (elbowAngle < 95) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (elbowAngle > 155) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Great overhead push!")
            }
        }

        return "GOOD_FORM"
    }

    // --- LEG PRESS & EXTENSIONS ---
    private fun checkLegPressFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftHip = landmarks[23]; val leftKnee = landmarks[25]; val leftAnkle = landmarks[27]

        val kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle)
        fragmentCameraBinding.angleDebugText.text = "Knee: ${kneeAngle.toInt()}°"

        if (kneeAngle < 100) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (kneeAngle > 155) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Great leg drive!")
            }
        }

        if (kneeAngle > 175) {
            return "Do not hyperextend or lock knees!"
        }

        return "GOOD_FORM"
    }

    // --- LAT PULLDOWN & ROWS ---
    private fun checkLatPulldownFormAndCountReps(landmarks: List<NormalizedLandmark>): String {
        val leftShoulder = landmarks[11]; val leftElbow = landmarks[13]; val leftWrist = landmarks[15]

        val elbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist)
        fragmentCameraBinding.angleDebugText.text = "Pull Angle: ${elbowAngle.toInt()}°"

        if (elbowAngle < 85) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        } else if (elbowAngle > 155) {
            if (workoutState == "down") {
                repCount++
                goodFormReps++
                fragmentCameraBinding.repCountText.text = "Reps: $repCount"
                workoutState = "up"
                speak("Great contraction!")
            }
        }

        return "GOOD_FORM"
    }

    private fun calculateAngle(
        p1: NormalizedLandmark, p2: NormalizedLandmark, p3: NormalizedLandmark
    ): Double {
        val v1x = p1.x() - p2.x()
        val v1y = p1.y() - p2.y()
        val v2x = p3.x() - p2.x()
        val v2y = p3.y() - p2.y()
        val dot = v1x * v2x + v1y * v2y
        val mag1 = Math.sqrt((v1x * v1x + v1y * v1y).toDouble())
        val mag2 = Math.sqrt((v2x * v2x + v2y * v2y).toDouble())
        if (mag1 * mag2 == 0.0) return 180.0
        val cosAngle = Math.max(-1.0, Math.min(1.0, dot / (mag1 * mag2)))
        return Math.toDegrees(Math.acos(cosAngle))
    }

    private fun finishAndSaveSession() {
        if (this::voiceCommandManager.isInitialized) {
            voiceCommandManager.stopListening()
        }
        val (exerciseName, finalReps, score) = if (currentWorkoutType == "PLANK") {
            val scorePct = if (plankSeconds > 0) ((plankGoodSeconds.toDouble() / plankSeconds) * 100).toInt().coerceIn(60, 100) else 100
            Triple("Plank Hold", plankSeconds, scorePct)
        } else if (currentWorkoutType == "RUNNING") {
            val scorePct = if (currentCadenceSpm >= 165) 98 else 88
            Triple("Running Gait", runningStepCount, scorePct)
        } else {
            val name = when (currentWorkoutType) {
                "SQUAT" -> "Squats"
                "PUSH_UP" -> "Push-ups"
                "DEADLIFT" -> "Barbell Deadlift"
                "PULL_UP" -> "Pull-ups"
                "CHIN_UP" -> "Chin-ups"
                "BICEP_CURL" -> "Bicep Curls"
                "LUNGE" -> "Lunges"
                "BENCH_PRESS" -> "Bench Press"
                "SHOULDER_PRESS" -> "Shoulder Press"
                "LEG_PRESS" -> "Leg Press"
                "LAT_PULLDOWN" -> "Lat Pulldown"
                else -> "Custom Workout"
            }
            val scorePct = if (repCount > 0) ((goodFormReps.toDouble() / repCount) * 100).toInt().coerceIn(75, 100) else 100
            Triple(name, repCount, scorePct)
        }

        val estimatedCalories = (finalReps * 0.45 + (if (currentWeightKg > 0) currentWeightKg * 0.08 else 0.0)).toInt().coerceAtLeast(5)
        val session = WorkoutSession(
            date = Date(),
            exerciseType = currentWorkoutType,
            exerciseName = exerciseName,
            reps = finalReps,
            score = score,
            calories = estimatedCalories,
            avgHeartRate = currentHeartRateBpm,
            weightKg = currentWeightKg
        )

        val summarySheet = WorkoutSummaryBottomSheet(session, lastMeasuredAngle, lastFaultDetected) {
            activity?.finish()
        }
        summarySheet.show(parentFragmentManager, "WorkoutSummarySheet")
    }

    private fun setUpCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(requireContext())
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            bindCameraUseCases()
        }, ContextCompat.getMainExecutor(requireContext()))
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {
        val cameraProvider = cameraProvider ?: throw IllegalStateException("Camera initialization failed.")
        val cameraSelector = CameraSelector.Builder().requireLensFacing(cameraFacing).build()
        preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation).build()
        imageAnalyzer = ImageAnalysis.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888).build()
            .also { it.setAnalyzer(backgroundExecutor) { image -> detectPose(image) } }
        cameraProvider.unbindAll()
        try {
            camera = cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalyzer)
            preview?.setSurfaceProvider(fragmentCameraBinding.viewFinder.surfaceProvider)
        } catch (exc: Exception) {
            Log.e(TAG, "Use case binding failed", exc)
        }
    }

    private fun detectPose(imageProxy: ImageProxy) {
        if (this::poseLandmarkerHelper.isInitialized) {
            poseLandmarkerHelper.detectLiveStream(
                imageProxy,
                isFrontCamera = cameraFacing == CameraSelector.LENS_FACING_FRONT
            )
        } else {
            imageProxy.close()
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = textToSpeech.setLanguage(Locale.US)
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED){
                Log.e(TAG, "The Language specified is not supported!")
            }
        } else {
            Log.e(TAG, "TTS Initialization Failed!")
        }
    }

    private fun speak(text: String) {
        if (this::elevenLabsService.isInitialized && elevenLabsService.isEnabled) {
            elevenLabsService.speak(text)
        } else if (this::textToSpeech.isInitialized) {
            textToSpeech.speak(text, TextToSpeech.QUEUE_FLUSH, null, "")
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        imageAnalyzer?.targetRotation = fragmentCameraBinding.viewFinder.display.rotation
    }

    override fun onError(error: String, errorCode: Int) {
        activity?.runOnUiThread { Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show() }
    }

    // MARK: - VoiceCommandListener Callbacks
    override fun onFinishSetCommand() {
        activity?.runOnUiThread {
            finishAndSaveSession()
        }
    }

    override fun onSmartRestCommand() {
        activity?.runOnUiThread {
            showSmartRestTimer()
        }
    }

    override fun onCoachHelpCommand() {
        activity?.runOnUiThread {
            val advice = "Keep your core braced and focus on a smooth, controlled 2-second negative."
            speak(advice)
            fragmentCameraBinding.aiFeedbackText.text = advice
            fragmentCameraBinding.aiFeedbackText.visibility = View.VISIBLE
        }
    }

    override fun onSwitchExerciseCommand(newType: String) {
        activity?.runOnUiThread {
            currentWorkoutType = newType
            repCount = 0
            goodFormReps = 0
            workoutState = "ready"
            setupExerciseHeader()
            speak("Switched to $newType. Let's go!")
        }
    }

    override fun onAdjustWeightCommand(weightKg: Double) {
        activity?.runOnUiThread {
            currentWeightKg = weightKg
            updateWeightUI()
            speak("Weight set to ${weightKg.toInt()} kilograms.")
        }
    }

    override fun onCommandRecognized(commandText: String) {
        activity?.runOnUiThread {
            fragmentCameraBinding.voiceStatusText.text = "Cmd: $commandText"
            fragmentCameraBinding.voiceStatusPill.visibility = View.VISIBLE
        }
    }

    override fun onMicLevelChanged(levelPct: Float) {
        activity?.runOnUiThread {
            fragmentCameraBinding.voiceMicIcon.alpha = 0.4f + (levelPct * 0.6f)
        }
    }

    override fun onListeningStateChanged(isListening: Boolean, status: String) {
        activity?.runOnUiThread {
            fragmentCameraBinding.voiceStatusText.text = status
        }
    }

    private fun showSmartRestTimer() {
        val timerSheet = SmartRestTimerBottomSheet(60, currentHeartRateBpm) {
            speak("Rest complete! Ready for next set.")
        }
        timerSheet.show(parentFragmentManager, "SmartRestTimer")
    }

    private fun updateWeightUI() {
        fragmentCameraBinding.weightDisplayText.text = if (currentWeightKg <= 0.0) "BW" else "${currentWeightKg.toInt()} kg"
    }

    private fun updateCoachPersonaBadge() {
        if (this::elevenLabsService.isInitialized) {
            val persona = elevenLabsService.selectedPersona
            fragmentCameraBinding.coachPersonaBadge.text = "${persona.displayName} ${persona.icon}"
        }
    }
}
