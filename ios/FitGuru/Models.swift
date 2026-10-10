import SwiftUI
import Combine

// MARK: - Workout Session Model (Room DB parity)
struct WorkoutSession: Identifiable, Codable {
    var id: String = UUID().uuidString
    let date: Date
    let exerciseType: String
    let exerciseName: String
    let reps: Int
    let score: Int // Form accuracy out of 100
    let calories: Int
    let avgHeartRate: Int
    var weightKg: Double = 0.0 // 0.0 represents Bodyweight
    
    var weightDisplay: String {
        if weightKg <= 0 {
            return "Bodyweight"
        } else if weightKg.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weightKg)) kg"
        } else {
            return String(format: "%.1f kg", weightKg)
        }
    }
    
    var totalVolumeKg: Double {
        return weightKg * Double(reps)
    }
}

// MARK: - Exercise Types
enum ExerciseType: String, CaseIterable, Identifiable {
    case squat = "SQUAT"
    case pushup = "PUSH_UP"
    case lunge = "LUNGE"
    case plank = "PLANK"
    case bicepCurl = "BICEP_CURL"
    case deadlift = "DEADLIFT"
    case benchPress = "BENCH_PRESS"
    case shoulderPress = "SHOULDER_PRESS"
    case pullUp = "PULL_UP"
    case latPulldown = "LAT_PULLDOWN"
    case running = "RUNNING"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .squat: return "Squats"
        case .pushup: return "Push-ups"
        case .lunge: return "Lunges"
        case .plank: return "Plank Hold"
        case .bicepCurl: return "Bicep Curls"
        case .deadlift: return "Deadlift"
        case .benchPress: return "Bench Press"
        case .shoulderPress: return "Shoulder Press"
        case .pullUp: return "Pull-ups"
        case .latPulldown: return "Lat Pulldown"
        case .running: return "Running Cadence"
        }
    }
    
    var icon: String {
        switch self {
        case .squat: return "🏋️"
        case .pushup: return "💪"
        case .lunge: return "🦵"
        case .plank: return "⏱️"
        case .bicepCurl: return "🦾"
        case .deadlift: return "🏋️‍♂️"
        case .benchPress: return "🏋️"
        case .shoulderPress: return "🙌"
        case .pullUp: return "🧗"
        case .latPulldown: return "🔽"
        case .running: return "🏃"
        }
    }
    
    var targetMuscles: String {
        switch self {
        case .squat: return "Quads, Glutes & Core"
        case .pushup: return "Chest, Shoulders & Triceps"
        case .lunge: return "Quads, Hamstrings & Glutes"
        case .plank: return "Core, Abs & Lower Back"
        case .bicepCurl: return "Biceps & Forearms"
        case .deadlift: return "Posterior Chain, Glutes & Back"
        case .benchPress: return "Pectorals & Triceps"
        case .shoulderPress: return "Anterior Deltoids & Triceps"
        case .pullUp: return "Latissimus Dorsi & Biceps"
        case .latPulldown: return "Upper Back & Lats"
        case .running: return "Cardio & Leg Cadence"
        }
    }
    
    var primaryAngleName: String {
        switch self {
        case .squat, .lunge: return "Knee Angle"
        case .pushup, .benchPress, .shoulderPress: return "Elbow Angle"
        case .plank, .deadlift: return "Hip Angle"
        case .bicepCurl: return "Elbow Flex"
        case .pullUp, .latPulldown: return "Arm Angle"
        case .running: return "Cadence SPM"
        }
    }
    
    var calPerRep: Double {
        switch self {
        case .squat: return 0.55
        case .pushup: return 0.45
        case .lunge: return 0.50
        case .plank: return 0.35
        case .bicepCurl: return 0.30
        case .deadlift: return 0.70
        case .benchPress: return 0.50
        case .shoulderPress: return 0.40
        case .pullUp: return 0.80
        case .latPulldown: return 0.45
        case .running: return 0.60
        }
    }
}

// MARK: - Machine & Equipment Catalog Models (GymCatalog.kt parity)
struct MachineGuide: Identifiable {
    let id: String
    let name: String
    let icon: String
    let what: String
    let labels: [String]
    let exercises: [String]
    let category: String
}

struct ExerciseGuide: Identifiable {
    let id: String
    let name: String
    let muscles: [String]
    let level: String
    let plan: String
    let setup: [String]
    let steps: [String]
    let mistakes: [String]
    let safety: String
    let cameraTip: String
    let workoutType: String
}

struct EquipmentWithExercise: Identifiable {
    var id: String { machine.id }
    let machine: MachineGuide
    let primaryExercise: ExerciseGuide
}

// MARK: - Central State Store
class WorkoutStore: ObservableObject {
    @Published var sessions: [WorkoutSession] = []
    @Published var currentHeartRate: Int = 117
    @Published var weeklyGoal: Int = 200
    @Published var userName: String = "Athrava"
    @Published var userHandle: String = "@athrava • Innovhacks 4.0"
    
    // Active sheet selections
    @Published var activeWorkoutType: ExerciseType? = nil
    @Published var selectedEquipment: EquipmentWithExercise? = nil
    @Published var isShowingHistory: Bool = false
    @Published var isShowingGoalsEditor: Bool = false
    
    private var hrTimer: AnyCancellable?
    
    private let sessionsStorageKey = "fitguru_sessions_storage_v1"
    
    init() {
        loadSavedSessions()
        startHeartRateSimulation()
    }
    
    func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsStorageKey)
        }
    }
    
    private func loadSavedSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsStorageKey),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data),
           !decoded.isEmpty {
            self.sessions = decoded
        } else {
            loadMockSessions()
            saveSessions()
        }
    }
    
    var totalReps: Int {
        sessions.reduce(0) { $0 + $1.reps }
    }
    
    var totalWorkouts: Int {
        sessions.count
    }
    
    var totalCalories: Int {
        sessions.reduce(0) { $0 + $1.calories }
    }
    
    var avgFormAccuracy: Int {
        guard !sessions.isEmpty else { return 97 }
        let total = sessions.reduce(0) { $0 + $1.score }
        return total / sessions.count
    }
    
    var currentWeeklyReps: Int {
        // Sum reps from the last 7 days
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentReps = sessions.filter { $0.date >= oneWeekAgo }.reduce(0) { $0 + $1.reps }
        return max(recentReps, 140) // Baseline matching Android preview
    }
    
    var totalVolumeLiftedKg: Double {
        sessions.reduce(0.0) { $0 + $1.totalVolumeKg }
    }

    func lastSession(for exerciseType: String) -> WorkoutSession? {
        sessions.first(where: { $0.exerciseType == exerciseType })
    }
    
    func defaultWeight(for exerciseType: ExerciseType) -> Double {
        if let last = lastSession(for: exerciseType.rawValue), last.weightKg > 0 {
            return last.weightKg
        }
        switch exerciseType {
        case .squat: return 60.0
        case .deadlift: return 80.0
        case .benchPress: return 60.0
        case .shoulderPress: return 30.0
        case .latPulldown: return 45.0
        case .bicepCurl: return 14.0
        case .lunge: return 16.0
        case .pushup, .pullUp, .plank, .running: return 0.0
        }
    }
    
    func progressiveTarget(for exerciseType: String) -> String {
        guard let last = lastSession(for: exerciseType) else {
            return "First session! Focus on solid form."
        }
        if last.weightKg > 0 {
            let nextWeight = last.weightKg + 2.5
            let formattedNext = nextWeight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(nextWeight))" : String(format: "%.1f", nextWeight)
            let formattedLast = last.weightKg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(last.weightKg))" : String(format: "%.1f", last.weightKg)
            return "Last: \(formattedLast) kg × \(last.reps) reps → Target: \(formattedNext) kg × \(last.reps) or \(formattedLast) kg × \(last.reps + 2) reps"
        } else {
            return "Last: \(last.reps) reps → Target: \(last.reps + 2) reps"
        }
    }
    
    @discardableResult
    func addSession(type: ExerciseType, reps: Int, score: Int, weightKg: Double = 0.0) -> WorkoutSession {
        let calories = Int(Double(reps) * type.calPerRep)
        let session = WorkoutSession(
            date: Date(),
            exerciseType: type.rawValue,
            exerciseName: type.displayName,
            reps: reps,
            score: score,
            calories: max(calories, 15),
            avgHeartRate: currentHeartRate,
            weightKg: weightKg
        )
        sessions.insert(session, at: 0)
        saveSessions()
        return session
    }
    
    func updateSessionWeight(id: String, weightKg: Double) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].weightKg = max(0.0, weightKg)
            saveSessions()
        }
    }
    
    private func loadMockSessions() {
        let calendar = Calendar.current
        sessions = [
            WorkoutSession(
                date: calendar.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                exerciseType: "SQUAT",
                exerciseName: "Squats",
                reps: 24,
                score: 98,
                calories: 65,
                avgHeartRate: 124,
                weightKg: 60.0
            ),
            WorkoutSession(
                date: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                exerciseType: "PUSH_UP",
                exerciseName: "Push-ups",
                reps: 30,
                score: 95,
                calories: 48,
                avgHeartRate: 118,
                weightKg: 0.0
            ),
            WorkoutSession(
                date: calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                exerciseType: "LUNGE",
                exerciseName: "Lunges",
                reps: 20,
                score: 96,
                calories: 42,
                avgHeartRate: 115,
                weightKg: 16.0
            ),
            WorkoutSession(
                date: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                exerciseType: "PLANK",
                exerciseName: "Plank Hold",
                reps: 60,
                score: 100,
                calories: 35,
                avgHeartRate: 108,
                weightKg: 0.0
            ),
            WorkoutSession(
                date: calendar.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
                exerciseType: "BICEP_CURL",
                exerciseName: "Bicep Curls",
                reps: 26,
                score: 94,
                calories: 32,
                avgHeartRate: 112,
                weightKg: 14.0
            )
        ]
    }
    
    private func startHeartRateSimulation() {
        hrTimer = Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Subtle physiological oscillation between 114 and 122 BPM
                let delta = Int.random(in: -2...2)
                let newHr = self.currentHeartRate + delta
                self.currentHeartRate = max(108, min(138, newHr))
            }
    }
}
