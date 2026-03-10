import Foundation

class APIManager: ObservableObject {
    static let shared = APIManager()
    
    private let session: URLSession
    private let cache = NSCache<NSString, NSData>()
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    private let maxRetries = 3
    private let backoffBase: TimeInterval = 1.0
    private let circuitBreakerThreshold = 5
    private let circuitBreakerTimeout: TimeInterval = 300 // 5 minutes
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6   // Reduced from 10
        config.timeoutIntervalForResource = 12 // Reduced from 20
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 5 * 1024 * 1024, diskCapacity: 20 * 1024 * 1024) // 5MB memory, 20MB disk
        self.session = URLSession(configuration: config)
        
        // Configure cache
        cache.countLimit = 200 // Increased from 100
        cache.totalCostLimit = 20 * 1024 * 1024 // Increased to 20MB
    }
    
    private var isCircuitBreakerOpen: Bool {
        guard let lastFailure = lastFailureTime else { return false }
        if failureCount >= circuitBreakerThreshold {
            return Date().timeIntervalSince(lastFailure) < circuitBreakerTimeout
        }
        return false
    }
    
    private func recordSuccess() {
        failureCount = 0
        lastFailureTime = nil
    }
    
    private func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
    }
    
    // Generic network request handler with retry, caching, and circuit breaker
    private func performRequest<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        // Check circuit breaker
        if isCircuitBreakerOpen {
            throw APIError.circuitBreakerOpen
        }
        
        // Check cache first
        let cacheKey = NSString(string: url.absoluteString)
        if let cachedData = cache.object(forKey: cacheKey) as Data? {
            let decoder = JSONDecoder()
            if let cachedResult = try? decoder.decode(responseType, from: cachedData) {
                print("🎯 Cache hit for: \(url.absoluteString)")
                return cachedResult
            }
        }
        
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let result = try await performSingleRequest(url: url, headers: headers, responseType: responseType)
                
                // Success - record it and cache the result
                recordSuccess()
                
                // Cache the successful response
                if let data = try? JSONEncoder().encode(result) {
                    cache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
                }
                
                return result
                
            } catch let error {
                lastError = error
                
                // Check if we should retry
                if attempt < maxRetries - 1 && shouldRetry(error: error) {
                    let delay = calculateBackoffDelay(attempt: attempt)
                    print("🔄 API retry \(attempt + 1)/\(maxRetries) after \(delay)s for: \(url.absoluteString)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Final failure
                    recordFailure()
                    break
                }
            }
        }
        
        throw lastError ?? APIError.networkError
    }
    
    private func performSingleRequest<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .returnCacheDataElseLoad
        
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
            
            // Debug: Log raw response for troubleshooting
            if let rawString = String(data: data, encoding: .utf8) {
                print("🔍 API Response for \(url.absoluteString): \(rawString.prefix(500))...")
            }
            
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(responseType, from: data)
            } catch let decodingError as DecodingError {
                print("❌ Decoding error for \(url.absoluteString):")
                print("   Error: \(decodingError)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   Raw JSON: \(jsonString)")
                }
                throw APIError.decodingError
            }
            
        } catch is DecodingError {
            throw APIError.decodingError
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError
        }
    }
    
    private func shouldRetry(error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError:
                return true
            case .serverError(let code):
                // Retry on network errors and 5xx server errors
                return code >= 500 || code == -1
            case .rateLimitExceeded:
                return true // Retry rate limits with backoff
            default:
                return false
            }
        }
        return false
    }
    
    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff with jitter
        let exponentialDelay = backoffBase * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.1) * exponentialDelay
        return min(exponentialDelay + jitter, 10.0) // Max 10 seconds
    }
    
    // Search for food by barcode using OpenFoodFacts API
    func searchByBarcode(_ barcode: String) async throws -> Food? {
        return try await OpenFoodFactsAPI.searchByBarcode(barcode, using: self)
    }
    
    // Search for foods by text query using OpenFoodFacts API
    func searchByText(_ query: String, pageSize: Int = 25) async throws -> [Food] {
        return try await OpenFoodFactsAPI.searchByText(query, pageSize: pageSize, using: self)
    }
    
    // Reset API manager state (useful for debugging connection issues)
    func resetConnectionState() {
        failureCount = 0
        lastFailureTime = nil
        cache.removeAllObjects()
        print("🔄 API connection state reset - cache cleared")
    }
    
    // Test API connectivity with a simple request
    func testAPIConnectivity() async -> Bool {
        do {
            let testUrl = URL(string: "https://world.openfoodfacts.org/api/v2/product/737628064502")!
            let (data, response) = try await session.data(from: testUrl)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧪 API Test - Status: \(httpResponse.statusCode)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("🧪 API Test - Response length: \(jsonString.count) characters")
                }
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("🧪 API Test failed: \(error)")
            return false
        }
    }
    
    // Get current API health status
    func getHealthStatus() -> (isHealthy: Bool, failureCount: Int, circuitBreakerOpen: Bool) {
        return (
            isHealthy: !isCircuitBreakerOpen && failureCount < 3,
            failureCount: failureCount,
            circuitBreakerOpen: isCircuitBreakerOpen
        )
    }
    
    // Internal helper method for API implementations
    internal func request<T: Codable>(
        url: URL,
        headers: [String: String] = [:],
        responseType: T.Type
    ) async throws -> T {
        return try await performRequest(url: url, headers: headers, responseType: responseType)
    }
    
    // Expose cache for API implementations that need direct access
    internal var searchCache: NSCache<NSString, NSData> {
        return self.cache
    }
}
