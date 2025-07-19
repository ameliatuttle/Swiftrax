import Foundation

struct NutritionInfo: Codable {
    var calories: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var cholesterol: Double?
    var saturatedFat: Double?
    var transFat: Double?
    var calcium: Double?
    var iron: Double?
    var vitaminA: Double?
    var vitaminC: Double?
    
    init(calories: Double? = nil, protein: Double? = nil, carbohydrates: Double? = nil, fat: Double? = nil, fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, cholesterol: Double? = nil, saturatedFat: Double? = nil, transFat: Double? = nil, calcium: Double? = nil, iron: Double? = nil, vitaminA: Double? = nil, vitaminC: Double? = nil) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.cholesterol = cholesterol
        self.saturatedFat = saturatedFat
        self.transFat = transFat
        self.calcium = calcium
        self.iron = iron
        self.vitaminA = vitaminA
        self.vitaminC = vitaminC
    }
    
    static let zero = NutritionInfo()
    
    // Add two nutrition info objects together
    static func + (lhs: NutritionInfo, rhs: NutritionInfo) -> NutritionInfo {
        return NutritionInfo(
            calories: (lhs.calories ?? 0) + (rhs.calories ?? 0),
            protein: (lhs.protein ?? 0) + (rhs.protein ?? 0),
            carbohydrates: (lhs.carbohydrates ?? 0) + (rhs.carbohydrates ?? 0),
            fat: (lhs.fat ?? 0) + (rhs.fat ?? 0),
            fiber: (lhs.fiber ?? 0) + (rhs.fiber ?? 0),
            sugar: (lhs.sugar ?? 0) + (rhs.sugar ?? 0),
            sodium: (lhs.sodium ?? 0) + (rhs.sodium ?? 0),
            cholesterol: (lhs.cholesterol ?? 0) + (rhs.cholesterol ?? 0),
            saturatedFat: (lhs.saturatedFat ?? 0) + (rhs.saturatedFat ?? 0),
            transFat: (lhs.transFat ?? 0) + (rhs.transFat ?? 0),
            calcium: (lhs.calcium ?? 0) + (rhs.calcium ?? 0),
            iron: (lhs.iron ?? 0) + (rhs.iron ?? 0),
            vitaminA: (lhs.vitaminA ?? 0) + (rhs.vitaminA ?? 0),
            vitaminC: (lhs.vitaminC ?? 0) + (rhs.vitaminC ?? 0)
        )
    }
    
    // Scale all nutrition values by a factor (for portion calculations)
    func scaled(by factor: Double) -> NutritionInfo {
        let scaledCalories = calories.map { $0 * factor }
        let scaledProtein = protein.map { $0 * factor }
        let scaledCarbohydrates = carbohydrates.map { $0 * factor }
        let scaledFat = fat.map { $0 * factor }
        let scaledFiber = fiber.map { $0 * factor }
        let scaledSugar = sugar.map { $0 * factor }
        let scaledSodium = sodium.map { $0 * factor }
        let scaledCholesterol = cholesterol.map { $0 * factor }
        let scaledSaturatedFat = saturatedFat.map { $0 * factor }
        let scaledTransFat = transFat.map { $0 * factor }
        let scaledCalcium = calcium.map { $0 * factor }
        let scaledIron = iron.map { $0 * factor }
        let scaledVitaminA = vitaminA.map { $0 * factor }
        let scaledVitaminC = vitaminC.map { $0 * factor }
        
        return NutritionInfo(
            calories: scaledCalories,
            protein: scaledProtein,
            carbohydrates: scaledCarbohydrates,
            fat: scaledFat,
            fiber: scaledFiber,
            sugar: scaledSugar,
            sodium: scaledSodium,
            cholesterol: scaledCholesterol,
            saturatedFat: scaledSaturatedFat,
            transFat: scaledTransFat,
            calcium: scaledCalcium,
            iron: scaledIron,
            vitaminA: scaledVitaminA,
            vitaminC: scaledVitaminC
        )
    }
}
