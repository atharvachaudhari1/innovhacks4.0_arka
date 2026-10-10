import SwiftUI

// MARK: - ElevenLabs AI Voice Persona Configuration Sheet
struct VoiceSettingsSheet: View {
    @ObservedObject var elevenLabs = ElevenLabsService.shared
    @ObservedObject var gemini = GeminiService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var tempApiKey: String = ""
    @State private var tempGeminiApiKey: String = ""
    @State private var previewingPersona: CoachPersona? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                FitTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        
                        // Header Banner
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("🎙️")
                                    .font(.system(size: 24))
                                Text("ElevenLabs Voice AI")
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundColor(FitTheme.textPrimary)
                            }
                            
                            Text("Experience dynamic, human-like coaching with emotionally expressive AI voices calibrated for athletic performance.")
                                .font(.system(size: 13))
                                .foregroundColor(FitTheme.textSecondary)
                                .lineSpacing(3)
                        }
                        .padding(.top, 10)
                        
                        // 1. Enable / Disable Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable ElevenLabs Voice AI")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(FitTheme.textPrimary)
                                Text("Fallback to native on-device TTS when offline")
                                    .font(.system(size: 12))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: $elevenLabs.isEnabled)
                                .labelsHidden()
                                .tint(FitTheme.accentLime)
                        }
                        .padding(16)
                        .background(FitTheme.cardBackground)
                        .cornerRadius(FitTheme.radiusMedium)
                        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                        
                        // 2. Coach Persona Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CHOOSE COACH PERSONA")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(FitTheme.textSecondary)
                                .tracking(1.0)
                            
                            ForEach(CoachPersona.allCases) { persona in
                                let isSelected = elevenLabs.selectedPersona == persona
                                
                                Button(action: {
                                    elevenLabs.selectedPersona = persona
                                }) {
                                    HStack(spacing: 14) {
                                        // Persona Icon
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? FitTheme.accentLime.opacity(0.18) : Color.white.opacity(0.05))
                                                .frame(width: 46, height: 46)
                                                .overlay(Circle().stroke(isSelected ? FitTheme.accentLime : Color.white.opacity(0.1), lineWidth: 1.5))
                                            
                                            Text(persona.icon)
                                                .font(.system(size: 22))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack {
                                                Text(persona.displayName)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(FitTheme.textPrimary)
                                                if isSelected {
                                                    Text("ACTIVE")
                                                        .font(.system(size: 9, weight: .heavy))
                                                        .foregroundColor(FitTheme.textOnAccent)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(FitTheme.accentLime)
                                                        .cornerRadius(4)
                                                }
                                            }
                                            
                                            Text(persona.subtitle)
                                                .font(.system(size: 11))
                                                .foregroundColor(FitTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Sample Preview Button
                                        Button(action: {
                                            previewingPersona = persona
                                            elevenLabs.speak(text: persona.samplePhrase, persona: persona) {
                                                previewingPersona = nil
                                            }
                                        }) {
                                            Image(systemName: previewingPersona == persona ? "speaker.wave.3.fill" : "play.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(isSelected ? FitTheme.accentLime : FitTheme.textSecondary)
                                        }
                                    }
                                    .padding(14)
                                    .background(isSelected ? FitTheme.accentLime.opacity(0.08) : FitTheme.cardBackground)
                                    .cornerRadius(FitTheme.radiusMedium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FitTheme.radiusMedium)
                                            .stroke(isSelected ? FitTheme.accentLime : FitTheme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                                    )
                                }
                            }
                        }
                        
                        // 3. API Key Configuration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ELEVENLABS API KEY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(FitTheme.textSecondary)
                                .tracking(1.0)
                            
                            VStack(spacing: 10) {
                                SecureField("Paste your ElevenLabs API Key", text: $tempApiKey)
                                    .padding(14)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(FitTheme.radiusSmall)
                                    .foregroundColor(.white)
                                    .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusSmall).stroke(FitTheme.cardBorder, lineWidth: 1))
                                
                                HStack {
                                    if !elevenLabs.apiKey.isEmpty {
                                        Text("✓ API Key Configured")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(FitTheme.accentLime)
                                    } else {
                                        Text("No key saved (using native TTS fallback)")
                                            .font(.system(size: 12))
                                            .foregroundColor(FitTheme.textSecondary)
                                    }
                                    Spacer()
                                    Button("Save Key") {
                                        if !tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            elevenLabs.apiKey = tempApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                        }
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(FitTheme.textOnAccent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(FitTheme.accentLime)
                                    .cornerRadius(FitTheme.radiusSmall)
                                }
                            }
                            .padding(16)
                            .background(FitTheme.cardBackground)
                            .cornerRadius(FitTheme.radiusMedium)
                            .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                        }
                        
                        // 4. Google Gemini API Key Configuration
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("GOOGLE GEMINI API KEY")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FitTheme.textSecondary)
                                    .tracking(1.0)
                                Spacer()
                                Text("BIOMECHANICS & RECOVERY")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(FitTheme.accentLime)
                            }
                            
                            VStack(spacing: 10) {
                                SecureField("Paste your Gemini API Key", text: $tempGeminiApiKey)
                                    .padding(14)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(FitTheme.radiusSmall)
                                    .foregroundColor(.white)
                                    .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusSmall).stroke(FitTheme.cardBorder, lineWidth: 1))
                                
                                HStack {
                                    if gemini.isKeyConfigured {
                                        Text("✓ Gemini 2.5 Flash Configured")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(FitTheme.accentLime)
                                    } else {
                                        Text("No key saved (using Cognitive Engine fallback)")
                                            .font(.system(size: 12))
                                            .foregroundColor(FitTheme.textSecondary)
                                    }
                                    Spacer()
                                    Button("Save Key") {
                                        if !tempGeminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            gemini.apiKey = tempGeminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                        }
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(FitTheme.textOnAccent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(FitTheme.accentLime)
                                    .cornerRadius(FitTheme.radiusSmall)
                                }
                            }
                            .padding(16)
                            .background(FitTheme.cardBackground)
                            .cornerRadius(FitTheme.radiusMedium)
                            .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                        }
                        
                        // Close / Done Button
                        Button(action: { dismiss() }) {
                            Text("Done")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(FitTheme.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FitTheme.accentLime)
                                .cornerRadius(FitTheme.radiusMedium)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(FitTheme.accentLime)
                }
            }
            .onAppear {
                tempApiKey = elevenLabs.apiKey
                tempGeminiApiKey = gemini.apiKey
            }
        }
    }
}
