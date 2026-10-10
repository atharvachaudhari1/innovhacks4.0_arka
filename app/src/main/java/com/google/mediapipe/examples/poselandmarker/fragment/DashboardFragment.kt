package com.google.mediapipe.examples.poselandmarker.fragment

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.mediapipe.examples.poselandmarker.QuickWorkout
import com.google.mediapipe.examples.poselandmarker.QuickWorkoutAdapter
import com.google.mediapipe.examples.poselandmarker.R
import com.google.mediapipe.examples.poselandmarker.WorkoutActivity
import com.google.mediapipe.examples.poselandmarker.data.AppDatabase
import com.google.mediapipe.examples.poselandmarker.data.Challenge
import com.google.mediapipe.examples.poselandmarker.databinding.FragmentDashboardBinding
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class DashboardFragment : Fragment() {

    private var _binding: FragmentDashboardBinding? = null
    private val binding get() = _binding!!

    private val PREFS_NAME = "FitGuruPrefs"
    private val USER_NAME_KEY = "FitGuruUserName"
    private val GOAL_KEY = "WeeklyRepGoal"
    private val LAST_CHALLENGE_COMPLETED_DAY_KEY = "LastChallengeCompletedDay"

    private val dailyChallenges = listOf(
        Challenge("Quick 15", "Do 15 push-ups in a single session.", 15, "Push-ups"),
        Challenge("Morning Burst", "Get your blood pumping with 20 push-ups.", 20, "Push-ups"),
        Challenge("Solid Strength", "Show your strength with 25 push-ups.", 25, "Push-ups"),
        Challenge("The Challenger", "Push your limits with 30 push-ups.", 30, "Push-ups"),
        Challenge("Endurance Test", "Go the distance with 35 push-ups.", 35, "Push-ups")
    )

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDashboardBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupUserGreeting()
        setupDate()
        setupCalendar()
        setupGoalCard()
        observeWeeklyProgress()
        setupDailyChallenge()
        setupHomeWorkouts()
    }

    private fun setupUserGreeting() {
        val sharedPref = activity?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val name = sharedPref?.getString(USER_NAME_KEY, "Athrava") ?: "Athrava"
        binding.activityTitle.text = "Hello, $name 👋"
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private fun setupDailyChallenge() {
        val calendar = Calendar.getInstance()
        val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
        val challengeIndex = dayOfYear % dailyChallenges.size
        val todayChallenge = dailyChallenges[challengeIndex]
        val sharedPref = activity?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastCompletedDay = sharedPref?.getInt(LAST_CHALLENGE_COMPLETED_DAY_KEY, -1)
        if (dayOfYear == lastCompletedDay) {
            binding.challengeTitleText.text = "Challenge Complete! 🎉"
            binding.challengeDescriptionText.text = "Amazing work! See you tomorrow for a new one."
            binding.challengeCard.setCardBackgroundColor(ContextCompat.getColor(requireContext(), R.color.card_background))
        } else {
            binding.challengeTitleText.text = todayChallenge.title
            binding.challengeDescriptionText.text = todayChallenge.description
        }
    }

    private fun setupGoalCard() {
        binding.goalsCard.setOnClickListener {
            showSetGoalDialog()
        }
    }

    private var currentWeeklyReps = 0

    // Dynamic database calculation from Room SQLite
    private fun observeWeeklyProgress() {
        val dao = AppDatabase.getDatabase(requireContext()).workoutDao()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.DAY_OF_WEEK, firstDayOfWeek)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfWeek = calendar.time
        calendar.add(Calendar.DAY_OF_WEEK, 6)
        calendar.set(Calendar.HOUR_OF_DAY, 23)
        calendar.set(Calendar.MINUTE, 59)
        calendar.set(Calendar.SECOND, 59)
        calendar.set(Calendar.MILLISECOND, 999)
        val endOfWeek = calendar.time
        
        lifecycleScope.launch {
            dao.getSessionsForWeek(startOfWeek, endOfWeek).collect { weeklySessions ->
                currentWeeklyReps = weeklySessions.sumOf { it.reps }
                updateProgressUI(currentWeeklyReps)
            }
        }
    }

    private fun updateProgressUI(currentReps: Int) {
        val goal = getWeeklyGoal()
        val progress = if (goal > 0) (currentReps * 100 / goal) else 0
        binding.progressBar.progress = progress
        binding.progressTextCurrent.text = "Current: $currentReps reps"
        binding.progressTextGoal.text = "Goal: $goal reps"
    }

    private fun showSetGoalDialog() {
        val builder = AlertDialog.Builder(requireContext())
        builder.setTitle("Set Weekly Rep Goal")
        val input = EditText(requireContext())
        input.inputType = InputType.TYPE_CLASS_NUMBER
        input.hint = "e.g., 200"
        input.setText(getWeeklyGoal().toString())
        builder.setView(input)
        builder.setPositiveButton("Set") { dialog, _ ->
            val goal = input.text.toString().toIntOrNull() ?: 200
            saveWeeklyGoal(goal)
            updateProgressUI(currentWeeklyReps)
            dialog.dismiss()
        }
        builder.setNegativeButton("Cancel") { dialog, _ -> dialog.cancel() }
        builder.show()
    }

    private fun saveWeeklyGoal(goal: Int) {
        val sharedPref = activity?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) ?: return
        with(sharedPref.edit()) {
            putInt(GOAL_KEY, goal)
            apply()
        }
    }

    private fun getWeeklyGoal(): Int {
        val sharedPref = activity?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPref?.getInt(GOAL_KEY, 200) ?: 200
    }

    private fun setupDate() {
        val dateFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
        val today = dateFormat.format(Date())
        binding.dateTextView.text = today
    }

    private fun setupCalendar() {
        val calendar = Calendar.getInstance()
        val today = calendar.get(Calendar.DAY_OF_MONTH)
        val days = listOf("M", "T", "W", "T", "F", "S", "S")
        val dayViews = listOf(
            binding.day1Container.day, binding.day2Container.day, binding.day3Container.day,
            binding.day4Container.day, binding.day5Container.day, binding.day6Container.day,
            binding.day7Container.day
        )
        val dateViews = listOf(
            binding.day1Container.date, binding.day2Container.date, binding.day3Container.date,
            binding.day4Container.date, binding.day5Container.date, binding.day6Container.date,
            binding.day7Container.date
        )
        val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
        val startOffset = if (dayOfWeek == 1) 6 else dayOfWeek - 2
        for (i in 0..6) {
            dayViews[i].text = days[i]
            val dayOfMonth = today - startOffset + i
            dateViews[i].text = dayOfMonth.toString()
            if (i == startOffset) {
                dateViews[i].setBackgroundResource(R.drawable.calendar_today_background)
                dateViews[i].setTextColor(ContextCompat.getColor(requireContext(), R.color.text_on_accent))
                dayViews[i].setTextColor(ContextCompat.getColor(requireContext(), R.color.accent_lime))
            }
        }
    }

    private fun setupHomeWorkouts() {
        val workouts = listOf(
            QuickWorkout("squat", "Squats", "🏋️", "Quads • Glutes", "SQUAT"),
            QuickWorkout("pushup", "Push-ups", "🤸", "Chest • Triceps", "PUSH_UP"),
            QuickWorkout("deadlift", "Deadlifts", "🏋️", "Hamstrings • Back", "DEADLIFT"),
            QuickWorkout("pull_up", "Pull-ups", "🧗", "Lats • Back", "PULL_UP"),
            QuickWorkout("chin_up", "Chin-ups", "💪", "Biceps • Arms", "CHIN_UP"),
            QuickWorkout("running", "Running Cadence", "🏃", "Cardio • Cadence", "RUNNING"),
            QuickWorkout("bicep_curl", "Bicep Curls", "💪", "Biceps • Arms", "BICEP_CURL"),
            QuickWorkout("lunge", "Lunges", "🦵", "Quads • Balance", "LUNGE"),
            QuickWorkout("plank", "Plank Hold", "🧘", "Core • Stability", "PLANK")
        )

        val adapter = QuickWorkoutAdapter(workouts) { item ->
            val intent = Intent(requireContext(), WorkoutActivity::class.java).apply {
                putExtra("WORKOUT_TYPE", item.workoutType)
            }
            startActivity(intent)
        }
        binding.recyclerHomeWorkouts.layoutManager =
            LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false)
        binding.recyclerHomeWorkouts.adapter = adapter

        binding.challengeCard.setOnClickListener {
            val intent = Intent(requireContext(), WorkoutActivity::class.java).apply {
                putExtra("WORKOUT_TYPE", "PUSH_UP")
            }
            startActivity(intent)
        }

        binding.cardGymDirectoryShortcut.setOnClickListener {
            try {
                findNavController().navigate(R.id.workoutsFragment)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
