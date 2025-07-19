import Foundation

struct OpenFoodFactsAPI {
    
    // MARK: - Response Models
    private struct OpenFoodFactsResponse: Codable {
        let code: String
        let product: OFFProduct?
        let status: Int
        let statusVerbose: String
        
        enum CodingKeys: String, CodingKey {
            case code, product, status
            case statusVerbose = "status_verbose"
        }
    }
    
    private struct OpenFoodFactsSearchResponse: Codable {
        let products: [OFFProduct]
        let count: Int
        let page: Int
        let pageCount: Int
        let pageSize: Int
        let skip: Int
        
        enum CodingKeys: String, CodingKey {
            case products, count, page
            case pageCount = "page_count"
            case pageSize = "page_size"
            case skip
        }
    }
    
    private struct OFFProduct: Codable {
        let code: String?
        let productName: String?
        let nutriments: OFFNutriments
        let brands: String?
        let categories: String?
        let quantity: String?
        let servingSize: String?
        let imageFrontUrl: String?
        
        enum CodingKeys: String, CodingKey {
            case code
            case productName = "product_name"
            case nutriments
            case brands
            case categories
            case quantity
            case servingSize = "serving_size"
            case imageFrontUrl = "image_front_url"
        }
    }
    
   private struct OFFNutriments: Codable {
       let energy: Double?
       let energyKcal: Double?
       let carbohydrates: Double?
       let proteins: Double?
       let fat: Double?
       let fiber: Double?
       let sugars: Double?
       let sodium: Double?
       let salt: Double?

       // ✅ 🔽 ADD THESE NEW FIELDS:
       let energyKcalServing: Double?
       let carbohydratesServing: Double?
       let proteinsServing: Double?
       let fatServing: Double?
       let fiberServing: Double?
       let sugarsServing: Double?
       let sodiumServing: Double?
       
       enum CodingKeys: String, CodingKey {
           case energy
           case energyKcal = "energy-kcal_100g"
           case carbohydrates = "carbohydrates_100g"
           case proteins = "proteins_100g"
           case fat = "fat_100g"
           case fiber = "fiber_100g"
           case sugars = "sugars_100g"
           case sodium = "sodium_100g"
           case salt = "salt_100g"

           // ✅ 🔽 ADD THESE TOO:
           case energyKcalServing = "energy-kcal_serving"
           case carbohydratesServing = "carbohydrates_serving"
           case proteinsServing = "proteins_serving"
           case fatServing = "fat_serving"
           case fiberServing = "fiber_serving"
           case sugarsServing = "sugars_serving"
           case sodiumServing = "sodium_serving"
       }
   }

    
    // MARK: - Public API Methods
    
    /// Search by barcode (existing functionality)
    static func searchByBarcode(_ barcode: String, using apiManager: APIManager) async throws -> Food? {
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode)?fields=product_name,nutriments,brands,categories,quantity,serving_size"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let headers = [
            "User-Agent": "SwiftTrax/1.0 (contact@swifttrax.app)"
        ]
        
        let response = try await apiManager.request(
            url: url,
            headers: headers,
            responseType: OpenFoodFactsResponse.self
        )
        
        guard response.status == 1, let product = response.product else {
            throw APIError.productNotFound
        }
        
        return convertToFood(product: product, barcode: barcode)
    }
    
    /// Search by text query (new functionality)
    static func searchByText(_ query: String, pageSize: Int = 25, using apiManager: APIManager) async throws -> [Food] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // OpenFoodFacts search endpoint
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=\(pageSize)&fields=code,product_name,nutriments,brands,categories,quantity,serving_size"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let headers = [
            "User-Agent": "SwiftTrax/1.0 (contact@swifttrax.app)"
        ]
        
        let response = try await apiManager.request(
            url: url,
            headers: headers,
            responseType: OpenFoodFactsSearchResponse.self
        )
        
        print("🌐 OpenFoodFacts search for '\(query)' returned \(response.products.count) products")
        
        // Convert and filter products
        let foods = response.products.compactMap { product in
            convertToFood(product: product, barcode: product.code)
        }
        
        // Filter and sort results for better relevance
        let filteredFoods = filterAndSortResults(foods: foods, query: query)
        
        print("🌐 After filtering: \(filteredFoods.count) foods")
        return filteredFoods
    }
    
    // MARK: - Helper Methods
    
    /// Filter and sort OpenFoodFacts results for better relevance
    private static func filterAndSortResults(foods: [Food], query: String) -> [Food] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return foods
            .filter { food in
                // Filter out products with no nutrition info
                let hasNutrition = (food.nutritionInfo.calories ?? 0) > 0
                
                // Filter out products with weird serving sizes
                let reasonableServing = food.servingSize > 0 && food.servingSize <= 5000
                
                // Filter out products with too many words (likely processed)
                let wordCount = food.name.components(separatedBy: .whitespacesAndNewlines).count
                let notTooComplex = wordCount <= 8
                
                return hasNutrition && reasonableServing && notTooComplex
            }
            .sorted { food1, food2 in
                let score1 = calculateRelevanceScore(food: food1, query: queryLower)
                let score2 = calculateRelevanceScore(food: food2, query: queryLower)
                return score1 > score2
            }
    }
    
    /// Calculate relevance score for sorting
    private static func calculateRelevanceScore(food: Food, query: String) -> Int {
        let nameLower = food.name.lowercased()
        let brandLower = food.brand?.lowercased() ?? ""
        var score = 0
        
        // Exact match gets highest priority
        if nameLower == query { score += 1000 }
        
        // Starts with query
        if nameLower.hasPrefix(query) { score += 500 }
        
        // Contains query
        if nameLower.contains(query) { score += 100 }
        
        // Prefer simpler names (basic foods)
        let wordCount = nameLower.components(separatedBy: .whitespacesAndNewlines).count
        if wordCount <= 2 { score += 300 }
        else if wordCount <= 4 { score += 100 }
        else if wordCount > 6 { score -= 200 }
        
        // Prefer reasonable calorie ranges
        let calories = food.nutritionInfo.calories ?? 0
        if calories > 20 && calories < 800 { score += 100 }
        else if calories > 1000 { score -= 100 }
        
        // Prefer standard serving sizes
        if food.servingSize == 100 { score += 50 } // 100g is standard
        
        // Boost basic food categories
        let basicCategories = ["fruits", "vegetables", "meats", "dairy", "grains", "eggs"]
        for category in basicCategories {
            if nameLower.contains(category) { score += 200 }
        }
        
        return score
    }
   
   private static func validateNutritionValue(_ value: Double?) -> Double? {
       guard let value = value else { return nil }
       if value.isNaN || value.isInfinite || value < 0 {
           return nil // Return nil for invalid values
       }
       return value
   }
    
    /// Convert OpenFoodFacts product to Food model
   private static func convertToFood(product: OFFProduct, barcode: String?) -> Food? {
       guard let productName = product.productName,
             !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
           return nil
       }
       
       let nutriments = product.nutriments
       
       // Use energyKcal if available, otherwise try to convert from energy
      let rawCalories = nutriments.energyKcalServing
          ?? nutriments.energyKcal
          ?? (nutriments.energy != nil ? nutriments.energy! / 4.184 : 0)

      let calories = validateNutritionValue(rawCalories) ?? 0

      let nutritionInfo = NutritionInfo(
          calories: calories,
          protein: validateNutritionValue(nutriments.proteinsServing ?? nutriments.proteins),
          carbohydrates: validateNutritionValue(nutriments.carbohydratesServing ?? nutriments.carbohydrates),
          fat: validateNutritionValue(nutriments.fatServing ?? nutriments.fat),
          fiber: validateNutritionValue(nutriments.fiberServing ?? nutriments.fiber),
          sugar: validateNutritionValue(nutriments.sugarsServing ?? nutriments.sugars),
          sodium: validateNutritionValue(nutriments.sodiumServing ?? nutriments.sodium)
      )

       
       // Validate serving size
      var servingSize: Double = 100
      var servingUnit: String = "g"

      if let productServingSize = product.servingSize {
          // Extract numeric value (e.g. "42.5 g" → 42.5)
         let numberRegex = try? NSRegularExpression(pattern: #"([0-9]*\.?[0-9]+)\s?g\b"#, options: [.caseInsensitive])
         if let match = numberRegex?.firstMatch(in: productServingSize, options: [], range: NSRange(location: 0, length: productServingSize.utf16.count)),
            let range = Range(match.range(at: 1), in: productServingSize) {
             let numericPart = String(productServingSize[range])
             if let parsed = Double(numericPart), parsed > 0 {
                 servingSize = parsed
                 servingUnit = "g"
             }
         }
          
          // Extract unit (e.g. "42.5 g" → g)
          let unitRegex = try? NSRegularExpression(pattern: #"[a-zA-Z]+"#, options: [])
          if let match = unitRegex?.firstMatch(in: productServingSize, options: [], range: NSRange(location: 0, length: productServingSize.utf16.count)) {
              if let range = Range(match.range, in: productServingSize) {
                  servingUnit = String(productServingSize[range]).lowercased()
              }
          }
         print("✅ Parsed serving size: \(servingSize) \(servingUnit)")
      }

       
       let servingSizeUnit = "g"
       
       // Clean up food name
       let cleanName = cleanFoodName(productName)
       
       // Clean up brand
       let cleanBrand = product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
       
       let food = Food(
           name: cleanName,
           barcode: barcode,
           nutritionInfo: nutritionInfo,
           servingSize: servingSize,
           servingSizeUnit: servingSizeUnit,
           brand: cleanBrand,
           isCustom: false,
           source: "OpenFoodFacts"
       )
       
       return food
   }
    
    /// Clean up food names from OpenFoodFacts
    private static func cleanFoodName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common OpenFoodFacts prefixes/suffixes
        let removePatterns = [
            " - ",
            " | ",
            " / ",
            "\\d+g",
            "\\d+ml",
            "\\d+oz"
        ]
        
        for pattern in removePatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        
        // Capitalize properly
        cleaned = cleaned.capitalized
        
        // Remove extra spaces
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
