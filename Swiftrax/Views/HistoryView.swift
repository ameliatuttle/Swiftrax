// fix bounce back .onAppear

import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModelMain()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedTimeRange) { _ in
                    viewModel.loadHistory(for: selectedTimeRange)
                }
            }
            .padding()
            
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading history...")
                    Spacer()
                }
            } else if viewModel.dailyData.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "chart.bar")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No history yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Start logging foods to see your progress here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        HStack {
                            Text("Daily Progress")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Label("Actual", systemImage: "circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Label("Goal", systemImage: "circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                        }
                        .padding(.horizontal)
                        
                        DailyProgressBarChart(
                            dailyData: viewModel.dailyData,
                            userGoals: viewModel.userGoals
                        )
                        
                        HistorySummaryView(
                            dailyData: viewModel.dailyData,
                            userGoals: viewModel.userGoals,
                            timeRange: selectedTimeRange
                        )
                    }
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .background(Color.appBackground)
        .onAppear {
            // Only load data on first appear or when explicitly refreshing
            if !hasAppeared {
                hasAppeared = true
                viewModel.loadHistory(for: selectedTimeRange)
                viewModel.loadUserGoals()
            }
        }
        .refreshable {
            // Explicit refresh when user pulls down
            viewModel.loadHistory(for: selectedTimeRange)
            viewModel.loadUserGoals()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DailyProgressBarChart: View {
    let dailyData: [DailyNutritionData]
    let userGoals: NutritionGoals?
    
    private let chartHeight: CGFloat = 200
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let barWidth = max(20, (geometry.size.width - 32) / CGFloat(dailyData.count) - 8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(dailyData.sorted(by: { $0.date < $1.date })) { data in
                            DailyBarView(
                                data: data,
                                goals: userGoals,
                                maxHeight: chartHeight - 40,
                                barWidth: barWidth
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(height: chartHeight)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct DailyBarView: View {
    let data: DailyNutritionData
    let goals: NutritionGoals?
    let maxHeight: CGFloat
    let barWidth: CGFloat
    
    private var maxGoal: Double {
        guard let goals = goals else { return 2500 }
        return max(
            goals.calorieGoal ?? 2000,
            goals.proteinGoal ?? 150,
            goals.carbGoal ?? 250,
            goals.fatGoal ?? 80
        )
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                if let calorieGoal = goals?.calorieGoal {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(
                            width: barWidth,
                            height: CGFloat(calorieGoal / maxGoal) * maxHeight
                        )
                        .cornerRadius(4)
                }
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: barWidth,
                        height: CGFloat(data.totalCalories / maxGoal) * maxHeight
                    )
                    .cornerRadius(4)
                
                if let calorieGoal = goals?.calorieGoal {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(
                            width: barWidth + 4,
                            height: 2
                        )
                        .offset(y: -CGFloat(calorieGoal / maxGoal) * maxHeight)
                }
            }
            
            Text(formatDateForChart(data.date))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    private func formatDateForChart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct HistorySummaryView: View {
    let dailyData: [DailyNutritionData]
    let userGoals: NutritionGoals?
    let timeRange: TimeRange
    
    private var averageCalories: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.map { $0.totalCalories }.reduce(0, +) / Double(dailyData.count)
    }
    
    // Calculates days within 20% of calorie goal
    private var daysOnTrack: Int {
        guard let calorieGoal = userGoals?.calorieGoal else { return 0 }
        return dailyData.filter { data in
            let percentage = data.totalCalories / calorieGoal
            return percentage >= 0.8 && percentage <= 1.2
        }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                SummaryCard(
                    title: "Avg Daily Calories",
                    value: "\(Int(averageCalories))",
                    subtitle: "kcal",
                    color: .blue
                )
                
                SummaryCard(
                    title: "Days On Track",
                    value: "\(daysOnTrack)",
                    subtitle: "out of \(dailyData.count)",
                    color: .green
                )
                
                if let calorieGoal = userGoals?.calorieGoal {
                    let adherencePercentage = dailyData.isEmpty ? 0 : (averageCalories / calorieGoal) * 100
                    SummaryCard(
                        title: "Goal Adherence",
                        value: "\(Int(adherencePercentage))%",
                        subtitle: "of target",
                        color: adherencePercentage >= 80 ? .green : .orange
                    )
                }
                
                SummaryCard(
                    title: "Total Days",
                    value: "\(dailyData.count)",
                    subtitle: timeRange.rawValue.lowercased(),
                    color: .purple
                )
            }
        }
        .padding()
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DailyNutritionData: Identifiable {
    let id = UUID()
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let entryCount: Int
}

class HistoryViewModelMain: ObservableObject {
    @Published var dailyData: [DailyNutritionData] = []
    @Published var userGoals: NutritionGoals?
    @Published var isLoading = false
    
    private let databaseManager = DatabaseManager.shared
    
    // Loads nutrition history for the specified time range
    func loadHistory(for timeRange: TimeRange) {
        isLoading = true
        print("Loading history for \(timeRange.rawValue)")
        
        let endDate = Date()
        let startDate = timeRange.startDate(from: endDate)
        
        databaseManager.getAllFoodEntriesThreadSafe(from: startDate, to: endDate) { allEntries in
            print("Retrieved \(allEntries.count) food entries for history")
            
            DispatchQueue.global(qos: .background).async {
                var dailyDataArray: [DailyNutritionData] = []
                var currentDate = startDate
                let calendar = Calendar.current
                
                while currentDate <= endDate {
                    let dayEntries = allEntries.filter { entry in
                        calendar.isDate(entry.dateLogged, inSameDayAs: currentDate)
                    }
                    
                    if !dayEntries.isEmpty {
                        let totalNutrition = dayEntries.totalNutrition()
                        
                        let dailyData = DailyNutritionData(
                            date: currentDate,
                            totalCalories: totalNutrition.calories ?? 0,
                            totalProtein: totalNutrition.protein ?? 0,
                            totalCarbs: totalNutrition.carbohydrates ?? 0,
                            totalFat: totalNutrition.fat ?? 0,
                            entryCount: dayEntries.count
                        )
                        
                        dailyDataArray.append(dailyData)
                    }
                    
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
                }
                
                DispatchQueue.main.async {
                    self.dailyData = dailyDataArray
                    self.isLoading = false
                    print("History loaded: \(dailyDataArray.count) days of data")
                }
            }
        }
    }
    
    func loadUserGoals() {
        databaseManager.getUserSettingsAsync { user in
            self.userGoals = user.nutritionGoals
        }
    }
}

enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    
    func startDate(from endDate: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        }
    }
}
