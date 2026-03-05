import SwiftUI

import SwiftUI

struct ManualEntryView: View {
    @State private var mealType: MealType = .breakfast
    @State private var foodName = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var servingSize = ""
    @State private var servingUnit: MeasurementUnit = .grams
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var sodium = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingUnitPicker = false
    @State private var isAdvancedMode = false
    @State private var showingValidationError = false
    @State private var validationErrorMessage = ""
    @State private var showingBarcodeScanner = false
   
   private let screenWidth = UIScreen.main.bounds.width
   private let screenHeight = UIScreen.main.bounds.height
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case foodName, brand, barcode, servingSize, calories, protein, carbohydrates, fat, fiber, sugar, sodium
    }
    
    @Environment(\.presentationMode) var presentationMode
    
    private let commonUnits: [MeasurementUnit] = [
        .grams, .ounces, .cups, .tablespoons, .teaspoons, .pieces, .servings
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Meal Type Selection
                Section("Add to Meal") {
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            Text("\(mealType.emoji) \(mealType.rawValue)")
                                .tag(mealType)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Food Information
                Section("Food Information") {
                    TextField("Food name", text: $foodName)
                        .focused($focusedField, equals: .foodName)
                        .autocapitalization(.words)
                        .onSubmit {
                            focusedField = .brand
                        }
                    
                    TextField("Brand (optional)", text: $brand)
                        .focused($focusedField, equals: .brand)
                        .autocapitalization(.words)
                        .onSubmit {
                            focusedField = .barcode
                        }
                }
                
                // Barcode Section
                Section(header: HStack {
                    Text("Barcode (optional)")
                    Spacer()
                    Text("For easy future scanning")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }) {
                    HStack {
                        TextField("Enter barcode manually", text: $barcode)
                            .focused($focusedField, equals: .barcode)
                            .keyboardType(.numberPad)
                            .onSubmit {
                                focusedField = .servingSize
                            }
                        
                        Button(action: {
                            focusedField = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingBarcodeScanner = true
                            }
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        .accessibilityLabel("Scan barcode")
                    }
                    
                    if !barcode.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Barcode added - this food will be findable by scanning")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Add a barcode to easily find this food later by scanning")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Enhanced Serving Size with Unit Picker
                Section("Serving Size") {
                    HStack {
                        TextField("Amount", text: $servingSize)
                            .focused($focusedField, equals: .servingSize)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: .infinity)
                            .onSubmit {
                                focusedField = .calories
                            }
                        
                        Button(action: {
                            focusedField = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingUnitPicker = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(servingUnit.displayName)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Quick unit buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(commonUnits.prefix(6), id: \.self) { unit in
                                Button(unit.abbreviation) {
                                    servingUnit = unit
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(servingUnit == unit ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(servingUnit == unit ? .white : .primary)
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Basic Nutrition Information
                Section("Basic Nutrition (per \(servingSize.isEmpty ? "1" : servingSize) \(servingUnit.displayName.lowercased()))") {
                    NutritionInputRow(
                        label: "Calories",
                        value: $calories,
                        unit: "kcal",
                        focusedField: $focusedField,
                        field: .calories,
                        nextField: .protein
                    )
                    
                    NutritionInputRow(
                        label: "Protein",
                        value: $protein,
                        unit: "g",
                        focusedField: $focusedField,
                        field: .protein,
                        nextField: .carbohydrates
                    )
                    
                    NutritionInputRow(
                        label: "Carbohydrates",
                        value: $carbohydrates,
                        unit: "g",
                        focusedField: $focusedField,
                        field: .carbohydrates,
                        nextField: .fat
                    )
                    
                    NutritionInputRow(
                        label: "Fat",
                        value: $fat,
                        unit: "g",
                        focusedField: $focusedField,
                        field: .fat,
                        nextField: nil
                    )
                }
                
                // Advanced Nutrition (Optional)
                Section {
                    DisclosureGroup("Additional Nutrients", isExpanded: $isAdvancedMode) {
                        NutritionInputRow(
                            label: "Fiber",
                            value: $fiber,
                            unit: "g",
                            focusedField: $focusedField,
                            field: .fiber,
                            nextField: .sugar
                        )
                        
                        NutritionInputRow(
                            label: "Sugar",
                            value: $sugar,
                            unit: "g",
                            focusedField: $focusedField,
                            field: .sugar,
                            nextField: .sodium
                        )
                        
                        NutritionInputRow(
                            label: "Sodium",
                            value: $sodium,
                            unit: "mg",
                            focusedField: $focusedField,
                            field: .sodium,
                            nextField: nil
                        )
                    }
                }
                
                // Validation Error Display
                if !validationErrorMessage.isEmpty {
                    Section {
                        Text(validationErrorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // Nutrition Preview
                if isValid {
                    Section("Nutrition Preview") {
                        let nutrition = createNutritionInfo()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Calories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(nutrition.calories ?? 0))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                MacroDisplay(label: "P", value: nutrition.protein ?? 0, color: .red)
                                MacroDisplay(label: "C", value: nutrition.carbohydrates ?? 0, color: .blue)
                                MacroDisplay(label: "F", value: nutrition.fat ?? 0, color: .purple)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Save Button
                Section {
                    Button(action: saveFood) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to \(mealType.rawValue)")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(isValid ? .white : .secondary)
                    }
                    .listRowBackground(isValid ? Color.blue : Color.gray.opacity(0.3))
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    HStack {
                        Button("Previous") {
                            moveToPreviousField()
                        }
                        .disabled(!canMoveToPrevious())
                        
                        Button("Next") {
                            moveToNextField()
                        }
                        .disabled(!canMoveToNext())
                        
                        Spacer()
                        
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .onAppear {
                Task { @MainActor in
                    validateForm()
                }
            }
            .onChange(of: foodName) { _ in validateFormAsync() }
            .onChange(of: servingSize) { _ in validateFormAsync() }
            .onChange(of: calories) { _ in validateFormAsync() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingUnitPicker) {
            NavigationView {
                List {
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Button(action: {
                            servingUnit = unit
                            showingUnitPicker = false
                            validateFormAsync()
                        }) {
                            HStack {
                                Text(unit.displayName)
                                Spacer()
                                if unit == servingUnit {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .navigationTitle("Select Unit")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    trailing: Button("Done") {
                        showingUnitPicker = false
                    }
                )
            }
        }
        .alert("Food Added Successfully!", isPresented: $showingSuccessAlert) {
            Button("Add Another") {
                clearForm()
            }
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(successMessage)
        }
        .alert("Validation Error", isPresented: $showingValidationError) {
            Button("OK") { }
        } message: {
            Text(validationErrorMessage)
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView { scannedBarcode in
                Task { @MainActor in
                    barcode = scannedBarcode
                    showingBarcodeScanner = false
                }
            }
        }
    }
    
    private var isValid: Bool {
        let validation = validateFormData()
        return validation.isValid
    }
    
    // Validates form without triggering state modification warnings
    private func validateFormAsync() {
        Task { @MainActor in
            validateForm()
        }
    }
    
    private func validateForm() {
        let validation = validateFormData()
        validationErrorMessage = validation.errorMessage
    }
    
    // Returns validation status and error message for form data
    private func validateFormData() -> (isValid: Bool, errorMessage: String) {
        let trimmedName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return (false, "Food name is required")
        }
        
        // Validate barcode if provided
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBarcode.isEmpty {
            // Check if barcode contains only numbers
            if !trimmedBarcode.allSatisfy({ $0.isNumber }) {
                return (false, "Barcode must contain only numbers")
            }
            
            // Check if barcode is reasonable length (most barcodes are 8-14 digits)
            if trimmedBarcode.count < 4 || trimmedBarcode.count > 20 {
                return (false, "Barcode must be between 4 and 20 digits")
            }
        }
        
        guard !servingSize.isEmpty else {
            return (false, "Serving size is required")
        }
        
        guard let servingSizeValue = Double(servingSize), servingSizeValue > 0 else {
            return (false, "Serving size must be a positive number")
        }
        
        guard !calories.isEmpty else {
            return (false, "Calories are required")
        }
        
        guard let caloriesValue = Double(calories), caloriesValue >= 0 else {
            return (false, "Calories must be a non-negative number")
        }
        
        if !protein.isEmpty {
            guard let proteinValue = Double(protein), proteinValue >= 0 else {
                return (false, "Protein must be a non-negative number")
            }
        }
        
        if !carbohydrates.isEmpty {
            guard let carbValue = Double(carbohydrates), carbValue >= 0 else {
                return (false, "Carbohydrates must be a non-negative number")
            }
        }
        
        if !fat.isEmpty {
            guard let fatValue = Double(fat), fatValue >= 0 else {
                return (false, "Fat must be a non-negative number")
            }
        }
        
        if !fiber.isEmpty {
            guard let fiberValue = Double(fiber), fiberValue >= 0 else {
                return (false, "Fiber must be a non-negative number")
            }
        }
        
        if !sugar.isEmpty {
            guard let sugarValue = Double(sugar), sugarValue >= 0 else {
                return (false, "Sugar must be a non-negative number")
            }
        }
        
        if !sodium.isEmpty {
            guard let sodiumValue = Double(sodium), sodiumValue >= 0 else {
                return (false, "Sodium must be a non-negative number")
            }
        }
        
        return (true, "")
    }
    
    // Creates nutrition info object from form inputs
    private func createNutritionInfo() -> NutritionInfo {
        return NutritionInfo(
            calories: Double(calories),
            protein: protein.isEmpty ? nil : Double(protein),
            carbohydrates: carbohydrates.isEmpty ? nil : Double(carbohydrates),
            fat: fat.isEmpty ? nil : Double(fat),
            fiber: fiber.isEmpty ? nil : Double(fiber),
            sugar: sugar.isEmpty ? nil : Double(sugar),
            sodium: sodium.isEmpty ? nil : Double(sodium)
        )
    }
    
    // Saves food to database and adds to selected meal
    private func saveFood() {
        let validation = validateFormData()
        guard validation.isValid else {
            validationErrorMessage = validation.errorMessage
            showingValidationError = true
            return
        }
        
        let savedFoodName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedMealType = mealType
        let nutritionInfo = createNutritionInfo()
        
        let food = Food(
            name: savedFoodName,
            barcode: barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : barcode.trimmingCharacters(in: .whitespacesAndNewlines),
            nutritionInfo: nutritionInfo,
            servingSize: Double(servingSize) ?? 1,
            servingSizeUnit: servingUnit.abbreviation,
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
            isCustom: true
        )
        
        print("Saving custom food: \(food.name) to database")
        if let foodBarcode = food.barcode {
            print("Food has barcode: \(foodBarcode) - will be scannable in the future")
        }
        
        DatabaseManager.shared.saveFoodThreadSafe(food) { success in
            Task { @MainActor in
                if success {
                    print("Food saved to database")
                    
                    let entry = FoodEntry.create(
                        food: food,
                        quantity: Double(self.servingSize) ?? 1,
                        unit: self.servingUnit,
                        mealType: self.mealType
                    )
                    
                    DatabaseManager.shared.saveFoodEntryThreadSafe(entry) { entrySuccess in
                        Task { @MainActor in
                            if entrySuccess {
                                print("Food entry saved to \(entry.mealType.rawValue)")
                                
                                NotificationCenter.default.post(name: NSNotification.Name("FoodEntryAdded"), object: nil)
                                
                                let barcodeMessage = !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                                    ? " You can now find this food by scanning its barcode!"
                                    : ""
                                
                                self.successMessage = "\(savedFoodName) has been added to your \(savedMealType.rawValue.lowercased())!\(barcodeMessage)"
                                self.showingSuccessAlert = true
                            } else {
                                self.validationErrorMessage = "Failed to save food entry. Please try again."
                                self.showingValidationError = true
                            }
                        }
                    }
                } else {
                    self.validationErrorMessage = "Failed to save food. Please try again."
                    self.showingValidationError = true
                }
            }
        }
    }
    
    // Resets all form fields to empty state
    private func clearForm() {
        Task { @MainActor in
            foodName = ""
            brand = ""
            barcode = ""
            servingSize = ""
            calories = ""
            protein = ""
            carbohydrates = ""
            fat = ""
            fiber = ""
            sugar = ""
            sodium = ""
            validationErrorMessage = ""
            focusedField = .foodName
            validateForm()
        }
    }
    
    private func moveToNextField() {
        switch focusedField {
        case .foodName: focusedField = .brand
        case .brand: focusedField = .barcode
        case .barcode: focusedField = .servingSize
        case .servingSize: focusedField = .calories
        case .calories: focusedField = .protein
        case .protein: focusedField = .carbohydrates
        case .carbohydrates: focusedField = .fat
        case .fat: focusedField = isAdvancedMode ? .fiber : nil
        case .fiber: focusedField = .sugar
        case .sugar: focusedField = .sodium
        default: focusedField = nil
        }
    }
    
    private func moveToPreviousField() {
        switch focusedField {
        case .brand: focusedField = .foodName
        case .barcode: focusedField = .brand
        case .servingSize: focusedField = .barcode
        case .calories: focusedField = .servingSize
        case .protein: focusedField = .calories
        case .carbohydrates: focusedField = .protein
        case .fat: focusedField = .carbohydrates
        case .fiber: focusedField = .fat
        case .sugar: focusedField = .fiber
        case .sodium: focusedField = .sugar
        default: break
        }
    }
    
    private func canMoveToNext() -> Bool {
        switch focusedField {
        case .foodName, .brand, .servingSize, .calories, .protein, .carbohydrates: return true
        case .fat: return isAdvancedMode
        case .fiber, .sugar: return true
        default: return false
        }
    }
    
    private func canMoveToPrevious() -> Bool {
        return focusedField != .foodName && focusedField != nil
    }
}

struct NutritionInputRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    var focusedField: FocusState<ManualEntryView.Field?>.Binding
    let field: ManualEntryView.Field
    let nextField: ManualEntryView.Field?
    
    var body: some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 4) {
                TextField("0", text: $value)
                    .focused(focusedField, equals: field)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .onSubmit {
                        if let nextField = nextField {
                            focusedField.wrappedValue = nextField
                        } else {
                            focusedField.wrappedValue = nil
                        }
                    }
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)
            }
        }
    }
}
