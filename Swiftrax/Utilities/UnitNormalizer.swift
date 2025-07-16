import Foundation

class UnitNormalizer {
    static let shared = UnitNormalizer()
    
    private init() {}
    
    // Unit conversion map
    private let unitConversions: [String: (unit: String, factor: Double)] = [
        "mlt": ("ml", 1.0),
        "grm": ("g", 1.0),
        "gram": ("g", 1.0),
        "grams": ("g", 1.0),
        "milliliter": ("ml", 1.0),
        "milliliters": ("ml", 1.0),
        "ounce": ("oz", 1.0),
        "ounces": ("oz", 1.0),
        "pounds": ("lb", 1.0),
        "pound": ("lb", 1.0),
        "cups": ("cup", 1.0),
        "tablespoon": ("tbsp", 1.0),
        "tablespoons": ("tbsp", 1.0),
        "teaspoon": ("tsp", 1.0),
        "teaspoons": ("tsp", 1.0)
    ]
    
    // Standard serving sizes for common foods
    private let standardServings: [String: (size: Double, unit: String)] = [
        "egg": (1, "piece"),
        "eggs": (1, "piece"),
        "sugar": (1, "tsp"),
        "salt": (1, "tsp"),
        "butter": (1, "tbsp"),
        "milk": (1, "cup"),
        "bread": (1, "slice"),
        "apple": (1, "piece"),
        "banana": (1, "piece"),
        "orange": (1, "piece"),
        "chicken breast": (4, "oz"),
        "chicken": (4, "oz"),
        "beef": (4, "oz"),
        "rice": (0.5, "cup"),
        "pasta": (1, "cup"),
        "cheese": (1, "oz")
    ]
    
    func normalizeFood(_ food: Food) -> Food {
        var normalizedFood = food
        
        // Step 3a: Normalize the unit
        let normalizedUnit = normalizeUnit(food.servingSizeUnit)
        normalizedFood.servingSizeUnit = normalizedUnit
        
        // Step 3b: Fix serving size if it's weird
        let normalizedSize = normalizeServingSize(
            foodName: food.name,
            currentSize: food.servingSize,
            unit: normalizedUnit
        )
        normalizedFood.servingSize = normalizedSize
        
        return normalizedFood
    }
    
    private func normalizeUnit(_ unit: String) -> String {
        let unitLower = unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let conversion = unitConversions[unitLower] {
            return conversion.unit
        }
        
        // Return original if no conversion found
        return unit.isEmpty ? "g" : unit
    }
    
    private func normalizeServingSize(foodName: String, currentSize: Double, unit: String) -> Double {
        let nameLower = foodName.lowercased()
        
        // Check if this food has a standard serving
        for (foodKey, serving) in standardServings {
            if nameLower.contains(foodKey) {
                // If the units match or are compatible, use standard serving
                if serving.unit == unit || areUnitsCompatible(serving.unit, unit) {
                    return serving.size
                }
            }
        }
        
        // If current size is reasonable, keep it
        if currentSize > 0 && currentSize <= 1000 {
            return currentSize
        }
        
        // Otherwise, provide sensible defaults by unit
        switch unit.lowercased() {
        case "piece", "slice", "serving": return 1
        case "tsp": return 1
        case "tbsp": return 1
        case "cup": return 1
        case "oz": return 1
        case "ml": return 250
        case "g": return 100
        default: return currentSize > 0 ? currentSize : 100
        }
    }
    
    private func areUnitsCompatible(_ unit1: String, _ unit2: String) -> Bool {
        let volumeUnits = ["ml", "cup", "tbsp", "tsp", "fl oz", "l"]
        let weightUnits = ["g", "kg", "oz", "lb"]
        let countUnits = ["piece", "slice", "serving"]
        
        let unit1Lower = unit1.lowercased()
        let unit2Lower = unit2.lowercased()
        
        return (volumeUnits.contains(unit1Lower) && volumeUnits.contains(unit2Lower)) ||
               (weightUnits.contains(unit1Lower) && weightUnits.contains(unit2Lower)) ||
               (countUnits.contains(unit1Lower) && countUnits.contains(unit2Lower))
    }
}
