import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModelMain()
    
   var body: some View {
       NavigationView {
           ScrollView {
               VStack(spacing: 16) {
                   HorizontalNutritionSummaryView(
                       totalNutrition: viewModel.dailyNutrition,
                       goals: viewModel.userSettings.nutritionGoals,
                       trackingPreferences: viewModel.userSettings.trackingPreferences
                   )
                   
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
           .background(Color.appBackground)
           .frame(maxWidth: .infinity, maxHeight: .infinity)
           .navigationTitle("Dashboard")
           .navigationBarTitleDisplayMode(.inline)
           .refreshable {
               await MainActor.run {
                   viewModel.loadEntries(for: Date())
                   viewModel.loadUserSettings()
               }
           }
           .onAppear {
               viewModel.setupNotificationObserver()
               Task { @MainActor in
                   viewModel.loadEntries(for: Date())
                   viewModel.loadUserSettings()
               }
           }
       }
       .navigationViewStyle(StackNavigationViewStyle())
   }
}

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
                        color: Color.nutritionOrange
                    )
                }
                
                if trackingPreferences.trackProtein {
                    NutritionMetricCard(
                        title: "Protein",
                        value: totalNutrition.protein ?? 0,
                        goal: goals?.proteinGoal,
                        unit: "g",
                        color: Color.nutritionRed
                    )
                }
                
                if trackingPreferences.trackCarbs {
                    NutritionMetricCard(
                        title: "Carbs",
                        value: totalNutrition.carbohydrates ?? 0,
                        goal: goals?.carbGoal,
                        unit: "g",
                        color: Color.nutritionBlue
                    )
                }
                
                if trackingPreferences.trackFat {
                    NutritionMetricCard(
                        title: "Fat",
                        value: totalNutrition.fat ?? 0,
                        goal: goals?.fatGoal,
                        unit: "g",
                        color: Color.nutritionPurple
                    )
                }
                
                if trackingPreferences.trackFiber {
                    NutritionMetricCard(
                        title: "Fiber",
                        value: totalNutrition.fiber ?? 0,
                        goal: goals?.fiberGoal,
                        unit: "g",
                        color: Color.nutritionGreen
                    )
                }
                
                if trackingPreferences.trackSugar {
                    NutritionMetricCard(
                        title: "Sugar",
                        value: totalNutrition.sugar ?? 0,
                        goal: goals?.sugarGoal,
                        unit: "g",
                        color: Color.nutritionPink
                    )
                }
                
                if trackingPreferences.trackSodium {
                    NutritionMetricCard(
                        title: "Sodium",
                        value: totalNutrition.sodium ?? 0,
                        goal: goals?.sodiumGoal,
                        unit: "mg",
                        color: Color.nutritionYellow
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

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
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptiveSecondaryText)
            
            Text("\(Int(value))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            if let goal = goal {
                VStack(spacing: 4) {
                    Text("/ \(Int(goal)) \(unit)")
                        .font(.caption2)
                        .foregroundColor(Color.adaptiveSecondaryText)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.fillSecondary)
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
                    .foregroundColor(Color.adaptiveSecondaryText)
            }
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.nutritionCardBackground)
        .cornerRadius(12)
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.12) :
                   Color.black.opacity(0.12),
            radius: 3, x: 0, y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(Int(value)) \(unit)")
        .accessibilityValue(goal != nil ? "Goal: \(Int(goal!)) \(unit)" : "")
    }
}

class DashboardViewModelMain: ObservableObject {
    @Published var foodEntries: [FoodEntry] = []
    @Published var userSettings = User()
    @Published var isLoading = false
    
    private let databaseManager = DatabaseManager.shared
    private var hasSetupObserver = false
    
    // Calculates total nutrition from all food entries
    var dailyNutrition: NutritionInfo {
        return foodEntries.totalNutrition()
    }
    
    // Sets up notification observer to refresh data when entries are added
    func setupNotificationObserver() {
        guard !hasSetupObserver else { return }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FoodEntryAdded"),
            object: nil,
            queue: .main
        ) { _ in
            print("Dashboard refreshing after food entry added")
            Task { @MainActor in
                self.loadEntries(for: Date())
            }
        }
        hasSetupObserver = true
    }
    
    @MainActor
    func loadEntries(for date: Date) {
        isLoading = true
        
        databaseManager.getFoodEntriesThreadSafe(for: date) { entries in
            Task { @MainActor in
                print("Dashboard loaded \(entries.count) food entries")
                self.foodEntries = entries
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    func loadUserSettings() {
        databaseManager.getUserSettingsAsync { user in
            Task { @MainActor in
                self.userSettings = user
            }
        }
    }
    
    // Deletes food entry from both UI and database
    @MainActor
    func deleteEntry(_ entry: FoodEntry) {
        foodEntries.removeAll { $0.id == entry.id }
        
        databaseManager.deleteEntryThreadSafe(entry) { success in
            Task { @MainActor in
                if success {
                    print("Food entry deleted successfully")
                    self.loadEntries(for: Date())
                } else {
                    print("Failed to delete food entry")
                    self.loadEntries(for: Date())
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
