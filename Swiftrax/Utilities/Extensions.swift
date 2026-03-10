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
    
    /// Formats a nutrition value with more precision for small values
    var formattedNutritionPrecise: String {
        switch self {
        case 0..<0.1:
            return String(format: "%.2f", self)
        case 0.1..<10:
            return String(format: "%.1f", self)
        default:
            return self.truncatingRemainder(dividingBy: 1) == 0 
                ? String(Int(self)) 
                : String(format: "%.1f", self)
        }
    }
}

extension Array where Element == FoodEntry {
    func filteredByMealType(_ mealType: MealType) -> [FoodEntry] {
        return self.filter { $0.mealType == mealType }
    }
    
    func totalNutrition() -> NutritionInfo {
        return self.reduce(NutritionInfo.zero) { total, entry in
            total + entry.scaledNutrition
        }
    }
}

extension Color {
    private static let _properSystemBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0) // #1C1C1E
        default:
            return UIColor.white // #FFFFFF
        }
    })
    
    private static let _properSystemGroupedBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        default:
            return UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1.0) // #F2F2F7
        }
    })
    
    private static let _properSecondarySystemBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1.0) // #2C2C2E
        default:
            return UIColor.white // #FFFFFF
        }
    })
    
    static let properSystemBackground = _properSystemBackground
    static let properSystemGroupedBackground = _properSystemGroupedBackground
    static let properSecondarySystemBackground = _properSecondarySystemBackground
    
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
            .adaptiveBorder()
    }
    
    func foodItemStyle() -> some View {
        self
            .background(Color.foodItemBackground)
            .cornerRadius(8)
            .shadow(color: Color.primary.opacity(0.08), radius: 2, x: 0, y: 1)
            .adaptiveBorder()
    }
    
    func nutritionMetricStyle(color: Color) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
            .accessibilityElement(children: .combine)
    }
    
    func accessibleButton(style: ButtonType = .primary) -> some View {
        self
            .padding()
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(12)
            .accessibilityAddTraits(.isButton)
            .scaleEffect(UIAccessibility.isReduceMotionEnabled ? 1.0 : 0.95)
            .animation(.easeInOut(duration: 0.1), value: UIAccessibility.isReduceMotionEnabled)
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
    
    /// Modern card style with enhanced accessibility support
    func modernCardStyle(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.adaptiveSecondaryBackground)
                    .shadow(
                        color: Color.primary.opacity(UIAccessibility.isReduceTransparencyEnabled ? 0.15 : 0.08),
                        radius: UIAccessibility.isReduceTransparencyEnabled ? 2 : 4,
                        x: 0, y: 2
                    )
            )
            .adaptiveBorder()
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

/// Button styling options that adapt to system appearance and accessibility settings
enum ButtonType {
    case primary
    case secondary
    case destructive
    case success
    case warning
    
    var backgroundColor: Color {
        switch self {
        case .primary: return Color.primaryAccent
        case .secondary: return Color.fillSecondary
        case .destructive: return Color.destructiveAction
        case .success: return Color.successAction
        case .warning: return Color.warningAction
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return Color.adaptiveText
        case .destructive: return .white
        case .success: return .white
        case .warning: return .white
        }
    }
}

/// Nutrition metrics that can be displayed with appropriate colors and formatting
enum NutritionMetric: String, CaseIterable {
    case calories
    case protein
    case carbohydrates
    case fat
    case fiber
    case sugar
    case sodium
    
    /// Display name for the nutrition metric
    var displayName: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .carbohydrates: return "Carbs"
        case .fat: return "Fat"
        case .fiber: return "Fiber"
        case .sugar: return "Sugar"
        case .sodium: return "Sodium"
        }
    }
    
    /// Unit of measurement for the nutrition metric
    var unit: String {
        switch self {
        case .calories: return "kcal"
        case .protein, .carbohydrates, .fat, .fiber, .sugar: return "g"
        case .sodium: return "mg"
        }
    }
    
    /// Gets the value from a NutritionInfo object
    func getValue(from nutrition: NutritionInfo) -> Double? {
        switch self {
        case .calories: return nutrition.calories
        case .protein: return nutrition.protein
        case .carbohydrates: return nutrition.carbohydrates
        case .fat: return nutrition.fat
        case .fiber: return nutrition.fiber
        case .sugar: return nutrition.sugar
        case .sodium: return nutrition.sodium
        }
    }
}


extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

/// A digital roller-style number picker that fits the app's design theme
struct DigitalRollerPicker: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Double?
    
    @State private var wholeNumberSelection: Int = 0
    @State private var decimalSelection: Int = 0
    @Environment(\.colorScheme) var colorScheme
    
    private let decimalSteps: [Int] = [0, 25, 5, 75] // Represents .00, .25, .50, .75
    
    init(value: Binding<Double>, 
         range: ClosedRange<Double> = 0...999,
         step: Double = 0.25,
         defaultValue: Double? = nil) {
        self._value = value
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
        
        // Always use the current binding value for initialization
        let initialValue = value.wrappedValue
        
        let wholeNumber = Int(initialValue)
        let decimal = initialValue - Double(wholeNumber)
        
        self._wholeNumberSelection = State(initialValue: wholeNumber)
        self._decimalSelection = State(initialValue: self.getDecimalIndex(for: decimal))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Whole number roller
            VStack(spacing: 4) {
                Text("Whole")
                    .font(.caption2)
                    .foregroundColor(Color.adaptiveSecondaryText)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.adaptiveSecondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.adaptiveSecondaryText.opacity(0.2), lineWidth: 1)
                        )
                        .frame(minWidth: 50, maxWidth: 80, minHeight: 80, maxHeight: 80)
                    
                    Picker("Whole Number", selection: $wholeNumberSelection) {
                        ForEach(0...999, id: \.self) { number in
                            Text(String(format: "%d", number))
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.primaryAccent)
                                .tag(number)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(minWidth: 50, maxWidth: 80, minHeight: 80, maxHeight: 80)
                    .clipped()
                }
                .modernCardStyle(cornerRadius: 8)
            }
            
            // Decimal point
            Text(".")
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.adaptiveText)
                .padding(.top, 20)
            
            // Decimal roller
            VStack(spacing: 4) {
                Text("Decimal")
                    .font(.caption2)
                    .foregroundColor(Color.adaptiveSecondaryText)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.adaptiveSecondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.adaptiveSecondaryText.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 60, height: 80)
                    
                    Picker("Decimal", selection: $decimalSelection) {
                        ForEach(0..<decimalSteps.count, id: \.self) { index in
                            Text(String(format: "%02d", decimalSteps[index]))
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.primaryAccent)
                                .tag(index)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 60, height: 80)
                    .clipped()
                }
                .modernCardStyle(cornerRadius: 8)
            }
        }
        .onChange(of: wholeNumberSelection) { _ in updateValue() }
        .onChange(of: decimalSelection) { _ in updateValue() }
        .onAppear { 
            syncToCurrentValue()
        }
    }
    
    private func updateValue() {
        let decimal = Double(decimalSteps[decimalSelection]) / 100.0
        let newValue = Double(wholeNumberSelection) + decimal
        
        // Only provide haptic feedback if the device supports it and it's enabled
        if UIAccessibility.isReduceMotionEnabled == false {
            Task { @MainActor in
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
        }
        
        value = newValue
    }
    
    private func syncToCurrentValue() {
        syncToValue(value)
    }
    
    private func syncToValue(_ targetValue: Double) {
        let wholeNumber = Int(targetValue)
        let decimal = targetValue - Double(wholeNumber)
        
        wholeNumberSelection = wholeNumber
        decimalSelection = getDecimalIndex(for: decimal)
    }
    
    private func getDecimalIndex(for decimal: Double) -> Int {
        let rounded = Int(round(decimal * 100))
        
        switch rounded {
        case 0...12: return 0   // .00
        case 13...37: return 1  // .25
        case 38...62: return 2  // .50
        case 63...87: return 3  // .75
        default: return 0
        }
    }
}

/// Compact version for smaller spaces
struct CompactDigitalRollerPicker: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Environment(\.colorScheme) var colorScheme
    
    @State private var wholeNumberSelection: Int = 0
    @State private var decimalSelection: Int = 0
    
    private let decimalSteps: [Int] = [0, 5] // Represents .0, .5
    
    init(value: Binding<Double>, 
         range: ClosedRange<Double> = 0...999) {
        self._value = value
        self.range = range
        
        let wholeNumber = Int(value.wrappedValue)
        let decimal = value.wrappedValue - Double(wholeNumber)
        
        self._wholeNumberSelection = State(initialValue: wholeNumber)
        self._decimalSelection = State(initialValue: decimal >= 0.25 ? 1 : 0)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.adaptiveSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.adaptiveSecondaryText.opacity(0.2), lineWidth: 1)
                    )
                    .frame(minWidth: 40, maxWidth: 60, minHeight: 60, maxHeight: 60)
                
                Picker("Whole", selection: $wholeNumberSelection) {
                    ForEach(0...999, id: \.self) { number in
                        Text("\(number)")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.primaryAccent)
                            .tag(number)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(minWidth: 40, maxWidth: 60, minHeight: 60, maxHeight: 60)
                .clipped()
            }
            
            Text(".")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.adaptiveText)
            
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.adaptiveSecondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.adaptiveSecondaryText.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 45, height: 60)
                
                Picker("Decimal", selection: $decimalSelection) {
                    ForEach(0..<decimalSteps.count, id: \.self) { index in
                        Text("\(decimalSteps[index])")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.primaryAccent)
                            .tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 45, height: 60)
                .clipped()
            }
        }
        .onChange(of: wholeNumberSelection) { _ in updateValue() }
        .onChange(of: decimalSelection) { _ in updateValue() }
        .onAppear { syncToCurrentValue() }
    }
    
    private func updateValue() {
        let decimal = Double(decimalSteps[decimalSelection]) / 10.0
        let newValue = Double(wholeNumberSelection) + decimal
        
        // Only provide haptic feedback if motion isn't reduced
        if UIAccessibility.isReduceMotionEnabled == false {
            Task { @MainActor in
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.prepare()
                selectionFeedback.selectionChanged()
            }
        }
        
        value = newValue
    }
    
    private func syncToCurrentValue() {
        let wholeNumber = Int(value)
        let decimal = value - Double(wholeNumber)
        
        wholeNumberSelection = wholeNumber
        decimalSelection = decimal >= 0.25 ? 1 : 0
    }
}

/// A view modifier to easily add the digital roller picker
extension View {
    func digitalRollerQuantityPicker(value: Binding<Double>,
                                   range: ClosedRange<Double> = 0...999,
                                   step: Double = 0.25,
                                   defaultValue: Double? = nil,
                                   compact: Bool = false) -> some View {
        VStack(spacing: 16) {
            self
            
            if compact {
                CompactDigitalRollerPicker(value: value, range: range)
            } else {
                DigitalRollerPicker(value: value, range: range, step: step, defaultValue: defaultValue)
            }
        }
    }
}

extension Food {
    var measurementUnit: MeasurementUnit {
        return MeasurementUnit(rawValue: servingSizeUnit) ?? .grams
    }
    

    
    /// Validates that the food has reasonable data
    var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              servingSize > 0,
              !servingSizeUnit.isEmpty else {
            return false
        }
        
        // At least calories should be provided
        guard let calories = nutritionInfo.calories, calories >= 0 else {
            return false
        }
        
        return true
    }
    
    /// Returns a sanitized version of the food with cleaned data
    func sanitized() -> Food {
        var sanitized = self
        sanitized.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.brand = brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.barcode = barcode?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure serving size is positive
        if servingSize <= 0 {
            sanitized.servingSize = 100
        }
        
        return sanitized
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
        guard quantity > 0, food.servingSize > 0 else {
            return NutritionInfo.zero
        }
        
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

// MARK: - Recipe Backward Compatibility Extensions
extension RecipeIngredient {
    // Custom decoder to handle legacy data without unit field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        food = try container.decode(Food.self, forKey: .food)
        quantity = try container.decode(Double.self, forKey: .quantity)
        
        // Handle backward compatibility for unit field
        if let unitString = try container.decodeIfPresent(String.self, forKey: .unit),
           let parsedUnit = MeasurementUnit(rawValue: unitString) {
            unit = parsedUnit
        } else {
            // Legacy recipe: use food's original unit
            unit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, food, quantity, unit
    }
}

extension Recipe {
    // Custom decoder to handle legacy data without serving weight fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        servings = try container.decode(Int.self, forKey: .servings)
        ingredients = try container.decode([RecipeIngredient].self, forKey: .ingredients)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        
        // Handle backward compatibility for new fields
        servingWeight = try container.decodeIfPresent(Double.self, forKey: .servingWeight)
        if let unitString = try container.decodeIfPresent(String.self, forKey: .servingWeightUnit),
           let parsedUnit = MeasurementUnit(rawValue: unitString) {
            servingWeightUnit = parsedUnit
        } else {
            servingWeightUnit = servingWeight != nil ? .grams : nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, servings, ingredients, dateCreated
        case servingWeight, servingWeightUnit
    }
}

// MARK: - Recipe Extensions
extension Recipe {
    /// Creates a copy of the recipe for editing purposes
    func editingCopy() -> Recipe {
        return Recipe(
            from: self,
            name: self.name,
            servings: self.servings,
            ingredients: self.ingredients,
            servingWeight: self.servingWeight,
            servingWeightUnit: self.servingWeightUnit
        )
    }
}
