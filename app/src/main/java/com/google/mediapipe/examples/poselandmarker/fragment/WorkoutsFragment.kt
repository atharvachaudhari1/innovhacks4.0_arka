package com.google.mediapipe.examples.poselandmarker.fragment

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.mediapipe.examples.poselandmarker.GymEquipmentAdapter
import com.google.mediapipe.examples.poselandmarker.QuickWorkout
import com.google.mediapipe.examples.poselandmarker.QuickWorkoutAdapter
import com.google.mediapipe.examples.poselandmarker.R
import com.google.mediapipe.examples.poselandmarker.WorkoutActivity
import com.google.mediapipe.examples.poselandmarker.data.EquipmentWithExercise
import com.google.mediapipe.examples.poselandmarker.data.GymCatalogRepository
import com.google.mediapipe.examples.poselandmarker.databinding.FragmentWorkoutsBinding

class WorkoutsFragment : Fragment() {

    private var _binding: FragmentWorkoutsBinding? = null
    private val binding get() = _binding!!

    private lateinit var equipmentAdapter: GymEquipmentAdapter
    private var fullEquipmentList: List<EquipmentWithExercise> = emptyList()
    private var selectedCategory: String = "All"

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentWorkoutsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        setupQuickWorkouts()
        setupEquipmentGuide()
        setupCategoryChips()

        binding.cardHeroAiCoach.setOnClickListener {
            launchWorkout("SQUAT")
        }
    }

    private fun setupQuickWorkouts() {
        val workouts = listOf(
            QuickWorkout("squat", "Squats", "🏋️", "Quads • Glutes", "SQUAT"),
            QuickWorkout("pushup", "Push-ups", "🤸", "Chest • Triceps", "PUSH_UP"),
            QuickWorkout("deadlift", "Deadlifts", "🏋️", "Hamstrings • Back", "DEADLIFT"),
            QuickWorkout("pull_up", "Pull-ups", "🧗", "Lats • Back", "PULL_UP"),
            QuickWorkout("chin_up", "Chin-ups", "💪", "Biceps • Arms", "CHIN_UP"),
            QuickWorkout("running", "Running Cadence", "🏃", "Cardio • Cadence", "RUNNING"),
            QuickWorkout("bicep_curl", "Bicep Curls", "💪", "Biceps • Arms", "BICEP_CURL"),
            QuickWorkout("lunge", "Lunges", "🦵", "Quads • Balance", "LUNGE"),
            QuickWorkout("plank", "Plank Hold", "🧘", "Core • Stability", "PLANK"),
            QuickWorkout("bench_press", "Bench Press", "🛏️", "Chest • Triceps", "BENCH_PRESS"),
            QuickWorkout("shoulder_press", "Shoulder Press", "🙌", "Shoulders • Delts", "SHOULDER_PRESS"),
            QuickWorkout("leg_press", "Leg Press", "🦵", "Hamstrings • Quads", "LEG_PRESS"),
            QuickWorkout("lat_pulldown", "Lat Pulldown", "⬇️", "Back (Lats) • Arms", "LAT_PULLDOWN")
        )

        val quickAdapter = QuickWorkoutAdapter(workouts) { item ->
            launchWorkout(item.workoutType)
        }
        binding.recyclerQuickWorkouts.layoutManager =
            LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false)
        binding.recyclerQuickWorkouts.adapter = quickAdapter
    }

    private fun setupEquipmentGuide() {
        fullEquipmentList = GymCatalogRepository.getEquipmentList(requireContext())
        binding.textEquipmentCount.text = "${fullEquipmentList.size} Machines"

        equipmentAdapter = GymEquipmentAdapter(fullEquipmentList) { item ->
            showEquipmentGuideBottomSheet(item)
        }
        binding.recyclerEquipment.layoutManager = LinearLayoutManager(requireContext())
        binding.recyclerEquipment.adapter = equipmentAdapter
    }

    private fun setupCategoryChips() {
        val chipViews = listOf(
            binding.chipAll to "All",
            binding.chipUpper to "Upper Body",
            binding.chipLower to "Lower Body",
            binding.chipFreeWeights to "Free Weights",
            binding.chipCore to "Core",
            binding.chipCardio to "Cardio"
        )

        for ((chip, category) in chipViews) {
            chip.setOnClickListener {
                selectedCategory = category
                updateChipStyles(chipViews, category)
                filterEquipment(category)
            }
        }
    }

    private fun updateChipStyles(chips: List<Pair<TextView, String>>, activeCategory: String) {
        val activeBg = ContextCompat.getDrawable(requireContext(), R.drawable.badge_smartwatch_bg)
        val inactiveBg = ContextCompat.getDrawable(requireContext(), R.drawable.card_border_bg)
        val activeColor = ContextCompat.getColor(requireContext(), R.color.accent_lime)
        val inactiveColor = ContextCompat.getColor(requireContext(), R.color.text_secondary)

        for ((chip, cat) in chips) {
            if (cat == activeCategory) {
                chip.background = activeBg
                chip.setTextColor(activeColor)
            } else {
                chip.background = inactiveBg
                chip.setTextColor(inactiveColor)
            }
        }
    }

    private fun filterEquipment(category: String) {
        val filtered = if (category == "All") {
            fullEquipmentList
        } else {
            fullEquipmentList.filter { it.machine.category.equals(category, ignoreCase = true) }
        }
        equipmentAdapter.updateList(filtered)
        binding.textEquipmentCount.text = "${filtered.size} Items"
    }

    private fun showEquipmentGuideBottomSheet(item: EquipmentWithExercise) {
        val dialog = BottomSheetDialog(requireContext())
        val sheetView = layoutInflater.inflate(R.layout.bottom_sheet_equipment_guide, null)

        val iconTv = sheetView.findViewById<TextView>(R.id.guide_icon)
        val titleTv = sheetView.findViewById<TextView>(R.id.guide_title)
        val catTv = sheetView.findViewById<TextView>(R.id.guide_category)
        val whatTv = sheetView.findViewById<TextView>(R.id.guide_what)
        val setupTv = sheetView.findViewById<TextView>(R.id.guide_setup_text)
        val stepsTv = sheetView.findViewById<TextView>(R.id.guide_steps_text)
        val mistakesTv = sheetView.findViewById<TextView>(R.id.guide_mistakes_text)
        val safetyTv = sheetView.findViewById<TextView>(R.id.guide_safety_text)
        val cameraTipTv = sheetView.findViewById<TextView>(R.id.guide_camera_tip)
        val startBtn = sheetView.findViewById<Button>(R.id.guide_start_coach_btn)

        iconTv.text = item.machine.icon
        titleTv.text = item.machine.name
        
        val muscles = item.primaryExercise?.muscles?.joinToString(", ") ?: item.machine.category
        catTv.text = "${item.machine.category} • $muscles"
        whatTv.text = item.machine.what.ifEmpty { "General gym equipment." }

        val ex = item.primaryExercise
        if (ex != null) {
            setupTv.text = if (ex.setup.isNotEmpty()) ex.setup.mapIndexed { i, s -> "${i + 1}. $s" }.joinToString("\n") else "Adjust machine to comfortable height."
            stepsTv.text = if (ex.steps.isNotEmpty()) ex.steps.mapIndexed { i, s -> "${i + 1}. $s" }.joinToString("\n") else "Perform controlled repetitions."
            mistakesTv.text = if (ex.mistakes.isNotEmpty()) ex.mistakes.joinToString("\n") { "• $it" } else "• None noted."
            safetyTv.text = ex.safety.ifEmpty { "Use controlled tempo and secure weights." }
            cameraTipTv.text = ex.cameraTip.ifEmpty { "Place phone 2-3m away at joint height." }

            startBtn.visibility = View.VISIBLE
            startBtn.text = "⚡ Start AI Coach for ${ex.name}"
            startBtn.setOnClickListener {
                dialog.dismiss()
                launchWorkout(ex.workoutType)
            }
        } else {
            setupTv.text = "Adjust seat and select appropriate weight."
            stepsTv.text = "Maintain smooth, controlled movement."
            mistakesTv.text = "• Rushing through reps\n• Improper posture"
            safetyTv.text = "Start with lightweight until movement is mastered."
            cameraTipTv.text = "Position phone 2-3m away with full view."
            startBtn.visibility = View.GONE
        }

        dialog.setContentView(sheetView)
        dialog.show()
    }

    private fun launchWorkout(workoutType: String) {
        val intent = Intent(activity, WorkoutActivity::class.java).apply {
            putExtra("WORKOUT_TYPE", workoutType)
        }
        startActivity(intent)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
