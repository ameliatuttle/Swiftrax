import Foundation

struct Food: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var barcode: String?
    var nutritionInfo: NutritionInfo
    var servingSize: Double
    var servingSizeUnit: String
    var brand: String?
    var isCustom: Bool = false
    var dateAdded: Date = Date()
    var recipeId: UUID? = nil
    var source: String = "manual" // "manual", "OpenFoodFacts", "USDA"
    var lastUpdated: Date = Date()
    
    init(name: String, barcode: String? = nil, nutritionInfo: NutritionInfo, servingSize: Double, servingSizeUnit: String, brand: String? = nil, isCustom: Bool = false, source: String = "manual") {
        self.id = UUID()
        self.name = name
        self.barcode = barcode
        self.nutritionInfo = nutritionInfo
        self.servingSize = servingSize
        self.servingSizeUnit = servingSizeUnit
        self.brand = brand
        self.isCustom = isCustom
        self.dateAdded = Date()
        self.source = source
        self.lastUpdated = Date()
    }
    
    // Convenience initializer for API data
    init(apiName: String, barcode: String? = nil, brand: String? = nil, calories: Double, protein: Double, carbohydrates: Double, fat: Double, fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, servingSize: Double, servingSizeUnit: String, source: String) {
        self.id = UUID()
        self.name = apiName
        self.barcode = barcode
        self.brand = brand
        self.servingSize = servingSize
        self.servingSizeUnit = servingSizeUnit
        self.isCustom = false
        self.dateAdded = Date()
        self.source = source
        self.lastUpdated = Date()
        
        // Create NutritionInfo from API data
        self.nutritionInfo = NutritionInfo(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
    }
    
    static func == (lhs: Food, rhs: Food) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Helper to check if this food is from API
    var isFromAPI: Bool {
        return source == "OpenFoodFacts" || source == "USDA"
    }
    
    // Helper to get source emoji for UI
    var sourceEmoji: String {
        switch source {
        case "OpenFoodFacts":
            return "🏷️"
        case "USDA":
            return "🇺🇸"
        case "manual":
            return "✏️"
        default:
            return "❓"
        }
    }
}

// MARK: - Unit Conversion Extensions
extension Food {
    var measurementUnit: MeasurementUnit {
        return MeasurementUnit(rawValue: servingSizeUnit) ?? .grams
    }
    
    func withConvertedServing(to newUnit: MeasurementUnit) -> Food? {
        guard let convertedSize = UnitConverter.shared.convert(
            value: servingSize,
            from: measurementUnit,
            to: newUnit
        ) else { return nil }
        
        var newFood = self
        newFood.servingSize = convertedSize
        newFood.servingSizeUnit = newUnit.abbreviation
        return newFood
    }
    
    // Get nutrition for a specific quantity and unit
    func nutritionFor(quantity: Double, unit: MeasurementUnit) -> NutritionInfo {
        let originalUnit = measurementUnit
        
        // Convert quantity to food's original unit
        let convertedQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: originalUnit) {
            convertedQuantity = converted
        } else {
            // If conversion not possible, use quantity as-is
            convertedQuantity = quantity
        }
        
        // Calculate scaling factor
        let scaleFactor = convertedQuantity / servingSize
        
        return nutritionInfo.scaled(by: scaleFactor)
    }
    
    // Get compatible units for this food
    var compatibleUnits: [MeasurementUnit] {
        return UnitConverter.shared.getCompatibleUnits(for: measurementUnit)
    }
    
    // Get suggested units for this food
    var suggestedUnits: [MeasurementUnit] {
        return UnitConverter.shared.getSuggestedUnits(for: self)
    }
   
   // Add this initializer to handle legacy data without source field
   init(from decoder: Decoder) throws {
       let container = try decoder.container(keyedBy: CodingKeys.self)
       
       id = try container.decode(UUID.self, forKey: .id)
       name = try container.decode(String.self, forKey: .name)
       barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
       nutritionInfo = try container.decode(NutritionInfo.self, forKey: .nutritionInfo)
       servingSize = try container.decode(Double.self, forKey: .servingSize)
       servingSizeUnit = try container.decode(String.self, forKey: .servingSizeUnit)
       brand = try container.decodeIfPresent(String.self, forKey: .brand)
       isCustom = try container.decode(Bool.self, forKey: .isCustom)
       dateAdded = try container.decode(Date.self, forKey: .dateAdded)
       recipeId = try container.decodeIfPresent(UUID.self, forKey: .recipeId)
       
       // Handle missing source field for legacy data
       source = try container.decodeIfPresent(String.self, forKey: .source) ?? "manual"
       
       // Handle missing lastUpdated field for legacy data
       lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
   }

   // Add the CodingKeys enum if it doesn't exist
   enum CodingKeys: String, CodingKey {
       case id, name, barcode, nutritionInfo, servingSize, servingSizeUnit
       case brand, isCustom, dateAdded, recipeId, source, lastUpdated
   }
}

