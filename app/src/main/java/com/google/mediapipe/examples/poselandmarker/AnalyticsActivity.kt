package com.google.mediapipe.examples.poselandmarker

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.mediapipe.examples.poselandmarker.data.AppDatabase
import com.google.mediapipe.examples.poselandmarker.data.WorkoutSession
import com.google.mediapipe.examples.poselandmarker.databinding.ActivityAnalyticsBinding
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class AnalyticsActivity : AppCompatActivity() {

    private lateinit var binding: ActivityAnalyticsBinding
    private lateinit var adapter: HistoryAdapter
    private var allSessions: List<WorkoutSession> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAnalyticsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.backButton.setOnClickListener { finish() }

        adapter = HistoryAdapter()
        binding.analyticsRecyclerView.layoutManager = LinearLayoutManager(this)
        binding.analyticsRecyclerView.adapter = adapter

        setupMetricButtons()
        observeSessions()
    }

    private fun setupMetricButtons() {
        binding.metricFormButton.setOnClickListener {
            highlightButton(0)
        }
        binding.metricVolumeButton.setOnClickListener {
            highlightButton(1)
        }
        binding.metricHrButton.setOnClickListener {
            highlightButton(2)
        }
    }

    private fun highlightButton(index: Int) {
        val selectedBg = ContextCompat.getColor(this, R.color.accent_lime)
        val selectedText = ContextCompat.getColor(this, R.color.text_on_accent)
        val defaultBg = android.graphics.Color.parseColor("#27272A")
        val defaultText = ContextCompat.getColor(this, R.color.white)

        binding.metricFormButton.setBackgroundColor(if (index == 0) selectedBg else defaultBg)
        binding.metricFormButton.setTextColor(if (index == 0) selectedText else defaultText)

        binding.metricVolumeButton.setBackgroundColor(if (index == 1) selectedBg else defaultBg)
        binding.metricVolumeButton.setTextColor(if (index == 1) selectedText else defaultText)

        binding.metricHrButton.setBackgroundColor(if (index == 2) selectedBg else defaultBg)
        binding.metricHrButton.setTextColor(if (index == 2) selectedText else defaultText)
    }

    private fun observeSessions() {
        val dao = AppDatabase.getDatabase(this).workoutDao()
        lifecycleScope.launch {
            dao.getAllSessions().collectLatest { sessions ->
                allSessions = sessions
                adapter.submitList(sessions.take(15))
                computeAnalytics(sessions)
            }
        }
    }

    private fun computeAnalytics(sessions: List<WorkoutSession>) {
        if (sessions.isEmpty()) {
            binding.statTotalWorkouts.text = "0"
            binding.statAvgAccuracy.text = "--%"
            binding.statTotalVolume.text = "0 kg"
            return
        }

        val totalWorkouts = sessions.size
        val avgScore = sessions.map { it.score }.average().toInt()
        val totalVolume = sessions.sumOf { it.totalVolumeKg }.toInt()

        binding.statTotalWorkouts.text = "$totalWorkouts"
        binding.statAvgAccuracy.text = "$avgScore%"
        binding.statTotalVolume.text = "$totalVolume kg"

        // PRs
        val squatSessions = sessions.filter { it.exerciseType.contains("SQUAT", true) }
        if (squatSessions.isNotEmpty()) {
            val maxReps = squatSessions.maxOf { it.reps }
            val maxWeight = squatSessions.maxOf { it.weightKg }
            binding.prSquatText.text = "$maxReps reps • ${if (maxWeight > 0) "${maxWeight.toInt()} kg" else "BW"}"
        }

        val pushupSessions = sessions.filter { it.exerciseType.contains("PUSH", true) }
        if (pushupSessions.isNotEmpty()) {
            val maxReps = pushupSessions.maxOf { it.reps }
            binding.prPushupText.text = "$maxReps reps • Bodyweight"
        }

        val curlSessions = sessions.filter { it.exerciseType.contains("CURL", true) }
        if (curlSessions.isNotEmpty()) {
            val maxReps = curlSessions.maxOf { it.reps }
            val maxWeight = curlSessions.maxOf { it.weightKg }
            binding.prCurlText.text = "$maxReps reps • ${if (maxWeight > 0) "${maxWeight.toInt()} kg" else "BW"}"
        }
    }
}
