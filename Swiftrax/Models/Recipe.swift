import Foundation

struct Recipe: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var servings: Int
    var ingredients: [RecipeIngredient]
    let dateCreated: Date
    let isCustom: Bool = true
    
    // New: Optional serving weight specification
    var servingWeight: Double? // Weight per serving in grams
    var servingWeightUnit: MeasurementUnit? // Unit for serving weight
    
    init(name: String, servings: Int, ingredients: [RecipeIngredient] = [], servingWeight: Double? = nil, servingWeightUnit: MeasurementUnit? = nil) {
        self.id = UUID()
        self.name = name
        self.servings = servings
        self.ingredients = ingredients
        self.dateCreated = Date()
        self.servingWeight = servingWeight
        self.servingWeightUnit = servingWeightUnit
    }
    
    // Copy initializer for editing existing recipes
    init(from existing: Recipe, name: String, servings: Int, ingredients: [RecipeIngredient], servingWeight: Double?, servingWeightUnit: MeasurementUnit?) {
        self.id = existing.id
        self.name = name
        self.servings = servings
        self.ingredients = ingredients
        self.dateCreated = existing.dateCreated
        self.servingWeight = servingWeight
        self.servingWeightUnit = servingWeightUnit
    }
    
    // Database initializer for reconstructing recipes from database data (preserves ID and date)
    init(id: UUID, name: String, servings: Int, ingredients: [RecipeIngredient], dateCreated: Date, servingWeight: Double?, servingWeightUnit: MeasurementUnit?) {
        self.id = id
        self.name = name
        self.servings = servings
        self.ingredients = ingredients
        self.dateCreated = dateCreated
        self.servingWeight = servingWeight
        self.servingWeightUnit = servingWeightUnit
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
    
    // Convert recipe to a Food object for logging to meals
    func asFood() -> Food {
        let servingSize: Double
        let servingUnit: String
        
        if let weight = servingWeight, let unit = servingWeightUnit {
            servingSize = weight
            servingUnit = unit.abbreviation
        } else {
            // Default to 1 serving if no weight specified
            servingSize = 1.0
            servingUnit = "serving"
        }
        
        var food = Food(
            name: name,
            nutritionInfo: nutritionPerServing,
            servingSize: servingSize,
            servingSizeUnit: servingUnit,
            brand: "Recipe",
            isCustom: true
        )
        food.recipeId = id
        return food
    }
}

struct RecipeIngredient: Identifiable, Codable, Equatable {
    let id: UUID
    let food: Food
    var quantity: Double
    var unit: MeasurementUnit // New: allows different units for recipe ingredients
    
    init(food: Food, quantity: Double, unit: MeasurementUnit? = nil) {
        self.id = UUID()
        self.food = food
        self.quantity = quantity
        // Default to the food's original unit if none specified
        self.unit = unit ?? (MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams)
    }
    
    // Database initializer for reconstructing ingredients from database data (preserves ID)
    init(id: UUID, food: Food, quantity: Double, unit: MeasurementUnit) {
        self.id = id
        self.food = food
        self.quantity = quantity
        self.unit = unit
    }
    
    // Calculate nutrition contribution of this ingredient to the recipe
    var nutritionContribution: NutritionInfo {
        // Convert ingredient quantity to food's base unit for calculation
        let foodOriginalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        let convertedQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: foodOriginalUnit) {
            convertedQuantity = converted
        } else {
            // If conversion fails, assume same quantity (for count units, etc.)
            convertedQuantity = quantity
        }
        
        let scaleFactor = convertedQuantity / food.servingSize
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
    
    // Display text for this ingredient
    var displayText: String {
        return "\(quantity.formattedNutrition) \(unit.abbreviation)"
    }
}
