package com.google.mediapipe.examples.poselandmarker

import org.junit.Test
import org.junit.Assert.*
import java.util.Calendar

class ExampleUnitTest {

    // Helper implementing the 2D joint angle formula
    private fun calculateAngle(
        p1x: Float, p1y: Float,
        p2x: Float, p2y: Float,
        p3x: Float, p3y: Float
    ): Double {
        val v1x = p1x - p2x
        val v1y = p1y - p2y
        val v2x = p3x - p2x
        val v2y = p3y - p2y
        val dot = v1x * v2x + v1y * v2y
        val mag1 = Math.sqrt((v1x * v1x + v1y * v1y).toDouble())
        val mag2 = Math.sqrt((v2x * v2x + v2y * v2y).toDouble())
        if (mag1 * mag2 == 0.0) return 180.0
        val cosAngle = Math.max(-1.0, Math.min(1.0, dot / (mag1 * mag2)))
        return Math.toDegrees(Math.acos(cosAngle))
    }

    @Test
    fun testRightAngleCalculation() {
        // Points forming a 90-degree angle: (0, 1) -> (0, 0) -> (1, 0)
        val angle = calculateAngle(0f, 1f, 0f, 0f, 1f, 0f)
        assertEquals(90.0, angle, 0.01)
    }

    @Test
    fun testStraightLineAngleCalculation() {
        // Collinear opposite vectors: (-1, 0) -> (0, 0) -> (1, 0) = 180 degrees
        val angle = calculateAngle(-1f, 0f, 0f, 0f, 1f, 0f)
        assertEquals(180.0, angle, 0.01)
    }

    @Test
    fun testAcuteAngleCalculation() {
        // 45 degrees
        val angle = calculateAngle(1f, 1f, 0f, 0f, 1f, 0f)
        assertEquals(45.0, angle, 0.01)
    }

    @Test
    fun testDegeneratePointCalculation() {
        // Zero-length vector should safely return 180 without dividing by zero
        val angle = calculateAngle(0f, 0f, 0f, 0f, 1f, 0f)
        assertEquals(180.0, angle, 0.01)
    }

    @Test
    fun testWeeklyCalendarBoundsCoverage() {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.DAY_OF_WEEK, firstDayOfWeek)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfWeek = calendar.timeInMillis

        calendar.add(Calendar.DAY_OF_WEEK, 6)
        calendar.set(Calendar.HOUR_OF_DAY, 23)
        calendar.set(Calendar.MINUTE, 59)
        calendar.set(Calendar.SECOND, 59)
        calendar.set(Calendar.MILLISECOND, 999)
        val endOfWeek = calendar.timeInMillis

        val diffMs = endOfWeek - startOfWeek
        val expectedSevenDaysMs = (7L * 24 * 60 * 60 * 1000) - 1 // 7 full days minus 1ms

        assertEquals(expectedSevenDaysMs, diffMs)
    }

    @Test
    fun testSquatRepCountingStateMachine() {
        var workoutState = "ready"
        var repCount = 0

        // Squat descent: knee < 105, hip < 115
        val kneeDown = 95.0
        val hipDown = 100.0
        if (kneeDown < 105 && hipDown < 115) {
            if (workoutState == "ready" || workoutState == "up") {
                workoutState = "down"
            }
        }
        assertEquals("down", workoutState)

        // Squat ascent: knee > 160, hip > 160
        val kneeUp = 168.0
        val hipUp = 165.0
        if (kneeUp > 160 && hipUp > 160) {
            if (workoutState == "down") {
                repCount++
                workoutState = "up"
            }
        }
        assertEquals("up", workoutState)
        assertEquals(1, repCount)
    }
}