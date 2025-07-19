import Foundation

class APIManager: ObservableObject {
    static let shared = APIManager()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // Generic network request handler with error handling
    private func performRequest<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 404:
                throw APIError.productNotFound
            case 429:
                throw APIError.rateLimitExceeded
            case 500...599:
                throw APIError.serverError(httpResponse.statusCode)
            default:
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            guard !data.isEmpty else {
                throw APIError.noData
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(responseType, from: data)
            
        } catch is DecodingError {
            throw APIError.decodingError
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError
        }
    }
    
    // Search for food by barcode using OpenFoodFacts API
    func searchByBarcode(_ barcode: String) async throws -> Food? {
        return try await OpenFoodFactsAPI.searchByBarcode(barcode, using: self)
    }
    
    // Search for foods by text query using OpenFoodFacts API
    func searchByText(_ query: String, pageSize: Int = 25) async throws -> [Food] {
        return try await OpenFoodFactsAPI.searchByText(query, pageSize: pageSize, using: self)
    }
    
    // Internal helper method for API implementations
    internal func request<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        return try await performRequest(url: url, headers: headers, responseType: responseType)
    }
}
