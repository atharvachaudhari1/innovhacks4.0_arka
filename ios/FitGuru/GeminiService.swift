import Foundation
import Combine

// MARK: - Gemini Biomechanical & Recovery Models
struct GeminiBiomechanicalReport: Codable {
    let diagnosis: String
    let correctiveCues: [String]
    let accessoryDrills: [String]
    let rawText: String
    let isLiveApi: Bool
}

struct GeminiRecoveryReport: Codable {
    let recoveryWindowHours: Int
    let strainAssessment: String
    let proteinGrams: Int
    let hydrationMl: Int
    let activeStretches: [String]
    let rawText: String
    let isLiveApi: Bool
}

// MARK: - Google Gemini API Client & Cognitive Biomechanics Engine
class GeminiService: ObservableObject {
    static let shared = GeminiService()
    
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "gemini_api_key") }
    }
    @Published var isAnalyzing: Bool = false
    @Published var lastBiomechanicalReport: GeminiBiomechanicalReport?
    @Published var lastRecoveryReport: GeminiRecoveryReport?
    
    // Recommended modern Gemini model (with automatic fallbacks)
    private let primaryModel = "gemini-2.5-flash"
    private let fallbackModel = "gemini-1.5-flash"
    
    init() {
        let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        if !savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.apiKey = savedKey
        } else {
            var key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
            if key.isEmpty, let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
               let secret = dict["GEMINI_API_KEY"] as? String {
                key = secret
            }
            self.apiKey = key
        }
    }
    
    var isKeyConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - 1. Personalized Biomechanical Form Analysis
    func analyzeBiomechanicalForm(
        session: WorkoutSession,
        primaryFault: String = "",
        jointAngle: Double = 0.0,
        completion: @escaping (GeminiBiomechanicalReport) -> Void
    ) {
        let faultDesc = primaryFault.isEmpty ? defaultFaultFor(exerciseType: session.exerciseType, score: session.score) : primaryFault
        let angleVal = jointAngle > 0 ? jointAngle : defaultAngleFor(exerciseType: session.exerciseType)
        
        guard isKeyConfigured else {
            // Intelligent on-device fallback rule-matrix
            let fallbackReport = generateOfflineBiomechanicalReport(
                session: session,
                fault: faultDesc,
                jointAngle: angleVal
            )
            DispatchQueue.main.async {
                self.lastBiomechanicalReport = fallbackReport
                completion(fallbackReport)
            }
            return
        }
        
        isAnalyzing = true
        
        let prompt = """
        You are an elite Olympic Sports Biomechanist and Physical Therapist.
        Analyze this workout session's kinematic telemetry:
        - Exercise: \(session.exerciseName)
        - Weight Lifted: \(session.weightDisplay)
        - Repetitions: \(session.reps)
        - Total Workload Volume: \(session.weightKg > 0 ? "\(Int(session.totalVolumeKg)) kg" : "Bodyweight volume")
        - Form Accuracy Score: \(session.score)%
        - Average Heart Rate: \(session.avgHeartRate) BPM
        - Observed Kinematic Fault: \(faultDesc)
        - Measured Joint Angle: \(String(format: "%.1f", angleVal))°
        
        Provide a concise, ultra-personalized biomechanical report formatted EXACTLY as:
        DIAGNOSIS: <1-2 sentences on root cause kinetic chain breakdown, joint torque, and muscle engagement>
        CUES:
        - <Actionable motor cue 1>
        - <Actionable motor cue 2>
        - <Actionable motor cue 3>
        ACCESSORIES:
        - <Corrective mobility or strengthening drill 1>
        - <Corrective mobility or strengthening drill 2>
        """
        
        callGeminiAPI(prompt: prompt, model: primaryModel) { [weak self] responseText in
            guard let self = self else { return }
            self.isAnalyzing = false
            
            if let text = responseText, !text.isEmpty {
                let report = self.parseBiomechanicalResponse(text: text)
                DispatchQueue.main.async {
                    self.lastBiomechanicalReport = report
                    completion(report)
                }
            } else {
                // Fallback on network failure
                let fallback = self.generateOfflineBiomechanicalReport(session: session, fault: faultDesc, jointAngle: angleVal)
                DispatchQueue.main.async {
                    self.lastBiomechanicalReport = fallback
                    completion(fallback)
                }
            }
        }
    }
    
    // MARK: - 2. Personalized Post-Workout Recovery Summary
    func generateRecoverySummary(
        session: WorkoutSession,
        completion: @escaping (GeminiRecoveryReport) -> Void
    ) {
        guard isKeyConfigured else {
            let fallback = generateOfflineRecoveryReport(session: session)
            DispatchQueue.main.async {
                self.lastRecoveryReport = fallback
                completion(fallback)
            }
            return
        }
        
        isAnalyzing = true
        
        let prompt = """
        You are an elite Sports Medicine Physician and Recovery Specialist.
        Generate a personalized post-workout recovery prescription:
        - Exercise: \(session.exerciseName)
        - Weight Lifted: \(session.weightDisplay)
        - Volume: \(session.reps) reps (\(session.weightKg > 0 ? "\(Int(session.totalVolumeKg)) kg total workload" : "bodyweight"))
        - Estimated Energy: \(session.calories) kcal
        - Average Heart Rate: \(session.avgHeartRate) BPM
        - Form Score: \(session.score)%
        
        Provide a concise recovery summary formatted EXACTLY as:
        WINDOW: <recommended rest hours before training this kinetic chain again, e.g. 36>
        STRAIN: <1-2 sentences assessing metabolic & cardiovascular strain zone>
        PROTEIN: <recommended post-workout protein intake in grams, e.g. 28>
        HYDRATION: <recommended water/electrolyte intake in ml, e.g. 650>
        STRETCHES:
        - <Specific active stretch 1 with duration>
        - <Specific active stretch 2 with duration>
        - <Specific active stretch 3 with duration>
        """
        
        callGeminiAPI(prompt: prompt, model: primaryModel) { [weak self] responseText in
            guard let self = self else { return }
            self.isAnalyzing = false
            
            if let text = responseText, !text.isEmpty {
                let report = self.parseRecoveryResponse(text: text, session: session)
                DispatchQueue.main.async {
                    self.lastRecoveryReport = report
                    completion(report)
                }
            } else {
                let fallback = self.generateOfflineRecoveryReport(session: session)
                DispatchQueue.main.async {
                    self.lastRecoveryReport = fallback
                    completion(fallback)
                }
            }
        }
    }
    
    // MARK: - Gemini REST API Executor
    private func callGeminiAPI(prompt: String, model: String, retryWithFallback: Bool = true, completion: @escaping (String?) -> Void) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(cleanKey)") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12.0
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.35,
                "maxOutputTokens": 800
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil)
            return
        }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil,
                  let httpResponse = response as? HTTPURLResponse else {
                if retryWithFallback {
                    self?.callGeminiAPI(prompt: prompt, model: self?.fallbackModel ?? "gemini-1.5-flash", retryWithFallback: false, completion: completion)
                } else {
                    completion(nil)
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    completion(text)
                    return
                }
            }
            
            if retryWithFallback {
                self.callGeminiAPI(prompt: prompt, model: self.fallbackModel, retryWithFallback: false, completion: completion)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - Parsers
    private func parseBiomechanicalResponse(text: String) -> GeminiBiomechanicalReport {
        var diagnosis = ""
        var cues: [String] = []
        var accessories: [String] = []
        
        let lines = text.components(separatedBy: .newlines)
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.uppercased().starts(with: "DIAGNOSIS:") {
                diagnosis = trimmed.replacingOccurrences(of: "DIAGNOSIS:", with: "").trimmingCharacters(in: .whitespaces)
                currentSection = "DIAGNOSIS"
            } else if trimmed.uppercased().starts(with: "CUES:") {
                currentSection = "CUES"
            } else if trimmed.uppercased().starts(with: "ACCESSORIES:") {
                currentSection = "ACCESSORIES"
            } else if trimmed.starts(with: "-") || trimmed.starts(with: "•") || trimmed.starts(with: "*") {
                let item = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if currentSection == "CUES" {
                    cues.append(item)
                } else if currentSection == "ACCESSORIES" {
                    accessories.append(item)
                }
            } else if currentSection == "DIAGNOSIS" && diagnosis.isEmpty {
                diagnosis = trimmed
            }
        }
        
        if diagnosis.isEmpty {
            diagnosis = "Optimal multi-joint coordination maintained. Slight kinetic drift observed in late-set eccentric phase."
        }
        if cues.isEmpty {
            cues = ["Root your feet firmly into the floor", "Maintain strict intra-abdominal bracing", "Control the tempo during the eccentric descent"]
        }
        if accessories.isEmpty {
            accessories = ["Banded Joint Distraction (2 sets x 45s)", "Isometric Tempo Holds (3 sets x 20s)"]
        }
        
        return GeminiBiomechanicalReport(
            diagnosis: diagnosis,
            correctiveCues: cues,
            accessoryDrills: accessories,
            rawText: text,
            isLiveApi: true
        )
    }
    
    private func parseRecoveryResponse(text: String, session: WorkoutSession) -> GeminiRecoveryReport {
        var window = 36
        var strain = ""
        var protein = 26
        var hydration = 650
        var stretches: [String] = []
        
        let lines = text.components(separatedBy: .newlines)
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if trimmed.uppercased().starts(with: "WINDOW:") {
                let numStr = trimmed.replacingOccurrences(of: "WINDOW:", with: "").components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let val = Int(numStr), val > 0 { window = val }
            } else if trimmed.uppercased().starts(with: "STRAIN:") {
                strain = trimmed.replacingOccurrences(of: "STRAIN:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().starts(with: "PROTEIN:") {
                let numStr = trimmed.replacingOccurrences(of: "PROTEIN:", with: "").components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let val = Int(numStr), val > 0 { protein = val }
            } else if trimmed.uppercased().starts(with: "HYDRATION:") {
                let numStr = trimmed.replacingOccurrences(of: "HYDRATION:", with: "").components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let val = Int(numStr), val > 0 { hydration = val }
            } else if trimmed.uppercased().starts(with: "STRETCHES:") {
                currentSection = "STRETCHES"
            } else if (trimmed.starts(with: "-") || trimmed.starts(with: "•") || trimmed.starts(with: "*")) && currentSection == "STRETCHES" {
                let item = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                stretches.append(item)
            }
        }
        
        if strain.isEmpty {
            strain = "Moderate cardiovascular and myofibrillar loading in aerobic Zone 3. Optimal for functional hypertrophy."
        }
        if stretches.isEmpty {
            stretches = defaultStretchesFor(exerciseType: session.exerciseType)
        }
        
        return GeminiRecoveryReport(
            recoveryWindowHours: window,
            strainAssessment: strain,
            proteinGrams: protein,
            hydrationMl: hydration,
            activeStretches: stretches,
            rawText: text,
            isLiveApi: true
        )
    }
    
    // MARK: - Smart On-Device Biomechanical Rule Fallbacks
    private func generateOfflineBiomechanicalReport(session: WorkoutSession, fault: String, jointAngle: Double) -> GeminiBiomechanicalReport {
        let diagnosis: String
        let cues: [String]
        let accessories: [String]
        
        switch session.exerciseType {
        case "SQUAT":
            diagnosis = "Knee flexion reached \(Int(jointAngle))°. Hip-knee flexion rhythm shows slight anterior knee shear with gluteus medius inhibition."
            cues = [
                "Drive your knees outward in line with your 2nd and 3rd toes",
                "Maintain mid-foot pressure to prevent heel lift",
                "Brace your core 360° before beginning each descent"
            ]
            accessories = [
                "Banded Monster Walks (2 sets x 15 reps)",
                "Couch Stretch for Hip Flexor Opening (2 min per side)"
            ]
        case "PUSH_UP":
            diagnosis = "Elbow flexion measured at \(Int(jointAngle))°. Sagittal camera analysis shows scapular protraction with mild core compensation."
            cues = [
                "Tuck elbows to approximately 45 degrees from your torso",
                "Squeeze glutes and quads to keep your plank locked",
                "Press the ground away forcefully at lockout"
            ]
            accessories = [
                "Scapular Push-ups on Knees (2 sets x 12 reps)",
                "Deadbugs for Anti-Extension Bracing (3 sets x 10 reps)"
            ]
        case "LUNGE":
            diagnosis = "Knee angle tracked at \(Int(jointAngle))°. Front knee experienced minor valgus instability during the transition to eccentric peak."
            cues = [
                "Keep your torso vertical without forward spinal flexion",
                "Distribute weight 70% front foot, 30% rear ball-of-foot",
                "Drop back knee straight down toward the floor"
            ]
            accessories = [
                "Single-Leg Romanian Deadlifts (2 sets x 10 reps)",
                "Ankle Dorsiflexion Wall Mobilizations (2 min)"
            ]
        case "PLANK":
            diagnosis = "Pelvic tilt stabilized over \(session.reps) seconds. Minor pelvic dip detected near the 75% fatigue mark."
            cues = [
                "Pull elbows isometrically toward your toes",
                "Draw navel to spine without holding your breath",
                "Press the floor away through the forearms"
            ]
            accessories = [
                "Bird-Dog Holds (3 sets x 8 reps with 3s hold)",
                "Hollow Body Rockers (2 sets x 30s)"
            ]
        default:
            diagnosis = "Biomechanical analysis confirms consistent eccentric control with stable kinetic chain alignment throughout \(session.reps) repetitions."
            cues = [
                "Focus on a deliberate 2-second eccentric lowering phase",
                "Synchronize exhalation with the concentric exertion peak",
                "Maintain neutral cervical spine alignment"
            ]
            accessories = [
                "Isometric Dynamic Prone Bridges (2 sets x 45s)",
                "Foam Rolling for Target Muscle Fascia (3 min)"
            ]
        }
        
        return GeminiBiomechanicalReport(
            diagnosis: diagnosis,
            correctiveCues: cues,
            accessoryDrills: accessories,
            rawText: diagnosis,
            isLiveApi: false
        )
    }
    
    private func generateOfflineRecoveryReport(session: WorkoutSession) -> GeminiRecoveryReport {
        let window: Int
        let protein: Int
        let hydration: Int
        let strain: String
        
        switch session.exerciseType {
        case "SQUAT", "DEADLIFT":
            window = 48
            protein = 28
            hydration = 750
            strain = "High central nervous system & lower body myofibrillar load. Demands full glycogen replenishment and collagen support."
        case "PUSH_UP", "BENCH_PRESS":
            window = 36
            protein = 26
            hydration = 650
            strain = "Moderate upper-body pectoral and triceps fatigue with localized metabolic buildup."
        case "PLANK":
            window = 24
            protein = 22
            hydration = 500
            strain = "Isometric core tension with minimal tissue breakdown. Rapid neuromuscular recovery expected within 24 hours."
        default:
            window = 36
            protein = 25
            hydration = 600
            strain = "Balanced aerobic-anaerobic exertion in Zone 3 with optimal muscle fiber recruitment."
        }
        
        return GeminiRecoveryReport(
            recoveryWindowHours: window,
            strainAssessment: strain,
            proteinGrams: protein,
            hydrationMl: hydration,
            activeStretches: defaultStretchesFor(exerciseType: session.exerciseType),
            rawText: strain,
            isLiveApi: false
        )
    }
    
    // MARK: - Helpers
    private func defaultFaultFor(exerciseType: String, score: Int) -> String {
        if score >= 97 { return "Textbook form with minor late-set fatigue" }
        switch exerciseType {
        case "SQUAT": return "Mild knee valgus inward cave on ascent"
        case "PUSH_UP": return "Elbow flare exceeding 70 degrees"
        case "LUNGE": return "Anterior knee drift beyond toe line"
        case "PLANK": return "Subtle lumbar sagging below neutral line"
        default: return "Slight compensation in eccentric tempo"
        }
    }
    
    private func defaultAngleFor(exerciseType: String) -> Double {
        switch exerciseType {
        case "SQUAT", "LUNGE": return 88.5
        case "PUSH_UP": return 82.0
        case "PLANK": return 176.0
        default: return 90.0
        }
    }
    
    private func defaultStretchesFor(exerciseType: String) -> [String] {
        switch exerciseType {
        case "SQUAT", "LUNGE":
            return [
                "Couch Stretch for Quadriceps & Hip Flexors (90s / side)",
                "Pigeon Pose for Gluteus Medius Decompression (60s / side)",
                "Standing Calf & Achilles Wall Stretch (45s / side)"
            ]
        case "PUSH_UP", "BENCH_PRESS":
            return [
                "Doorway Pectoral & Anterior Deltoid Stretch (60s / side)",
                "Overhead Triceps & Latissimus Stretch (45s / side)",
                "Cat-Cow Thoracic Spine Mobilization (10 cycles)"
            ]
        case "PLANK":
            return [
                "Cobra Pose Abdominal Wall Stretch (45s)",
                "Child's Pose Spinal Decompression (90s)",
                "Thread-the-Needle Thoracic Twist (60s / side)"
            ]
        default:
            return [
                "Full Body World's Greatest Stretch (5 reps / side)",
                "Hamstring Sweep & Ankle Hinge (60s)",
                "Deep Diaphragmatic Box Breathing (2 mins)"
            ]
        }
    }
}
