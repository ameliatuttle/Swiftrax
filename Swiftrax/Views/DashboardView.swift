import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModelMain()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Horizontal Nutrition Summary
                    HorizontalNutritionSummaryView(
                        totalNutrition: viewModel.dailyNutrition,
                        goals: viewModel.userSettings.nutritionGoals,
                        trackingPreferences: viewModel.userSettings.trackingPreferences
                    )
                    
                    // Meal Sections
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        MealSectionView(
                            mealType: mealType,
                            entries: viewModel.foodEntries.filteredByMealType(mealType),
                            onDeleteEntry: { entry in
                                viewModel.deleteEntry(entry)
                            }
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color.appBackground) // Consistent grouped background
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.loadEntries(for: Date())
                viewModel.loadUserSettings()
            }
            .onAppear {
                Swift.print("📊 Dashboard: View appeared")
                viewModel.setupNotificationObserver()
                viewModel.loadEntries(for: Date())
                viewModel.loadUserSettings()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
   
}

// MARK: - Horizontal Nutrition Summary
struct HorizontalNutritionSummaryView: View {
    let totalNutrition: NutritionInfo
    let goals: NutritionGoals?
    let trackingPreferences: TrackingPreferences
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if trackingPreferences.trackCalories {
                    NutritionMetricCard(
                        title: "Calories",
                        value: totalNutrition.calories ?? 0,
                        goal: goals?.calorieGoal,
                        unit: "kcal",
                        color: Color.nutritionOrange // Updated to use semantic color
                    )
                }
                
                if trackingPreferences.trackProtein {
                    NutritionMetricCard(
                        title: "Protein",
                        value: totalNutrition.protein ?? 0,
                        goal: goals?.proteinGoal,
                        unit: "g",
                        color: Color.nutritionRed // Updated to use semantic color
                    )
                }
                
                if trackingPreferences.trackCarbs {
                    NutritionMetricCard(
                        title: "Carbs",
                        value: totalNutrition.carbohydrates ?? 0,
                        goal: goals?.carbGoal,
                        unit: "g",
                        color: Color.nutritionBlue // Updated to use semantic color
                    )
                }
                
                if trackingPreferences.trackFat {
                    NutritionMetricCard(
                        title: "Fat",
                        value: totalNutrition.fat ?? 0,
                        goal: goals?.fatGoal,
                        unit: "g",
                        color: Color.nutritionPurple // Updated to use semantic color
                    )
                }
                
                // Additional nutrients if tracking
                if trackingPreferences.trackFiber {
                    NutritionMetricCard(
                        title: "Fiber",
                        value: totalNutrition.fiber ?? 0,
                        goal: goals?.fiberGoal,
                        unit: "g",
                        color: Color.nutritionGreen // Updated to use semantic color
                    )
                }
                
                if trackingPreferences.trackSugar {
                    NutritionMetricCard(
                        title: "Sugar",
                        value: totalNutrition.sugar ?? 0,
                        goal: goals?.sugarGoal,
                        unit: "g",
                        color: Color.nutritionPink // Updated to use semantic color
                    )
                }
                
                if trackingPreferences.trackSodium {
                    NutritionMetricCard(
                        title: "Sodium",
                        value: totalNutrition.sodium ?? 0,
                        goal: goals?.sodiumGoal,
                        unit: "mg",
                        color: Color.nutritionYellow // Updated to use semantic color
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Nutrition Metric Card (Enhanced for Apple Guidelines)
struct NutritionMetricCard: View {
    let title: String
    let value: Double
    let goal: Double?
    let unit: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var progressPercentage: Double {
        guard let goal = goal, goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Title
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
            
            // Value
            Text("\(Int(value))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            // Goal and progress
            if let goal = goal {
                VStack(spacing: 4) {
                    Text("/ \(Int(goal)) \(unit)")
                        .font(.caption2)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.fillSecondary) // Using semantic fill color
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(color)
                                .frame(width: geometry.size.width * progressPercentage, height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                }
            } else {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
            }
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.nutritionCardBackground) // Consistent white cards
        .cornerRadius(12)
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.12) :
                   Color.black.opacity(0.12),
            radius: 3, x: 0, y: 2
        )
        .accessibilityElement(children: .combine) // Better accessibility
        .accessibilityLabel("\(title): \(Int(value)) \(unit)")
        .accessibilityValue(goal != nil ? "Goal: \(Int(goal!)) \(unit)" : "")
    }
}

// MARK: - Dashboard ViewModel (Unchanged)
class DashboardViewModelMain: ObservableObject {
    @Published var foodEntries: [FoodEntry] = []
    @Published var userSettings = User()
    @Published var isLoading = false
    
    private let databaseManager = DatabaseManager.shared
    private var hasSetupObserver = false
    
    var dailyNutrition: NutritionInfo {
        let nutrition = foodEntries.totalNutrition()
        Swift.print("📊 Dashboard: Calculated daily nutrition - Calories: \(nutrition.calories ?? 0)")
        return nutrition
    }
    
    func setupNotificationObserver() {
        guard !hasSetupObserver else { return }
        
        Swift.print("🔔 Dashboard: Setting up notification observer")
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FoodEntryAdded"),
            object: nil,
            queue: .main
        ) { _ in
            Swift.print("📢 Dashboard: Received FoodEntryAdded notification, refreshing...")
            self.loadEntries(for: Date())
        }
        hasSetupObserver = true
    }
    
    func loadEntries(for date: Date) {
        Swift.print("📊 Dashboard: Loading entries for \(DateFormatters.shared.dayFormatter.string(from: date))")
        isLoading = true
        
        DatabaseManager.shared.getFoodEntriesThreadSafe(for: date) { entries in
            Swift.print("📊 Dashboard: Found \(entries.count) entries in database")
            for entry in entries {
                Swift.print("📊 Dashboard: Entry - \(entry.food.name) (\(entry.mealType.rawValue)) - \(entry.food.nutritionInfo.calories ?? 0) cal")
            }
            
            self.foodEntries = entries
            self.isLoading = false
            Swift.print("📊 Dashboard: Updated UI with \(entries.count) entries")
            
            // Force UI update for nutrition summary
            self.objectWillChange.send()
        }
    }
    
    func loadUserSettings() {
        DatabaseManager.shared.getUserSettingsAsync { user in
            self.userSettings = user
        }
    }
    
    func deleteEntry(_ entry: FoodEntry) {
        foodEntries.removeAll { $0.id == entry.id }
        // TODO: Implement database deletion
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
