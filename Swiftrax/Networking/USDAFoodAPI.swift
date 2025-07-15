import Foundation

struct USDAFoodAPI {
    
    // MARK: - Response Models
    private struct USDASearchResponse: Codable {
        let foods: [USDAFood]
        let totalHits: Int
        let currentPage: Int
        let totalPages: Int
    }
    
    private struct USDAFood: Codable {
        let fdcId: Int
        let description: String
        let dataType: String
        let brandOwner: String?
        let brandName: String?
        let foodNutrients: [USDANutrient]
        let servingSize: Double?
        let servingSizeUnit: String?
        let householdServingFullText: String?
        
        enum CodingKeys: String, CodingKey {
            case fdcId, description, dataType, brandOwner, brandName, foodNutrients, servingSize, servingSizeUnit, householdServingFullText
        }
    }
    
    private struct USDANutrient: Codable {
        let nutrientId: Int
        let nutrientName: String
        let nutrientNumber: String
        let unitName: String
        let value: Double?
        
        enum CodingKeys: String, CodingKey {
            case nutrientId, nutrientName, nutrientNumber, unitName, value
        }
    }
    
    // MARK: - Public API Method
    static func searchByText(_ query: String, pageSize: Int = 25, using apiManager: APIManager) async throws -> [Food] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let apiKey = apiManager.apiKey
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(apiKey)&query=\(encodedQuery)&dataType=Branded&pageSize=\(pageSize)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let headers = [
            "Content-Type": "application/json"
        ]
        
        let response = try await apiManager.request(
            url: url,
            headers: headers,
            responseType: USDASearchResponse.self
        )
        
        return response.foods.compactMap { convertToFood(food: $0) }
    }
    
    // MARK: - Conversion Helper
    private static func convertToFood(food: USDAFood) -> Food? {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double? = nil
        var sugar: Double? = nil
        var sodium: Double? = nil
        
        // Extract nutrients by ID
        for nutrient in food.foodNutrients {
            guard let value = nutrient.value else { continue }
            
            switch nutrient.nutrientId {
            case 1008: calories = value // Energy (kcal)
            case 1003: protein = value  // Protein
            case 1005: carbs = value    // Carbohydrates
            case 1004: fat = value      // Total lipid (fat)
            case 1079: fiber = value    // Fiber
            case 2000: sugar = value    // Total Sugars
            case 1093: sodium = value   // Sodium
            default: break
            }
        }
        
        // Create NutritionInfo using your existing structure
        let nutritionInfo = NutritionInfo(
            calories: calories,
            protein: protein,
            carbohydrates: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
        
        // Use your existing Food initializer
        var food = Food(
            name: food.description,
            barcode: nil,
            nutritionInfo: nutritionInfo,
            servingSize: food.servingSize ?? 100,
            servingSizeUnit: food.servingSizeUnit ?? "g",
            brand: food.brandOwner ?? food.brandName,
            isCustom: false,
            source: "USDA"
        )
        
        return food
    }
}
