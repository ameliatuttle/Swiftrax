import Foundation

struct MealItem: Identifiable, Codable {
    var id: Int?
    var food: Food
    var quantity: Double
    var unit: String
    
    init(id: Int? = nil,
         food: Food,
         quantity: Double = 1.0,
         unit: String = "g") {
        self.id = id
        self.food = food
        self.quantity = quantity
        self.unit = unit
    }
    
    // Calculate scaled calories based on quantity (assumes 100g base)
    func scaledCalories() -> Int {
        guard let calories = food.nutritionInfo.calories else { return 0 }
        return Int(Double(calories) * (quantity / 100.0))
    }
    
    // Calculate all scaled nutrition values based on quantity
    func scaledNutrition() -> NutritionInfo {
        let scale = quantity / 100.0
        
        let scaledCalories = food.nutritionInfo.calories != nil ? food.nutritionInfo.calories! * scale : nil
        let scaledProtein = food.nutritionInfo.protein != nil ? food.nutritionInfo.protein! * scale : nil
        let scaledCarbohydrates = food.nutritionInfo.carbohydrates != nil ? food.nutritionInfo.carbohydrates! * scale : nil
        let scaledFat = food.nutritionInfo.fat != nil ? food.nutritionInfo.fat! * scale : nil
        let scaledFiber = food.nutritionInfo.fiber != nil ? food.nutritionInfo.fiber! * scale : nil
        let scaledSugar = food.nutritionInfo.sugar != nil ? food.nutritionInfo.sugar! * scale : nil
        let scaledSodium = food.nutritionInfo.sodium != nil ? food.nutritionInfo.sodium! * scale : nil
        let scaledCholesterol = food.nutritionInfo.cholesterol != nil ? food.nutritionInfo.cholesterol! * scale : nil
        
        return NutritionInfo(
            calories: scaledCalories,
            protein: scaledProtein,
            carbohydrates: scaledCarbohydrates,
            fat: scaledFat,
            fiber: scaledFiber,
            sugar: scaledSugar,
            sodium: scaledSodium,
            cholesterol: scaledCholesterol
        )
    }
}
