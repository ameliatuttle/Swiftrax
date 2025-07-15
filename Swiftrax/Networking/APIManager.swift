import Foundation

// Remove @MainActor from here - it's causing the async issues
class APIManager: ObservableObject {
    static let shared = APIManager()
    
    private let session: URLSession
    private let usdaAPIKey = "ebF03jerwcmtyPgXfs7PSKy6BkJjalqXHd4xBVfP"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Network Request
    private func performRequest<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                break // Success
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
    
    // MARK: - Public API Methods
    func searchByBarcode(_ barcode: String) async throws -> Food? {
        return try await OpenFoodFactsAPI.searchByBarcode(barcode, using: self)
    }
    
    func searchByText(_ query: String, pageSize: Int = 25) async throws -> [Food] {
        return try await USDAFoodAPI.searchByText(query, pageSize: pageSize, using: self)
    }
    
    // MARK: - Internal helper for API classes
    internal func request<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        return try await performRequest(url: url, headers: headers, responseType: responseType)
    }
    
    // Make this a simple property - no async needed
    internal var apiKey: String {
        return usdaAPIKey
    }
}
