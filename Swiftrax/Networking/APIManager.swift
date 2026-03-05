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
        config.timeoutIntervalForRequest = 10  // Reduced from 30
        config.timeoutIntervalForResource = 20 // Reduced from 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        
        // Configure cache
        cache.countLimit = 100
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
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
}
