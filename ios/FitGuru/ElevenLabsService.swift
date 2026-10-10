import Foundation
import AVFoundation
import Combine

// MARK: - ElevenLabs AI Voice Coach Personas
enum CoachPersona: String, CaseIterable, Identifiable {
    case drillSergeant = "marcus"
    case mindfulMaya = "maya"
    case olympianAlex = "alex"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .drillSergeant: return "Coach Marcus"
        case .mindfulMaya: return "Coach Maya"
        case .olympianAlex: return "Coach Alex"
        }
    }
    
    var subtitle: String {
        switch self {
        case .drillSergeant: return "Drill Sergeant • High Intensity & Grit"
        case .mindfulMaya: return "Mindful Guide • Calm, Form & Breath"
        case .olympianAlex: return "The Olympian • Biomechanical Precision"
        }
    }
    
    var icon: String {
        switch self {
        case .drillSergeant: return "🔥"
        case .mindfulMaya: return "🧘"
        case .olympianAlex: return "🏆"
        }
    }
    
    // Official ElevenLabs Voice IDs
    var voiceId: String {
        switch self {
        case .drillSergeant: return "onwK4e9ZLuTAKqWW03F9" // Daniel (deep, authoritative)
        case .mindfulMaya: return "EXAVITQu4vr4xnSDxMaL"    // Sarah (calm, warm, articulate)
        case .olympianAlex: return "ErXwobaYiN019PkySvjV"   // Antoni (clear, dynamic, energetic)
        }
    }
    
    var samplePhrase: String {
        switch self {
        case .drillSergeant: return "Let's go! Chest up, drive through your heels, don't quit on me!"
        case .mindfulMaya: return "Breathe in deeply, find your balance, and maintain a calm, steady rhythm."
        case .olympianAlex: return "Excellent bar path. Lock your hips out at the peak of each repetition."
        }
    }
}

// MARK: - ElevenLabs Real-Time Audio Engine
class ElevenLabsService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = ElevenLabsService()
    
    // Published State
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "elevenlabs_enabled") }
    }
    @Published var selectedPersona: CoachPersona {
        didSet { UserDefaults.standard.set(selectedPersona.rawValue, forKey: "elevenlabs_persona") }
    }
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "elevenlabs_api_key") }
    }
    @Published var isSpeaking: Bool = false
    
    private var audioPlayer: AVAudioPlayer?
    private let fallbackSynthesizer = AVSpeechSynthesizer()
    private let cacheDirectory: URL
    
    override init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "elevenlabs_enabled") as? Bool ?? true
        
        let savedPersona = UserDefaults.standard.string(forKey: "elevenlabs_persona") ?? CoachPersona.drillSergeant.rawValue
        self.selectedPersona = CoachPersona(rawValue: savedPersona) ?? .drillSergeant
        
        let savedKey = UserDefaults.standard.string(forKey: "elevenlabs_api_key") ?? ""
        if !savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.apiKey = savedKey
        } else {
            var key = Bundle.main.infoDictionary?["ELEVENLABS_API_KEY"] as? String ?? ""
            if key.isEmpty, let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
               let secret = dict["ELEVENLABS_API_KEY"] as? String {
                key = secret
            }
            self.apiKey = key
        }
        
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("ElevenLabsCache", isDirectory: true)
        
        super.init()
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    // MARK: - Speech Synthesis (With In-Memory & Disk Caching)
    func speak(text: String, persona: CoachPersona? = nil, onComplete: (() -> Void)? = nil) {
        let activePersona = persona ?? self.selectedPersona
        
        // If ElevenLabs is toggled off or no API key, seamlessly use native device TTS fallback
        guard isEnabled, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            speakWithFallback(text)
            onComplete?()
            return
        }
        
        let cacheKey = "\(activePersona.voiceId)_\(text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey.hashValue).mp3")
        
        // 1. Play from local cache if already synthesized (0ms network latency!)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            playAudio(from: fileURL, onComplete: onComplete)
            return
        }
        
        // 2. Fetch from ElevenLabs REST API
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(activePersona.voiceId)?output_format=mp3_44100_128") else {
            speakWithFallback(text)
            onComplete?()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5", // Ultra low-latency conversational model
            "voice_settings": [
                "stability": 0.50,
                "similarity_boost": 0.80,
                "style": 0.35,
                "use_speaker_boost": true
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            speakWithFallback(text)
            onComplete?()
            return
        }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil,
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    // Fall back to on-device TTS on network issue or quota limit
                    self?.speakWithFallback(text)
                    onComplete?()
                }
                return
            }
            
            // Save to disk cache for instantaneous re-use
            try? data.write(to: fileURL)
            
            DispatchQueue.main.async {
                self.playAudio(from: fileURL, onComplete: onComplete)
            }
        }.resume()
    }
    
    private func playAudio(from fileURL: URL, onComplete: (() -> Void)? = nil) {
        do {
            setupAudioSession()
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            isSpeaking = true
            audioPlayer?.play()
        } catch {
            speakWithFallback("")
            onComplete?()
        }
    }
    
    // MARK: - Smart Native TTS Fallback
    func speakWithFallback(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        fallbackSynthesizer.speak(utterance)
    }
    
    func stop() {
        audioPlayer?.stop()
        fallbackSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
