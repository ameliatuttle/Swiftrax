// fix bounce back .onAppear

import SwiftUI
import Charts

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModelMain()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedNutrient: NutrientType = .calories
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
                        }
                        .padding(.horizontal)
                        
                        SingleNutrientChart(
                            dailyData: viewModel.dailyData,
                            userGoals: viewModel.userGoals,
                            timeRange: selectedTimeRange,
                            selectedNutrient: selectedNutrient
                        )
                        
                        HistorySummaryView(
                            dailyData: viewModel.dailyData,
                            userGoals: viewModel.userGoals,
                            timeRange: selectedTimeRange,
                            selectedNutrient: $selectedNutrient
                        )
                    }
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
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


struct HistorySummaryView: View {
    let dailyData: [DailyNutritionData]
    let userGoals: NutritionGoals?
    let timeRange: TimeRange
    @Binding var selectedNutrient: NutrientType
    
    private var averageCalories: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.map { $0.totalCalories }.reduce(0, +) / Double(dailyData.count)
    }
    
    private var averageProtein: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.map { $0.totalProtein }.reduce(0, +) / Double(dailyData.count)
    }
    
    private var averageCarbs: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.map { $0.totalCarbs }.reduce(0, +) / Double(dailyData.count)
    }
    
    private var averageFat: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.map { $0.totalFat }.reduce(0, +) / Double(dailyData.count)
    }
    
    private var averageFiber: Double {
        guard !dailyData.isEmpty else { return 0 }
        return dailyData.map { $0.totalFiber }.reduce(0, +) / Double(dailyData.count)
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
            Text("Average Daily Intake")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                SelectableSummaryCard(
                    title: "Avg Calories",
                    value: "\(Int(averageCalories))",
                    subtitle: "kcal",
                    color: .blue,
                    nutrientType: .calories,
                    isSelected: selectedNutrient == .calories
                ) {
                    selectedNutrient = .calories
                }
                
                SelectableSummaryCard(
                    title: "Avg Protein",
                    value: "\(Int(averageProtein))",
                    subtitle: "g",
                    color: .red,
                    nutrientType: .protein,
                    isSelected: selectedNutrient == .protein
                ) {
                    selectedNutrient = .protein
                }
                
                SelectableSummaryCard(
                    title: "Avg Carbs",
                    value: "\(Int(averageCarbs))",
                    subtitle: "g",
                    color: .green,
                    nutrientType: .carbs,
                    isSelected: selectedNutrient == .carbs
                ) {
                    selectedNutrient = .carbs
                }
                
                SelectableSummaryCard(
                    title: "Avg Fat",
                    value: "\(Int(averageFat))",
                    subtitle: "g",
                    color: .purple,
                    nutrientType: .fat,
                    isSelected: selectedNutrient == .fat
                ) {
                    selectedNutrient = .fat
                }
                
                if averageFiber > 0 {
                    SelectableSummaryCard(
                        title: "Avg Fiber",
                        value: "\(Int(averageFiber))",
                        subtitle: "g",
                        color: .green,
                        nutrientType: .fiber,
                        isSelected: selectedNutrient == .fiber
                    ) {
                        selectedNutrient = .fiber
                    }
                }
                
                SelectableSummaryCard(
                    title: "Days Tracked",
                    value: "\(dailyData.count)",
                    subtitle: timeRange.rawValue.lowercased(),
                    color: .gray,
                    nutrientType: nil,
                    isSelected: false
                ) {
                    // Non-selectable
                }
            }
        }
        .padding()
    }
}

struct SelectableSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let nutrientType: NutrientType?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
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
            .background(color.opacity(isSelected ? 0.3 : 0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(nutrientType == nil) // Disable "Days Tracked" card
    }
}

// MARK: - Single Nutrient Chart
struct SingleNutrientChart: View {
    let dailyData: [DailyNutritionData]
    let userGoals: NutritionGoals?
    let timeRange: TimeRange
    let selectedNutrient: NutrientType
    
    private var sortedData: [DailyNutritionData] {
        dailyData.sorted(by: { $0.date < $1.date })
    }
    
    private var goal: Double? {
        selectedNutrient.getGoal(from: userGoals)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(selectedNutrient.rawValue) Trend")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedNutrient.color)
                
                Spacer()
                
                if let goal = goal {
                    Text("Goal: \(Int(goal))\(selectedNutrient.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            Chart(sortedData) { dataPoint in
                BarMark(
                    x: .value("Date", dataPoint.date, unit: .day),
                    y: .value(selectedNutrient.rawValue, selectedNutrient.getValue(from: dataPoint))
                )
                .foregroundStyle(selectedNutrient.color)
                .cornerRadius(3)
                
                // Goal line
                if let goal = goal, goal > 0 {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(selectedNutrient.color.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks(values: .stride(by: getXAxisStride())) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.secondary.opacity(0.2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue))")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(.secondary.opacity(0.2))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedNutrient)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func getXAxisStride() -> Calendar.Component {
        switch timeRange {
        case .week: return .day
        case .month: return .weekOfYear  
        case .threeMonths: return .month
        }
    }
}

struct DailyNutritionData: Identifiable {
    let id = UUID()
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let totalFiber: Double
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
                            totalFiber: totalNutrition.fiber ?? 0,
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

// MARK: - Nutrient Types for Chart Selection
enum NutrientType: String, CaseIterable {
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    case fiber = "Fiber"
    
    var color: Color {
        switch self {
        case .calories: return .blue
        case .protein: return .red
        case .carbs: return .green
        case .fat: return .purple
        case .fiber: return .orange
        }
    }
    
    var unit: String {
        switch self {
        case .calories: return "kcal"
        default: return "g"
        }
    }
    
    func getValue(from data: DailyNutritionData) -> Double {
        switch self {
        case .calories: return data.totalCalories
        case .protein: return data.totalProtein
        case .carbs: return data.totalCarbs
        case .fat: return data.totalFat
        case .fiber: return data.totalFiber
        }
    }
    
    func getGoal(from goals: NutritionGoals?) -> Double? {
        switch self {
        case .calories: return goals?.calorieGoal
        case .protein: return goals?.proteinGoal
        case .carbs: return goals?.carbGoal
        case .fat: return goals?.fatGoal
        case .fiber: return goals?.fiberGoal
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
