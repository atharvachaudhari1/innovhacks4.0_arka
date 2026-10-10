import AppIntents
import SwiftUI

// MARK: - Shared App State Bridge (connects Siri Intents → SwiftUI)
/// Coordinates App Intents (which may execute in a separate system process)
/// with the foreground SwiftUI app using URL schemes, UserDefaults, and Notifications.
final class SiriCommandBridge {
    static let shared = SiriCommandBridge()
    
    /// In-process Notification identifiers
    static let startExerciseNotification = Notification.Name("FitGuru.Siri.StartExercise")
    static let finishSetNotification     = Notification.Name("FitGuru.Siri.FinishSet")
    static let startRestNotification     = Notification.Name("FitGuru.Siri.StartRest")
    static let formCheckNotification     = Notification.Name("FitGuru.Siri.FormCheck")
    
    /// Cross-Process Persistence Keys
    static let keyPendingFinishSet     = "FitGuru.Siri.PendingFinishSet"
    static let keyPendingStartExercise = "FitGuru.Siri.PendingStartExercise"
    static let keyPendingStartRest     = "FitGuru.Siri.PendingStartRest"
    static let keyPendingFormCheck     = "FitGuru.Siri.PendingFormCheck"
    
    private init() {}
    
    static func recordAction(urlScheme: String, notification: Notification.Name, userInfo: [String: Any]? = nil, pendingKey: String? = nil, pendingValue: Any? = nil) {
        // 1. Post in-process notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: notification, object: nil, userInfo: userInfo)
        }
        
        // 2. Persist to standard UserDefaults with timestamp for foreground polling
        if let key = pendingKey {
            UserDefaults.standard.set(pendingValue ?? Date().timeIntervalSince1970, forKey: key)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "\(key).timestamp")
            UserDefaults.standard.synchronize()
        }
        
        // 3. Open Custom URL Scheme to bring app forward and route action
        if let url = URL(string: urlScheme) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

// MARK: - Exercise Type Enum for Siri (AppEnum)
/// Maps natural-language exercise names to our internal ExerciseType enum.
enum SiriExercise: String, AppEnum {
    case pushups    = "PUSH_UP"
    case squats     = "SQUAT"
    case lunges     = "LUNGE"
    case deadlift   = "DEADLIFT"
    case bicepCurls = "BICEP_CURL"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Exercise")
    }
    
    static var caseDisplayRepresentations: [SiriExercise: DisplayRepresentation] {
        [
            .pushups:    DisplayRepresentation(title: "Push-ups",    subtitle: "Chest & Triceps"),
            .squats:     DisplayRepresentation(title: "Squats",      subtitle: "Quads & Glutes"),
            .lunges:     DisplayRepresentation(title: "Lunges",      subtitle: "Quads & Hamstrings"),
            .deadlift:   DisplayRepresentation(title: "Deadlift",    subtitle: "Posterior Chain"),
            .bicepCurls: DisplayRepresentation(title: "Bicep Curls", subtitle: "Biceps & Forearms"),
        ]
    }
    
    /// Convert to the app's native ExerciseType
    var exerciseType: ExerciseType {
        switch self {
        case .pushups:    return .pushup
        case .squats:     return .squat
        case .lunges:     return .lunge
        case .deadlift:   return .deadlift
        case .bicepCurls: return .bicepCurl
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 1. Start Exercise Intent
// MARK: ─────────────────────────────────────────────────────────────

/// "Hey Siri, start push-ups in FitGuru"
/// "Hey Siri, start squats with FitGuru"
struct StartExerciseIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Exercise"
    static var description: IntentDescription = IntentDescription(
        "Start tracking a specific exercise with FitGuru's AI pose coach.",
        categoryName: "Workout"
    )
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Exercise", description: "The exercise to start tracking")
    var exercise: SiriExercise
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriCommandBridge.recordAction(
            urlScheme: "fitguru://start-exercise?type=\(exercise.exerciseType.rawValue)",
            notification: SiriCommandBridge.startExerciseNotification,
            userInfo: ["exercise": exercise.exerciseType.rawValue],
            pendingKey: SiriCommandBridge.keyPendingStartExercise,
            pendingValue: exercise.exerciseType.rawValue
        )
        
        let name = exercise.exerciseType.displayName
        return .result(dialog: "Starting \(name). Get into position — FitGuru is watching your form! 💪")
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 2. Finish Set Intent
// MARK: ─────────────────────────────────────────────────────────────

/// "Hey Siri, finish my set in FitGuru"
/// "Hey Siri, end workout with FitGuru"
struct FinishSetIntent: AppIntent {
    static var title: LocalizedStringResource = "Finish Set"
    static var description: IntentDescription = IntentDescription(
        "Finish the current exercise set and log results.",
        categoryName: "Workout"
    )
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriCommandBridge.recordAction(
            urlScheme: "fitguru://finish-set",
            notification: SiriCommandBridge.finishSetNotification,
            pendingKey: SiriCommandBridge.keyPendingFinishSet
        )
        
        return .result(dialog: "Set finished! Great work — your results are being saved. 🎯")
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 3. Start Rest Timer Intent
// MARK: ─────────────────────────────────────────────────────────────

/// "Hey Siri, start rest timer in FitGuru"
/// "Hey Siri, take a break with FitGuru"
struct StartRestTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Rest Timer"
    static var description: IntentDescription = IntentDescription(
        "Start a smart rest timer that monitors your heart rate recovery.",
        categoryName: "Workout"
    )
    
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Duration (seconds)", default: 60)
    var duration: Int
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriCommandBridge.recordAction(
            urlScheme: "fitguru://start-rest?duration=\(duration)",
            notification: SiriCommandBridge.startRestNotification,
            userInfo: ["duration": duration],
            pendingKey: SiriCommandBridge.keyPendingStartRest,
            pendingValue: duration
        )
        
        return .result(dialog: "Rest timer started for \(duration) seconds. Monitoring your recovery. ⏱️")
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: 4. Form Check Intent
// MARK: ─────────────────────────────────────────────────────────────

/// "Hey Siri, how was my form in FitGuru?"
/// "Hey Siri, check my form with FitGuru"
struct FormCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Form"
    static var description: IntentDescription = IntentDescription(
        "Get a quick form accuracy report from your last exercise set.",
        categoryName: "Workout"
    )
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        SiriCommandBridge.recordAction(
            urlScheme: "fitguru://form-check",
            notification: SiriCommandBridge.formCheckNotification,
            pendingKey: SiriCommandBridge.keyPendingFormCheck
        )
        
        return .result(dialog: "Checking your form data... Open FitGuru for the full biomechanical debrief! 📊")
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: App Shortcuts Provider (Siri Phrase Registration)
// MARK: ─────────────────────────────────────────────────────────────

/// Registers natural-language phrases with Siri so users can invoke intents
/// without manual Shortcut setup.
struct FitGuruShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        
        // "Start push-ups in FitGuru"
        AppShortcut(
            intent: StartExerciseIntent(),
            phrases: [
                "Start \(\.$exercise) in \(.applicationName)",
                "Start \(\.$exercise) with \(.applicationName)",
                "Begin \(\.$exercise) in \(.applicationName)",
                "Track \(\.$exercise) with \(.applicationName)",
                "\(.applicationName) start \(\.$exercise)"
            ],
            shortTitle: "Start Exercise",
            systemImageName: "figure.run"
        )
        
        // "Finish my set in FitGuru"
        AppShortcut(
            intent: FinishSetIntent(),
            phrases: [
                "Finish my set in \(.applicationName)",
                "End workout with \(.applicationName)",
                "Stop my set in \(.applicationName)",
                "Complete set in \(.applicationName)",
                "\(.applicationName) finish set"
            ],
            shortTitle: "Finish Set",
            systemImageName: "checkmark.circle.fill"
        )
        
        // "Start rest timer in FitGuru"
        AppShortcut(
            intent: StartRestTimerIntent(),
            phrases: [
                "Start rest timer in \(.applicationName)",
                "Take a break with \(.applicationName)",
                "Rest timer in \(.applicationName)",
                "\(.applicationName) rest timer"
            ],
            shortTitle: "Rest Timer",
            systemImageName: "timer"
        )
        
        // "Check my form in FitGuru"
        AppShortcut(
            intent: FormCheckIntent(),
            phrases: [
                "Check my form in \(.applicationName)",
                "How was my form in \(.applicationName)",
                "Form check with \(.applicationName)",
                "\(.applicationName) form check"
            ],
            shortTitle: "Form Check",
            systemImageName: "chart.bar.fill"
        )
    }
}
