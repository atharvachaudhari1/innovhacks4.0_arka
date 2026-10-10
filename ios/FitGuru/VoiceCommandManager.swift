import SwiftUI
import Speech
import AVFoundation
import Combine

// MARK: - Voice Command Manager (Hands-Free Gym Control)
class VoiceCommandManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = VoiceCommandManager()
    
    @Published var isListening: Bool = false
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "voice_commands_enabled")
        }
    }
    @Published var recognizedText: String = ""
    @Published var lastCommandDetected: String? = nil
    @Published var statusMessage: String = "Ready for voice commands"
    @Published var isAuthorized: Bool = false
    @Published var micAudioLevel: CGFloat = 0.0
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private var isSpeakingFeedback: Bool = false
    private var lastCommandExecutionTime: Date = Date.distantPast
    private var lastProcessedText: String = ""
    weak var currentStore: WorkoutStore?
    
    var isCoachSpeaking: Bool {
        return isSpeakingFeedback || ElevenLabsService.shared.isCurrentlySpeaking || speechSynthesizer.isSpeaking
    }
    
    override init() {
        super.init()
        self.isEnabled = UserDefaults.standard.object(forKey: "voice_commands_enabled") as? Bool ?? true
        speechRecognizer?.delegate = self
        speechSynthesizer.delegate = self
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("FitGuru.TTS.Finished"), object: nil, queue: .main) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            self.isSpeakingFeedback = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.isEnabled, let store = self.currentStore else { return }
                if !self.isListening {
                    self.ensureListening(store: store)
                }
            }
        }
    }
    
    // MARK: - Dual Permission Request (Speech Recognition + Microphone)
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .authorized {
            checkMicPermission(completion: completion)
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                DispatchQueue.main.async {
                    self.isAuthorized = false
                    self.statusMessage = "Speech recognition permission denied in Settings"
                    completion(false)
                }
                return
            }
            
            self.checkMicPermission(completion: completion)
        }
    }
    
    private func checkMicPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            let recordPermission = AVAudioApplication.shared.recordPermission
            if recordPermission == .granted {
                DispatchQueue.main.async {
                    self.isAuthorized = true
                    self.statusMessage = "Microphone & Speech ready"
                    completion(true)
                }
                return
            } else if recordPermission == .denied {
                DispatchQueue.main.async {
                    self.isAuthorized = false
                    self.statusMessage = "Microphone permission denied"
                    completion(false)
                }
                return
            }
            
            AVAudioApplication.requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    self.isAuthorized = micGranted
                    self.statusMessage = micGranted ? "Microphone & Speech ready" : "Microphone permission denied"
                    completion(micGranted)
                }
            }
        } else {
            let recordPermission = AVAudioSession.sharedInstance().recordPermission
            if recordPermission == .granted {
                DispatchQueue.main.async {
                    self.isAuthorized = true
                    self.statusMessage = "Microphone & Speech ready"
                    completion(true)
                }
                return
            } else if recordPermission == .denied {
                DispatchQueue.main.async {
                    self.isAuthorized = false
                    self.statusMessage = "Microphone permission denied"
                    completion(false)
                }
                return
            }
            
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    self.isAuthorized = micGranted
                    self.statusMessage = micGranted ? "Microphone & Speech ready" : "Microphone permission denied"
                    completion(micGranted)
                }
            }
        }
    }
    
    // MARK: - Toggle Hands-Free Continuous Listening
    func toggleListening(store: WorkoutStore) {
        self.currentStore = store
        if isListening || isEnabled {
            stopListening()
        } else {
            startListening(store: store)
        }
    }
    
    func startListening(store: WorkoutStore) {
        self.currentStore = store
        isEnabled = true
        ensureListening(store: store)
    }
    
    /// Rock-solid polling / retry loop: ensures hands-free listening is active,
    /// waiting for any active TTS speech to finish before turning the mic on.
    func ensureListening(store: WorkoutStore) {
        guard isEnabled else { return }
        self.currentStore = store
        
        requestAuthorization { [weak self] authorized in
            guard let self = self, authorized, self.isEnabled else { return }
            
            if self.isListening { return }
            
            // If coach or feedback audio is currently playing, wait and retry
            if self.isCoachSpeaking {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self, self.isEnabled else { return }
                    self.ensureListening(store: store)
                }
                return
            }
            
            self.beginRecordingSession(store: store)
        }
    }
    
    func stopListening() {
        isEnabled = false
        stopRecordingSessionOnly()
        DispatchQueue.main.async {
            self.isListening = false
            self.currentStore?.isVoiceListening = false
            self.statusMessage = "Voice commands paused"
        }
    }
    
    private func stopRecordingSessionOnly() {
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isStartingSession = false
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    // MARK: - Core Audio Engine & Speech Session
    private var isStartingSession: Bool = false
    
    func beginRecordingSession(store: WorkoutStore) {
        guard isEnabled else { return }
        self.currentStore = store
        
        // If coach or feedback is speaking, auto-retry once audio finishes
        if isCoachSpeaking {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.isEnabled else { return }
                self.ensureListening(store: store)
            }
            return
        }
        
        guard !isStartingSession else { return }
        isStartingSession = true
        stopRecordingSessionOnly()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceCommandManager] AudioSession error: \(error.localizedDescription)")
        }
        
        let engine = AVAudioEngine()
        audioEngine = engine
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            isStartingSession = false
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)
        
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat: AVAudioFormat
        if hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 {
            recordingFormat = hardwareFormat
        } else {
            let rate = audioSession.sampleRate > 0 ? audioSession.sampleRate : 44100.0
            recordingFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) ?? hardwareFormat
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = transcription
                }
                
                // Do not parse speech while coach is speaking (prevent self-echo loops)
                if !self.isCoachSpeaking {
                    self.parseVoiceCommand(transcription.lowercased(), store: store)
                } else {
                    self.lastProcessedText = transcription
                }
            }
            
            // Auto-restart session on natural timeout or silence if user still wants hands-free mode
            if error != nil || (result?.isFinal ?? false) {
                self.stopRecordingSessionOnly()
                if self.isEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let self = self, self.isEnabled else { return }
                        self.ensureListening(store: store)
                    }
                }
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            let channelData = buffer.floatChannelData?[0]
            let channelDataLength = Int(buffer.frameLength)
            if let channelData = channelData, channelDataLength > 0 {
                var sum: Float = 0
                let count = min(channelDataLength, 256)
                for i in 0..<count {
                    sum += abs(channelData[i])
                }
                let avg = sum / Float(count)
                DispatchQueue.main.async {
                    self?.micAudioLevel = CGFloat(min(1.0, max(0.1, avg * 15.0)))
                }
            }
        }
        
        do {
            engine.prepare()
            try engine.start()
            isStartingSession = false
            DispatchQueue.main.async {
                self.isListening = true
                store.isVoiceListening = true
                let isWorkoutActive = store.activeWorkoutType != nil
                self.statusMessage = isWorkoutActive ? "Listening: say 'finish set' or 'smart rest'..." : "Listening: say 'start pushups' or 'start squats'..."
            }
        } catch {
            isStartingSession = false
            print("[VoiceCommandManager] AudioEngine start failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isListening = false
                store.isVoiceListening = false
                self.statusMessage = "Mic error: \(error.localizedDescription)"
            }
        }
    }
    
    // Track when last exercise was started, to prevent immediate accidental finish
    private var lastExerciseStartTime: Date = Date.distantPast
    
    // MARK: - Command Intent Matching
    func parseVoiceCommand(_ text: String, store: WorkoutStore) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        
        // Calculate newly spoken words since the last executed command
        let candidate: String
        if !lastProcessedText.isEmpty && cleaned.hasPrefix(lastProcessedText) {
            let suffix = String(cleaned.dropFirst(lastProcessedText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            // No new words spoken — nothing to process
            guard !suffix.isEmpty else { return }
            candidate = suffix
        } else if cleaned == lastProcessedText {
            // Exact duplicate transcription — skip
            return
        } else {
            candidate = cleaned
        }
        
        // Debounce: prevent duplicate triggers within 2.0 seconds
        let now = Date()
        guard now.timeIntervalSince(lastCommandExecutionTime) > 2.0 else { return }
        
        let isWorkoutActive = store.activeWorkoutType != nil
        
        // MARK: - 1. IF IN AN ACTIVE WORKOUT: Prioritize Finish, Rest, and Form Review
        if isWorkoutActive {
            // Check for explicit finish phrases.
            // NOTE: Do NOT match bare "done" or "stop" because "down" (e.g., "get down", "head down")
            // and background noise are frequently mistranscribed as "done" or "stop".
            let isFinishIntent = candidate.contains("finish set") ||
                                 candidate.contains("finish the set") ||
                                 candidate.contains("finish workout") ||
                                 candidate.contains("finish exercise") ||
                                 candidate.contains("end set") ||
                                 candidate.contains("end the set") ||
                                 candidate.contains("end workout") ||
                                 candidate.contains("complete set") ||
                                 candidate.contains("complete the set") ||
                                 candidate.contains("stop set") ||
                                 candidate.contains("stop the set") ||
                                 candidate.contains("stop workout") ||
                                 candidate.contains("stop exercise") ||
                                 candidate.contains("i'm done") ||
                                 candidate.contains("i am done") ||
                                 candidate.contains("done with set") ||
                                 candidate.contains("all done") ||
                                 candidate == "finish" ||
                                 candidate.hasPrefix("finish ") ||
                                 candidate.hasSuffix(" finish")
            
            if isFinishIntent {
                // Prevent finishing within 2.0 seconds of starting exercise
                guard now.timeIntervalSince(lastExerciseStartTime) > 2.0 else {
                    print("[VoiceCmd] Ignoring finish intent — exercise just started \(now.timeIntervalSince(lastExerciseStartTime))s ago")
                    return
                }
                executeCommand("Finish Set", candidate: candidate, fullText: cleaned, store: store) {
                    store.requestFinishActiveWorkout = true
                    self.speakFeedback("Set finished! Great intensity.")
                }
                return
            }
            
            // Rest Timer
            if candidate.contains("rest") || candidate.contains("timer") || candidate.contains("break") {
                executeCommand("Smart Rest Timer", candidate: candidate, fullText: cleaned, store: store) {
                    store.startSmartRest(duration: 60)
                    store.isShowingRestTimer = true
                    self.speakFeedback("Smart rest timer started. Monitoring heart rate recovery.")
                }
                return
            }
            
            // Form Review
            if candidate.contains("how was") || candidate.contains("how's") || candidate.contains("how is my form") || candidate.contains("form check") || candidate.contains("check form") || candidate.contains("how did i do") {
                executeCommand("Form Review", candidate: candidate, fullText: cleaned, store: store) {
                    if let last = store.sessions.first {
                        let feedback = "Great work! Your last set of \(last.exerciseName) scored \(last.score)% form accuracy with \(last.reps) reps. Biomechanical symmetry was rock solid!"
                        self.speakFeedback(feedback)
                    } else {
                        self.speakFeedback("Complete your first exercise set, and I'll give you a detailed biomechanical debrief!")
                    }
                }
                return
            }
        }
        
        // MARK: - 2. IF NOT IN A WORKOUT (Dashboard): Exercise Launchers
        else {
            if candidate.contains("pushup") || candidate.contains("push up") || candidate.contains("push-up") {
                executeCommand("Start Push-ups", candidate: candidate, fullText: cleaned, store: store, isExerciseStart: true) {
                    store.requestFinishActiveWorkout = false
                    store.activeWorkoutType = .pushup
                }
                return
            }
            
            if candidate.contains("squat") {
                executeCommand("Start Squats", candidate: candidate, fullText: cleaned, store: store, isExerciseStart: true) {
                    store.requestFinishActiveWorkout = false
                    store.activeWorkoutType = .squat
                }
                return
            }
            
            if candidate.contains("deadlift") || candidate.contains("dead lift") {
                executeCommand("Start Deadlift", candidate: candidate, fullText: cleaned, store: store, isExerciseStart: true) {
                    store.requestFinishActiveWorkout = false
                    store.activeWorkoutType = .deadlift
                }
                return
            }
            
            if candidate.contains("lunge") {
                executeCommand("Start Lunges", candidate: candidate, fullText: cleaned, store: store, isExerciseStart: true) {
                    store.requestFinishActiveWorkout = false
                    store.activeWorkoutType = .lunge
                }
                return
            }
            
            if candidate.contains("curl") || candidate.contains("bicep") {
                executeCommand("Start Bicep Curls", candidate: candidate, fullText: cleaned, store: store, isExerciseStart: true) {
                    store.requestFinishActiveWorkout = false
                    store.activeWorkoutType = .bicepCurl
                }
                return
            }
            
            // Rest Timer on Dashboard
            if candidate.contains("rest") || candidate.contains("timer") || candidate.contains("break") {
                executeCommand("Smart Rest Timer", candidate: candidate, fullText: cleaned, store: store) {
                    store.startSmartRest(duration: 60)
                    store.isShowingRestTimer = true
                    self.speakFeedback("Smart rest timer started. Monitoring heart rate recovery.")
                }
                return
            }
            
            // Form Review on Dashboard
            if candidate.contains("how was") || candidate.contains("how's") || candidate.contains("how is my form") || candidate.contains("form check") || candidate.contains("check form") || candidate.contains("how did i do") {
                executeCommand("Form Review", candidate: candidate, fullText: cleaned, store: store) {
                    if let last = store.sessions.first {
                        let feedback = "Great work! Your last set of \(last.exerciseName) scored \(last.score)% form accuracy with \(last.reps) reps."
                        self.speakFeedback(feedback)
                    } else {
                        self.speakFeedback("Start an exercise like squats or push-ups, and I will track your form!")
                    }
                }
                return
            }
        }
    }
    
    /// Central command execution: updates state, fires the action, then ensures
    /// the recognition session resumes cleanly.
    private func executeCommand(_ name: String, candidate: String, fullText: String, store: WorkoutStore, isExerciseStart: Bool = false, action: @escaping () -> Void) {
        lastCommandExecutionTime = Date()
        lastProcessedText = fullText
        if isExerciseStart {
            lastExerciseStartTime = Date()
        }
        
        print("[VoiceCmd] ✅ Matched '\(name)' from candidate: \"\(candidate)\"")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastCommandDetected = name
            store.lastVoiceCommand = name
            action()
            
            // Auto-clear last command banner after 4s
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if self.lastCommandDetected == name {
                    self.lastCommandDetected = nil
                    store.lastVoiceCommand = nil
                }
            }
        }
        
        // Stop audio recording session briefly while command initiates
        stopRecordingSessionOnly()
        
        // Ensure voice commands immediately resume listening
        if isEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self, self.isEnabled else { return }
                self.ensureListening(store: store)
            }
        }
    }
    
    // MARK: - Voice Feedback Output (ElevenLabs or Native Synthesizer)
    func speakFeedback(_ text: String) {
        isSpeakingFeedback = true
        
        let resumeListening = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSpeakingFeedback = false
                self.recognizedText = ""
                self.lastProcessedText = ""
                if let store = self.currentStore, self.isEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        guard let self = self, self.isEnabled else { return }
                        self.ensureListening(store: store)
                    }
                }
            }
        }
        
        if ElevenLabsService.shared.isConfigured {
            ElevenLabsService.shared.speak(text: text) {
                resumeListening()
            }
        } else {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.52
            utterance.pitchMultiplier = 1.05
            speechSynthesizer.speak(utterance)
        }
        
        // Safety timeout to resume listening if speech callbacks get delayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            if self?.isSpeakingFeedback == true {
                resumeListening()
            }
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSpeakingFeedback = false
            self.recognizedText = ""
            self.lastProcessedText = ""
            if let store = self.currentStore, self.isEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self, self.isEnabled else { return }
                    self.ensureListening(store: store)
                }
            }
        }
    }
    
    // MARK: - Direct Quick Action Command Trigger (Simulate / Chip Tap)
    func simulateCommand(_ commandText: String, store: WorkoutStore) {
        self.currentStore = store
        recognizedText = commandText
        parseVoiceCommand(commandText.lowercased(), store: store)
    }
}
