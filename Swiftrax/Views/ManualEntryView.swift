import SwiftUI

struct ManualEntryView: View {
    @State private var mealType: MealType = .breakfast
    @State private var foodName = ""
    @State private var brand = ""
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
                        .autocapitalization(.words)
                        .onChange(of: foodName) { _ in
                            print("🍎 Food name changed to: '\(foodName)'")
                        }
                    
                    TextField("Brand (optional)", text: $brand)
                        .autocapitalization(.words)
                }
                
                // Enhanced Serving Size with Unit Picker
                Section("Serving Size") {
                    HStack {
                        TextField("Amount", text: $servingSize)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: .infinity)
                            .onChange(of: servingSize) { _ in
                                print("📏 Serving size changed to: '\(servingSize)'")
                            }
                        
                        Button(action: {
                            showingUnitPicker = true
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
                    NutritionInputRow(label: "Calories", value: $calories, unit: "kcal")
                    NutritionInputRow(label: "Protein", value: $protein, unit: "g")
                    NutritionInputRow(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                    NutritionInputRow(label: "Fat", value: $fat, unit: "g")
                }
                
                // Advanced Nutrition (Optional)
                Section {
                    DisclosureGroup("Additional Nutrients", isExpanded: $isAdvancedMode) {
                        NutritionInputRow(label: "Fiber", value: $fiber, unit: "g")
                        NutritionInputRow(label: "Sugar", value: $sugar, unit: "g")
                        NutritionInputRow(label: "Sodium", value: $sodium, unit: "mg")
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
                    Button(action: {
                        print("🎯 CREATE FOOD BUTTON TAPPED!")
                        print("🔍 Current form state:")
                        print("   - Food name: '\(foodName)'")
                        print("   - Serving size: '\(servingSize)' \(servingUnit.abbreviation)")
                        print("   - Meal type: '\(mealType.rawValue)'")
                        print("   - Is valid: \(isValid)")
                        saveFood()
                    }) {
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
            .onAppear {
                print("📱 Enhanced ManualEntryView appeared")
            }
        }
        .sheet(isPresented: $showingUnitPicker) {
            NavigationView {
                List {
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Button(action: {
                            servingUnit = unit
                            showingUnitPicker = false
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
    }
    
    private var isValid: Bool {
        let nameValid = !foodName.trimmingCharacters(in: .whitespaces).isEmpty
        let servingSizeValid = !servingSize.isEmpty && Double(servingSize) != nil && Double(servingSize)! > 0
        let caloriesValid = !calories.isEmpty && Double(calories) != nil
        
        print("🔍 Form Validation:")
        print("   - Food name: '\(foodName)' -> Valid: \(nameValid)")
        print("   - Serving size: '\(servingSize)' -> Valid: \(servingSizeValid)")
        print("   - Calories: '\(calories)' -> Valid: \(caloriesValid)")
        print("   - Overall valid: \(nameValid && servingSizeValid && caloriesValid)")
        
        return nameValid && servingSizeValid && caloriesValid
    }
    
    private func createNutritionInfo() -> NutritionInfo {
        return NutritionInfo(
            calories: Double(calories),
            protein: Double(protein),
            carbohydrates: Double(carbohydrates),
            fat: Double(fat),
            fiber: fiber.isEmpty ? nil : Double(fiber),
            sugar: sugar.isEmpty ? nil : Double(sugar),
            sodium: sodium.isEmpty ? nil : Double(sodium)
        )
    }
    
    private func saveFood() {
        guard isValid else {
            print("❌ Manual Entry: Form is not valid")
            return
        }
        
        print("✅ Manual Entry: Starting save process...")
        
        let savedFoodName = foodName
        let savedMealType = mealType
        
        // Create food with enhanced nutrition info
        let nutritionInfo = createNutritionInfo()
        
        let food = Food(
            name: foodName,
            nutritionInfo: nutritionInfo,
            servingSize: Double(servingSize) ?? 1,
            servingSizeUnit: servingUnit.abbreviation,
            brand: brand.isEmpty ? nil : brand,
            isCustom: true
        )
        
        print("📦 Created food: \(food.name) with \(food.nutritionInfo.calories ?? 0) calories per \(food.servingSize) \(food.servingSizeUnit)")
        
        // Save to database using thread-safe version
        DatabaseManager.shared.saveFoodThreadSafe(food) { success in
            if success {
                print("💾 Food saved to database")
                
                // Create food entry using the unit system
                let entry = FoodEntry.create(
                    food: food,
                    quantity: Double(servingSize) ?? 1,
                    unit: servingUnit,
                    mealType: mealType
                )
                
                print("📝 Created food entry for \(entry.mealType.rawValue)")
                
                // Save food entry
                DatabaseManager.shared.saveFoodEntryThreadSafe(entry) { entrySuccess in
                    if entrySuccess {
                        print("💾 Food entry saved to database")
                        
                        // Post notification to refresh dashboard
                        NotificationCenter.default.post(name: NSNotification.Name("FoodEntryAdded"), object: nil)
                        print("📢 Posted notification to refresh dashboard")
                        
                        successMessage = "\(savedFoodName) has been added to your \(savedMealType.rawValue.lowercased())!"
                        showingSuccessAlert = true
                        
                        print("✅ Manual Entry: Complete!")
                    } else {
                        print("❌ Failed to save food entry")
                    }
                }
            } else {
                print("❌ Failed to save food")
            }
        }
    }
    
    private func clearForm() {
        foodName = ""
        brand = ""
        servingSize = ""
        calories = ""
        protein = ""
        carbohydrates = ""
        fat = ""
        fiber = ""
        sugar = ""
        sodium = ""
        // Keep the same meal type and unit for convenience
    }
}

//// MARK: - Macro Display Component
//struct MacroDisplay: View {
//    let label: String
//    let value: Double
//    let color: Color
//    
//    var body: some View {
//        VStack(spacing: 2) {
//            Text(label)
//                .font(.caption2)
//                .foregroundColor(.secondary)
//            Text("\(Int(value))g")
//                .font(.caption)
//                .fontWeight(.semibold)
//                .foregroundColor(color)
//        }
//    }
//}

// MARK: - Enhanced Nutrition Input Row
struct NutritionInputRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 4) {
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)
            }
        }
    }
}

#Preview {
    ManualEntryView()
}
