import SwiftUI

// MARK: - User Profile Screen (fragment_profile.xml parity)
struct ProfileView: View {
    @ObservedObject var store: WorkoutStore
    @State private var showVoiceSettings: Bool = false
    @ObservedObject private var elevenLabs = ElevenLabsService.shared
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                // 1. Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("USER PROFILE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FitTheme.textSecondary)
                        .tracking(1.2)
                    
                    Text("My FitGuru")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(FitTheme.textPrimary)
                }
                .padding(.top, 54)
                
                // 2. Profile Info Card
                HStack(spacing: 16) {
                    // Avatar Circle
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [FitTheme.accentLime.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 58, height: 58)
                            .overlay(Circle().stroke(FitTheme.accentLime, lineWidth: 2))
                        
                        Text("⚡")
                            .font(.system(size: 26))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.userName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(FitTheme.textPrimary)
                        
                        Text(store.userHandle)
                            .font(.system(size: 12))
                            .foregroundColor(FitTheme.textSecondary)
                        
                        // Smartwatch Badge
                        HStack(spacing: 5) {
                            Text("⌚")
                                .font(.system(size: 11))
                            Text("Smartwatch Synced")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FitTheme.accentLime.opacity(0.12))
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                }
                .padding(18)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusLarge)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusLarge).stroke(FitTheme.cardBorder, lineWidth: 1))
                
                // 3. 2x2 Stats Grid (fragment_profile.xml parity)
                VStack(spacing: 12) {
                    // Row 1: Total Reps & Workouts
                    HStack(spacing: 12) {
                        StatCard(icon: "💪", value: "\(store.totalReps)", title: "TOTAL REPS")
                        StatCard(icon: "🏋️", value: "\(store.totalWorkouts)", title: "WORKOUTS")
                    }
                    
                    // Row 2: Calories & Form Accuracy
                    HStack(spacing: 12) {
                        StatCard(icon: "🔥", value: "\(store.totalCalories)", title: "CALORIES")
                        StatCard(icon: "🎯", value: "\(store.avgFormAccuracy)%", title: "FORM ACCURACY")
                    }
                }
                
                // 4. Achievement Records Card (fragment_profile.xml parity)
                let b1 = store.totalWorkouts >= 1
                let b2 = store.totalReps >= 100
                let b3 = store.avgFormAccuracy >= 95 && store.totalWorkouts >= 1
                let b4 = store.totalReps >= 250
                let unlockedCount = [b1, b2, b3, b4].filter { $0 }.count
                
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACHIEVEMENT RECORDS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FitTheme.accentLime)
                            .tracking(1.0)
                        
                        Text("Badges Unlocked: \(unlockedCount) / 4")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(FitTheme.textPrimary)
                    }
                    
                    HStack(spacing: 8) {
                        AchievementBadgeView(icon: "⚡", title: "First Step", status: b1 ? "Unlocked! 🎉" : "1 Workout", isUnlocked: b1)
                        AchievementBadgeView(icon: "💯", title: "Century", status: b2 ? "Unlocked! 🎉" : "\(store.totalReps)/100", isUnlocked: b2)
                        AchievementBadgeView(icon: "🎯", title: "Form Pro", status: b3 ? "Unlocked! 🎉" : "95% Score", isUnlocked: b3)
                        AchievementBadgeView(icon: "🦾", title: "Iron Will", status: b4 ? "Unlocked! 🎉" : "\(store.totalReps)/250", isUnlocked: b4)
                    }
                }
                .padding(18)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusLarge)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusLarge).stroke(FitTheme.cardBorder, lineWidth: 1))
                
                // 5. Menu Action Cards
                VStack(spacing: 0) {
                    // Workout History Button
                    Button(action: {
                        store.isShowingHistory = true
                    }) {
                        HStack(spacing: 14) {
                            Text("📜")
                                .font(.system(size: 22))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Workout History")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(FitTheme.textPrimary)
                                Text("View all past sessions & form scores")
                                    .font(.system(size: 11))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text("➔")
                                .font(.system(size: 14))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        .padding(16)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // Weekly Goals Button
                    Button(action: {
                        store.isShowingGoalsEditor = true
                    }) {
                        HStack(spacing: 14) {
                            Text("🎯")
                                .font(.system(size: 22))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weekly Goals & Target")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(FitTheme.textPrimary)
                                Text("Configure repetition targets")
                                    .font(.system(size: 11))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text("➔")
                                .font(.system(size: 14))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        .padding(16)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // Smartwatch Telemetry
                    HStack(spacing: 14) {
                        Text("❤️")
                            .font(.system(size: 22))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wearable DataLayer")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(FitTheme.textPrimary)
                            Text("Live Pulse: \(store.currentHeartRate) BPM • Low latency")
                                .font(.system(size: 11))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                    .padding(16)
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // ElevenLabs AI Voice Coach
                    Button(action: {
                        showVoiceSettings = true
                    }) {
                        HStack(spacing: 14) {
                            Text("🎙️")
                                .font(.system(size: 22))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("AI Coach & Engine Settings")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(FitTheme.textPrimary)
                                    Text("AI")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(FitTheme.textOnAccent)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(FitTheme.accentLime)
                                        .cornerRadius(4)
                                }
                                Text("ElevenLabs Voice • Gemini Biomechanics & Recovery")
                                    .font(.system(size: 11))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text("➔")
                                .font(.system(size: 14))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        .padding(16)
                    }
                }
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusLarge)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusLarge).stroke(FitTheme.cardBorder, lineWidth: 1))
                
                Spacer(minLength: 90) // Nav bar spacing
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsSheet()
        }
        .background(FitTheme.background.ignoresSafeArea())
    }
}

// MARK: - Stat Card (fragment_profile.xml item parity)
struct StatCard: View {
    let icon: String
    let value: String
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(icon)
                .font(.system(size: 20))
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(FitTheme.textPrimary)
            
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(FitTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FitTheme.cardBackground)
        .cornerRadius(FitTheme.radiusMedium)
        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
    }
}

// MARK: - Achievement Badge View (styles.xml AchievementIcon parity)
struct AchievementBadgeView: View {
    let icon: String
    let title: String
    let status: String
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? FitTheme.accentLime.opacity(0.18) : Color.white.opacity(0.04))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(isUnlocked ? FitTheme.accentLime : Color.white.opacity(0.12), lineWidth: isUnlocked ? 2 : 1))
                
                Text(icon)
                    .font(.system(size: 20))
            }
            
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(FitTheme.textPrimary)
                .lineLimit(1)
            
            Text(status)
                .font(.system(size: 9))
                .foregroundColor(isUnlocked ? FitTheme.accentLime : FitTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

