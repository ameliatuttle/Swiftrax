import Foundation

struct FoodEntry: Codable, Identifiable {
    var id: UUID
    var food: Food
    var quantity: Double
    var mealType: MealType
    var dateLogged: Date
    var notes: String?
    
    // Standard initializer for new entries
    init(food: Food, quantity: Double, mealType: MealType, dateLogged: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.food = food
        self.quantity = quantity
        self.mealType = mealType
        self.dateLogged = dateLogged
        self.notes = notes
    }
    
    // Initializer for database loading with existing ID
    init(id: UUID, food: Food, quantity: Double, mealType: MealType, dateLogged: Date, notes: String? = nil) {
        self.id = id
        self.food = food
        self.quantity = quantity
        self.mealType = mealType
        self.dateLogged = dateLogged
        self.notes = notes
    }
    
    // Calculate nutrition based on actual quantity consumed
    var scaledNutrition: NutritionInfo {
        let scaleFactor = quantity / food.servingSize
        return food.nutritionInfo.scaled(by: scaleFactor)
    }
}

enum MealType: String, CaseIterable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    
    var emoji: String {
        switch self {
        case .breakfast:
            return "🌅"
        case .lunch:
            return "☀️"
        case .dinner:
            return "🌙"
        case .snack:
            return "🍎"
        }
    }
}
