import SwiftUI

struct QuantityEntryView: View {
    let food: Food
    let mealType: MealType
    let onSave: (Double, MeasurementUnit) -> Void
    
    @State private var quantity: String = ""
    @State private var selectedUnit: MeasurementUnit
    @State private var showingUnitPicker = false
    @State private var isConverting = false
    @State private var showingConversionHelper = false
    
    @Environment(\.presentationMode) var presentationMode
    
    private let originalUnit: MeasurementUnit
    private let suggestedUnits: [MeasurementUnit]
    
    init(food: Food, mealType: MealType, onSave: @escaping (Double, MeasurementUnit) -> Void) {
        self.food = food
        self.mealType = mealType
        self.onSave = onSave
        
        self.originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        self.suggestedUnits = UnitConverter.shared.getSuggestedUnits(for: food)
        
        self._selectedUnit = State(initialValue: originalUnit)
        self._quantity = State(initialValue: UnitConversionHelper.formatQuantity(food.servingSize))
    }
    
    var calculatedNutrition: NutritionInfo {
        guard let quantityValue = Double(quantity) else {
            return NutritionInfo.zero
        }
        
        // Get nutrition for the current quantity and unit
        return food.nutritionFor(quantity: quantityValue, unit: selectedUnit)
    }
    
    var isValidQuantity: Bool {
        guard let value = Double(quantity) else { return false }
        return value > 0
    }
    
    // Smart default quantities for different units
   private func getSmartDefaultQuantity(for unit: MeasurementUnit) -> String {
       // Always return the food’s actual serving size if the unit matches the original
       if unit == originalUnit {
           return food.servingSize.formattedNutrition
       }

       // Only use these if user switches units
       switch unit.category {
       case .weight:
           if unit == .grams {
               return "100"
           } else if unit == .ounces {
               return "3.5"
           } else if unit == .pounds {
               return "0.25"
           }
       case .volume:
           if unit == .cups {
               return "1"
           } else if unit == .tablespoons {
               return "2"
           } else if unit == .milliliters {
               return "250"
           }
       case .count:
           return "1"
       }

       // Fallback to original serving size
       return food.servingSize.formattedNutrition
   }
   
   var numberOfServings: Double? {
       guard food.servingSize > 0, let qty = Double(quantity) else { return nil }
       let ratio = qty / food.servingSize
       return round(ratio * 100) / 100  // round to 2 decimals
   }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Food Information Card
                    ImprovedFoodInfoCard(food: food)
                   
                   if let servings = numberOfServings {
                      Text("≈ \(String(format: "%.2f", servings)) servings")
                           .font(.subheadline)
                           .foregroundColor(.secondary)
                   }
                   
                    // Quantity Input Section
                    ImprovedQuantityInputSection(
                        quantity: $quantity,
                        selectedUnit: $selectedUnit,
                        showingUnitPicker: $showingUnitPicker,
                        suggestedUnits: suggestedUnits,
                        originalUnit: originalUnit,
                        onUnitChanged: { unit in handleUnitChange(to: unit) }
                    )
                   
                   Slider(
                       value: Binding(
                           get: { Double(quantity) ?? 0 },
                           set: { quantity = UnitConversionHelper.formatQuantity($0) }
                       ),
                       in: 0...500,
                       step: 0.5
                   )
                   .accentColor(.blue)
                   .padding(.horizontal)
                   
                    
                   // Unit Conversion Display
                   if selectedUnit != originalUnit {
                       VStack(spacing: 8) {
                           Text("Unit Conversion")
                               .font(.headline)
                               .fontWeight(.semibold)
                               .foregroundColor(Color.adaptiveText) // Using semantic color
                           
                           HStack {
                               Text("\(quantity) \(selectedUnit.abbreviation)")
                                   .font(.subheadline)
                                   .fontWeight(.medium)
                                   .foregroundColor(Color.adaptiveText) // Using semantic color
                               
                               Image(systemName: "arrow.right")
                                   .foregroundColor(Color.primaryAccent) // Using semantic accent color
                                   .font(.caption)
                               
                               if let convertedQuantity = UnitConverter.shared.convert(
                                   value: Double(quantity) ?? 0,
                                   from: selectedUnit,
                                   to: originalUnit
                               ) {
                                   Text("\(UnitConversionHelper.formatQuantity(convertedQuantity)) \(originalUnit.abbreviation)")
                                       .font(.subheadline)
                                       .fontWeight(.medium)
                                       .foregroundColor(Color.primaryAccent) // Using semantic accent color
                               }
                               
                               Spacer()
                           }
                           .padding()
                           .background(Color.primaryAccent.opacity(0.05)) // Using semantic accent color
                           .cornerRadius(8)
                       }
                       .padding()
                       .background(Color.nutritionOrange.opacity(0.05)) // Using semantic orange color
                       .cornerRadius(12)
                   }
                    
                    // Nutrition Preview
                    if isValidQuantity {
                        ImprovedNutritionPreviewCard(
                            nutrition: calculatedNutrition,
                            quantity: quantity,
                            unit: selectedUnit,
                            originalFood: food
                        )
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    saveEntry()
                }
                .disabled(!isValidQuantity)
                .fontWeight(.semibold)
                .foregroundColor(isValidQuantity ? Color.primaryAccent : Color.adaptiveSecondaryText) // Using semantic colors
            )
        }
        .sheet(isPresented: $showingUnitPicker) {
            ImprovedUnitPickerView(
                selectedUnit: $selectedUnit,
                availableUnits: suggestedUnits,
                food: food,
                onUnitSelected: { unit in
                    handleUnitChange(to: unit)
                    showingUnitPicker = false
                }
            )
        }
    }
    
   private func handleUnitChange(to newUnit: MeasurementUnit) {
       withAnimation(.easeInOut(duration: 0.3)) {
           selectedUnit = newUnit
           // Set a smart default quantity for the new unit
           quantity = getSmartDefaultQuantity(for: newUnit)
       }
   }
    
    private func saveEntry() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else { return }
        
        print("💾 Saving entry: \(quantityValue) \(selectedUnit.abbreviation) of \(food.name)")
        onSave(quantityValue, selectedUnit)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Improved Food Info Card
struct ImprovedFoodInfoCard: View {
    let food: Food
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(food.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Color.adaptiveText) // Using semantic color
                    
                    if let brand = food.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                    }
                }
                
                Spacer()
                
                // Source indicator
                VStack(spacing: 4) {
                    if food.isFromAPI {
                        VStack(spacing: 2) {
                            Text(food.sourceEmoji)
                                .font(.title2)
                            Text(food.source)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text("✏️")
                                .font(.title2)
                            Text("Custom")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                        }
                    }
                }
            }
            
            Divider()
            
            // Original serving information
            VStack(spacing: 8) {
                HStack {
                    Text("Original Serving Size")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(food.servingSize.formattedNutrition) \(food.servingSizeUnit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText) // Using semantic color
                }
                
                // Macro breakdown for original serving
                HStack {
                    MacroChip(label: "Cal", value: food.nutritionInfo.calories ?? 0, color: Color.nutritionOrange)
                    MacroChip(label: "P", value: food.nutritionInfo.protein ?? 0, color: Color.nutritionRed)
                    MacroChip(label: "C", value: food.nutritionInfo.carbohydrates ?? 0, color: Color.nutritionBlue)
                    MacroChip(label: "F", value: food.nutritionInfo.fat ?? 0, color: Color.nutritionPurple)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.fillSecondary.opacity(0.5)) // Using semantic fill color
        .cornerRadius(12)
    }
}

// MARK: - Macro Chip (Updated with semantic colors)
struct MacroChip: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
            Text("\(Int(value))")
                .font(.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - Improved Quantity Input Section
struct ImprovedQuantityInputSection: View {
    @Binding var quantity: String
    @Binding var selectedUnit: MeasurementUnit
    @Binding var showingUnitPicker: Bool
    
    let suggestedUnits: [MeasurementUnit]
    let originalUnit: MeasurementUnit
    let onUnitChanged: (MeasurementUnit) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How much are you eating?")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText) // Using semantic color
            
            HStack(spacing: 12) {
                // Quantity Input
                HStack {
                    TextField("Amount", text: $quantity)
                        .keyboardType(.decimalPad)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    hideKeyboard()
                                }
                            }
                        }

                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.adaptiveText) // Using semantic color
                    
                    Button("Clear") {
                        quantity = ""
                    }
                    .font(.caption)
                    .foregroundColor(Color.primaryAccent) // Using semantic accent color
                    .opacity(quantity.isEmpty ? 0 : 1)
                }
                .padding()
                .background(Color.fillSecondary) // Using semantic fill color
                .cornerRadius(12)
                
                // Unit Selector Button
                Button(action: {
                    showingUnitPicker = true
                }) {
                    VStack(spacing: 4) {
                        Text(selectedUnit.abbreviation)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text(selectedUnit.displayName)
                            .font(.caption2)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                    }
                    .padding()
                    .frame(minWidth: 80)
                    .background(Color.primaryAccent.opacity(0.1)) // Using semantic accent color
                    .foregroundColor(Color.primaryAccent) // Using semantic accent color
                    .cornerRadius(12)
                }
            }
            
            // Quick Unit Buttons
            if suggestedUnits.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick units:")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedUnits.prefix(5), id: \.self) { unit in
                                QuickUnitButton(
                                    unit: unit,
                                    isSelected: unit == selectedUnit,
                                    isOriginal: unit == originalUnit
                                ) {
                                    onUnitChanged(unit)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color.fillSecondary.opacity(0.5)) // Using semantic fill color
        .cornerRadius(12)
    }
}

// MARK: - Quick Unit Button (Updated with semantic colors)
struct QuickUnitButton: View {
    let unit: MeasurementUnit
    let isSelected: Bool
    let isOriginal: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(unit.abbreviation)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                if isOriginal {
                    Text("original")
                        .font(.caption2)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                } else {
                    Text(unit.displayName)
                        .font(.caption2)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primaryAccent : Color.fillSecondary) // Using semantic colors
            .foregroundColor(isSelected ? .white : Color.adaptiveText) // Using semantic colors
            .cornerRadius(8)
        }
        .disabled(isSelected)
    }
}

// MARK: - Improved Nutrition Preview Card
struct ImprovedNutritionPreviewCard: View {
    let nutrition: NutritionInfo
    let quantity: String
    let unit: MeasurementUnit
    let originalFood: Food
    
    private var servingRatio: Double {
        guard let quantityValue = Double(quantity) else { return 1.0 }
        
        let originalUnit = MeasurementUnit(rawValue: originalFood.servingSizeUnit) ?? .grams
        
        if let convertedQuantity = UnitConverter.shared.convert(
            value: quantityValue,
            from: unit,
            to: originalUnit
        ) {
            return convertedQuantity / originalFood.servingSize
        }
        
        return quantityValue / originalFood.servingSize
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText) // Using semantic color
                
                Spacer()
                
                if servingRatio != 1.0 {
                    Text("\(servingRatio.formattedNutrition)× serving")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.fillSecondary) // Using semantic fill color
                        .cornerRadius(4)
                }
            }
            
            Text("For \(quantity) \(unit.displayName.lowercased())")
                .font(.subheadline)
                .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
            
            // Main calories display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                    
                    Text("\(Int(nutrition.calories ?? 0))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.nutritionOrange) // Using semantic color
                }
                
                Spacer()
                
                // Macros grid
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 12) {
                       MacroDisplay(label: "Protein", value: nutrition.protein ?? 0, color: Color.nutritionRed)
                       MacroDisplay(label: "Carbs", value: nutrition.carbohydrates ?? 0, color: Color.nutritionBlue)
                    }
                    
                    HStack(spacing: 12) {
                       MacroDisplay(label: "Fat", value: nutrition.fat ?? 0, color: Color.nutritionPurple)
                        
                        if let fiber = nutrition.fiber, fiber > 0 {
                           MacroDisplay(label: "Fiber", value: fiber, color: Color.nutritionGreen)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.fillSecondary.opacity(0.5)) // Using semantic fill color
        .cornerRadius(12)
    }
}

// MARK: - Macro Display (Updated with semantic colors)
struct MacroDisplay: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
            Text("\(Int(value))g")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Improved Unit Picker View
struct ImprovedUnitPickerView: View {
    @Binding var selectedUnit: MeasurementUnit
    let availableUnits: [MeasurementUnit]
    let food: Food
    let onUnitSelected: (MeasurementUnit) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var groupedUnits: [(UnitCategory, [MeasurementUnit])] {
        let categories = Set(availableUnits.map { $0.category })
        return categories.map { category in
            (category, availableUnits.filter { $0.category == category })
        }.sorted { $0.0.rawValue < $1.0.rawValue }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Current selection
                Section("Current Selection") {
                    HStack {
                        Text(selectedUnit.displayName)
                            .fontWeight(.medium)
                            .foregroundColor(Color.adaptiveText) // Using semantic color
                        
                        Spacer()
                        
                        Text("(\(selectedUnit.abbreviation))")
                            .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                        
                        Image(systemName: "checkmark")
                            .foregroundColor(Color.primaryAccent) // Using semantic accent color
                    }
                }
                
                // Available units by category
                ForEach(groupedUnits, id: \.0) { category, units in
                    Section(category.rawValue) {
                        ForEach(units, id: \.self) { unit in
                            Button(action: {
                                onUnitSelected(unit)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(unit.displayName)
                                            .font(.body)
                                            .foregroundColor(Color.adaptiveText) // Using semantic color
                                        
                                        Text(unit.abbreviation)
                                            .font(.caption)
                                            .foregroundColor(Color.adaptiveSecondaryText) // Using semantic color
                                    }
                                    
                                    Spacer()
                                    
                                    // Show conversion preview
                                    if unit != selectedUnit,
                                       let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) {
                                        if let converted = UnitConverter.shared.convert(
                                            value: food.servingSize,
                                            from: originalUnit,
                                            to: unit
                                        ) {
                                            Text("\(converted.formattedNutrition) \(unit.abbreviation)")
                                                .font(.caption)
                                                .foregroundColor(Color.primaryAccent) // Using semantic accent color
                                        }
                                    }
                                    
                                    if unit == selectedUnit {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.primaryAccent) // Using semantic accent color
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Select Unit")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Color.primaryAccent) // Using semantic accent color
            )
        }
    }
}

#Preview {
    let sampleFood = Food(
        name: "Grilled Chicken Breast",
        nutritionInfo: NutritionInfo(calories: 165, protein: 31, carbohydrates: 0, fat: 3.6),
        servingSize: 100,
        servingSizeUnit: "g",
        brand: "Generic"
    )
    
    return QuantityEntryView(
        food: sampleFood,
        mealType: .lunch
    ) { quantity, unit in
        print("Saving \(quantity) \(unit.abbreviation)")
    }
}
