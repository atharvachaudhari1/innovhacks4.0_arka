import SwiftUI

// MARK: - Workout History Screen (activity_history.xml parity)
struct HistoryView: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: WorkoutSession? = nil
    @State private var viewMode: Int = 0
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    
                    // Summary Banner Card
                    HStack(spacing: 14) {
                        VStack(spacing: 4) {
                            Text("\(store.sessions.count)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                            Text("Sessions")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        
                        Divider().frame(height: 28).background(FitTheme.cardBorder)
                        
                        VStack(spacing: 4) {
                            Text("\(store.totalReps)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Total Reps")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        
                        Divider().frame(height: 28).background(FitTheme.cardBorder)
                        
                        VStack(spacing: 4) {
                            Text("\(Int(store.totalVolumeLiftedKg)) kg")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                            Text("Total Vol")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        
                        Divider().frame(height: 28).background(FitTheme.cardBorder)
                        
                        VStack(spacing: 4) {
                            Text("\(store.avgFormAccuracy)%")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Avg Form")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(FitTheme.cardBackground)
                    .cornerRadius(FitTheme.radiusMedium)
                    .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                    
                    // View Mode Segmented Picker
                    Picker("View Mode", selection: $viewMode) {
                        Text("📋 Workout Logs").tag(0)
                        Text("📊 Progress Analytics").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    
                    if viewMode == 1 {
                        // Multi-week Form, Reps & Heart Rate Progress Charts
                        AnalyticsDashboardView(store: store)
                    } else {
                        // Session List (item_history_entry.xml parity)
                        if store.sessions.isEmpty {
                        VStack(spacing: 12) {
                            Text("🏃")
                                .font(.system(size: 48))
                            Text("No recorded workouts yet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Start any AI coaching session to track your form and reps!")
                                .font(.system(size: 13))
                                .foregroundColor(FitTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(store.sessions) { session in
                            Button(action: {
                                selectedSession = session
                            }) {
                                HStack(spacing: 14) {
                                    // Exercise Icon
                                    Text(iconFor(type: session.exerciseType))
                                        .font(.system(size: 28))
                                        .frame(width: 48, height: 48)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(FitTheme.radiusSmall)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(session.exerciseName)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(FitTheme.textPrimary)
                                            Text("✨ Gemini")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(FitTheme.accentLime)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(FitTheme.accentLime.opacity(0.12))
                                                .cornerRadius(3)
                                        }
                                        
                                        Text(dateFormatter.string(from: session.date))
                                            .font(.system(size: 12))
                                            .foregroundColor(FitTheme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 3) {
                                        HStack(spacing: 5) {
                                            if session.weightKg > 0 {
                                                Text(session.weightDisplay)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                Text("•")
                                                    .foregroundColor(FitTheme.textMuted)
                                            }
                                            Text("\(session.reps) Reps")
                                                .font(.system(size: 15, weight: .heavy))
                                                .foregroundColor(FitTheme.accentLime)
                                        }
                                        
                                        HStack(spacing: 6) {
                                            Text("\(session.score)% Form")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                            if session.totalVolumeKg > 0 {
                                                Text("• \(Int(session.totalVolumeKg)) kg vol")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(FitTheme.accentLime.opacity(0.85))
                                            } else {
                                                Text("• \(session.calories) kcal")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(FitTheme.textMuted)
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                                .background(FitTheme.cardBackground)
                                .cornerRadius(FitTheme.radiusMedium)
                                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                            }
                        }
                    }
                }
                }
                .padding(20)
            }
            .background(FitTheme.background.ignoresSafeArea())
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(FitTheme.accentLime)
                }
            }
            .sheet(item: $selectedSession) { session in
                WorkoutSummarySheet(session: session)
            }
        }
    }
    
    private func iconFor(type: String) -> String {
        ExerciseType(rawValue: type)?.icon ?? "🏋️"
    }
}
