import SwiftUI

// MARK: - Dashboard Screen (fragment_dashboard.xml parity)
struct DashboardView: View {
    @ObservedObject var store: WorkoutStore
    @Binding var selectedTab: Int
    
    // Calendar days for October 2026
    private let calendarDays: [(day: String, num: Int, isToday: Bool)] = [
        ("S", 4, false),
        ("M", 5, false),
        ("T", 6, false),
        ("W", 7, false),
        ("T", 8, false),
        ("F", 9, false),
        ("S", 10, true) // Today
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                // 1. Header (Your Activity & Date)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Activity")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(FitTheme.textPrimary)
                    
                    Text("October 2026")
                        .font(.system(size: 16))
                        .foregroundColor(FitTheme.textSecondary)
                }
                .padding(.top, 54)
                
                // 2. 7-Day Calendar Strip (calendar_day.xml parity)
                HStack(spacing: 8) {
                    ForEach(calendarDays, id: \.num) { item in
                        VStack(spacing: 6) {
                            Text(item.day)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(item.isToday ? FitTheme.textOnAccent : FitTheme.textSecondary)
                            
                            Text("\(item.num)")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(item.isToday ? FitTheme.textOnAccent : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: FitTheme.radiusSmall)
                                .fill(item.isToday ? FitTheme.accentLime : FitTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FitTheme.radiusSmall)
                                        .stroke(item.isToday ? Color.clear : FitTheme.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                }
                
                // 3. My Goals Card (Weekly Rep Goal)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weekly Rep Goal")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(FitTheme.textPrimary)
                            Text("Tap to set your goal and track your progress!")
                                .font(.system(size: 13))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        Spacer()
                        Text("🎯")
                            .font(.system(size: 24))
                    }
                    
                    // Custom Progress Bar (140 / 200 reps)
                    GeometryReader { barGeo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(FitTheme.accentLime)
                                .frame(width: barGeo.size.width * min(1.0, CGFloat(store.currentWeeklyReps) / CGFloat(store.weeklyGoal)), height: 10)
                        }
                    }
                    .frame(height: 10)
                    
                    HStack {
                        Text("Current: \(store.currentWeeklyReps)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(FitTheme.textSecondary)
                        Spacer()
                        Text("Goal: \(store.weeklyGoal)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(FitTheme.accentLime)
                    }
                }
                .padding(20)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: FitTheme.radiusLarge)
                        .stroke(FitTheme.cardBorder, lineWidth: 1)
                )
                .onTapGesture {
                    store.isShowingGoalsEditor = true
                }
                
                // 4. Today's Challenge Card (Full Body HIIT)
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Body HIIT")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(FitTheme.textOnAccent)
                        
                        Text("Complete your plan before 9:00 AM")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.75))
                    }
                    Spacer()
                    Image(systemName: "figure.highintensity.intervaltraining")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(FitTheme.textOnAccent)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [FitTheme.accentLime, Color(red: 170/255, green: 220/255, blue: 0/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(FitTheme.radiusLarge)
                
                // 5. Featured Quick Start AI Coach Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("⚡ Quick Start AI Coach")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(FitTheme.textPrimary)
                    
                    Text("Real-time joint angle tracking & audio feedback")
                        .font(.system(size: 13))
                        .foregroundColor(FitTheme.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach([ExerciseType.squat, .pushup, .lunge, .plank, .bicepCurl, .deadlift]) { ex in
                                QuickWorkoutCard(
                                    exercise: ex,
                                    previousSession: store.lastSession(for: ex.rawValue)
                                ) {
                                    store.activeWorkoutType = ex
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.top, 10)
                
                // 6. Shortcut to Gym Directory Card
                Button(action: {
                    selectedTab = 1 // Switch to Workouts & Equipment tab
                }) {
                    HStack(spacing: 14) {
                        Text("📖")
                            .font(.system(size: 28))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("20 Gym Equipment Guides")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(FitTheme.textPrimary)
                            Text("Setup, form cues, safety tips & mistakes")
                                .font(.system(size: 12))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text("Explore →")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(FitTheme.accentLime)
                    }
                    .padding(16)
                    .background(FitTheme.cardBackground)
                    .cornerRadius(FitTheme.radiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: FitTheme.radiusMedium)
                            .stroke(FitTheme.cardBorder, lineWidth: 1)
                    )
                }
                .padding(.bottom, 90) // Nav bar padding
            }
            .padding(.horizontal, 20)
        }
        .background(FitTheme.background.ignoresSafeArea())
    }
}

// MARK: - Quick Workout Card (item_quick_workout.xml parity)
struct QuickWorkoutCard: View {
    let exercise: ExerciseType
    var previousSession: WorkoutSession? = nil
    let onStart: () -> Void
    
    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(exercise.icon)
                        .font(.system(size: 26))
                    Spacer()
                    Text("AI COACH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(FitTheme.accentLime)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(FitTheme.accentLime.opacity(0.15))
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(exercise.targetMuscles)
                        .font(.system(size: 11))
                        .foregroundColor(FitTheme.textSecondary)
                        .lineLimit(1)
                }
                
                // Progressive Overload Previous Session Tag
                if let prev = previousSession {
                    HStack(spacing: 4) {
                        Text("🎯 Last:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(FitTheme.textSecondary)
                        Text(prev.weightKg > 0 ? "\(prev.weightDisplay) × \(prev.reps)" : "\(prev.reps) reps")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(FitTheme.accentLime)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)
                }
                
                HStack {
                    Text("Start Live →")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FitTheme.accentLime)
                    Spacer()
                    Text("\(Int(exercise.calPerRep * 100)) kcal/100")
                        .font(.system(size: 10))
                        .foregroundColor(FitTheme.textMuted)
                }
            }
            .padding(14)
            .frame(width: 175)
            .background(FitTheme.cardBackground)
            .cornerRadius(FitTheme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: FitTheme.radiusMedium)
                    .stroke(FitTheme.cardBorder, lineWidth: 1)
            )
        }
    }
}
