import Foundation

struct Meal: Codable, Identifiable {
    var id: UUID
    var name: String
    var items: [SwiftraxMealItem]
    var isCustom: Bool
    var dateCreated: Date
    
    init(name: String, items: [SwiftraxMealItem] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
        self.isCustom = true
        self.dateCreated = Date()
    }
    
    var totalNutrition: NutritionInfo {
        return items.reduce(NutritionInfo.zero) { result, item in
            let scaledNutrition = item.food.nutritionInfo.scaled(by: item.quantity / item.food.servingSize)
            return result + scaledNutrition
        }
    }
}

struct SwiftraxMealItem: Codable, Identifiable {
    var id: UUID
    var food: Food
    var quantity: Double
    
    init(food: Food, quantity: Double) {
        self.id = UUID()
        self.food = food
        self.quantity = quantity
    }
}
