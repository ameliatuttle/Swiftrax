import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case productNotFound
    case serverError(Int)
    case noData
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network connection error"
        case .decodingError:
            return "Failed to decode response data"
        case .productNotFound:
            return "Product not found in database"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .noData:
            return "No data received from server"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later."
        }
    }
}
