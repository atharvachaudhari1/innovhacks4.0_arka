package com.google.mediapipe.examples.poselandmarker

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.lifecycle.lifecycleScope
import com.google.android.material.bottomsheet.BottomSheetDialogFragment
import com.google.mediapipe.examples.poselandmarker.data.AppDatabase
import com.google.mediapipe.examples.poselandmarker.data.WorkoutSession
import com.google.mediapipe.examples.poselandmarker.databinding.BottomSheetWorkoutSummaryBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class WorkoutSummaryBottomSheet(
    private val session: WorkoutSession,
    private val measuredAngle: Double = 0.0,
    private val primaryFault: String = "",
    private val onDismissAction: () -> Unit
) : BottomSheetDialogFragment() {

    private var _binding: BottomSheetWorkoutSummaryBinding? = null
    private val binding get() = _binding!!

    private var biomechanicalReport: GeminiBiomechanicalReport? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = BottomSheetWorkoutSummaryBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.summaryExerciseTitle.text = session.exerciseName
        binding.summaryRepsText.text = "${session.reps}"
        binding.summaryScoreText.text = "${session.score}%"
        binding.summaryVolumeText.text = if (session.totalVolumeKg > 0) "${session.totalVolumeKg.toInt()} kg" else "BW"
        binding.summaryHrText.text = if (session.avgHeartRate > 0) "${session.avgHeartRate} BPM" else "128 BPM"

        val persona = ElevenLabsService.getInstance(requireContext()).selectedPersona
        binding.hearCoachReviewButton.text = "🔊 Hear ${persona.displayName} Review (ElevenLabs)"

        binding.closeSummaryButton.setOnClickListener {
            dismiss()
            onDismissAction()
        }

        binding.saveAndFinishButton.setOnClickListener {
            saveSessionToDatabase()
        }

        binding.hearCoachReviewButton.setOnClickListener {
            val report = biomechanicalReport
            val textToSpeak = if (report != null) {
                "${report.diagnosis}. Here are your cues: " + report.correctiveCues.joinToString(". ")
            } else {
                "Great workout on ${session.exerciseName}. You completed ${session.reps} repetitions with ${session.score} percent accuracy."
            }
            ElevenLabsService.getInstance(requireContext()).speak(textToSpeak)
        }

        runGeminiAnalysis()
    }

    private fun runGeminiAnalysis() {
        val gemini = GeminiService.getInstance(requireContext())
        binding.geminiLoadingBar.visibility = View.VISIBLE

        gemini.analyzeBiomechanicalForm(session, primaryFault, measuredAngle) { report ->
            biomechanicalReport = report
            binding.geminiLoadingBar.visibility = View.GONE
            binding.geminiDiagnosisText.text = report.diagnosis
            binding.geminiCuesText.text = report.correctiveCues.joinToString("\n") { "• $it" }
        }

        gemini.generateRecoveryProtocol(session) { recovery ->
            binding.recoveryWindowText.text = "⏱️ Window: ${recovery.recoveryWindowHours} hrs"
            binding.recoveryNutritionText.text = "🍗 Protein: ${recovery.proteinGrams}g • ${recovery.hydrationMl}ml H2O"
            binding.recoveryStretchesText.text = "Mobility: " + recovery.activeStretches.joinToString(", ")
        }
    }

    private fun saveSessionToDatabase() {
        val context = context ?: return
        val dao = AppDatabase.getDatabase(context).workoutDao()
        lifecycleScope.launch(Dispatchers.IO) {
            dao.insert(session)
            withContext(Dispatchers.Main) {
                dismiss()
                onDismissAction()
            }
        }
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }
}
