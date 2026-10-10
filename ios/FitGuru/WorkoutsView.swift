import SwiftUI

// MARK: - Workouts & Equipment Directory Screen (fragment_workouts.xml parity)
struct WorkoutsView: View {
    @ObservedObject var store: WorkoutStore
    
    @State private var selectedCategory: String = "All"
    private let categories = ["All", "Upper Body", "Lower Body", "Free Weights", "Core", "Cardio"]
    
    var filteredEquipment: [EquipmentWithExercise] {
        if selectedCategory == "All" {
            return GymCatalogRepository.equipmentList
        }
        return GymCatalogRepository.equipmentList.filter { $0.machine.category == selectedCategory }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                // 1. Header with INNOVHACKS Badge
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workouts & AI Coach")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(FitTheme.textPrimary)
                        
                        Text("Real-time Form Correction & Machine Guides")
                            .font(.system(size: 13))
                            .foregroundColor(FitTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("INNOVHACKS")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(FitTheme.accentLime)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(FitTheme.cardBackground)
                                .overlay(Capsule().stroke(FitTheme.accentLime.opacity(0.4), lineWidth: 1))
                        )
                }
                .padding(.top, 54)
                
                // 2. Featured AI Coach Hero Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("⚡ ON-DEVICE AI POSE COACH")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FitTheme.accentLime)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(FitTheme.accentLime.opacity(0.15))
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        Text("LIVE CAMERA")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FitTheme.textMuted)
                    }
                    
                    Text("AI Real-Time Biomechanics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(FitTheme.textPrimary)
                    
                    Text("Tracks 33 body points at 30 FPS to guide joint angles, range of motion, posture alignment, and rep counts with voice feedback.")
                        .font(.system(size: 13))
                        .foregroundColor(FitTheme.textSecondary)
                        .lineSpacing(2)
                    
                    Button(action: {
                        store.activeWorkoutType = .squat
                    }) {
                        HStack {
                            Text("Select exercise below or start Squats →")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: FitTheme.radiusLarge)
                        .stroke(FitTheme.cardBorder, lineWidth: 1)
                )
                
                // 3. Section 1: AI Form Coach Exercises (Horizontal)
                VStack(alignment: .leading, spacing: 12) {
                    Text("⚡ AI Form Coach Exercises")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(FitTheme.textPrimary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ExerciseType.allCases) { ex in
                                QuickWorkoutCard(
                                    exercise: ex,
                                    previousSession: store.lastSession(for: ex.rawValue)
                                ) {
                                    store.activeWorkoutType = ex
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 4)
                
                // 4. Section 2: Gym Equipment Directory Header & Counter
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("📖 Gym Equipment Directory")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(FitTheme.textPrimary)
                        Spacer()
                        Text("\(filteredEquipment.count) Machines")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(FitTheme.accentLime)
                    }
                    
                    Text("Tap any equipment to learn setup, correct form, mistakes to avoid, and launch AI coach.")
                        .font(.system(size: 13))
                        .foregroundColor(FitTheme.textSecondary)
                }
                .padding(.top, 10)
                
                // 5. Category Filter Chips (Horizontal Scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            let isSelected = (selectedCategory == cat)
                            Button(action: {
                                selectedCategory = cat
                            }) {
                                Text(cat)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isSelected ? FitTheme.textOnAccent : FitTheme.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? FitTheme.accentLime : FitTheme.cardBackground)
                                    .cornerRadius(FitTheme.radiusPill)
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.clear : FitTheme.cardBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 6. Equipment List (item_gym_equipment.xml parity)
                VStack(spacing: 14) {
                    ForEach(filteredEquipment) { item in
                        GymEquipmentCard(item: item) {
                            store.selectedEquipment = item
                        }
                    }
                }
                .padding(.bottom, 90) // Bottom nav padding
            }
            .padding(.horizontal, 20)
        }
        .background(FitTheme.background.ignoresSafeArea())
    }
}

// MARK: - Gym Equipment Card (item_gym_equipment.xml parity)
struct GymEquipmentCard: View {
    let item: EquipmentWithExercise
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    // Machine Icon Box
                    Text(item.machine.icon)
                        .font(.system(size: 32))
                        .frame(width: 54, height: 54)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(FitTheme.radiusSmall)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.machine.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(FitTheme.textPrimary)
                            Spacer()
                            Text(item.primaryExercise.level)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FitTheme.accentLime)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FitTheme.accentLime.opacity(0.12))
                                .cornerRadius(4)
                        }
                        
                        Text(item.primaryExercise.muscles.joined(separator: " • "))
                            .font(.system(size: 12))
                            .foregroundColor(FitTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                // Setup Cue Snippet
                if let firstSetup = item.primaryExercise.setup.first {
                    HStack(spacing: 6) {
                        Text("💡")
                            .font(.system(size: 12))
                        Text(firstSetup)
                            .font(.system(size: 12))
                            .foregroundColor(FitTheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                }
                
                HStack {
                    Text("Category: \(item.machine.category)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(FitTheme.textMuted)
                    Spacer()
                    Text("View Full Guide →")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FitTheme.accentLime)
                }
            }
            .padding(16)
            .background(FitTheme.cardBackground)
            .cornerRadius(FitTheme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: FitTheme.radiusMedium)
                    .stroke(FitTheme.cardBorder, lineWidth: 1)
            )
        }
    }
}
