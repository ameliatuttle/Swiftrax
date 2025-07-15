import Foundation

class DateFormatters {
    static let shared = DateFormatters()
    
    private init() {}
    
    let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
    
    let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    let isoFormatter: ISO8601DateFormatter = {
        return ISO8601DateFormatter()
    }()
}

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    func isSameDay(as date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func adding(weeks: Int) -> Date {
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }
    
    func adding(months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
}
