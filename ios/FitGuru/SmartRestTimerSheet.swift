import SwiftUI

// MARK: - Smart Rest Timer View (Heart Rate Recovery Driven)
struct SmartRestTimerSheet: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var autoAdvanceOnRecovery: Bool = true
    @State private var hasPlayedChime: Bool = false
    
    var body: some View {
        ZStack {
            FitTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("⏱️")
                            Text("Smart Rest Interval")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(FitTheme.textPrimary)
                        }
                        Text("Heart rate recovery adaptive pacing")
                            .font(.system(size: 13))
                            .foregroundColor(FitTheme.textSecondary)
                    }
                    Spacer()
                    Button(action: {
                        store.stopSmartRest()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(FitTheme.textMuted)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer()
                
                // Circular Timer Dial
                ZStack {
                    // Outer background ring
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 16)
                        .frame(width: 220, height: 220)
                    
                    // Animated progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(store.restTimerRemainingSeconds) / CGFloat(max(1, store.restTimerTotalSeconds)))
                        .stroke(
                            LinearGradient(
                                colors: [FitTheme.accentLime, Color(red: 170/255, green: 235/255, blue: 20/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 220, height: 220)
                        .animation(.linear(duration: 1.0), value: store.restTimerRemainingSeconds)
                    
                    // Inside dial metrics
                    VStack(spacing: 6) {
                        Text("\(store.restTimerRemainingSeconds)")
                            .font(.system(size: 58, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("SECONDS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FitTheme.textSecondary)
                            .tracking(1.5)
                        
                        // Live HR Badge inside circle
                        HStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                            Text("\(store.currentHeartRate) BPM")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.18))
                        .cornerRadius(12)
                        .padding(.top, 4)
                    }
                }
                
                // Smart Recovery Suggestion Banner
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: store.isHeartRateRecovered ? "checkmark.seal.fill" : "waveform.path.ecg")
                            .foregroundColor(store.isHeartRateRecovered ? FitTheme.accentLime : .orange)
                            .font(.system(size: 16, weight: .bold))
                        
                        Text(store.isHeartRateRecovered ? "Cardiovascular Recovery Complete" : "Cardiac Load Active")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(store.isHeartRateRecovered ? FitTheme.accentLime : .orange)
                        
                        Spacer()
                        
                        Text(store.isHeartRateRecovered ? "Ready" : "Target: <115 BPM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FitTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                    
                    Text(store.smartRestSuggestion)
                        .font(.system(size: 13))
                        .foregroundColor(FitTheme.textPrimary)
                        .lineSpacing(2)
                }
                .padding(16)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: FitTheme.radiusMedium)
                        .stroke(store.isHeartRateRecovered ? FitTheme.accentLime.opacity(0.4) : FitTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                // Timer Adjusters (+30s / -15s)
                HStack(spacing: 12) {
                    Button(action: {
                        store.adjustSmartRest(by: -15)
                    }) {
                        Text("-15s")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FitTheme.cardBackground)
                            .cornerRadius(FitTheme.radiusSmall)
                            .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusSmall).stroke(FitTheme.cardBorder, lineWidth: 1))
                    }
                    
                    Button(action: {
                        store.adjustSmartRest(by: 30)
                    }) {
                        Text("+30s")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(FitTheme.cardBackground)
                            .cornerRadius(FitTheme.radiusSmall)
                            .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusSmall).stroke(FitTheme.cardBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        store.stopSmartRest()
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Skip Rest & Start Next Set")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(FitTheme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FitTheme.accentLime)
                        .cornerRadius(FitTheme.radiusLarge)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            if !store.isRestTimerActive {
                store.startSmartRest(duration: 60)
            }
        }
    }
}
