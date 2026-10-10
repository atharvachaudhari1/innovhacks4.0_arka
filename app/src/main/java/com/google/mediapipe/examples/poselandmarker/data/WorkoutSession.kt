package com.google.mediapipe.examples.poselandmarker.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date

@Entity(tableName = "workout_history")
data class WorkoutSession(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val date: Date,
    val exerciseType: String,
    val exerciseName: String = exerciseType,
    val reps: Int,
    val score: Int, // Form accuracy out of 100
    val calories: Int = 0,
    val avgHeartRate: Int = 0,
    val weightKg: Double = 0.0 // 0.0 represents Bodyweight
) {
    val weightDisplay: String
        get() {
            return if (weightKg <= 0.0) {
                "Bodyweight"
            } else if (weightKg % 1.0 == 0.0) {
                "${weightKg.toInt()} kg"
            } else {
                String.format("%.1f kg", weightKg)
            }
        }

    val totalVolumeKg: Double
        get() = weightKg * reps
}
