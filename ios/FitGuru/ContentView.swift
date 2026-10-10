import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            FitTheme.background.ignoresSafeArea()
            
            // Tab Content Views (MainActivity.kt Fragments parity)
            Group {
                switch selectedTab {
                case 0:
                    DashboardView(store: store, selectedTab: $selectedTab)
                case 1:
                    WorkoutsView(store: store)
                case 2:
                    ProfileView(store: store)
                default:
                    DashboardView(store: store, selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Android Jet Black Bottom Navigation Bar
            CustomBottomNavBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        
        // Fullscreen AI Camera Pose Coach Screen (WorkoutActivity / CameraFragment parity)
        .fullScreenCover(item: $store.activeWorkoutType) { exercise in
            PoseCoachView(exercise: exercise, store: store)
        }
        
        // Equipment Guide Bottom Sheet (bottom_sheet_equipment_guide.xml parity)
        .sheet(item: $store.selectedEquipment) { item in
            EquipmentGuideSheet(item: item, store: store)
        }
        
        // Workout History Modal (HistoryActivity.kt parity)
        .sheet(isPresented: $store.isShowingHistory) {
            HistoryView(store: store)
        }
        
        // Weekly Rep Goal Editor Sheet
        .sheet(isPresented: $store.isShowingGoalsEditor) {
            GoalEditorSheet(store: store)
        }
    }
}

// MARK: - Android BottomNavigationView Parity Bar
struct CustomBottomNavBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            // Tab 0: Dashboard
            NavBarButton(
                icon: "house.fill",
                title: "Dashboard",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            Spacer()
            
            // Tab 1: Workouts & Equipment
            NavBarButton(
                icon: "dumbbell.fill",
                title: "Workouts",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            Spacer()
            
            // Tab 2: Profile & Stats
            NavBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 14)
        .padding(.bottom, 28) // Safe area bottom on iPhone 16/17
        .background(
            Color(red: 14/255, green: 14/255, blue: 16/255).opacity(0.96)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(FitTheme.cardBorder),
                    alignment: .top
                )
        )
    }
}

struct NavBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? FitTheme.accentLime : FitTheme.textSecondary)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? FitTheme.accentLime : FitTheme.textSecondary)
            }
            .frame(width: 70)
        }
    }
}

// MARK: - Goal Editor Sheet
struct GoalEditorSheet: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var goalText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("🎯")
                        .font(.system(size: 48))
                    Text("Configure Weekly Rep Target")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Set your milestone repetition count to maintain progressive overload and stay accountable.")
                        .font(.system(size: 13))
                        .foregroundColor(FitTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("WEEKLY GOAL (REPS)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FitTheme.textSecondary)
                    
                    TextField("e.g. 250", text: $goalText)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(FitTheme.cardBackground)
                        .cornerRadius(FitTheme.radiusMedium)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
                }
                
                HStack(spacing: 12) {
                    ForEach([150, 200, 300, 500], id: \.self) { preset in
                        Button(action: {
                            goalText = "\(preset)"
                        }) {
                            Text("\(preset)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(goalText == "\(preset)" ? FitTheme.textOnAccent : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(goalText == "\(preset)" ? FitTheme.accentLime : FitTheme.cardBackground)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if let val = Int(goalText), val > 0 {
                        store.weeklyGoal = val
                    }
                    dismiss()
                }) {
                    Text("Save Target")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FitTheme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FitTheme.accentLime)
                        .cornerRadius(FitTheme.radiusMedium)
                }
            }
            .padding(20)
            .background(FitTheme.background.ignoresSafeArea())
            .navigationTitle("Goal Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FitTheme.textSecondary)
                }
            }
            .onAppear {
                goalText = "\(store.weeklyGoal)"
            }
        }
    }
}
