import SwiftUI

// MARK: - Equipment Guide Bottom Sheet (bottom_sheet_equipment_guide.xml parity)
struct EquipmentGuideSheet: View {
    let item: EquipmentWithExercise
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                // Sheet Drag Indicator
                HStack {
                    Spacer()
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                    Spacer()
                }
                
                // Machine Header & Badges
                HStack(alignment: .top, spacing: 16) {
                    Text(item.machine.icon)
                        .font(.system(size: 40))
                        .frame(width: 64, height: 64)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(FitTheme.radiusMedium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.machine.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(FitTheme.textPrimary)
                        
                        Text(item.machine.what)
                            .font(.system(size: 13))
                            .foregroundColor(FitTheme.textSecondary)
                        
                        HStack(spacing: 8) {
                            Text(item.machine.category)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(FitTheme.accentLime.opacity(0.12))
                                .cornerRadius(6)
                            
                            Text(item.primaryExercise.level)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(FitTheme.cardBackground)
                                .cornerRadius(6)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // Target Muscles Pills
                VStack(alignment: .leading, spacing: 8) {
                    Text("TARGET MUSCLES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FitTheme.textSecondary)
                    
                    HStack(spacing: 6) {
                        ForEach(item.primaryExercise.muscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Divider().background(FitTheme.cardBorder)
                
                // Section 1: Machine Setup & Adjustments
                VStack(alignment: .leading, spacing: 10) {
                    Label("1. Machine Setup & Adjustments", systemImage: "wrench.and.screwdriver.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FitTheme.accentLime)
                    
                    ForEach(Array(item.primaryExercise.setup.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                            Text(step)
                                .font(.system(size: 13))
                                .foregroundColor(FitTheme.textPrimary)
                        }
                    }
                }
                .padding(16)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusMedium)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                
                // Section 2: Proper Form & Execution
                VStack(alignment: .leading, spacing: 10) {
                    Label("2. Proper Form & Execution", systemImage: "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach(Array(item.primaryExercise.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                            Text(step)
                                .font(.system(size: 13))
                                .foregroundColor(FitTheme.textPrimary)
                        }
                    }
                }
                .padding(16)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusMedium)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                
                // Section 3: Common Mistakes to Avoid
                VStack(alignment: .leading, spacing: 10) {
                    Label("3. Mistakes to Avoid", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    ForEach(item.primaryExercise.mistakes, id: \.self) { mistake in
                        HStack(alignment: .top, spacing: 10) {
                            Text("⚠️")
                                .font(.system(size: 12))
                            Text(mistake)
                                .font(.system(size: 13))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusMedium)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                
                // Section 4: Safety Advice
                HStack(spacing: 12) {
                    Text("🛡️")
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safety First")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(item.primaryExercise.safety)
                            .font(.system(size: 12))
                            .foregroundColor(FitTheme.textSecondary)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(FitTheme.radiusSmall)
                
                // Action Button: Start AI Pose Coach
                Button(action: {
                    let type = ExerciseType(rawValue: item.primaryExercise.workoutType) ?? .squat
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        store.activeWorkoutType = type
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Start AI Pose Coach 🏋️")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(FitTheme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FitTheme.accentLime)
                    .cornerRadius(FitTheme.radiusMedium)
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .background(FitTheme.background.ignoresSafeArea())
    }
}
