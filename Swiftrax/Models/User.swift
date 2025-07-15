import Foundation

struct User: Codable, Equatable {
    var trackingPreferences: TrackingPreferences
    var nutritionGoals: NutritionGoals?
    var theme: AppTheme = .system
    
    init() {
        self.trackingPreferences = TrackingPreferences()
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.trackingPreferences == rhs.trackingPreferences &&
               lhs.nutritionGoals == rhs.nutritionGoals &&
               lhs.theme == rhs.theme
    }
}

struct TrackingPreferences: Codable, Equatable {
    var trackCalories: Bool = true
    var trackProtein: Bool = true
    var trackCarbs: Bool = true
    var trackFat: Bool = true
    var trackFiber: Bool = false
    var trackSugar: Bool = false
    var trackSodium: Bool = false
    var trackCholesterol: Bool = false
    var trackSaturatedFat: Bool = false
    var trackTransFat: Bool = false
    var trackCalcium: Bool = false
    var trackIron: Bool = false
    var trackVitaminA: Bool = false
    var trackVitaminC: Bool = false
}

struct NutritionGoals: Codable, Equatable {
    var calorieGoal: Double?
    var proteinGoal: Double?
    var carbGoal: Double?
    var fatGoal: Double?
    var fiberGoal: Double?
    var sugarGoal: Double?
    var sodiumGoal: Double?
}

enum AppTheme: String, CaseIterable, Codable, Equatable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}
