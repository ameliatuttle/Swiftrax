import Foundation

struct FoodEntry: Codable, Identifiable {
    var id: UUID
    var food: Food
    var quantity: Double
    var mealType: MealType
    var dateLogged: Date
    var notes: String?
    
    init(food: Food, quantity: Double, mealType: MealType, dateLogged: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.food = food
        self.quantity = quantity
        self.mealType = mealType
        self.dateLogged = dateLogged
        self.notes = notes
    }
    
    // Custom initializer for database loading
    init(id: UUID, food: Food, quantity: Double, mealType: MealType, dateLogged: Date, notes: String? = nil) {
        self.id = id
        self.food = food
        self.quantity = quantity
        self.mealType = mealType
        self.dateLogged = dateLogged
        self.notes = notes
    }
    
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

// MARK: - Unit Conversion Extensions
extension FoodEntry {
    // Calculate nutrition with unit conversion
    func nutritionForQuantity(_ quantity: Double, unit: MeasurementUnit) -> NutritionInfo {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        // Convert the quantity to the food's original unit
        let convertedQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: originalUnit) {
            convertedQuantity = converted
        } else {
            // If conversion not possible, use quantity as-is
            convertedQuantity = quantity
        }
        
        // Calculate scaling factor
        let scaleFactor = convertedQuantity / food.servingSize
        
        return food.nutritionInfo.scaled(by: scaleFactor)
    }
    
    // Create food entry with specific unit
    static func create(food: Food, quantity: Double, unit: MeasurementUnit, mealType: MealType) -> FoodEntry {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        // Convert quantity to food's original unit for storage
        let storageQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: originalUnit) {
            storageQuantity = converted
        } else {
            // If conversion not possible, store as-is
            storageQuantity = quantity
        }
        
        return FoodEntry(
            food: food,
            quantity: storageQuantity,
            mealType: mealType
        )
    }
    
    // Get the display quantity in a specific unit
    func getDisplayQuantity(in unit: MeasurementUnit) -> Double? {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        return UnitConverter.shared.convert(
            value: quantity,
            from: originalUnit,
            to: unit
        )
    }
    
    // Get formatted display text for quantity and unit
    func getDisplayText(in unit: MeasurementUnit) -> String {
        guard let displayQuantity = getDisplayQuantity(in: unit) else {
            return "\(quantity.formattedNutrition) \(food.servingSizeUnit)"
        }
        
        return UnitConversionHelper.getDisplayText(quantity: displayQuantity, unit: unit)
    }
    
    // Check if this entry can be converted to a specific unit
    func canConvertTo(_ unit: MeasurementUnit) -> Bool {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        return UnitConversionHelper.isValidConversion(from: originalUnit, to: unit)
    }
    
    // Get the original unit of this entry
    var originalUnit: MeasurementUnit {
        return MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
    }
    
    // Get compatible units for this entry
    var compatibleUnits: [MeasurementUnit] {
        return originalUnit.category.units
    }
}
