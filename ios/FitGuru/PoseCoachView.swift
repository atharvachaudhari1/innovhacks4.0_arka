import SwiftUI
import AVFoundation

// MARK: - Native Camera Preview Layer Wrapper
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let isFrontCamera: Bool
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if let connection = uiView.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isFrontCamera
        }
    }
}

class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Live AI Workout Coach Screen (fragment_camera.xml parity)
struct PoseCoachView: View {
    let exercise: ExerciseType
    @ObservedObject var store: WorkoutStore
    @StateObject private var poseEstimator = PoseEstimator()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSimulatorDrawer: Bool = false
    @State private var showVoiceSheet: Bool = false
    @State private var showSummarySheet: Bool = false
    @State private var showRestTimerSheet: Bool = false
    @State private var completedSession: WorkoutSession? = nil
    @State private var currentWeightKg: Double = 0.0
    @State private var workoutStartTime: Date = Date()
    @ObservedObject private var elevenLabs = ElevenLabsService.shared
    @ObservedObject private var voiceManager = VoiceCommandManager.shared
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 1. Live Camera Feed
                CameraPreviewView(session: poseEstimator.captureSession, isFrontCamera: poseEstimator.isFrontCamera)
                    .ignoresSafeArea()
                
                // 2. Real-time Skeleton Overlay
                Canvas { context, size in
                    // Draw Faint Bystanders in Background (Gym Multi-Person Shield)
                    for bystanderLines in poseEstimator.bystanderConnections {
                        for connection in bystanderLines {
                            let p1 = CGPoint(x: connection.from.point.x * size.width, y: connection.from.point.y * size.height)
                            let p2 = CGPoint(x: connection.to.point.x * size.width, y: connection.to.point.y * size.height)
                            
                            var path = Path()
                            path.move(to: p1)
                            path.addLine(to: p2)
                            context.stroke(path, with: .color(Color.gray.opacity(0.28)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        }
                    }
                    
                    // Draw Subtle Target Reticle Ring when Lifter is Locked
                    if let anchor = poseEstimator.lifterAnchorPoint, poseEstimator.isLifterLocked {
                        let center = CGPoint(x: anchor.x * size.width, y: anchor.y * size.height)
                        let rect = CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)
                        context.stroke(Path(ellipseIn: rect), with: .color(FitTheme.accentLime.opacity(0.35)), lineWidth: 1.5)
                    }
                    
                    // Draw Primary Lifter Bone Connections (Teal)
                    for connection in poseEstimator.connections {
                        let p1 = CGPoint(x: connection.from.point.x * size.width, y: connection.from.point.y * size.height)
                        let p2 = CGPoint(x: connection.to.point.x * size.width, y: connection.to.point.y * size.height)
                        
                        var path = Path()
                        path.move(to: p1)
                        path.addLine(to: p2)
                        context.stroke(path, with: .color(FitTheme.skeletonTeal), lineWidth: 4)
                    }
                    
                    // Draw Primary Lifter Joint Points (Yellow)
                    for (_, joint) in poseEstimator.joints {
                        let center = CGPoint(x: joint.point.x * size.width, y: joint.point.y * size.height)
                        let rect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)
                        context.fill(Path(ellipseIn: rect), with: .color(FitTheme.skeletonYellow))
                        context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.4)), lineWidth: 1)
                    }
                }
                .ignoresSafeArea()
                
                // 3. Complete Workout Overlay HUD (Unified, Non-overlapping, Responsive)
                VStack(spacing: 0) {
                    // TOP BAR: Navigation, Exercise Name, Mic, Timer & Finish
                    VStack(spacing: 8) {
                        // Row 1: Exercise Capsule & Primary Actions
                        HStack(spacing: 8) {
                            // Exercise Title Badge
                            HStack(spacing: 6) {
                                Text(exercise.icon)
                                    .font(.system(size: 16))
                                Text(exercise.displayName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(Capsule().stroke(FitTheme.cardBorder, lineWidth: 1))
                            )
                            .fixedSize(horizontal: true, vertical: false)
                            
                            Spacer()
                            
                            // Hands-Free Voice Command Mic Button
                            Button(action: {
                                voiceManager.toggleListening(store: store)
                            }) {
                                Image(systemName: (voiceManager.isListening || voiceManager.isEnabled) ? "waveform" : "mic.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor((voiceManager.isListening || voiceManager.isEnabled) ? .red : FitTheme.accentLime)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.75))
                                            .overlay(Circle().stroke((voiceManager.isListening || voiceManager.isEnabled) ? Color.red.opacity(0.8) : Color.white.opacity(0.25), lineWidth: 1))
                                    )
                            }
                            
                            // Smart Rest Timer HUD Button
                            Button(action: {
                                showRestTimerSheet = true
                            }) {
                                Text("⏱️")
                                    .font(.system(size: 14))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.75))
                                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                    )
                            }
                            
                            // Finish Workout Button
                            Button(action: {
                                completeWorkout()
                            }) {
                                HStack(spacing: 4) {
                                    Text("Finish")
                                        .font(.system(size: 13, weight: .bold))
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(FitTheme.textOnAccent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(FitTheme.accentLime)
                                .cornerRadius(FitTheme.radiusSmall)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // Row 2: Secondary Settings (Voice Persona, Weight Selector, State Indicator)
                        HStack(spacing: 8) {
                            // ElevenLabs AI Voice Coach Selector
                            Button(action: {
                                showVoiceSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Text("🎙️")
                                        .font(.system(size: 11))
                                    Text(elevenLabs.selectedPersona.displayName)
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.75))
                                        .overlay(Capsule().stroke(FitTheme.accentLime.opacity(0.5), lineWidth: 1))
                                )
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            
                            // Weight / Load Selector Pill
                            Menu {
                                Button("Bodyweight (0 kg)") { currentWeightKg = 0.0 }
                                Divider()
                                ForEach([5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 120.0, 140.0], id: \.self) { w in
                                    Button("\(Int(w)) kg") { currentWeightKg = w }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text("⚖️")
                                        .font(.system(size: 10))
                                    Text(currentWeightKg > 0 ? "\(Int(currentWeightKg)) kg" : "BW")
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 7))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.75))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                )
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            
                            Spacer()
                            
                            // Workout State & Bystander Shield Pill
                            HStack(spacing: 6) {
                                Text(poseEstimator.workoutState)
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundColor(poseEstimator.isStepBackNeeded ? .yellow : FitTheme.accentLime)
                                    .lineLimit(1)
                                
                                if poseEstimator.isOccludedHolding {
                                    HStack(spacing: 3) {
                                        Image(systemName: "hand.raised.fill")
                                            .font(.system(size: 9))
                                        Text("HOLD")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundColor(.orange)
                                } else if poseEstimator.gymBystanderCount > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 9))
                                        Text("SHIELD (\(poseEstimator.gymBystanderCount))")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundColor(FitTheme.skeletonTeal)
                                } else if poseEstimator.isLifterLocked {
                                    HStack(spacing: 3) {
                                        Image(systemName: "scope")
                                            .font(.system(size: 9))
                                        Text("LOCKED")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundColor(FitTheme.accentLime)
                                }
                                
                                // Quick Re-lock Button
                                Button(action: {
                                    poseEstimator.resetSubjectLock()
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(Capsule().stroke(poseEstimator.isStepBackNeeded ? Color.yellow.opacity(0.6) : FitTheme.accentLime.opacity(0.4), lineWidth: 1))
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // Voice Command Live Feedback Banner
                        if let cmd = voiceManager.lastCommandDetected {
                            HStack(spacing: 6) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(FitTheme.accentLime)
                                Text("Heard: '\(cmd)'")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.88))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FitTheme.accentLime, lineWidth: 1))
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(geo.safeAreaInsets.top, 52))
                    
                    // MIDDLE LEFT: Vital Telemetry HUD (Heart Rate, Reps, Joint Angles)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            // Heart Rate
                            HStack(spacing: 5) {
                                Text("❤️")
                                    .font(.system(size: 12))
                                Text("\(store.currentHeartRate) BPM")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            )
                            .fixedSize(horizontal: true, vertical: false)
                            
                            // Reps Counter
                            HStack(spacing: 6) {
                                Text("REPS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(FitTheme.textSecondary)
                                Text("\(poseEstimator.repCount)")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(FitTheme.accentLime)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            )
                            .fixedSize(horizontal: true, vertical: false)
                            
                            // Joint Telemetry
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text("\(exercise.primaryAngleName):")
                                        .font(.system(size: 11))
                                        .foregroundColor(FitTheme.textSecondary)
                                    Text("\(Int(poseEstimator.currentAngle))°")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FitTheme.accentLime)
                                }
                                if exercise == .squat || exercise == .pushup {
                                    HStack(spacing: 4) {
                                        Text("Hip Angle:")
                                            .font(.system(size: 11))
                                            .foregroundColor(FitTheme.textSecondary)
                                        Text("\(Int(poseEstimator.secondaryAngle))°")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FitTheme.accentLime)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.75))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.14), lineWidth: 1))
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // BOTTOM: AI Real-Time Feedback Banner & Controls
                    VStack(spacing: 10) {
                        // AI Voice Feedback Banner
                        HStack(spacing: 10) {
                            Text("💡")
                                .font(.system(size: 18))
                            Text(poseEstimator.aiFeedback)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: FitTheme.radiusMedium)
                                .fill(Color(red: 9/255, green: 9/255, blue: 11/255).opacity(0.92))
                                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                        )
                        .padding(.horizontal, 16)
                        
                        // Control Row (GenAI, Voice, Flip Cam)
                        HStack(spacing: 8) {
                            // GenAI Button
                            Button(action: {
                                poseEstimator.isGenAiEnabled.toggle()
                            }) {
                                HStack(spacing: 5) {
                                    Text("✨")
                                    Text(poseEstimator.isGenAiEnabled ? "GenAI (ON)" : "GenAI (OFF)")
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                }
                                .foregroundColor(poseEstimator.isGenAiEnabled ? FitTheme.textOnAccent : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(poseEstimator.isGenAiEnabled ? FitTheme.accentLime : FitTheme.cardBackground)
                                .cornerRadius(FitTheme.radiusSmall)
                            }
                            
                            // Voice Coach Button
                            Button(action: {
                                poseEstimator.isVoiceEnabled.toggle()
                            }) {
                                HStack(spacing: 5) {
                                    Text(poseEstimator.isVoiceEnabled ? "🔊" : "🔇")
                                    Text(poseEstimator.isVoiceEnabled ? "Voice: ON" : "Voice: OFF")
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                }
                                .foregroundColor(poseEstimator.isVoiceEnabled ? FitTheme.textOnAccent : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(poseEstimator.isVoiceEnabled ? FitTheme.accentLime : FitTheme.cardBackground)
                                .cornerRadius(FitTheme.radiusSmall)
                            }
                            
                            // Flip Camera Button
                            Button(action: {
                                poseEstimator.flipCamera()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "camera.rotate.fill")
                                        .font(.system(size: 11))
                                    Text("Flip Cam")
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(FitTheme.cardBackground)
                                .cornerRadius(FitTheme.radiusSmall)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Interactive Test Mode Simulator Bar
                        VStack(spacing: 8) {
                            HStack {
                                Text("🧪 Test Simulator (No camera needed):")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(FitTheme.textSecondary)
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        showSimulatorDrawer.toggle()
                                    }
                                }) {
                                    Text(showSimulatorDrawer ? "Hide" : "Show")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FitTheme.accentLime)
                                }
                            }
                            
                            if showSimulatorDrawer {
                                HStack(spacing: 8) {
                                    Button(action: {
                                        poseEstimator.runSimulatorRep()
                                    }) {
                                        Text("✅ Do 1 Rep")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FitTheme.textOnAccent)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(FitTheme.accentLime)
                                            .cornerRadius(8)
                                    }
                                    
                                    Button(action: {
                                        poseEstimator.toggleAutoRunSimulator()
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(poseEstimator.isSimulatorRunning ? "⏸ Stop" : "▶ Auto Run")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(FitTheme.cardBackground)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(FitTheme.accentLime.opacity(0.4), lineWidth: 1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(FitTheme.radiusSmall)
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                    }
                }
            }
        }
        .sheet(isPresented: $showVoiceSheet) {
            VoiceSettingsSheet()
        }
        .sheet(isPresented: $showRestTimerSheet) {
            SmartRestTimerSheet(store: store)
        }
        .sheet(isPresented: $showSummarySheet, onDismiss: {
            dismiss()
        }) {
            if let session = completedSession {
                WorkoutSummarySheet(
                    session: session,
                    primaryFault: poseEstimator.workoutState,
                    jointAngle: poseEstimator.currentAngle,
                    onDismiss: {
                        dismiss()
                    }
                )
            }
        }
        .onReceive(store.$requestFinishActiveWorkout) { shouldFinish in
            if shouldFinish {
                store.requestFinishActiveWorkout = false
                completeWorkout()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SiriCommandBridge.finishSetNotification)) { _ in
            completeWorkout()
        }
        .onReceive(store.$isShowingRestTimer) { show in
            if show {
                store.isShowingRestTimer = false
                showRestTimerSheet = true
            }
        }
        .onAppear {
            workoutStartTime = Date()
            store.requestFinishActiveWorkout = false
            currentWeightKg = store.defaultWeight(for: exercise)
            poseEstimator.start(exercise: exercise)
            
            // Connect store to voice manager & ensure hands-free listening is active
            voiceManager.currentStore = store
            voiceManager.isEnabled = true
            voiceManager.ensureListening(store: store)
        }
        .onDisappear {
            poseEstimator.stop()
            voiceManager.currentStore = store
            if voiceManager.isEnabled {
                voiceManager.ensureListening(store: store)
            }
        }
    }
    
    private func completeWorkout() {
        guard completedSession == nil else { return }
        let session = store.addSession(type: exercise, reps: poseEstimator.repCount, score: 98, weightKg: currentWeightKg)
        poseEstimator.stop()
        completedSession = session
        showSummarySheet = true
    }
}
