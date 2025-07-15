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
    
    private struct OFFProduct: Codable {
        let productName: String?
        let nutriments: OFFNutriments
        let brands: String?
        
        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case nutriments
            case brands
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
        }
    }
    
    // MARK: - Public API Method
    static func searchByBarcode(_ barcode: String, using apiManager: APIManager) async throws -> Food? {
        let urlString = "https://world.openfoodfacts.net/api/v2/product/\(barcode)?fields=product_name,nutriments,brands"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let headers = [
            "Authorization": "Basic " + Data("off:off".utf8).base64EncodedString(),
            "User-Agent": "SwiftTrax/1.0"
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
    
    // MARK: - Conversion Helper
    private static func convertToFood(product: OFFProduct, barcode: String) -> Food {
        let nutriments = product.nutriments
        
        // Create NutritionInfo using your existing structure
        let nutritionInfo = NutritionInfo(
            calories: nutriments.energyKcal ?? 0,
            protein: nutriments.proteins ?? 0,
            carbohydrates: nutriments.carbohydrates ?? 0,
            fat: nutriments.fat ?? 0,
            fiber: nutriments.fiber,
            sugar: nutriments.sugars,
            sodium: nutriments.sodium
        )
        
        // Use your existing Food initializer
        var food = Food(
            name: product.productName ?? "Unknown Product",
            barcode: barcode,
            nutritionInfo: nutritionInfo,
            servingSize: 100, // OpenFoodFacts returns per 100g
            servingSizeUnit: "g",
            brand: product.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            isCustom: false,
            source: "OpenFoodFacts"
        )
        
        return food
    }
}
