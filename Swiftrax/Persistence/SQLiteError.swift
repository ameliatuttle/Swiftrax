import Foundation
import SQLite3

enum SQLiteError: Error {
    case openDatabase(message: String)
    case prepare(message: String)
    case step(message: String)
    case bind(message: String)
    
    var localizedDescription: String {
        switch self {
        case .openDatabase(let message):
            return "Could not open database: \(message)"
        case .prepare(let message):
            return "Could not prepare statement: \(message)"
        case .step(let message):
            return "Could not step statement: \(message)"
        case .bind(let message):
            return "Could not bind statement: \(message)"
        }
    }
}

extension SQLiteError {
    static func errorMessage(db: OpaquePointer?) -> String {
        if let errorPointer = sqlite3_errmsg(db) {
            return String(cString: errorPointer)
        } else {
            return "No error message provided from SQLite."
        }
    }
}
