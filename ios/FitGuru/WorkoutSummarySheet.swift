import SwiftUI

// MARK: - Post-Workout Summary & Gemini Biomechanical Analysis Sheet
struct WorkoutSummarySheet: View {
    let session: WorkoutSession
    let primaryFault: String
    let jointAngle: Double
    let onDismiss: () -> Void
    
    @ObservedObject private var gemini = GeminiService.shared
    @ObservedObject private var elevenLabs = ElevenLabsService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var biomechanicalReport: GeminiBiomechanicalReport? = nil
    @State private var recoveryReport: GeminiRecoveryReport? = nil
    @State private var isLoading: Bool = true
    @State private var isSpeaking: Bool = false
    @State private var recordedWeightKg: Double = 0.0
    
    init(
        session: WorkoutSession,
        primaryFault: String = "",
        jointAngle: Double = 0.0,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.session = session
        self.primaryFault = primaryFault
        self.jointAngle = jointAngle
        self.onDismiss = onDismiss
        self._recordedWeightKg = State(initialValue: session.weightKg)
    }
    
    private var progressiveTargetText: String {
        if recordedWeightKg > 0 {
            let nextWeight = recordedWeightKg + 2.5
            let formattedNext = nextWeight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(nextWeight))" : String(format: "%.1f", nextWeight)
            let formattedCurrent = recordedWeightKg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(recordedWeightKg))" : String(format: "%.1f", recordedWeightKg)
            return "Target: \(formattedNext) kg × \(session.reps) reps OR \(formattedCurrent) kg × \(session.reps + 2) reps"
        } else {
            return "Target: \(session.reps + 2) reps with solid form"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                FitTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. Hero Achievement Header
                        VStack(spacing: 8) {
                            HStack {
                                Spacer()
                                VStack(spacing: 6) {
                                    Text("🎉")
                                        .font(.system(size: 42))
                                    Text("Workout Complete!")
                                        .font(.system(size: 24, weight: .heavy))
                                        .foregroundColor(FitTheme.textPrimary)
                                    Text("\(session.exerciseName) session recorded with on-device telemetry")
                                        .font(.system(size: 13))
                                        .foregroundColor(FitTheme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(.top, 12)
                        
                        // 2. Performance Metrics Grid (Reps, Form, Weight, Volume, Calories, Heart Rate)
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                SummaryStatBox(icon: "💪", title: "TOTAL REPS", value: "\(session.reps)")
                                SummaryStatBox(icon: "🎯", title: "FORM SCORE", value: "\(session.score)%")
                            }
                            HStack(spacing: 10) {
                                SummaryStatBox(
                                    icon: "⚖️",
                                    title: "WEIGHT LIFTED",
                                    value: recordedWeightKg > 0 ? "\(Int(recordedWeightKg)) kg" : "Bodyweight"
                                )
                                SummaryStatBox(
                                    icon: "📊",
                                    title: "TOTAL VOLUME",
                                    value: recordedWeightKg > 0 ? "\(Int(recordedWeightKg * Double(session.reps))) kg" : "\(session.reps) Reps"
                                )
                            }
                            HStack(spacing: 10) {
                                SummaryStatBox(icon: "🔥", title: "CALORIES", value: "\(session.calories) kcal")
                                SummaryStatBox(icon: "❤️", title: "AVG HEART RATE", value: "\(session.avgHeartRate) BPM")
                            }
                        }
                        
                        // 3. Progressive Overload & Weight Stepper Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("🎯")
                                        .font(.system(size: 16))
                                    Text("PROGRESSIVE OVERLOAD TARGET")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(FitTheme.accentLime)
                                        .tracking(0.8)
                                }
                                Spacer()
                                Text("NEXT SESSION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(4)
                            }
                            
                            Text(progressiveTargetText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Weight Adjustment Stepper
                            HStack(spacing: 12) {
                                Text("Adjust Weight Lifted:")
                                    .font(.system(size: 12))
                                    .foregroundColor(FitTheme.textSecondary)
                                Spacer()
                                Button(action: {
                                    if recordedWeightKg >= 2.5 {
                                        recordedWeightKg -= 2.5
                                    }
                                }) {
                                    Text("-2.5kg")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                Text(recordedWeightKg > 0 ? "\(Int(recordedWeightKg)) kg" : "BW")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundColor(FitTheme.accentLime)
                                    .frame(minWidth: 44)
                                Button(action: {
                                    recordedWeightKg += 2.5
                                }) {
                                    Text("+2.5kg")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(14)
                        .background(FitTheme.cardBackground)
                        .cornerRadius(FitTheme.radiusMedium)
                        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.accentLime.opacity(0.3), lineWidth: 1))
                        
                        // 3. Audio Narration Action Bar (Gemini + ElevenLabs Bridge)
                        HStack(spacing: 12) {
                            Button(action: {
                                if isSpeaking {
                                    elevenLabs.stop()
                                    isSpeaking = false
                                } else {
                                    speakGeminiSummary()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(isSpeaking ? "⏹" : "🎙️")
                                        .font(.system(size: 16))
                                    Text(isSpeaking ? "Stop Voice Coach" : "Listen to \(elevenLabs.selectedPersona.displayName) Read Summary")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(FitTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(FitTheme.accentLime)
                                .cornerRadius(FitTheme.radiusSmall)
                            }
                        }
                        
                        // 4. Gemini Biomechanical Analysis Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("✨")
                                        .font(.system(size: 16))
                                    Text("GEMINI BIOMECHANICAL ANALYSIS")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(FitTheme.accentLime)
                                        .tracking(1.0)
                                }
                                Spacer()
                                Text(gemini.isKeyConfigured ? "GEMINI 2.5 FLASH" : "ON-DEVICE COGNITIVE")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(FitTheme.accentLime)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FitTheme.accentLime.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            if isLoading {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(FitTheme.accentLime)
                                    Text("Gemini is analyzing multi-joint kinematics...")
                                        .font(.system(size: 13))
                                        .foregroundColor(FitTheme.textSecondary)
                                }
                                .padding(.vertical, 14)
                            } else if let report = biomechanicalReport {
                                // Kinematic Diagnosis
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Kinematic Breakdown:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(FitTheme.textPrimary)
                                    Text(report.diagnosis)
                                        .font(.system(size: 13))
                                        .foregroundColor(FitTheme.textSecondary)
                                        .lineSpacing(3)
                                }
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                // Corrective Motor Cues
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Personalized Corrective Cues:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(FitTheme.textPrimary)
                                    
                                    ForEach(report.correctiveCues, id: \.self) { cue in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("➔")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(FitTheme.accentLime)
                                            Text(cue)
                                                .font(.system(size: 12))
                                                .foregroundColor(FitTheme.textPrimary)
                                        }
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                // Accessory Drills
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Prescribed Accessory Drills:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(FitTheme.textPrimary)
                                    
                                    ForEach(report.accessoryDrills, id: \.self) { drill in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("🦾")
                                                .font(.system(size: 12))
                                            Text(drill)
                                                .font(.system(size: 12))
                                                .foregroundColor(FitTheme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(FitTheme.cardBackground)
                        .cornerRadius(FitTheme.radiusMedium)
                        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                        
                        // 5. Gemini Recovery Summary Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("🔋")
                                        .font(.system(size: 16))
                                    Text("PERSONALIZED RECOVERY PLAN")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(Color.cyan)
                                        .tracking(1.0)
                                }
                                Spacer()
                                if let rec = recoveryReport {
                                    Text("\(rec.recoveryWindowHours)H REST")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(Color.cyan)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.cyan.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            
                            if let rec = recoveryReport {
                                // Strain & Recovery Window
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Physiological Strain:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(FitTheme.textPrimary)
                                    Text(rec.strainAssessment)
                                        .font(.system(size: 13))
                                        .foregroundColor(FitTheme.textSecondary)
                                        .lineSpacing(3)
                                }
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                // Nutrition & Hydration
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("🥩 Target Protein")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FitTheme.textSecondary)
                                        Text("\(rec.proteinGrams)g Whey / Plant")
                                            .font(.system(size: 14, weight: .heavy))
                                            .foregroundColor(FitTheme.textPrimary)
                                    }
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("💧 Hydration Target")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FitTheme.textSecondary)
                                        Text("\(rec.hydrationMl) ml + Electrolytes")
                                            .font(.system(size: 14, weight: .heavy))
                                            .foregroundColor(FitTheme.textPrimary)
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                // Active Mobility
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Prescribed Active Stretches:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(FitTheme.textPrimary)
                                    
                                    ForEach(rec.activeStretches, id: \.self) { stretch in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("🧘")
                                                .font(.system(size: 12))
                                            Text(stretch)
                                                .font(.system(size: 12))
                                                .foregroundColor(FitTheme.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(FitTheme.cardBackground)
                        .cornerRadius(FitTheme.radiusMedium)
                        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                        
                        // 6. Done / Return Button
                        Button(action: {
                            elevenLabs.stop()
                            onDismiss()
                            dismiss()
                        }) {
                            Text("Done • Return to Dashboard")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(FitTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FitTheme.accentLime)
                                .cornerRadius(FitTheme.radiusMedium)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 36)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        elevenLabs.stop()
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(FitTheme.accentLime)
                }
            }
            .onAppear {
                generateReports()
            }
        }
    }
    
    private func generateReports() {
        isLoading = true
        let group = DispatchGroup()
        
        group.enter()
        gemini.analyzeBiomechanicalForm(session: session, primaryFault: primaryFault, jointAngle: jointAngle) { report in
            self.biomechanicalReport = report
            group.leave()
        }
        
        group.enter()
        gemini.generateRecoverySummary(session: session) { report in
            self.recoveryReport = report
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func speakGeminiSummary() {
        guard let bio = biomechanicalReport, let rec = recoveryReport else { return }
        let summaryText = """
        Great effort on your \(session.exerciseName) session! You finished \(session.reps) repetitions with a \(session.score) percent form score.
        Here is your Gemini biomechanical breakdown: \(bio.diagnosis).
        For recovery: target \(rec.proteinGrams) grams of protein and \(rec.recoveryWindowHours) hours of rest. You've earned it!
        """
        
        isSpeaking = true
        elevenLabs.speak(text: summaryText) {
            self.isSpeaking = false
        }
    }
}

// MARK: - Summary Stat Box
struct SummaryStatBox: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(FitTheme.textSecondary)
                    .tracking(0.6)
            }
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(FitTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(FitTheme.cardBackground)
        .cornerRadius(FitTheme.radiusSmall)
        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusSmall).stroke(FitTheme.cardBorder, lineWidth: 1))
    }
}
