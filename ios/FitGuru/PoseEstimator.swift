import SwiftUI
import AVFoundation
import Vision
import Speech

// MARK: - Recognized Skeleton Joint
struct PoseJoint: Identifiable {
    var id: String
    var point: CGPoint // Normalized (0...1, 0...1) in screen coordinates
    var confidence: Float
}

// MARK: - Skeleton Connection Line
struct PoseConnection: Identifiable {
    var id: String { "\(from.id)-\(to.id)" }
    var from: PoseJoint
    var to: PoseJoint
}

// MARK: - Candidate Body Representation (Gym Multi-Person Tracking)
struct CandidateSubject {
    let observation: VNHumanBodyPoseObservation
    let center: CGPoint
    let torsoHeight: CGFloat
    let confidence: Float
    let jointCount: Int
    let prominence: CGFloat
}

// MARK: - Pose Estimator & Real-Time Biomechanics Engine
class PoseEstimator: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var joints: [String: PoseJoint] = [:]
    @Published var connections: [PoseConnection] = []
    
    // Gym Multi-Person Shield & Lifter Lock
    @Published var isLifterLocked: Bool = false
    @Published var gymBystanderCount: Int = 0
    @Published var isOccludedHolding: Bool = false
    @Published var lifterAnchorPoint: CGPoint? = nil
    @Published var bystanderConnections: [[PoseConnection]] = []
    
    // Workout Telemetry
    @Published var repCount: Int = 0
    @Published var currentAngle: Double = 175.0
    @Published var secondaryAngle: Double = 178.0
    @Published var workoutState: String = "READY"
    @Published var aiFeedback: String = "Position yourself in full view of the camera"
    @Published var isAiThinking: Bool = false
    @Published var isStepBackNeeded: Bool = false
    
    // Settings
    @Published var isGenAiEnabled: Bool = true
    @Published var isVoiceEnabled: Bool = true
    @Published var isFrontCamera: Bool = true
    
    // Gym Subject Lock State Machine
    private var lockedSubjectCenter: CGPoint? = nil
    private var lockedTorsoHeight: CGFloat = 0.0
    private var lockConfirmFrames: Int = 0
    private var occlusionFrames: Int = 0
    private let maxOcclusionGraceFrames: Int = 45 // ~1.5s @ 30 FPS hold
    private let maxJumpDistance: CGFloat = 0.35 // Max plausible body jump in screen space
    
    // Camera Engine
    // Camera Engine
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let visionQueue = DispatchQueue(label: "com.innovhacks.fitguru.vision", qos: .userInteractive)
    
    // Speech Synthesizer
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastSpeechTime: Date = Date.distantPast
    
    // Rep Machine State & Biomechanics Filters
    var currentExercise: ExerciseType = .squat
    private var stateMachineState: String = "calibrating"
    private var lastRepTime: Date = Date.distantPast
    private var plankTimer: Timer?
    private var plankSeconds: Int = 0
    
    // Calibration & Stability Filtering
    private var isCalibrated: Bool = false
    private var standingFrames: Int = 0
    private var inflectionFrames: Int = 0
    private var baselineStandingHipY: CGFloat = 0.0
    private var smoothedAngle1: Double = 180.0
    private var smoothedAngle2: Double = 180.0
    private let minRepCycleDuration: TimeInterval = 0.95
    
    // Simulator Mode
    @Published var isSimulatorRunning: Bool = false
    private var simAngleProgress: Double = 0.0
    private var simTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
        setupCamera()
    }
    
    func start(exercise: ExerciseType) {
        currentExercise = exercise
        repCount = 0
        stateMachineState = "calibrating"
        isCalibrated = false
        standingFrames = 0
        inflectionFrames = 0
        baselineStandingHipY = 0.0
        smoothedAngle1 = 180.0
        smoothedAngle2 = 180.0
        lastRepTime = Date.distantPast
        resetSubjectLock()
        
        switch exercise {
        case .pushup:
            workoutState = "GET IN PLANK"
            aiFeedback = "Place phone and get into a horizontal plank position on the floor"
            speak("Get in a plank position on the floor to begin.")
        case .plank:
            workoutState = "HOLD PLANK ON FLOOR"
            aiFeedback = "Hold a straight horizontal plank on the floor"
            speak("Get into plank position on the floor.")
        case .squat, .lunge, .deadlift:
            workoutState = "STAND UP TO START"
            aiFeedback = "Stand upright in front of camera to calibrate starting posture"
            speak("Stand up straight to calibrate.")
        case .bicepCurl:
            workoutState = "EXTEND ARMS DOWN"
            aiFeedback = "Stand facing camera with your arms extended down at your sides"
            speak("Stand with arms down to begin.")
        default:
            workoutState = "GET READY"
            aiFeedback = "Position yourself in camera view for \(exercise.displayName) coaching!"
            speak("Starting \(exercise.displayName) session. Get ready!")
        }
        
        if exercise == .plank {
            plankSeconds = 0
            startPlankTimer()
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() {
        stopPlankTimer()
        stopSimulator()
        resetSubjectLock()
        ElevenLabsService.shared.stop()
        speechSynthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func resetSubjectLock() {
        lockedSubjectCenter = nil
        lockedTorsoHeight = 0.0
        lockConfirmFrames = 0
        occlusionFrames = 0
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLifterLocked = false
            self.gymBystanderCount = 0
            self.isOccludedHolding = false
            self.lifterAnchorPoint = nil
            self.bystanderConnections = []
        }
    }
    
    // MARK: - Camera Setup
    private func setupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.configureCaptureSession()
                    }
                }
            }
        default:
            configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func flipCamera() {
        isFrontCamera.toggle()
        configureCaptureSession()
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & Gym Multi-Person Shield
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isSimulatorRunning else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let orientation: CGImagePropertyOrientation = isFrontCamera ? .leftMirrored : .right
        let request = VNDetectHumanBodyPoseRequest()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
            guard let observations = request.results, !observations.isEmpty else {
                handleLostSubject()
                return
            }
            
            // 1. Evaluate all detected human bodies in frame
            let candidates = observations.compactMap { evaluateCandidate(observation: $0) }
            guard !candidates.isEmpty else {
                handleLostSubject()
                return
            }
            
            // 2. Select Primary Lifter vs Bystanders
            let (selectedLifter, bystanders) = matchPrimaryLifter(candidates: candidates)
            
            // 3. Process selected lifter or hold state during passerby occlusion
            if let lifter = selectedLifter {
                processVisionObservation(lifter.observation, bystanders: bystanders)
            } else {
                handleOcclusionHold(bystanderCount: candidates.count)
            }
        } catch {
            print("Vision error: \(error)")
        }
    }
    
    // MARK: - Candidate Body Evaluation (Torso Center, Scale & Prominence)
    private func evaluateCandidate(observation: VNHumanBodyPoseObservation) -> CandidateSubject? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        
        var totalX: CGFloat = 0.0
        var totalY: CGFloat = 0.0
        var validCount = 0
        var confSum: Float = 0.0
        
        // Key landmark points
        var hipCenter: CGPoint? = nil
        var shoulderCenter: CGPoint? = nil
        
        let leftHip = points[.leftHip]
        let rightHip = points[.rightHip]
        if let lh = leftHip, let rh = rightHip, lh.confidence > 0.15, rh.confidence > 0.15 {
            hipCenter = CGPoint(x: (lh.location.x + rh.location.x) / 2.0, y: 1.0 - ((lh.location.y + rh.location.y) / 2.0))
        }
        
        let leftShoulder = points[.leftShoulder]
        let rightShoulder = points[.rightShoulder]
        if let ls = leftShoulder, let rs = rightShoulder, ls.confidence > 0.15, rs.confidence > 0.15 {
            shoulderCenter = CGPoint(x: (ls.location.x + rs.location.x) / 2.0, y: 1.0 - ((ls.location.y + rs.location.y) / 2.0))
        }
        
        for (_, pt) in points {
            guard pt.confidence > 0.15 else { continue }
            totalX += pt.location.x
            totalY += (1.0 - pt.location.y)
            confSum += pt.confidence
            validCount += 1
        }
        
        guard validCount >= 4 else { return nil }
        
        let center: CGPoint
        let torsoHeight: CGFloat
        
        if let h = hipCenter, let s = shoulderCenter {
            center = CGPoint(x: (h.x + s.x) / 2.0, y: (h.y + s.y) / 2.0)
            torsoHeight = max(0.08, hypot(h.x - s.x, h.y - s.y))
        } else if let h = hipCenter {
            center = h
            torsoHeight = 0.22
        } else if let s = shoulderCenter {
            center = s
            torsoHeight = 0.22
        } else {
            center = CGPoint(x: totalX / CGFloat(validCount), y: totalY / CGFloat(validCount))
            torsoHeight = 0.20
        }
        
        let avgConf = confSum / Float(validCount)
        
        // Prominence score: closer users (larger torsoHeight) and more centered users get priority
        let centerDist = hypot(center.x - 0.5, center.y - 0.5)
        let centralityScore = max(0.0, 1.0 - centerDist * 1.4)
        let prominence = (torsoHeight * 2.0) + (centralityScore * 1.0) + CGFloat(avgConf * 0.5)
        
        return CandidateSubject(
            observation: observation,
            center: center,
            torsoHeight: torsoHeight,
            confidence: avgConf,
            jointCount: validCount,
            prominence: prominence
        )
    }
    
    // MARK: - Primary Lifter vs Passerby / Bystander Matching
    private func matchPrimaryLifter(candidates: [CandidateSubject]) -> (CandidateSubject?, [CandidateSubject]) {
        guard let lockedCenter = lockedSubjectCenter, isLifterLocked else {
            // Initial Acquisition: Pick the most prominent subject (closest & centered)
            guard let best = candidates.max(by: { $0.prominence < $1.prominence }) else {
                return (nil, [])
            }
            
            lockConfirmFrames += 1
            if lockConfirmFrames >= 5 {
                lockedSubjectCenter = best.center
                lockedTorsoHeight = best.torsoHeight
                DispatchQueue.main.async { [weak self] in
                    self?.isLifterLocked = true
                    self?.lifterAnchorPoint = best.center
                }
            }
            let others = candidates.filter { $0.observation !== best.observation }
            return (best, others)
        }
        
        // Tracking Mode: Match candidate closest to locked anchor & scale
        var bestMatch: CandidateSubject? = nil
        var lowestCost: CGFloat = .greatestFiniteMagnitude
        
        for candidate in candidates {
            let dist = hypot(candidate.center.x - lockedCenter.x, candidate.center.y - lockedCenter.y)
            let scaleDiff = abs(candidate.torsoHeight - lockedTorsoHeight) / max(0.05, lockedTorsoHeight)
            let cost = dist + (scaleDiff * 0.4)
            
            if cost < lowestCost {
                lowestCost = cost
                bestMatch = candidate
            }
        }
        
        // Check if best match is within plausible human movement limits
        if let match = bestMatch, lowestCost < maxJumpDistance {
            // Successful match: Smoothly update anchor (Exponential Moving Average)
            let updatedCenter = CGPoint(
                x: lockedCenter.x * 0.82 + match.center.x * 0.18,
                y: lockedCenter.y * 0.82 + match.center.y * 0.18
            )
            let updatedHeight = lockedTorsoHeight * 0.85 + match.torsoHeight * 0.15
            self.lockedSubjectCenter = updatedCenter
            self.lockedTorsoHeight = updatedHeight
            self.occlusionFrames = 0
            
            let others = candidates.filter { $0.observation !== match.observation }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isOccludedHolding = false
                self.gymBystanderCount = others.count
                self.lifterAnchorPoint = updatedCenter
            }
            return (match, others)
        } else {
            // No plausible match: Lifter is temporarily blocked by passerby!
            occlusionFrames += 1
            if occlusionFrames <= maxOcclusionGraceFrames {
                // OCCLUSION HOLD: Gracefully hold state without disruption
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isOccludedHolding = true
                    self.gymBystanderCount = candidates.count
                }
                return (nil, candidates)
            } else {
                // Lifter has genuinely stepped away for > 1.5s; reset lock to re-acquire
                self.lockedSubjectCenter = nil
                self.isLifterLocked = false
                self.lockConfirmFrames = 0
                self.occlusionFrames = 0
                guard let fallback = candidates.max(by: { $0.prominence < $1.prominence }) else {
                    return (nil, [])
                }
                let others = candidates.filter { $0.observation !== fallback.observation }
                return (fallback, others)
            }
        }
    }
    
    // MARK: - Occlusion & Lost Subject Handlers
    private func handleOcclusionHold(bystanderCount: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isOccludedHolding = true
            self.gymBystanderCount = bystanderCount
        }
    }
    
    private func handleLostSubject() {
        occlusionFrames += 1
        if occlusionFrames > maxOcclusionGraceFrames {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.joints = [:]
                self.connections = []
                self.bystanderConnections = []
                self.isOccludedHolding = false
                self.gymBystanderCount = 0
                self.isLifterLocked = false
                self.lifterAnchorPoint = nil
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isOccludedHolding = true
            }
        }
    }
    
    // MARK: - Landmark & Biomechanics Processing
    private func processVisionObservation(_ observation: VNHumanBodyPoseObservation, bystanders: [CandidateSubject]) {
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)
            var newJoints: [String: PoseJoint] = [:]
            
            // Vision coordinates: origin is bottom-left (0,0).
            // SwiftUI coordinates: origin is top-left (0,0).
            // Convert y: 1.0 - visionPoint.y
            for (key, point) in recognizedPoints {
                guard point.confidence > 0.15 else { continue }
                let screenX = point.location.x
                let screenY = 1.0 - point.location.y
                newJoints[key.rawValue.rawValue] = PoseJoint(
                    id: key.rawValue.rawValue,
                    point: CGPoint(x: screenX, y: screenY),
                    confidence: point.confidence
                )
            }
            
            // Build skeleton connections
            let pairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
                (.leftShoulder, .rightShoulder),
                (.leftShoulder, .leftElbow),
                (.leftElbow, .leftWrist),
                (.rightShoulder, .rightElbow),
                (.rightElbow, .rightWrist),
                (.leftShoulder, .leftHip),
                (.rightShoulder, .rightHip),
                (.leftHip, .rightHip),
                (.leftHip, .leftKnee),
                (.leftKnee, .leftAnkle),
                (.rightHip, .rightKnee),
                (.rightKnee, .rightAnkle),
                (.nose, .neck),
                (.neck, .leftShoulder),
                (.neck, .rightShoulder)
            ]
            
            var newConnections: [PoseConnection] = []
            for (j1, j2) in pairs {
                if let p1 = newJoints[j1.rawValue.rawValue],
                   let p2 = newJoints[j2.rawValue.rawValue],
                   p1.confidence > 0.3, p2.confidence > 0.3 {
                    newConnections.append(PoseConnection(from: p1, to: p2))
                }
            }
            
            // Build faint skeleton connections for bystanders (Gym Multi-Person Visualization)
            var newBystanderConnections: [[PoseConnection]] = []
            for bystander in bystanders {
                if let bPoints = try? bystander.observation.recognizedPoints(.all) {
                    var bJoints: [String: PoseJoint] = [:]
                    for (k, pt) in bPoints {
                        guard pt.confidence > 0.2 else { continue }
                        bJoints[k.rawValue.rawValue] = PoseJoint(
                            id: k.rawValue.rawValue,
                            point: CGPoint(x: pt.location.x, y: 1.0 - pt.location.y),
                            confidence: pt.confidence
                        )
                    }
                    var lines: [PoseConnection] = []
                    for (j1, j2) in pairs {
                        if let b1 = bJoints[j1.rawValue.rawValue],
                           let b2 = bJoints[j2.rawValue.rawValue],
                           b1.confidence > 0.25, b2.confidence > 0.25 {
                            lines.append(PoseConnection(from: b1, to: b2))
                        }
                    }
                    if !lines.isEmpty {
                        newBystanderConnections.append(lines)
                    }
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.joints = newJoints
                self.connections = newConnections
                self.bystanderConnections = newBystanderConnections
                self.analyzeBiomechanics(joints: newJoints)
            }
        } catch {
            print("Pose extraction failed: \(error)")
        }
    }
    
    // MARK: - Real-Time Biomechanics & Rep Counting Pipeline
    private func smooth(current: inout Double, target: Double, alpha: Double = 0.35) -> Double {
        if current.isNaN || current == 0.0 || (current == 180.0 && target < 120.0) {
            current = target
        } else {
            current = (current * (1.0 - alpha)) + (target * alpha)
        }
        return current
    }

    private func analyzeBiomechanics(joints: [String: PoseJoint]) {
        // 1. Resolve Landmarks
        let leftShoulder = joints[VNHumanBodyPoseObservation.JointName.leftShoulder.rawValue.rawValue]
        let rightShoulder = joints[VNHumanBodyPoseObservation.JointName.rightShoulder.rawValue.rawValue]
        let leftElbow = joints[VNHumanBodyPoseObservation.JointName.leftElbow.rawValue.rawValue]
        let rightElbow = joints[VNHumanBodyPoseObservation.JointName.rightElbow.rawValue.rawValue]
        let leftWrist = joints[VNHumanBodyPoseObservation.JointName.leftWrist.rawValue.rawValue]
        let rightWrist = joints[VNHumanBodyPoseObservation.JointName.rightWrist.rawValue.rawValue]
        let leftHip = joints[VNHumanBodyPoseObservation.JointName.leftHip.rawValue.rawValue]
        let rightHip = joints[VNHumanBodyPoseObservation.JointName.rightHip.rawValue.rawValue]
        let leftKnee = joints[VNHumanBodyPoseObservation.JointName.leftKnee.rawValue.rawValue]
        let rightKnee = joints[VNHumanBodyPoseObservation.JointName.rightKnee.rawValue.rawValue]
        let leftAnkle = joints[VNHumanBodyPoseObservation.JointName.leftAnkle.rawValue.rawValue]
        let rightAnkle = joints[VNHumanBodyPoseObservation.JointName.rightAnkle.rawValue.rawValue]
        
        // 2. Consistent Single-Side Limb Selection (Prevents cross-diagonal joint mixing)
        let leftLegValid = (leftHip?.confidence ?? 0 > 0.25) && (leftKnee?.confidence ?? 0 > 0.25) && (leftAnkle?.confidence ?? 0 > 0.25)
        let rightLegValid = (rightHip?.confidence ?? 0 > 0.25) && (rightKnee?.confidence ?? 0 > 0.25) && (rightAnkle?.confidence ?? 0 > 0.25)
        let leftLegScore = (leftHip?.confidence ?? 0) + (leftKnee?.confidence ?? 0) + (leftAnkle?.confidence ?? 0)
        let rightLegScore = (rightHip?.confidence ?? 0) + (rightKnee?.confidence ?? 0) + (rightAnkle?.confidence ?? 0)
        let useRightLeg = rightLegValid && (!leftLegValid || rightLegScore >= leftLegScore)
        
        let legHip = useRightLeg ? rightHip : leftHip
        let legKnee = useRightLeg ? rightKnee : leftKnee
        let legAnkle = useRightLeg ? rightAnkle : leftAnkle
        let legShoulder = (useRightLeg ? rightShoulder : leftShoulder) ?? (leftShoulder ?? rightShoulder)
        
        let leftArmValid = (leftShoulder?.confidence ?? 0 > 0.25) && (leftElbow?.confidence ?? 0 > 0.25) && (leftWrist?.confidence ?? 0 > 0.25)
        let rightArmValid = (rightShoulder?.confidence ?? 0 > 0.25) && (rightElbow?.confidence ?? 0 > 0.25) && (rightWrist?.confidence ?? 0 > 0.25)
        let leftArmScore = (leftShoulder?.confidence ?? 0) + (leftElbow?.confidence ?? 0) + (leftWrist?.confidence ?? 0)
        let rightArmScore = (rightShoulder?.confidence ?? 0) + (rightElbow?.confidence ?? 0) + (rightWrist?.confidence ?? 0)
        let useRightArm = rightArmValid && (!leftArmValid || rightArmScore >= leftArmScore)
        
        let armShoulder = useRightArm ? rightShoulder : leftShoulder
        let armElbow = useRightArm ? rightElbow : leftElbow
        let armWrist = useRightArm ? rightWrist : leftWrist
        let armHip = (useRightArm ? rightHip : leftHip) ?? (leftHip ?? rightHip)
        let armKnee = (useRightArm ? rightKnee : leftKnee) ?? (leftKnee ?? rightKnee)
        
        // 3. Form Analysis & Guard State Machines
        switch currentExercise {
        case .squat:
            guard let hip = legHip, let knee = legKnee, let ankle = legAnkle, let shoulder = legShoulder else {
                isStepBackNeeded = true
                workoutState = "STEP BACK"
                aiFeedback = "Step back so your hips, knees, and ankles are clearly visible"
                return
            }
            isStepBackNeeded = false
            
            let rawKneeAngle = angleBetween(p1: hip.point, p2: knee.point, p3: ankle.point)
            let rawHipAngle = angleBetween(p1: shoulder.point, p2: hip.point, p3: knee.point)
            let kneeAngle = smooth(current: &smoothedAngle1, target: rawKneeAngle)
            let hipAngle = smooth(current: &smoothedAngle2, target: rawHipAngle)
            self.currentAngle = kneeAngle
            self.secondaryAngle = hipAngle
            
            // Posture Calibration: User MUST start standing upright
            let isStandingPosture = kneeAngle > 160 && hipAngle > 152
            if isStandingPosture {
                standingFrames += 1
                if standingFrames >= 6 {
                    if !isCalibrated {
                        isCalibrated = true
                        baselineStandingHipY = hip.point.y
                        speak("Standing calibrated. Begin your squats!")
                    }
                    if stateMachineState == "calibrating" || stateMachineState == "waiting_for_stand" {
                        stateMachineState = "standing"
                        workoutState = "READY (BEGIN SQUAT)"
                        aiFeedback = "Good standing posture. Squat down to parallel."
                    }
                    // Slowly drift baseline standing hip Y to account for user subtle posture adjustment
                    baselineStandingHipY = (baselineStandingHipY * 0.85) + (hip.point.y * 0.15)
                }
            } else {
                standingFrames = 0
            }
            
            guard isCalibrated else {
                workoutState = "STAND UP TO BEGIN"
                aiFeedback = "Stand upright facing or sideways to camera to calibrate starting posture"
                stateMachineState = "waiting_for_stand"
                return
            }
            
            // Vertical hip descent guard (screen coordinates: top is 0, bottom is 1)
            let verticalDrop = hip.point.y - baselineStandingHipY
            
            if stateMachineState == "standing" {
                if kneeAngle < 105 && hipAngle < 120 {
                    // Must have physical vertical descent (at least 3.5% of frame height)
                    if verticalDrop > 0.035 {
                        inflectionFrames += 1
                        if inflectionFrames >= 3 {
                            stateMachineState = "squat_depth"
                            workoutState = "DOWN (DEEP SQUAT)"
                            aiFeedback = "Great squat depth! Drive up through your heels."
                        }
                    }
                } else {
                    inflectionFrames = 0
                    if kneeAngle < 140 {
                        workoutState = "DESCENDING..."
                    }
                }
            } else if stateMachineState == "squat_depth" {
                if kneeAngle > 158 && hipAngle > 152 {
                    if verticalDrop < 0.045 {
                        let now = Date()
                        if now.timeIntervalSince(lastRepTime) >= minRepCycleDuration {
                            stateMachineState = "standing"
                            workoutState = "UP (STANDING)"
                            inflectionFrames = 0
                            standingFrames = 4
                            triggerGoodRep(message: "Great squat depth!")
                        }
                    }
                } else if hipAngle < 75 {
                    provideFeedback("Keep your chest up!")
                }
            }
            
        case .pushup:
            guard let shoulder = armShoulder, let elbow = armElbow, let wrist = armWrist, let hip = armHip else {
                isStepBackNeeded = true
                workoutState = "STEP BACK"
                aiFeedback = "Step back so your full body is visible in the camera frame"
                return
            }
            isStepBackNeeded = false
            
            // Prone Orientation Guard (Eliminates sitting at desk / standing false reps)
            let torsoDy = abs(shoulder.point.y - hip.point.y)
            let torsoDx = abs(shoulder.point.x - hip.point.x)
            let isUpright = (shoulder.point.y < hip.point.y - 0.20) && (torsoDy > torsoDx * 1.15)
            if isUpright {
                workoutState = "GET IN PLANK POSITION"
                aiFeedback = "Place phone and assume a horizontal plank position on the floor"
                stateMachineState = "waiting_for_plank"
                standingFrames = 0
                inflectionFrames = 0
                return
            }
            
            let rawElbowAngle = angleBetween(p1: shoulder.point, p2: elbow.point, p3: wrist.point)
            let rawHipAngle = (armKnee != nil) ? angleBetween(p1: shoulder.point, p2: hip.point, p3: armKnee!.point) : 175.0
            let elbowAngle = smooth(current: &smoothedAngle1, target: rawElbowAngle)
            let hipAngle = smooth(current: &smoothedAngle2, target: rawHipAngle)
            self.currentAngle = elbowAngle
            self.secondaryAngle = hipAngle
            
            if hipAngle < 140 {
                provideFeedback("Lift your hips! Keep core braced straight.")
            } else if hipAngle > 205 {
                provideFeedback("Lower your hips into a straight plank line.")
            }
            
            // Starting position calibration: must establish top plank with arms extended (> 150°)
            if elbowAngle > 148 {
                standingFrames += 1
                if standingFrames >= 5 {
                    if !isCalibrated {
                        isCalibrated = true
                        speak("Plank calibrated. Begin push-ups!")
                    }
                    if stateMachineState == "calibrating" || stateMachineState == "waiting_for_plank" {
                        stateMachineState = "up_lockout"
                        workoutState = "UP (PLANK READY)"
                        aiFeedback = "Plank locked. Lower your chest down smoothly."
                    }
                }
            } else {
                standingFrames = 0
            }
            
            guard isCalibrated else {
                workoutState = "LOCK ARMS IN PLANK"
                return
            }
            
            if stateMachineState == "up_lockout" {
                if elbowAngle < 92 {
                    inflectionFrames += 1
                    if inflectionFrames >= 3 {
                        stateMachineState = "down_depth"
                        workoutState = "DOWN (HOLD DEPTH)"
                        aiFeedback = "Good depth! Drive up powerfully."
                    }
                } else {
                    inflectionFrames = 0
                    if elbowAngle < 130 {
                        workoutState = "LOWERING..."
                    }
                }
            } else if stateMachineState == "down_depth" {
                if elbowAngle > 150 {
                    let now = Date()
                    if now.timeIntervalSince(lastRepTime) >= minRepCycleDuration {
                        stateMachineState = "up_lockout"
                        workoutState = "UP (LOCKED)"
                        inflectionFrames = 0
                        standingFrames = 4
                        triggerGoodRep(message: "Good push-up!")
                    }
                }
            }
            
        case .lunge:
            guard let hip = legHip, let knee = legKnee, let ankle = legAnkle else {
                isStepBackNeeded = true
                workoutState = "STEP BACK"
                aiFeedback = "Step back so legs are fully visible"
                return
            }
            isStepBackNeeded = false
            
            let rawKneeAngle = angleBetween(p1: hip.point, p2: knee.point, p3: ankle.point)
            let kneeAngle = smooth(current: &smoothedAngle1, target: rawKneeAngle)
            self.currentAngle = kneeAngle
            
            if kneeAngle > 158 {
                standingFrames += 1
                if standingFrames >= 6 {
                    if !isCalibrated {
                        isCalibrated = true
                        speak("Ready! Begin lunges.")
                    }
                    if stateMachineState == "calibrating" || stateMachineState == "waiting_for_stand" {
                        stateMachineState = "standing"
                        workoutState = "READY (BEGIN LUNGE)"
                    }
                }
            } else {
                standingFrames = 0
            }
            
            guard isCalibrated else {
                workoutState = "STAND UP TO BEGIN"
                aiFeedback = "Stand upright facing camera to start lunges"
                stateMachineState = "waiting_for_stand"
                return
            }
            
            if stateMachineState == "standing" {
                if kneeAngle < 98 {
                    inflectionFrames += 1
                    if inflectionFrames >= 3 {
                        stateMachineState = "lunge_down"
                        workoutState = "DOWN (LUNGE)"
                        aiFeedback = "Solid depth! Push back up through front heel."
                    }
                } else {
                    inflectionFrames = 0
                }
            } else if stateMachineState == "lunge_down" {
                if kneeAngle > 152 {
                    let now = Date()
                    if now.timeIntervalSince(lastRepTime) >= minRepCycleDuration {
                        stateMachineState = "standing"
                        workoutState = "UP (STANDING)"
                        inflectionFrames = 0
                        standingFrames = 4
                        triggerGoodRep(message: "Excellent lunge!")
                    }
                }
            }
            
        case .bicepCurl:
            guard let shoulder = armShoulder, let elbow = armElbow, let wrist = armWrist, let hip = armHip else {
                isStepBackNeeded = true
                workoutState = "POSITION ARMS"
                aiFeedback = "Make sure your arm and torso are visible in frame"
                return
            }
            isStepBackNeeded = false
            
            let rawElbowAngle = angleBetween(p1: shoulder.point, p2: elbow.point, p3: wrist.point)
            let rawUpperArmSwing = angleBetween(p1: hip.point, p2: shoulder.point, p3: elbow.point)
            let elbowAngle = smooth(current: &smoothedAngle1, target: rawElbowAngle)
            let upperArmSwing = smooth(current: &smoothedAngle2, target: rawUpperArmSwing)
            self.currentAngle = elbowAngle
            self.secondaryAngle = upperArmSwing
            
            if upperArmSwing > 38 {
                provideFeedback("Keep elbows pinned to your ribs!")
            }
            
            // Calibration: Arm must start extended straight down (> 145°)
            if elbowAngle > 145 {
                standingFrames += 1
                if standingFrames >= 5 {
                    if !isCalibrated {
                        isCalibrated = true
                        speak("Ready! Begin bicep curls.")
                    }
                    if stateMachineState == "calibrating" || stateMachineState == "waiting_for_extend" {
                        stateMachineState = "arm_extended"
                        workoutState = "READY (EXTENDED)"
                        aiFeedback = "Arm fully extended. Curl up smoothly."
                    }
                }
            } else {
                standingFrames = 0
            }
            
            guard isCalibrated else {
                workoutState = "LOWER ARM TO EXTEND"
                aiFeedback = "Start with your arm extended straight down at your side"
                stateMachineState = "waiting_for_extend"
                return
            }
            
            if stateMachineState == "arm_extended" {
                if elbowAngle < 65 {
                    inflectionFrames += 1
                    if inflectionFrames >= 3 {
                        stateMachineState = "arm_curled"
                        workoutState = "FLEXED (PEAK)"
                        aiFeedback = "Peak contraction! Squeeze and lower slowly."
                    }
                } else {
                    inflectionFrames = 0
                }
            } else if stateMachineState == "arm_curled" {
                if elbowAngle > 142 {
                    let now = Date()
                    if now.timeIntervalSince(lastRepTime) >= minRepCycleDuration {
                        stateMachineState = "arm_extended"
                        workoutState = "DOWN (EXTENDED)"
                        inflectionFrames = 0
                        standingFrames = 4
                        triggerGoodRep(message: "Great bicep squeeze!")
                    }
                }
            }
            
        case .deadlift:
            guard let hip = legHip, let knee = legKnee, let ankle = legAnkle, let shoulder = legShoulder else {
                isStepBackNeeded = true
                workoutState = "STEP BACK"
                aiFeedback = "Step back so your full body is visible"
                return
            }
            isStepBackNeeded = false
            
            let rawHipAngle = angleBetween(p1: shoulder.point, p2: hip.point, p3: knee.point)
            let rawKneeAngle = angleBetween(p1: hip.point, p2: knee.point, p3: ankle.point)
            let hipAngle = smooth(current: &smoothedAngle1, target: rawHipAngle)
            let kneeAngle = smooth(current: &smoothedAngle2, target: rawKneeAngle)
            self.currentAngle = hipAngle
            self.secondaryAngle = kneeAngle
            
            if hipAngle > 165 && kneeAngle > 160 {
                standingFrames += 1
                if standingFrames >= 6 {
                    if !isCalibrated {
                        isCalibrated = true
                        speak("Ready! Begin deadlifts.")
                    }
                    if stateMachineState == "calibrating" || stateMachineState == "waiting_for_stand" {
                        stateMachineState = "standing"
                        workoutState = "READY (LOCKOUT)"
                    }
                }
            } else {
                standingFrames = 0
            }
            
            guard isCalibrated else {
                workoutState = "STAND TALL TO BEGIN"
                aiFeedback = "Stand fully upright with shoulders pinned back to calibrate"
                stateMachineState = "waiting_for_stand"
                return
            }
            
            if stateMachineState == "standing" {
                if hipAngle < 115 && kneeAngle < 130 {
                    inflectionFrames += 1
                    if inflectionFrames >= 3 {
                        stateMachineState = "hinge_down"
                        workoutState = "HINGE (BOTTOM)"
                        aiFeedback = "Solid hinge! Drive hips forward to lock out."
                    }
                } else {
                    inflectionFrames = 0
                }
            } else if stateMachineState == "hinge_down" {
                if hipAngle > 165 && kneeAngle > 160 {
                    let now = Date()
                    if now.timeIntervalSince(lastRepTime) >= minRepCycleDuration {
                        stateMachineState = "standing"
                        workoutState = "LOCKED OUT (TOP)"
                        inflectionFrames = 0
                        standingFrames = 4
                        triggerGoodRep(message: "Powerful hip drive!")
                    }
                }
            }
            
        case .plank:
            guard let shoulder = armShoulder, let hip = armHip, let knee = armKnee else {
                isStepBackNeeded = true
                workoutState = "STEP BACK"
                aiFeedback = "Step back so your full body is visible in the camera frame"
                return
            }
            isStepBackNeeded = false
            
            let torsoDy = abs(shoulder.point.y - hip.point.y)
            let torsoDx = abs(shoulder.point.x - hip.point.x)
            let isUpright = (shoulder.point.y < hip.point.y - 0.20) && (torsoDy > torsoDx * 1.15)
            if isUpright {
                workoutState = "GET IN PLANK POSITION"
                aiFeedback = "Get on the floor in a horizontal plank position"
                return
            }
            
            let rawHipAngle = angleBetween(p1: shoulder.point, p2: hip.point, p3: knee.point)
            let hipAngle = smooth(current: &smoothedAngle1, target: rawHipAngle)
            self.currentAngle = hipAngle
            
            if hipAngle >= 150 && hipAngle <= 198 {
                workoutState = "HOLDING PLANK (\(plankSeconds)s)"
                provideFeedback("Perfect neutral spine! Keep breathing.")
            } else if hipAngle < 150 {
                workoutState = "ADJUST (HIPS TOO LOW)"
                provideFeedback("Engage core! Lift your hips into a straight line.")
            } else {
                workoutState = "ADJUST (HIPS TOO HIGH)"
                provideFeedback("Lower your hips slightly into straight line.")
            }
            
        default:
            guard let shoulder = armShoulder, let elbow = armElbow, let wrist = armWrist else { return }
            let rawAngle = angleBetween(p1: shoulder.point, p2: elbow.point, p3: wrist.point)
            let armAngle = smooth(current: &smoothedAngle1, target: rawAngle)
            self.currentAngle = armAngle
            
            if armAngle > 150 {
                standingFrames += 1
                if standingFrames >= 5 {
                    isCalibrated = true
                    stateMachineState = "extended"
                    workoutState = "READY (EXTENDED)"
                }
            }
            
            guard isCalibrated else {
                workoutState = "EXTEND ARMS TO START"
                return
            }
            
            if stateMachineState == "extended" {
                if armAngle < 90 {
                    inflectionFrames += 1
                    if inflectionFrames >= 3 {
                        stateMachineState = "contracted"
                        workoutState = "CONTRACTED"
                    }
                } else {
                    inflectionFrames = 0
                }
            } else if stateMachineState == "contracted" {
                if armAngle > 150 {
                    let now = Date()
                    if now.timeIntervalSince(lastRepTime) >= minRepCycleDuration {
                        stateMachineState = "extended"
                        workoutState = "EXTENDED"
                        inflectionFrames = 0
                        standingFrames = 4
                        triggerGoodRep(message: "Good repetition!")
                    }
                }
            }
        }
    }
    
    // MARK: - Mathematical Vector Angle Calculation
    func angleBetween(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1x = p1.x - p2.x
        let v1y = p1.y - p2.y
        let v2x = p3.x - p2.x
        let v2y = p3.y - p2.y
        let dot = v1x * v2x + v1y * v2y
        let mag1 = hypot(v1x, v1y)
        let mag2 = hypot(v2x, v2y)
        guard mag1 * mag2 > 0 else { return 180.0 }
        let cosAngle = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        return acos(cosAngle) * (180.0 / .pi)
    }
    
    func triggerGoodRep(message: String) {
        let now = Date()
        guard now.timeIntervalSince(lastRepTime) >= 0.8 else { return }
        lastRepTime = now
        repCount += 1
        
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
        
        if repCount % 5 == 0 {
            speak("\(repCount) reps completed! Great pace.")
        } else {
            speak(message)
        }
        
        aiFeedback = "💡 \(message)"
    }
    
    private func provideFeedback(_ message: String) {
        guard aiFeedback != message else { return }
        aiFeedback = message
        
        // Debounce audio speech
        let now = Date()
        if now.timeIntervalSince(lastSpeechTime) > 3.5 {
            speak(message)
        }
    }
    
    func speak(_ text: String) {
        guard isVoiceEnabled else { return }
        lastSpeechTime = Date()
        ElevenLabsService.shared.speak(text: text)
    }
    
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    private func startPlankTimer() {
        plankTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.workoutState.starts(with: "HOLDING PLANK") || self.isSimulatorRunning {
                self.plankSeconds += 1
                self.repCount = self.plankSeconds
            }
        }
    }
    
    private func stopPlankTimer() {
        plankTimer?.invalidate()
        plankTimer = nullTimer()
    }
    
    private func nullTimer() -> Timer? { return nil }
    
    // MARK: - Interactive Test Mode Simulator (No camera / seated demo)
    func runSimulatorRep() {
        stopSimulator()
        isSimulatorRunning = true
        var phase: Double = 0.0 // 0 -> 1 -> 0
        var isDescending = true
        
        simTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if isDescending {
                phase += 0.06
                if phase >= 1.0 { isDescending = false }
            } else {
                phase -= 0.06
                if phase <= 0.0 {
                    timer.invalidate()
                    self.isSimulatorRunning = false
                    self.triggerGoodRep(message: "Simulated rep counted!")
                    return
                }
            }
            self.renderSimulatedSkeleton(depth: phase)
        }
    }
    
    func toggleAutoRunSimulator() {
        if isSimulatorRunning {
            stopSimulator()
        } else {
            isSimulatorRunning = true
            var phase: Double = 0.0
            var direction: Double = 0.05
            simTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                phase += direction
                if phase >= 1.0 {
                    direction = -0.05
                } else if phase <= 0.0 {
                    direction = 0.05
                    self.triggerGoodRep(message: "Rep counted!")
                }
                self.renderSimulatedSkeleton(depth: phase)
            }
        }
    }
    
    func stopSimulator() {
        simTimer?.invalidate()
        simTimer = nil
        isSimulatorRunning = false
    }
    
    private func renderSimulatedSkeleton(depth: Double) {
        // Generates realistic anatomically accurate points mapped to screen (0...1, 0...1)
        // Standing at depth 0, Deep squat/push-up at depth 1
        let hipY = 0.52 + (depth * 0.16)
        let kneeY = 0.70 + (depth * 0.08)
        let kneeXLeft = 0.44 - (depth * 0.04)
        let kneeXRight = 0.56 + (depth * 0.04)
        
        var simJoints: [String: PoseJoint] = [:]
        
        simJoints[VNHumanBodyPoseObservation.JointName.nose.rawValue.rawValue] = PoseJoint(id: "nose", point: CGPoint(x: 0.5, y: 0.22 + (depth * 0.12)), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.neck.rawValue.rawValue] = PoseJoint(id: "neck", point: CGPoint(x: 0.5, y: 0.28 + (depth * 0.12)), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.leftShoulder.rawValue.rawValue] = PoseJoint(id: "leftShoulder", point: CGPoint(x: 0.42, y: 0.31 + (depth * 0.13)), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.rightShoulder.rawValue.rawValue] = PoseJoint(id: "rightShoulder", point: CGPoint(x: 0.58, y: 0.31 + (depth * 0.13)), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.leftElbow.rawValue.rawValue] = PoseJoint(id: "leftElbow", point: CGPoint(x: 0.38, y: 0.44 + (depth * 0.08)), confidence: 0.95)
        simJoints[VNHumanBodyPoseObservation.JointName.rightElbow.rawValue.rawValue] = PoseJoint(id: "rightElbow", point: CGPoint(x: 0.62, y: 0.44 + (depth * 0.08)), confidence: 0.95)
        simJoints[VNHumanBodyPoseObservation.JointName.leftWrist.rawValue.rawValue] = PoseJoint(id: "leftWrist", point: CGPoint(x: 0.45, y: 0.40 + (depth * 0.06)), confidence: 0.95)
        simJoints[VNHumanBodyPoseObservation.JointName.rightWrist.rawValue.rawValue] = PoseJoint(id: "rightWrist", point: CGPoint(x: 0.55, y: 0.40 + (depth * 0.06)), confidence: 0.95)
        simJoints[VNHumanBodyPoseObservation.JointName.leftHip.rawValue.rawValue] = PoseJoint(id: "leftHip", point: CGPoint(x: 0.45, y: hipY), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.rightHip.rawValue.rawValue] = PoseJoint(id: "rightHip", point: CGPoint(x: 0.55, y: hipY), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.leftKnee.rawValue.rawValue] = PoseJoint(id: "leftKnee", point: CGPoint(x: kneeXLeft, y: kneeY), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.rightKnee.rawValue.rawValue] = PoseJoint(id: "rightKnee", point: CGPoint(x: kneeXRight, y: kneeY), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.leftAnkle.rawValue.rawValue] = PoseJoint(id: "leftAnkle", point: CGPoint(x: 0.44, y: 0.88), confidence: 0.99)
        simJoints[VNHumanBodyPoseObservation.JointName.rightAnkle.rawValue.rawValue] = PoseJoint(id: "rightAnkle", point: CGPoint(x: 0.56, y: 0.88), confidence: 0.99)
        
        self.joints = simJoints
        
        var simConnections: [PoseConnection] = []
        let pairs: [(String, String)] = [
            ("leftShoulder", "rightShoulder"),
            ("leftShoulder", "leftElbow"),
            ("leftElbow", "leftWrist"),
            ("rightShoulder", "rightElbow"),
            ("rightElbow", "rightWrist"),
            ("leftShoulder", "leftHip"),
            ("rightShoulder", "rightHip"),
            ("leftHip", "rightHip"),
            ("leftHip", "leftKnee"),
            ("leftKnee", "leftAnkle"),
            ("rightHip", "rightKnee"),
            ("rightKnee", "rightAnkle"),
            ("nose", "neck"),
            ("neck", "leftShoulder"),
            ("neck", "rightShoulder")
        ]
        
        for (k1, k2) in pairs {
            if let j1 = simJoints[k1], let j2 = simJoints[k2] {
                simConnections.append(PoseConnection(from: j1, to: j2))
            }
        }
        self.connections = simConnections
        
        // Compute angles
        let kneeAngle = 175.0 - (depth * 85.0) // 175° down to 90°
        let hipAngle = 172.0 - (depth * 75.0)  // 172° down to 97°
        self.currentAngle = kneeAngle
        self.secondaryAngle = hipAngle
        
        if depth > 0.8 {
            self.workoutState = "DOWN (DEEP SQUAT)"
            self.aiFeedback = "💡 Excellent squat depth! Maintain core tension."
        } else if depth < 0.2 {
            self.workoutState = "UP (STANDING)"
        }
    }
}
