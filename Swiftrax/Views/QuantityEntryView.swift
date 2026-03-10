import SwiftUI

struct QuantityEntryView: View {
    let food: Food
    let initialMealType: MealType
    let onSave: (Double, MeasurementUnit, MealType) -> Void
    
    @State private var quantity: String = ""
    @State private var selectedUnit: MeasurementUnit
    @State private var selectedMealType: MealType
    @State private var showingUnitPicker = false
    @State private var isConverting = false
    @State private var showingConversionHelper = false
    @State private var showingSourcesInfo = false

    
    @Environment(\.presentationMode) var presentationMode
    
    private let originalUnit: MeasurementUnit
    private let suggestedUnits: [MeasurementUnit]
    
    init(food: Food, mealType: MealType, onSave: @escaping (Double, MeasurementUnit, MealType) -> Void) {
        self.food = food
        self.initialMealType = mealType
        self.onSave = onSave
        
        self.originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        self.suggestedUnits = UnitConverter.shared.getSuggestedUnits(for: food)
        
        self._selectedUnit = State(initialValue: originalUnit)
        self._selectedMealType = State(initialValue: mealType) // Use mealType here
        self._quantity = State(initialValue: UnitConversionHelper.formatQuantity(food.servingSize))
    }
    
    // Initializer with prefilled quantity (for recent entries)
    init(food: Food, mealType: MealType, prefilledQuantity: Double, onSave: @escaping (Double, MeasurementUnit, MealType) -> Void) {
        self.food = food
        self.initialMealType = mealType
        self.onSave = onSave
        
        self.originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        self.suggestedUnits = UnitConverter.shared.getSuggestedUnits(for: food)
        
        self._selectedUnit = State(initialValue: originalUnit)
        self._selectedMealType = State(initialValue: mealType)
        self._quantity = State(initialValue: UnitConversionHelper.formatQuantity(prefilledQuantity))
    }
    
    var calculatedNutrition: NutritionInfo {
        guard let quantityValue = Double(quantity) else {
            return NutritionInfo.zero
        }
        
        return food.nutritionFor(quantity: quantityValue, unit: selectedUnit)
    }
    
    var isValidQuantity: Bool {
        guard let value = Double(quantity) else { return false }
        return value > 0
    }
    
    // Returns appropriate default quantity based on unit type and category
    private func getSmartDefaultQuantity(for unit: MeasurementUnit) -> String {
        if unit == originalUnit {
            return food.servingSize.formattedNutrition
        }

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

        return food.servingSize.formattedNutrition
    }
   
   var numberOfServings: Double? {
       guard food.servingSize > 0, let qty = Double(quantity) else { return nil }
       let ratio = qty / food.servingSize
       return round(ratio * 100) / 100
   }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    ImprovedFoodInfoCard(
                        food: food,
                        selectedMealType: $selectedMealType
                    )
                   
                    ImprovedQuantityInputSection(
                        quantity: $quantity,
                        selectedUnit: $selectedUnit,
                        showingUnitPicker: $showingUnitPicker,
                        suggestedUnits: suggestedUnits,
                        originalUnit: originalUnit,
                        numberOfServings: numberOfServings,
                        onUnitChanged: { unit in handleUnitChange(to: unit) }
                    )
                   
                   CompactDigitalRollerPicker(
                       value: Binding(
                           get: { Double(quantity) ?? 0 },
                           set: { quantity = UnitConversionHelper.formatQuantity($0) }
                       ),
                       range: 0...999
                   )
                   .padding(.horizontal)
                   
                   if selectedUnit != originalUnit {
                       VStack(spacing: 8) {
                           Text("Unit Conversion")
                               .font(.headline)
                               .fontWeight(.semibold)
                               .foregroundColor(Color.adaptiveText)
                           
                           HStack {
                               Text("\(quantity) \(selectedUnit.abbreviation)")
                                   .font(.subheadline)
                                   .fontWeight(.medium)
                                   .foregroundColor(Color.adaptiveText)
                               
                               Image(systemName: "arrow.right")
                                   .foregroundColor(Color.primaryAccent)
                                   .font(.caption)
                               
                               if let convertedQuantity = UnitConverter.shared.convert(
                                   value: Double(quantity) ?? 0,
                                   from: selectedUnit,
                                   to: originalUnit
                               ) {
                                   Text("\(UnitConversionHelper.formatQuantity(convertedQuantity)) \(originalUnit.abbreviation)")
                                       .font(.subheadline)
                                       .fontWeight(.medium)
                                       .foregroundColor(Color.primaryAccent)
                               }
                               
                               Spacer()
                           }
                           .padding()
                           .background(Color.primaryAccent.opacity(0.05))
                           .cornerRadius(8)
                       }
                       .padding()
                       .background(Color.nutritionOrange.opacity(0.05))
                       .cornerRadius(12)
                   }
                    
                    if isValidQuantity {
                        ImprovedNutritionPreviewCard(
                            nutrition: calculatedNutrition,
                            quantity: quantity,
                            unit: selectedUnit,
                            originalFood: food,
                            onShowSources: { showingSourcesInfo = true }
                        )
                    }

                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Add Food")
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
                .foregroundColor(isValidQuantity ? Color.primaryAccent : Color.adaptiveSecondaryText)
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
        .sheet(isPresented: $showingSourcesInfo) {
            SearchLogView.NutritionSourcesView()
        }

    }
    
    // Updates selected unit and sets appropriate default quantity
    private func handleUnitChange(to newUnit: MeasurementUnit) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedUnit = newUnit
            quantity = getSmartDefaultQuantity(for: newUnit)
        }
    }
    
    private func saveEntry() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else { return }
        
        onSave(quantityValue, selectedUnit, selectedMealType)
        presentationMode.wrappedValue.dismiss()
    }
}

struct ImprovedFoodInfoCard: View {
    let food: Food
    @Binding var selectedMealType: MealType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(food.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(Color.adaptiveText)
                    
                    if let brand = food.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(Color.adaptiveSecondaryText)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    if food.isFromAPI {
                        VStack(spacing: 2) {
                            Text(food.sourceEmoji)
                                .font(.title2)
                            Text(food.source)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(Color.adaptiveSecondaryText)
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text("✏️")
                                .font(.title2)
                            Text("Custom")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(Color.adaptiveSecondaryText)
                        }
                    }
                }
            }
            
            // Meal Selection Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Add to Meal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText)
                
                Picker("Select Meal", selection: $selectedMealType) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        let displayText = mealType.emoji + " " + mealType.rawValue
                        Text(displayText)
                            .font(.caption)
                            .tag(mealType)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Divider()
            
            VStack(spacing: 8) {
                HStack {
                    Text("Original Serving Size")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(food.servingSize.formattedNutrition) \(food.servingSizeUnit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText)
                }
                
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
        .background(Color.fillSecondary.opacity(0.5))
        .cornerRadius(12)
    }
}

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

struct ImprovedQuantityInputSection: View {
    @Binding var quantity: String
    @Binding var selectedUnit: MeasurementUnit
    @Binding var showingUnitPicker: Bool
    
    let suggestedUnits: [MeasurementUnit]
    let originalUnit: MeasurementUnit
    let numberOfServings: Double?
    let onUnitChanged: (MeasurementUnit) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let servings = numberOfServings {
                Text("≈ \(String(format: "%.2f", servings)) servings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } else {
                Text("How much are you eating?")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText)
            }
            
            HStack(spacing: 12) {
                HStack {
                    TextField("Amount", text: $quantity)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.adaptiveText)
                    
                    Button("Clear") {
                        quantity = ""
                    }
                    .font(.caption)
                    .foregroundColor(Color.primaryAccent)
                    .opacity(quantity.isEmpty ? 0 : 1)
                }
                .padding()
                .background(Color.fillSecondary)
                .cornerRadius(12)
                
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
                            .foregroundColor(Color.adaptiveSecondaryText)
                    }
                    .padding()
                    .frame(minWidth: 80)
                    .background(Color.primaryAccent.opacity(0.1))
                    .foregroundColor(Color.primaryAccent)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.fillSecondary.opacity(0.5))
        .cornerRadius(12)
    }
}

struct ImprovedNutritionPreviewCard: View {
    let nutrition: NutritionInfo
    let quantity: String
    let unit: MeasurementUnit
    let originalFood: Food
    let onShowSources: () -> Void
    
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
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if servingRatio != 1.0 {
                        Text("\(servingRatio.formattedNutrition)× serving")
                            .font(.caption)
                            .foregroundColor(Color.adaptiveSecondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.fillSecondary)
                            .cornerRadius(4)
                    }
                    
                    Button(action: onShowSources) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                            Text("Sources")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Text("For \(quantity) \(unit.displayName.lowercased())")
                .font(.subheadline)
                .foregroundColor(Color.adaptiveSecondaryText)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText)
                    
                    Text("\(Int(nutrition.calories ?? 0))")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.nutritionOrange)
                }
                
                Spacer()
                
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
        .background(Color.fillSecondary.opacity(0.5))
        .cornerRadius(12)
    }
}

struct MacroDisplay: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.adaptiveSecondaryText)
            Text("\(Int(value))g")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

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
                Section("Current Selection") {
                    HStack {
                        Text(selectedUnit.displayName)
                            .fontWeight(.medium)
                            .foregroundColor(Color.adaptiveText)
                        
                        Spacer()
                        
                        Text("(\(selectedUnit.abbreviation))")
                            .foregroundColor(Color.adaptiveSecondaryText)
                        
                        Image(systemName: "checkmark")
                            .foregroundColor(Color.primaryAccent)
                    }
                }
                
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
                                            .foregroundColor(Color.adaptiveText)
                                        
                                        Text(unit.abbreviation)
                                            .font(.caption)
                                            .foregroundColor(Color.adaptiveSecondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    if unit != selectedUnit,
                                       let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) {
                                        if let converted = UnitConverter.shared.convert(
                                            value: food.servingSize,
                                            from: originalUnit,
                                            to: unit
                                        ) {
                                            Text("\(converted.formattedNutrition) \(unit.abbreviation)")
                                                .font(.caption)
                                                .foregroundColor(Color.primaryAccent)
                                        }
                                    }
                                    
                                    if unit == selectedUnit {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.primaryAccent)
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
                .foregroundColor(Color.primaryAccent)
            )
        }
    }
}
