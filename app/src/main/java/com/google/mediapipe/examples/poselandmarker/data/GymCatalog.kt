package com.google.mediapipe.examples.poselandmarker.data

import android.content.Context
import org.json.JSONObject

data class MachineGuide(
    val id: String,
    val name: String,
    val icon: String,
    val what: String,
    val labels: List<String>,
    val exercises: List<String>,
    val category: String = "Machine"
)

data class ExerciseGuide(
    val id: String,
    val name: String,
    val muscles: List<String>,
    val level: String,
    val plan: String,
    val setup: List<String>,
    val steps: List<String>,
    val mistakes: List<String>,
    val safety: String,
    val cameraTip: String,
    val hasAiAnalysis: Boolean,
    val workoutType: String
)

data class EquipmentWithExercise(
    val machine: MachineGuide,
    val primaryExercise: ExerciseGuide?
)

object GymCatalogRepository {
    private var cachedList: List<EquipmentWithExercise>? = null

    fun getEquipmentList(context: Context): List<EquipmentWithExercise> {
        if (cachedList != null) return cachedList!!

        val list = mutableListOf<EquipmentWithExercise>()
        try {
            val jsonString = context.assets.open("gym_catalog.json").bufferedReader().use { it.readText() }
            val root = JSONObject(jsonString)
            val machinesArray = root.getJSONArray("machines")
            val exercisesObj = root.getJSONObject("exercises")

            for (i in 0 until machinesArray.length()) {
                val mObj = machinesArray.getJSONObject(i)
                val id = mObj.getString("id")
                val name = mObj.getString("name")
                val icon = mObj.optString("icon", "🏋️")
                val what = mObj.optString("what", "")

                val labelsList = mutableListOf<String>()
                val labelsArr = mObj.optJSONArray("labels")
                if (labelsArr != null) {
                    for (j in 0 until labelsArr.length()) {
                        labelsList.add(labelsArr.getString(j))
                    }
                }

                val exList = mutableListOf<String>()
                val exArr = mObj.optJSONArray("exercises")
                if (exArr != null) {
                    for (j in 0 until exArr.length()) {
                        exList.add(exArr.getString(j))
                    }
                }

                val category = determineCategory(id)
                val machine = MachineGuide(id, name, icon, what, labelsList, exList, category)

                var primaryExercise: ExerciseGuide? = null
                if (exList.isNotEmpty()) {
                    val exId = exList[0]
                    if (exercisesObj.has(exId)) {
                        val eObj = exercisesObj.getJSONObject(exId)
                        val exName = eObj.optString("name", name)
                        val level = eObj.optString("level", "Beginner")
                        val plan = eObj.optString("plan", "")
                        val safety = eObj.optString("safety", "")

                        val musclesList = mutableListOf<String>()
                        val mArr = eObj.optJSONArray("muscles")
                        if (mArr != null) {
                            for (j in 0 until mArr.length()) {
                                musclesList.add(mArr.getString(j))
                            }
                        }

                        val setupList = mutableListOf<String>()
                        val sArr = eObj.optJSONArray("setup")
                        if (sArr != null) {
                            for (j in 0 until sArr.length()) {
                                setupList.add(sArr.getString(j))
                            }
                        }

                        val stepsList = mutableListOf<String>()
                        val stArr = eObj.optJSONArray("steps")
                        if (stArr != null) {
                            for (j in 0 until stArr.length()) {
                                stepsList.add(stArr.getString(j))
                            }
                        }

                        val mistakesList = mutableListOf<String>()
                        val misArr = eObj.optJSONArray("mistakes")
                        if (misArr != null) {
                            for (j in 0 until misArr.length()) {
                                mistakesList.add(misArr.getString(j))
                            }
                        }

                        val cameraObj = eObj.optJSONObject("camera")
                        val cameraTip = cameraObj?.optString("tip") ?: "Place phone 2-3 meters away at joint height."
                        val hasAnalysis = !eObj.isNull("analysis")
                        val workoutType = mapToWorkoutType(exId)

                        primaryExercise = ExerciseGuide(
                            id = exId,
                            name = exName,
                            muscles = musclesList,
                            level = level,
                            plan = plan,
                            setup = setupList,
                            steps = stepsList,
                            mistakes = mistakesList,
                            safety = safety,
                            cameraTip = cameraTip,
                            hasAiAnalysis = hasAnalysis,
                            workoutType = workoutType
                        )
                    }
                }

                list.add(EquipmentWithExercise(machine, primaryExercise))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        cachedList = list
        return list
    }

    private fun determineCategory(id: String): String {
        return when {
            id in listOf("treadmill", "exercise_bike", "rowing_machine", "running_track") -> "Cardio"
            id in listOf("dumbbells", "squat_rack", "bench_press", "deadlift_platform", "pullup_bar") -> "Free Weights"
            id in listOf("exercise_mat") -> "Core"
            id in listOf("leg_press", "leg_extension", "leg_curl", "smith_machine") -> "Lower Body"
            id in listOf("lat_pulldown", "seated_cable_row", "chest_press_machine", "shoulder_press_machine", "cable_machine", "pec_deck") -> "Upper Body"
            else -> "Upper Body"
        }
    }

    fun mapToWorkoutType(exId: String): String {
        return when (exId.lowercase()) {
            "squat" -> "SQUAT"
            "push_up", "pushups", "push-up" -> "PUSH_UP"
            "bicep_curl" -> "BICEP_CURL"
            "lunge" -> "LUNGE"
            "plank" -> "PLANK"
            "bench_press" -> "BENCH_PRESS"
            "shoulder_press" -> "SHOULDER_PRESS"
            "leg_press" -> "LEG_PRESS"
            "lat_pulldown" -> "LAT_PULLDOWN"
            "chest_press" -> "CHEST_PRESS"
            "seated_cable_row" -> "SEATED_ROW"
            "leg_extension" -> "LEG_EXTENSION"
            "leg_curl" -> "LEG_CURL"
            "triceps_pushdown" -> "TRICEPS_PUSHDOWN"
            "deadlift" -> "DEADLIFT"
            "pull_up", "pull-up", "pullups" -> "PULL_UP"
            "chin_up", "chin-up", "chinups" -> "CHIN_UP"
            "running", "running_gait" -> "RUNNING"
            else -> "PUSH_UP"
        }
    }
}
