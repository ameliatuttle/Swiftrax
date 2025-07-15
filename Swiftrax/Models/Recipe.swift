import Foundation

// MARK: - Simplified Recipe Model
struct Recipe: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var servings: Int // Total servings the recipe makes
    var ingredients: [RecipeIngredient]
    let dateCreated: Date
    let isCustom: Bool = true
    
    init(name: String, servings: Int, ingredients: [RecipeIngredient] = []) {
        self.id = UUID()
        self.name = name
        self.servings = servings
        self.ingredients = ingredients
        self.dateCreated = Date()
    }
    
    // Calculate total nutrition for entire recipe
    var totalNutrition: NutritionInfo {
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        var totalFiber: Double = 0
        var totalSugar: Double = 0
        var totalSodium: Double = 0
        
        for ingredient in ingredients {
            let scaleFactor = ingredient.quantity / ingredient.food.servingSize
            let ingredientNutrition = ingredient.food.nutritionInfo
            
            totalCalories += (ingredientNutrition.calories ?? 0) * scaleFactor
            totalProtein += (ingredientNutrition.protein ?? 0) * scaleFactor
            totalCarbs += (ingredientNutrition.carbohydrates ?? 0) * scaleFactor
            totalFat += (ingredientNutrition.fat ?? 0) * scaleFactor
            totalFiber += (ingredientNutrition.fiber ?? 0) * scaleFactor
            totalSugar += (ingredientNutrition.sugar ?? 0) * scaleFactor
            totalSodium += (ingredientNutrition.sodium ?? 0) * scaleFactor
        }
        
        return NutritionInfo(
            calories: totalCalories,
            protein: totalProtein,
            carbohydrates: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            sugar: totalSugar,
            sodium: totalSodium
        )
    }
    
    // Calculate nutrition per serving
    var nutritionPerServing: NutritionInfo {
        let total = totalNutrition
        let servingCount = Double(servings)
        
        return NutritionInfo(
            calories: (total.calories ?? 0) / servingCount,
            protein: (total.protein ?? 0) / servingCount,
            carbohydrates: (total.carbohydrates ?? 0) / servingCount,
            fat: (total.fat ?? 0) / servingCount,
            fiber: (total.fiber ?? 0) / servingCount,
            sugar: (total.sugar ?? 0) / servingCount,
            sodium: (total.sodium ?? 0) / servingCount
        )
    }
    
    // Convert recipe to a Food object (for logging purposes)
    func asFood() -> Food {
        var food = Food(
            name: name,
            nutritionInfo: nutritionPerServing,
            servingSize: 1.0,
            servingSizeUnit: "serving",
            brand: "Recipe",
            isCustom: true
        )
        food.recipeId = id
        return food
    }
}

// MARK: - Recipe Ingredient Model
struct RecipeIngredient: Identifiable, Codable, Equatable {
    let id: UUID
    let food: Food
    var quantity: Double // Amount of this ingredient used
    
    init(food: Food, quantity: Double) {
        self.id = UUID()
        self.food = food
        self.quantity = quantity
    }
    
    // Calculate nutrition contribution of this ingredient to the recipe
    var nutritionContribution: NutritionInfo {
        let scaleFactor = quantity / food.servingSize
        let baseNutrition = food.nutritionInfo
        
        return NutritionInfo(
            calories: (baseNutrition.calories ?? 0) * scaleFactor,
            protein: (baseNutrition.protein ?? 0) * scaleFactor,
            carbohydrates: (baseNutrition.carbohydrates ?? 0) * scaleFactor,
            fat: (baseNutrition.fat ?? 0) * scaleFactor,
            fiber: (baseNutrition.fiber ?? 0) * scaleFactor,
            sugar: (baseNutrition.sugar ?? 0) * scaleFactor,
            sodium: (baseNutrition.sodium ?? 0) * scaleFactor
        )
    }
}
