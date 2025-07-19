import Foundation

enum MeasurementUnit: String, CaseIterable, Codable {
    // Weight units
    case grams = "g"
    case kilograms = "kg"
    case ounces = "oz"
    case pounds = "lb"
    case milligrams = "mg"
    
    // Volume units
    case milliliters = "ml"
    case liters = "L"
    case fluidOunces = "fl oz"
    case cups = "cup"
    case tablespoons = "tbsp"
    case teaspoons = "tsp"
    case pints = "pt"
    case quarts = "qt"
    case gallons = "gal"
    
    // Count/Serving units
    case pieces = "piece"
    case servings = "serving"
    case slices = "slice"
    case containers = "container"
    case packages = "package"
    case cans = "can"
    case bottles = "bottle"
    
    var displayName: String {
        switch self {
        case .grams: return "Grams"
        case .kilograms: return "Kilograms"
        case .ounces: return "Ounces"
        case .pounds: return "Pounds"
        case .milligrams: return "Milligrams"
        case .milliliters: return "Milliliters"
        case .liters: return "Liters"
        case .fluidOunces: return "Fluid Ounces"
        case .cups: return "Cups"
        case .tablespoons: return "Tablespoons"
        case .teaspoons: return "Teaspoons"
        case .pints: return "Pints"
        case .quarts: return "Quarts"
        case .gallons: return "Gallons"
        case .pieces: return "Pieces"
        case .servings: return "Servings"
        case .slices: return "Slices"
        case .containers: return "Containers"
        case .packages: return "Packages"
        case .cans: return "Cans"
        case .bottles: return "Bottles"
        }
    }
    
    var category: UnitCategory {
        switch self {
        case .grams, .kilograms, .ounces, .pounds, .milligrams:
            return .weight
        case .milliliters, .liters, .fluidOunces, .cups, .tablespoons, .teaspoons, .pints, .quarts, .gallons:
            return .volume
        case .pieces, .servings, .slices, .containers, .packages, .cans, .bottles:
            return .count
        }
    }
    
    var abbreviation: String {
        return self.rawValue
    }
}

enum UnitCategory: String, CaseIterable {
    case weight = "Weight"
    case volume = "Volume"
    case count = "Count/Serving"
    
    var units: [MeasurementUnit] {
        return MeasurementUnit.allCases.filter { $0.category == self }
    }
}

class UnitConverter {
    static let shared = UnitConverter()
    
    private init() {}
    
    // Convert value from one unit to another within the same category
    func convert(value: Double, from fromUnit: MeasurementUnit, to toUnit: MeasurementUnit) -> Double? {
        if fromUnit == toUnit {
            return value
        }
        
        guard fromUnit.category == toUnit.category else {
            return nil
        }
        
        switch fromUnit.category {
        case .weight:
            return convertWeight(value: value, from: fromUnit, to: toUnit)
        case .volume:
            return convertVolume(value: value, from: fromUnit, to: toUnit)
        case .count:
            return nil
        }
    }
    
    // Convert weight units using grams as base unit
    private func convertWeight(value: Double, from fromUnit: MeasurementUnit, to toUnit: MeasurementUnit) -> Double {
        let grams: Double
        switch fromUnit {
        case .grams:
            grams = value
        case .kilograms:
            grams = value * 1000
        case .ounces:
            grams = value * 28.3495
        case .pounds:
            grams = value * 453.592
        case .milligrams:
            grams = value / 1000
        default:
            return value
        }
        
        switch toUnit {
        case .grams:
            return grams
        case .kilograms:
            return grams / 1000
        case .ounces:
            return grams / 28.3495
        case .pounds:
            return grams / 453.592
        case .milligrams:
            return grams * 1000
        default:
            return value
        }
    }
    
    // Convert volume units using milliliters as base unit
    private func convertVolume(value: Double, from fromUnit: MeasurementUnit, to toUnit: MeasurementUnit) -> Double {
        let milliliters: Double
        switch fromUnit {
        case .milliliters:
            milliliters = value
        case .liters:
            milliliters = value * 1000
        case .fluidOunces:
            milliliters = value * 29.5735
        case .cups:
            milliliters = value * 236.588
        case .tablespoons:
            milliliters = value * 14.7868
        case .teaspoons:
            milliliters = value * 4.92892
        case .pints:
            milliliters = value * 473.176
        case .quarts:
            milliliters = value * 946.353
        case .gallons:
            milliliters = value * 3785.41
        default:
            return value
        }
        
        switch toUnit {
        case .milliliters:
            return milliliters
        case .liters:
            return milliliters / 1000
        case .fluidOunces:
            return milliliters / 29.5735
        case .cups:
            return milliliters / 236.588
        case .tablespoons:
            return milliliters / 14.7868
        case .teaspoons:
            return milliliters / 4.92892
        case .pints:
            return milliliters / 473.176
        case .quarts:
            return milliliters / 946.353
        case .gallons:
            return milliliters / 3785.41
        default:
            return value
        }
    }
    
    func getCompatibleUnits(for unit: MeasurementUnit) -> [MeasurementUnit] {
        return unit.category.units
    }
    
    // Get contextually appropriate units based on food characteristics
    func getSuggestedUnits(for food: Food) -> [MeasurementUnit] {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        var suggestedUnits = getCompatibleUnits(for: originalUnit)
        
        if originalUnit.category == .weight {
            if food.servingSize >= 1000 {
                suggestedUnits = [.grams, .kilograms, .ounces, .pounds]
            } else if food.servingSize <= 10 {
                suggestedUnits = [.milligrams, .grams, .ounces]
            } else {
                suggestedUnits = [.grams, .ounces, .pounds]
            }
        } else if originalUnit.category == .volume {
            if food.servingSize >= 1000 {
                suggestedUnits = [.milliliters, .liters, .cups, .fluidOunces]
            } else {
                suggestedUnits = [.milliliters, .cups, .tablespoons, .fluidOunces]
            }
        }
        
        suggestedUnits.removeAll { $0 == originalUnit }
        suggestedUnits.insert(originalUnit, at: 0)
        
        return Array(suggestedUnits.prefix(6))
    }
    
    // Scale nutrition values based on quantity change
    func convertNutrition(nutrition: NutritionInfo, originalAmount: Double, newAmount: Double) -> NutritionInfo {
        let ratio = newAmount / originalAmount
        return nutrition.scaled(by: ratio)
    }
}

struct UnitConversionHelper {
    // Format quantity for display with appropriate decimal places
    static func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(quantity))
        } else if quantity < 10 {
            return String(format: "%.2f", quantity)
        } else {
            return String(format: "%.1f", quantity)
        }
    }
    
    static func getDisplayText(quantity: Double, unit: MeasurementUnit) -> String {
        let formattedQuantity = formatQuantity(quantity)
        return "\(formattedQuantity) \(unit.abbreviation)"
    }
    
    static func isValidConversion(from: MeasurementUnit, to: MeasurementUnit) -> Bool {
        return from.category == to.category
    }
}
