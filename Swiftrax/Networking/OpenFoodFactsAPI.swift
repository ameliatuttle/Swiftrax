import Foundation

struct OpenFoodFactsAPI {
    
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
        let count: Int?
        let page: Int?
        let pageCount: Int?
        let pageSize: Int?
        let skip: Int?
        
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
        let nutriments: OFFNutriments?
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
            
            case energyKcalServing = "energy-kcal_serving"
            case carbohydratesServing = "carbohydrates_serving"
            case proteinsServing = "proteins_serving"
            case fatServing = "fat_serving"
            case fiberServing = "fiber_serving"
            case sugarsServing = "sugars_serving"
            case sodiumServing = "sodium_serving"
        }
    }
    
    // Search for food by barcode
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
    
    // Search for foods by text query
    static func searchByText(_ query: String, pageSize: Int = 25, using apiManager: APIManager) async throws -> [Food] {
        // Check cache first - use a normalized cache key for searches
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = NSString(string: "search:\(normalizedQuery):\(pageSize)")
        if let cachedData = apiManager.searchCache.object(forKey: cacheKey) as Data? {
            let decoder = JSONDecoder()
            if let cachedResult = try? decoder.decode([Food].self, from: cachedData) {
                print("🎯 Search cache hit for: '\(query)' - returning \(cachedResult.count) cached results")
                return cachedResult
            }
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=\(pageSize)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        print("🌐 Searching OpenFoodFacts for: '\(query)'")
        print("🌐 URL: \(urlString)")
        
        let headers = [
            "User-Agent": "SwiftTrax/1.0 (contact@swifttrax.app)"
        ]
        
        do {
            let response = try await apiManager.request(
                url: url,
                headers: headers,
                responseType: OpenFoodFactsSearchResponse.self
            )
            
            print("🌐 API search for '\(query)' returned \(response.products.count) raw products")
            
            let foods = response.products.compactMap { product in
                convertToFood(product: product, barcode: product.code)
            }
            
            print("🌐 After conversion: \(foods.count) valid foods")
            
            let filteredFoods = filterAndSortResults(foods: foods, query: query)
            
            print("🌐 After filtering: \(filteredFoods.count) foods")
            
            // Cache the successful search result
            if let cacheData = try? JSONEncoder().encode(filteredFoods) {
                let cacheKey = NSString(string: "search:\(normalizedQuery):\(pageSize)")
                apiManager.searchCache.setObject(cacheData as NSData, forKey: cacheKey, cost: cacheData.count)
                print("💾 Cached search results for: '\(query)'")
            }
            
            return filteredFoods
        } catch {
            print("❌ OpenFoodFacts API error for '\(query)': \(error)")
            
            // Try a fallback approach with minimal parsing
            do {
                print("🔄 Trying fallback API approach...")
                return try await fallbackSearch(query: query, using: apiManager)
            } catch let fallbackError {
                print("❌ Fallback search also failed: \(fallbackError)")
                throw error // Throw the original error
            }
        }
    }
    
    // Fallback search with minimal data structure requirements
    private static func fallbackSearch(query: String, using apiManager: APIManager) async throws -> [Food] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&json=1&page_size=10"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        // Use raw JSON parsing for maximum flexibility
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let productsArray = jsonObject["products"] as? [[String: Any]] else {
            throw APIError.decodingError
        }
        
        print("🔄 Fallback found \(productsArray.count) raw products")
        
        let foods: [Food] = productsArray.compactMap { productDict in
            return createFoodFromDictionary(productDict)
        }
        
        print("🔄 Fallback converted \(foods.count) foods")
        
        let filteredFoods = filterAndSortResults(foods: foods, query: query)
        
        // Cache the fallback result too
        if let cacheData = try? JSONEncoder().encode(filteredFoods) {
            let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let cacheKey = NSString(string: "search:\(normalizedQuery):10") // fallback uses page size 10
            apiManager.searchCache.setObject(cacheData as NSData, forKey: cacheKey, cost: cacheData.count)
            print("💾 Cached fallback search results for: '\(query)'")
        }
        
        return filteredFoods
    }
    
    // Create a Food object from a raw dictionary (fallback method)
    private static func createFoodFromDictionary(_ dict: [String: Any]) -> Food? {
        guard let productName = dict["product_name"] as? String,
              !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        guard let nutrimentsDict = dict["nutriments"] as? [String: Any] else {
            return nil
        }
        
        let getDouble = { (key: String) -> Double? in
            if let value = nutrimentsDict[key] as? Double {
                return value
            } else if let value = nutrimentsDict[key] as? String {
                return Double(value)
            }
            return nil
        }
        
        let calories = getDouble("energy-kcal_100g") ?? (getDouble("energy_100g") != nil ? (getDouble("energy_100g")! / 4.184) : 0)
        
        let nutritionInfo = NutritionInfo(
            calories: calories,
            protein: getDouble("proteins_100g"),
            carbohydrates: getDouble("carbohydrates_100g"),
            fat: getDouble("fat_100g"),
            fiber: getDouble("fiber_100g"),
            sugar: getDouble("sugars_100g"),
            sodium: getDouble("sodium_100g")
        )
        
        let brand = (dict["brands"] as? String)?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let barcode = dict["code"] as? String
        
        return Food(
            name: cleanFoodName(productName),
            barcode: barcode,
            nutritionInfo: nutritionInfo,
            servingSize: 100,
            servingSizeUnit: "g",
            brand: brand,
            isCustom: false,
            source: "OpenFoodFacts"
        )
    }
    
    // Filter and sort search results for relevance
    private static func filterAndSortResults(foods: [Food], query: String) -> [Food] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return foods
            .filter { food in
                let hasNutrition = (food.nutritionInfo.calories ?? 0) > 0
                let reasonableServing = food.servingSize > 0 && food.servingSize <= 5000
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
    
    // Calculate relevance score for search result ranking
    private static func calculateRelevanceScore(food: Food, query: String) -> Int {
        let nameLower = food.name.lowercased()
        var score = 0
        
        if nameLower == query { score += 1000 }
        if nameLower.hasPrefix(query) { score += 500 }
        if nameLower.contains(query) { score += 100 }
        
        let wordCount = nameLower.components(separatedBy: .whitespacesAndNewlines).count
        if wordCount <= 2 { score += 300 }
        else if wordCount <= 4 { score += 100 }
        else if wordCount > 6 { score -= 200 }
        
        let calories = food.nutritionInfo.calories ?? 0
        if calories > 20 && calories < 800 { score += 100 }
        else if calories > 1000 { score -= 100 }
        
        if food.servingSize == 100 { score += 50 }
        
        let basicCategories = ["fruits", "vegetables", "meats", "dairy", "grains", "eggs"]
        for category in basicCategories {
            if nameLower.contains(category) { score += 200 }
        }
        
        return score
    }
    
    // Validate nutrition values for safety
    private static func validateNutritionValue(_ value: Double?) -> Double? {
        guard let value = value else { return nil }
        if value.isNaN || value.isInfinite || value < 0 {
            return nil
        }
        return value
    }
    
    // Convert OpenFoodFacts product data to Food model
    private static func convertToFood(product: OFFProduct, barcode: String?) -> Food? {
        guard let productName = product.productName,
              !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Skipping product with missing name")
            return nil
        }
        
        // Handle missing nutriments gracefully
        guard let nutriments = product.nutriments else {
            print("⚠️ Skipping product '\(productName)' with missing nutriments")
            return nil
        }
        
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
        
        var servingSize: Double = 100
        var servingUnit: String = "g"
        
        if let productServingSize = product.servingSize {
            let numberRegex = try? NSRegularExpression(pattern: #"([0-9]*\.?[0-9]+)\s?g\b"#, options: [.caseInsensitive])
            if let match = numberRegex?.firstMatch(in: productServingSize, options: [], range: NSRange(location: 0, length: productServingSize.utf16.count)),
               let range = Range(match.range(at: 1), in: productServingSize) {
                let numericPart = String(productServingSize[range])
                if let parsed = Double(numericPart), parsed > 0 {
                    servingSize = parsed
                    servingUnit = "g"
                }
            }
            
            let unitRegex = try? NSRegularExpression(pattern: #"[a-zA-Z]+"#, options: [])
            if let match = unitRegex?.firstMatch(in: productServingSize, options: [], range: NSRange(location: 0, length: productServingSize.utf16.count)) {
                if let range = Range(match.range, in: productServingSize) {
                    servingUnit = String(productServingSize[range]).lowercased()
                }
            }
        }
        
        let servingSizeUnit = "g"
        let cleanName = cleanFoodName(productName)
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
    
    // Clean up food names from API data
    private static func cleanFoodName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
        
        cleaned = cleaned.capitalized
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
