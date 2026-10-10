import SwiftUI

// MARK: - Workout Progress Analytics Screen (Multi-Week Charts)
struct AnalyticsDashboardView: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    
    enum MetricType: String, CaseIterable, Identifiable {
        case formScore = "Form Score"
        case repsAndVolume = "Reps & Vol"
        case heartRate = "Heart Rate"
        
        var id: String { rawValue }
        
        var unit: String {
            switch self {
            case .formScore: return "%"
            case .repsAndVolume: return "kg"
            case .heartRate: return "BPM"
            }
        }
        
        var icon: String {
            switch self {
            case .formScore: return "checkmark.shield.fill"
            case .repsAndVolume: return "dumbbell.fill"
            case .heartRate: return "heart.fill"
            }
        }
    }
    
    enum TimeWindow: String, CaseIterable, Identifiable {
        case sevenDays = "7 Days"
        case fourWeeks = "4 Weeks"
        case allTime = "All Time"
        var id: String { rawValue }
    }
    
    @State private var selectedMetric: MetricType = .formScore
    @State private var selectedWindow: TimeWindow = .sevenDays
    @State private var selectedSessionIndex: Int? = nil
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "M/d"
        return df
    }()
    
    var chartSessions: [WorkoutSession] {
        // Return sessions in chronological order for chart display
        return Array(store.sessions.prefix(7).reversed())
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                
                // 1. Header with metric picker
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workout Progress")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(FitTheme.textPrimary)
                            Text("Biomechanical form & cardiovascular trends")
                                .font(.system(size: 13))
                                .foregroundColor(FitTheme.textSecondary)
                        }
                        Spacer()
                    }
                    
                    // Metric Pills Selector
                    HStack(spacing: 8) {
                        ForEach(MetricType.allCases) { metric in
                            Button(action: {
                                selectedMetric = metric
                                selectedSessionIndex = nil
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: metric.icon)
                                        .font(.system(size: 12))
                                    Text(metric.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedMetric == metric ? FitTheme.accentLime : FitTheme.cardBackground)
                                .foregroundColor(selectedMetric == metric ? FitTheme.textOnAccent : FitTheme.textSecondary)
                                .cornerRadius(FitTheme.radiusSmall)
                                .overlay(
                                    RoundedRectangle(cornerRadius: FitTheme.radiusSmall)
                                        .stroke(selectedMetric == metric ? Color.clear : FitTheme.cardBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // Time Window Picker
                    Picker("Time Window", selection: $selectedWindow) {
                        ForEach(TimeWindow.allCases) { window in
                            Text(window.rawValue).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // 2. High-Fidelity Interactive Progress Chart Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chartTitle)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(FitTheme.textSecondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(headlineStat)
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                Text(selectedMetric.unit)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(FitTheme.accentLime)
                            }
                        }
                        
                        Spacer()
                        
                        // Benchmark pill
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("+4.2% vs last week")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(FitTheme.accentLime)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(FitTheme.accentLime.opacity(0.12))
                        .cornerRadius(6)
                    }
                    
                    // The Bar Chart Canvas
                    chartCanvas
                        .frame(height: 180)
                    
                    // Selected Bar Tooltip
                    if let idx = selectedSessionIndex, idx < chartSessions.count {
                        let item = chartSessions[idx]
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.exerciseName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(dateFormatter.string(from: item.date)) • \(item.reps) reps \(item.weightKg > 0 ? "• \(item.weightDisplay)" : "")")
                                    .font(.system(size: 11))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(metricValueString(for: item))
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundColor(FitTheme.accentLime)
                                Text(selectedMetric.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                    }
                }
                .padding(20)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusLarge)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusLarge).stroke(FitTheme.cardBorder, lineWidth: 1))
                .padding(.horizontal, 20)
                
                // 3. Four Metric Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatMetricCard(
                        title: "Avg Form Accuracy",
                        value: "\(store.avgFormAccuracy)%",
                        subtitle: "Green Zone (>90%)",
                        icon: "checkmark.seal.fill",
                        tint: FitTheme.accentLime
                    )
                    
                    StatMetricCard(
                        title: "Total Volume",
                        value: "\(Int(store.totalVolumeLiftedKg)) kg",
                        subtitle: "\(store.totalReps) total reps",
                        icon: "dumbbell.fill",
                        tint: .white
                    )
                    
                    StatMetricCard(
                        title: "Avg Heart Rate",
                        value: "\(store.currentHeartRate) BPM",
                        subtitle: "Optimal zone",
                        icon: "heart.fill",
                        tint: .red
                    )
                    
                    StatMetricCard(
                        title: "Lifter Streak",
                        value: "\(store.streakDays) Days",
                        subtitle: "On-device active",
                        icon: "flame.fill",
                        tint: .orange
                    )
                }
                .padding(.horizontal, 20)
                
                // 4. Biomechanical Exercise Form Breakdown Table
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Biomechanical Exercise Breakdown")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(FitTheme.textPrimary)
                        Spacer()
                    }
                    
                    ForEach(store.personalRecords) { pr in
                        HStack(spacing: 12) {
                            Text(iconFor(type: pr.exerciseType))
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.exerciseName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Max: \(pr.maxReps) reps \(pr.maxWeightKg > 0 ? "• \(pr.weightDisplay)" : "")")
                                    .font(.system(size: 12))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(pr.bestScore)%")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(pr.bestScore >= 95 ? FitTheme.accentLime : .white)
                                Text("Best Form")
                                    .font(.system(size: 10))
                                    .foregroundColor(FitTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if pr.id != store.personalRecords.last?.id {
                            Divider().background(FitTheme.cardBorder)
                        }
                    }
                }
                .padding(20)
                .background(FitTheme.cardBackground)
                .cornerRadius(FitTheme.radiusLarge)
                .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusLarge).stroke(FitTheme.cardBorder, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Chart Canvas
    private var chartCanvas: some View {
        GeometryReader { geo in
            let sessions = chartSessions
            let count = max(1, sessions.count)
            let barWidth = max(24, (geo.size.width - CGFloat(count - 1) * 12) / CGFloat(count))
            let maxVal = maxMetricValue
            
            VStack(spacing: 8) {
                // Target Guide Line (90% for form, or reference baseline)
                if selectedMetric == .formScore {
                    HStack {
                        Text("Target: 90%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(FitTheme.accentLime.opacity(0.8))
                        Rectangle()
                            .fill(FitTheme.accentLime.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.bottom, 2)
                }
                
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        let val = metricValue(for: session)
                        let ratio = maxVal > 0 ? CGFloat(val) / CGFloat(maxVal) : 0.5
                        let isSelected = selectedSessionIndex == index
                        
                        VStack(spacing: 6) {
                            // Value on top of bar
                            Text("\(Int(val))\(selectedMetric.unit)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isSelected ? FitTheme.accentLime : FitTheme.textSecondary)
                            
                            // The Bar
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: isSelected ?
                                            [FitTheme.accentLime, Color(red: 200/255, green: 255/255, blue: 50/255)] :
                                            [FitTheme.accentLime.opacity(0.85), FitTheme.accentLime.opacity(0.4)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barWidth, height: max(16, (geo.size.height - 40) * ratio))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
                                )
                            
                            // Date label below bar
                            Text(dateFormatter.string(from: session.date))
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : FitTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            selectedSessionIndex = index
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var chartTitle: String {
        switch selectedMetric {
        case .formScore: return "Biomechanical Form Accuracy Trend"
        case .repsAndVolume: return "Workload Volume Tonnage Trend"
        case .heartRate: return "Average Cardiovascular Heart Rate"
        }
    }
    
    private var headlineStat: String {
        switch selectedMetric {
        case .formScore: return "\(store.avgFormAccuracy)"
        case .repsAndVolume: return "\(Int(store.totalVolumeLiftedKg))"
        case .heartRate: return "\(store.currentHeartRate)"
        }
    }
    
    private var maxMetricValue: Double {
        switch selectedMetric {
        case .formScore: return 100.0
        case .repsAndVolume:
            let maxVol = chartSessions.map { $0.totalVolumeKg > 0 ? $0.totalVolumeKg : Double($0.reps) }.max() ?? 100.0
            return max(maxVol, 100.0)
        case .heartRate: return 150.0
        }
    }
    
    private func metricValue(for session: WorkoutSession) -> Double {
        switch selectedMetric {
        case .formScore: return Double(session.score)
        case .repsAndVolume: return session.totalVolumeKg > 0 ? session.totalVolumeKg : Double(session.reps)
        case .heartRate: return Double(session.avgHeartRate)
        }
    }
    
    private func metricValueString(for session: WorkoutSession) -> String {
        switch selectedMetric {
        case .formScore: return "\(session.score)%"
        case .repsAndVolume:
            return session.totalVolumeKg > 0 ? "\(Int(session.totalVolumeKg)) kg" : "\(session.reps) reps"
        case .heartRate: return "\(session.avgHeartRate) BPM"
        }
    }
    
    private func iconFor(type: String) -> String {
        switch type {
        case "SQUAT": return "🏋️‍♂️"
        case "PUSH_UP": return "💪"
        case "LUNGE": return "🦵"
        case "PLANK": return "⏱️"
        case "BICEP_CURL": return "🦾"
        case "DEADLIFT": return "⚡"
        default: return "🏃"
        }
    }
}

// MARK: - Stat Metric Card Component
struct StatMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FitTheme.textSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(tint)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(FitTheme.textSecondary)
        }
        .padding(16)
        .background(FitTheme.cardBackground)
        .cornerRadius(FitTheme.radiusMedium)
        .overlay(RoundedRectangle(cornerRadius: FitTheme.radiusMedium).stroke(FitTheme.cardBorder, lineWidth: 1))
    }
}
