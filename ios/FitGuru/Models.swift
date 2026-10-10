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

// MARK: - Personal Record Model (PR Tracker)
struct PersonalRecord: Identifiable {
    var id: String { exerciseType }
    let exerciseType: String
    let exerciseName: String
    let bestScore: Int
    let maxReps: Int
    let maxWeightKg: Double
    let maxVolumeKg: Double
    
    var weightDisplay: String {
        if maxWeightKg <= 0 {
            return "Bodyweight"
        } else if maxWeightKg.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(maxWeightKg)) kg"
        } else {
            return String(format: "%.1f kg", maxWeightKg)
        }
    }
}

// MARK: - Milestone Badge Model (Achievements & Streaks)
struct MilestoneBadge: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let isUnlocked: Bool
    let category: String
    let unlockedDate: String?
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
    
    // Active sheet selections & modal tools
    @Published var activeWorkoutType: ExerciseType? = nil
    @Published var selectedEquipment: EquipmentWithExercise? = nil
    @Published var isShowingHistory: Bool = false
    @Published var isShowingGoalsEditor: Bool = false
    @Published var isShowingRestTimer: Bool = false
    @Published var isShowingAnalytics: Bool = false
    @Published var requestFinishActiveWorkout: Bool = false
    
    // Smart Rest Timer State
    @Published var isRestTimerActive: Bool = false
    @Published var restTimerRemainingSeconds: Int = 60
    @Published var restTimerTotalSeconds: Int = 60
    private var restTimerCancellable: AnyCancellable?
    
    // Voice Command State
    @Published var isVoiceListening: Bool = false
    @Published var lastVoiceCommand: String? = nil
    @Published var voiceFeedbackMessage: String? = nil
    
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
    
    // MARK: - Streaks & Personal Records (PRs)
    var streakDays: Int {
        guard !sessions.isEmpty else { return 5 }
        let calendar = Calendar.current
        let daysWithWorkouts = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var currentStreak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        if !daysWithWorkouts.contains(checkDate) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate),
               daysWithWorkouts.contains(yesterday) {
                checkDate = yesterday
            } else {
                return 5 // Default active streak from training history
            }
        }
        
        while daysWithWorkouts.contains(checkDate) {
            currentStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }
        return max(currentStreak, 5)
    }
    
    var personalRecords: [PersonalRecord] {
        var prs: [String: PersonalRecord] = [:]
        for session in sessions {
            if let existing = prs[session.exerciseType] {
                prs[session.exerciseType] = PersonalRecord(
                    exerciseType: session.exerciseType,
                    exerciseName: session.exerciseName,
                    bestScore: max(existing.bestScore, session.score),
                    maxReps: max(existing.maxReps, session.reps),
                    maxWeightKg: max(existing.maxWeightKg, session.weightKg),
                    maxVolumeKg: max(existing.maxVolumeKg, session.totalVolumeKg)
                )
            } else {
                prs[session.exerciseType] = PersonalRecord(
                    exerciseType: session.exerciseType,
                    exerciseName: session.exerciseName,
                    bestScore: session.score,
                    maxReps: session.reps,
                    maxWeightKg: session.weightKg,
                    maxVolumeKg: session.totalVolumeKg
                )
            }
        }
        return Array(prs.values).sorted(by: { $0.maxVolumeKg > $1.maxVolumeKg })
    }
    
    var milestoneBadges: [MilestoneBadge] {
        let hasHighScore = sessions.contains(where: { $0.score >= 98 })
        let hasCenturyReps = totalReps >= 100
        let hasHeavyLoad = sessions.contains(where: { $0.weightKg >= 50.0 })
        let hasHighVol = sessions.contains(where: { $0.totalVolumeKg >= 1000.0 })
        let streak = streakDays
        
        return [
            MilestoneBadge(
                id: "streak_flame",
                title: "\(streak)-Day Streak",
                subtitle: "Consistent on-device workouts",
                icon: "🔥",
                isUnlocked: streak >= 3,
                category: "Consistency",
                unlockedDate: "Active"
            ),
            MilestoneBadge(
                id: "form_perfectionist",
                title: "Form Perfectionist",
                subtitle: "Achieved 98%+ biomechanical accuracy",
                icon: "🥇",
                isUnlocked: hasHighScore,
                category: "Technique",
                unlockedDate: "Today"
            ),
            MilestoneBadge(
                id: "volume_titan",
                title: "Volume Titan",
                subtitle: "Over 1,000 kg moved in single session",
                icon: "⚡",
                isUnlocked: hasHighVol,
                category: "Strength",
                unlockedDate: "Recent"
            ),
            MilestoneBadge(
                id: "century_club",
                title: "Century Club",
                subtitle: "Completed over 100 total reps",
                icon: "💯",
                isUnlocked: hasCenturyReps,
                category: "Endurance",
                unlockedDate: "Unlocked"
            ),
            MilestoneBadge(
                id: "iron_lifter",
                title: "Iron Lifter",
                subtitle: "Trained with 50+ kg external load",
                icon: "🏋️",
                isUnlocked: hasHeavyLoad,
                category: "Power",
                unlockedDate: "Unlocked"
            ),
            MilestoneBadge(
                id: "gym_shield",
                title: "Gym Shield Lock",
                subtitle: "Zero lost tracking in crowded gym",
                icon: "🛡️",
                isUnlocked: true,
                category: "AI Tracking",
                unlockedDate: "Active"
            )
        ]
    }
    
    // MARK: - Smart Rest Timer Logic
    var isHeartRateRecovered: Bool {
        return currentHeartRate <= 114
    }
    
    var smartRestSuggestion: String {
        if currentHeartRate > 125 {
            return "Elevated cardiac load (\(currentHeartRate) BPM). Rest 40 more seconds until HR drops below 115 BPM."
        } else if currentHeartRate > 114 {
            return "Steady recovery (\(currentHeartRate) BPM). Rest ~20 seconds for neuro-muscular ATP reset."
        } else {
            return "✅ Heart rate recovered (\(currentHeartRate) BPM)! Cardiovascular readiness optimal for your next set."
        }
    }
    
    func startSmartRest(duration: Int = 60) {
        restTimerTotalSeconds = duration
        restTimerRemainingSeconds = duration
        isRestTimerActive = true
        isShowingRestTimer = true
        
        restTimerCancellable?.cancel()
        restTimerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.restTimerRemainingSeconds > 0 {
                    self.restTimerRemainingSeconds -= 1
                } else {
                    self.stopSmartRest()
                }
            }
    }
    
    func adjustSmartRest(by seconds: Int) {
        restTimerRemainingSeconds = max(5, restTimerRemainingSeconds + seconds)
        restTimerTotalSeconds = max(restTimerRemainingSeconds, restTimerTotalSeconds + seconds)
    }
    
    func stopSmartRest() {
        isRestTimerActive = false
        isShowingRestTimer = false
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
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
