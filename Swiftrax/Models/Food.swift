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
    var source: String = "manual"
    var lastUpdated: Date = Date()
    
    // Standard initializer for manual food entry
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
    
    // Check if this food came from an external API
    var isFromAPI: Bool {
        return source == "OpenFoodFacts" || source == "USDA"
    }
    
    // Get emoji representing the food's data source
    var sourceEmoji: String {
        switch source {
        case "OpenFoodFacts":
            return "🏷️"
        case "manual":
            return "✏️"
        default:
            return "🇺🇸"
        }
    }
}
