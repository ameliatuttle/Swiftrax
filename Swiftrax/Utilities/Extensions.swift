import SwiftUI
import Foundation

extension Double {
    var formattedNutrition: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(self))
        } else {
            return String(format: "%.1f", self)
        }
    }
}

extension Array where Element == FoodEntry {
    func filteredByMealType(_ mealType: MealType) -> [FoodEntry] {
        return self.filter { $0.mealType == mealType }
    }
    
    func totalNutrition() -> NutritionInfo {
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        var totalFiber: Double = 0
        var totalSugar: Double = 0
        var totalSodium: Double = 0
        
        for entry in self {
            let scaledNutrition = entry.scaledNutrition
            totalCalories += scaledNutrition.calories ?? 0
            totalProtein += scaledNutrition.protein ?? 0
            totalCarbs += scaledNutrition.carbohydrates ?? 0
            totalFat += scaledNutrition.fat ?? 0
            totalFiber += scaledNutrition.fiber ?? 0
            totalSugar += scaledNutrition.sugar ?? 0
            totalSodium += scaledNutrition.sodium ?? 0
        }
        
        return NutritionInfo(
            calories: totalCalories,
            protein: totalProtein,
            carbohydrates: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            sugar: totalSugar,
            sodium: totalSodium
        )
    }
}

extension Color {
    static let properSystemBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0) // #1C1C1E
        default:
            return UIColor.white // #FFFFFF
        }
    })
    
    static let properSystemGroupedBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        default:
            return UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1.0) // #F2F2F7
        }
    })
    
    static let properSecondarySystemBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1.0) // #2C2C2E
        default:
            return UIColor.white // #FFFFFF
        }
    })
    
    static let appBackground = properSystemGroupedBackground
    static let mealCardBackground = properSystemBackground
    static let foodItemBackground = properSecondarySystemBackground
    static let nutritionCardBackground = properSystemBackground

    static let adaptiveText = Color(.label)
    static let adaptiveSecondaryText = Color(.secondaryLabel)
    static let adaptiveTertiaryText = Color(.tertiaryLabel)

    static let adaptiveBackground = properSystemBackground
    static let adaptiveSecondaryBackground = properSecondarySystemBackground
    static let adaptiveTertiaryBackground = Color(.tertiarySystemBackground)

    static let nutritionOrange = Color(.systemOrange)
    static let nutritionRed = Color(.systemRed)
    static let nutritionBlue = Color(.systemBlue)
    static let nutritionPurple = Color(.systemPurple)
    static let nutritionGreen = Color(.systemGreen)
    static let nutritionPink = Color(.systemPink)
    static let nutritionYellow = Color(.systemYellow)
    static let nutritionIndigo = Color(.systemIndigo)
    static let nutritionTeal = Color(.systemTeal)
    static let nutritionMint = Color(.systemMint)

    static var primaryAccent: Color {
        Color(.systemBlue)
    }
    
    static var destructiveAction: Color {
        Color(.systemRed)
    }
    
    static var successAction: Color {
        Color(.systemGreen)
    }
    
    static var warningAction: Color {
        Color(.systemOrange)
    }

    static func adaptiveNutritionColor(base: UIColor, highContrast: UIColor) -> Color {
        Color(UIColor { traitCollection in
            if traitCollection.accessibilityContrast == .high {
                return highContrast
            } else {
                return base
            }
        })
    }
    
    // High contrast nutrition colors for accessibility
    static var nutritionCalories: Color {
        adaptiveNutritionColor(base: .systemOrange, highContrast: .systemRed)
    }
    
    static var nutritionProtein: Color {
        adaptiveNutritionColor(base: .systemRed, highContrast: .systemPink)
    }
    
    static var nutritionCarbs: Color {
        adaptiveNutritionColor(base: .systemBlue, highContrast: .systemIndigo)
    }
    
    static var nutritionFat: Color {
        adaptiveNutritionColor(base: .systemPurple, highContrast: .systemPurple)
    }

    static let fillPrimary = Color(.systemFill)
    static let fillSecondary = Color(.secondarySystemFill)
    static let fillTertiary = Color(.tertiarySystemFill)
    static let fillQuaternary = Color(.quaternarySystemFill)

    static let cardBackground = properSecondarySystemBackground
    static let highContrastCardBackground = Color(.tertiarySystemBackground)
    static let subCardBackground = properSystemBackground
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
    
    // Check if we're in high contrast mode
    static var isHighContrastEnabled: Bool {
        UIAccessibility.isReduceTransparencyEnabled ||
        UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    // Get appropriate nutrition color for accessibility
    static func accessibleNutritionColor(for metric: NutritionMetric) -> Color {
        switch metric {
        case .calories: return nutritionCalories
        case .protein: return nutritionProtein
        case .carbohydrates: return nutritionCarbs
        case .fat: return nutritionFat
        case .fiber: return nutritionGreen
        case .sugar: return nutritionPink
        case .sodium: return nutritionYellow
        }
    }
}

extension AppTheme {
    var displayName: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

extension View {

    func appleCardStyle() -> some View {
        self
            .background(Color.mealCardBackground)
            .cornerRadius(12)
            .shadow(
                color: Color(.systemFill).opacity(0.3),
                radius: 8, x: 0, y: 4
            )
    }

    func appBackground() -> some View {
        self.background(Color.appBackground)
    }

    func mealCardStyle() -> some View {
        self
            .background(Color.mealCardBackground)
            .cornerRadius(12)
            .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    func foodItemStyle() -> some View {
        self
            .background(Color.foodItemBackground)
            .cornerRadius(8)
            .shadow(color: Color.primary.opacity(0.08), radius: 2, x: 0, y: 1)
    }
    
    func nutritionMetricStyle(color: Color) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    func accessibleButton(style: ButtonType = .primary) -> some View {
        self
            .padding()
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(12)
            .accessibilityAddTraits(.isButton)
    }
    
    @ViewBuilder
    func adaptiveBorder() -> some View {
        if UIAccessibility.isReduceTransparencyEnabled {
            self.overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        } else {
            self
        }
    }
}

struct AdaptiveCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.adaptiveSecondaryBackground)
                    .shadow(
                        color: colorScheme == .dark ?
                               Color.white.opacity(0.05) :
                               Color.black.opacity(0.1),
                        radius: 4, x: 0, y: 2
                    )
            )
    }
}

extension View {
    func adaptiveCardStyle() -> some View {
        modifier(AdaptiveCardStyle())
    }
}

enum ButtonType {
    case primary
    case secondary
    case destructive
    case success
    
    var backgroundColor: Color {
        switch self {
        case .primary: return Color.primaryAccent
        case .secondary: return Color.fillSecondary
        case .destructive: return Color.destructiveAction
        case .success: return Color.successAction
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return Color.adaptiveText
        case .destructive: return .white
        case .success: return .white
        }
    }
}

enum NutritionMetric {
    case calories
    case protein
    case carbohydrates
    case fat
    case fiber
    case sugar
    case sodium
}

extension DatabaseManager {
    func searchFoodsAsync(query: String) async -> [Food] {
        await withCheckedContinuation { continuation in
            self.searchFoodsWithFuzzyMatching(query: query) { results in
                continuation.resume(returning: results)
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

extension Food {
    var measurementUnit: MeasurementUnit {
        return MeasurementUnit(rawValue: servingSizeUnit) ?? .grams
    }
    
    // Create a copy of this food with converted serving size
    func withConvertedServing(to newUnit: MeasurementUnit) -> Food? {
        guard let convertedSize = UnitConverter.shared.convert(
            value: servingSize,
            from: measurementUnit,
            to: newUnit
        ) else { return nil }
        
        var newFood = self
        newFood.servingSize = convertedSize
        newFood.servingSizeUnit = newUnit.abbreviation
        return newFood
    }
    
    // Calculate nutrition for a specific quantity and unit
    func nutritionFor(quantity: Double, unit: MeasurementUnit) -> NutritionInfo {
        let originalUnit = measurementUnit
        
        let convertedQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: originalUnit) {
            convertedQuantity = converted
        } else {
            convertedQuantity = quantity
        }
        
        let scaleFactor = convertedQuantity / servingSize
        return nutritionInfo.scaled(by: scaleFactor)
    }
    
    var compatibleUnits: [MeasurementUnit] {
        return UnitConverter.shared.getCompatibleUnits(for: measurementUnit)
    }
    
    var suggestedUnits: [MeasurementUnit] {
        return UnitConverter.shared.getSuggestedUnits(for: self)
    }
   
   // Custom decoder to handle legacy data compatibility
   init(from decoder: Decoder) throws {
       let container = try decoder.container(keyedBy: CodingKeys.self)
       
       id = try container.decode(UUID.self, forKey: .id)
       name = try container.decode(String.self, forKey: .name)
       barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
       nutritionInfo = try container.decode(NutritionInfo.self, forKey: .nutritionInfo)
       servingSize = try container.decode(Double.self, forKey: .servingSize)
       servingSizeUnit = try container.decode(String.self, forKey: .servingSizeUnit)
       brand = try container.decodeIfPresent(String.self, forKey: .brand)
       isCustom = try container.decode(Bool.self, forKey: .isCustom)
       dateAdded = try container.decode(Date.self, forKey: .dateAdded)
       recipeId = try container.decodeIfPresent(UUID.self, forKey: .recipeId)
       
       // Default values for fields that might not exist in legacy data
       source = try container.decodeIfPresent(String.self, forKey: .source) ?? "manual"
       lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
   }

   enum CodingKeys: String, CodingKey {
       case id, name, barcode, nutritionInfo, servingSize, servingSizeUnit
       case brand, isCustom, dateAdded, recipeId, source, lastUpdated
   }
}

extension FoodEntry {
    // Calculate nutrition with unit conversion
    func nutritionForQuantity(_ quantity: Double, unit: MeasurementUnit) -> NutritionInfo {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        let convertedQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: originalUnit) {
            convertedQuantity = converted
        } else {
            convertedQuantity = quantity
        }
        
        let scaleFactor = convertedQuantity / food.servingSize
        return food.nutritionInfo.scaled(by: scaleFactor)
    }
    
    // Create food entry with unit conversion handling
    static func create(food: Food, quantity: Double, unit: MeasurementUnit, mealType: MealType) -> FoodEntry {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        let storageQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: originalUnit) {
            storageQuantity = converted
        } else {
            storageQuantity = quantity
        }
        
        return FoodEntry(
            food: food,
            quantity: storageQuantity,
            mealType: mealType
        )
    }
    
    // Convert stored quantity to display in specified unit
    func getDisplayQuantity(in unit: MeasurementUnit) -> Double? {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        return UnitConverter.shared.convert(
            value: quantity,
            from: originalUnit,
            to: unit
        )
    }
    
    // Get formatted text for quantity display
    func getDisplayText(in unit: MeasurementUnit) -> String {
        guard let displayQuantity = getDisplayQuantity(in: unit) else {
            return "\(quantity.formattedNutrition) \(food.servingSizeUnit)"
        }
        
        return UnitConversionHelper.getDisplayText(quantity: displayQuantity, unit: unit)
    }
    
    func canConvertTo(_ unit: MeasurementUnit) -> Bool {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        return UnitConversionHelper.isValidConversion(from: originalUnit, to: unit)
    }
    
    var originalUnit: MeasurementUnit {
        return MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
    }
    
    var compatibleUnits: [MeasurementUnit] {
        return originalUnit.category.units
    }
}
