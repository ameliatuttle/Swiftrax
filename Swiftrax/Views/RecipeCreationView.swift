import SwiftUI

// Main view for creating new recipes with ingredients and nutrition tracking
struct RecipeCreationView: View {
    let editingRecipe: Recipe?
    let isEditing: Bool
    @State private var recipeName = ""
    @State private var servings = "4"
    @State private var ingredients: [RecipeIngredient] = []
    @State private var showingAddIngredient = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingQuantityEntry = false
    @State private var selectedFood: Food?
    
    // New: Serving weight specification
    @State private var hasServingWeight = false
    @State private var servingWeight = ""
    @State private var servingWeightUnit: MeasurementUnit = .grams
    @State private var showingServingWeightUnitPicker = false
    
    @Environment(\.presentationMode) var presentationMode
    
    // Available weight units for serving weight
    private let weightUnits: [MeasurementUnit] = [.grams, .kilograms, .ounces, .pounds]
    
    init(editingRecipe: Recipe? = nil) {
        self.editingRecipe = editingRecipe
        self.isEditing = editingRecipe != nil
        
        // Pre-populate fields if editing
        if let recipe = editingRecipe {
            self._recipeName = State(initialValue: recipe.name)
            self._servings = State(initialValue: String(recipe.servings))
            self._ingredients = State(initialValue: recipe.ingredients)
            
            // Handle serving weight
            if let weight = recipe.servingWeight {
                self._hasServingWeight = State(initialValue: true)
                self._servingWeight = State(initialValue: weight.formattedNutrition)
                self._servingWeightUnit = State(initialValue: recipe.servingWeightUnit ?? .grams)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipe Information") {
                    TextField("Recipe name", text: $recipeName)
                        .autocapitalization(.words)
                    
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("4", text: $servings)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                
                Section {
                    Toggle("Specify serving weight", isOn: $hasServingWeight)
                        .toggleStyle(SwitchToggleStyle())
                    
                    if hasServingWeight {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Weight per serving:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                TextField("Weight", text: $servingWeight)
                                    .keyboardType(.decimalPad)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                Button {
                                    showingServingWeightUnitPicker = true
                                } label: {
                                    HStack {
                                        Text(servingWeightUnit.abbreviation)
                                            .font(.body)
                                            .foregroundColor(.blue)
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            
                            Text("This allows the recipe to be logged with precise portions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Serving Details")
                }
                
                Section {
                    Button {
                        showingAddIngredient = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Ingredient")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ForEach(ingredients) { ingredient in
                        IngredientRow(ingredient: ingredient) {
                            removeIngredient(ingredient)
                        }
                    }
                } header: {
                    HStack {
                        Text("Ingredients")
                        Spacer()
                        if !ingredients.isEmpty {
                            Text("\(ingredients.count) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !ingredients.isEmpty && isValid {
                    Section("Nutrition (per serving)") {
                        let nutrition = calculatedRecipe.nutritionPerServing
                        
                        NutritionPreviewRow(label: "Calories", value: nutrition.calories ?? 0, unit: "kcal")
                        NutritionPreviewRow(label: "Protein", value: nutrition.protein ?? 0, unit: "g")
                        NutritionPreviewRow(label: "Carbohydrates", value: nutrition.carbohydrates ?? 0, unit: "g")
                        NutritionPreviewRow(label: "Fat", value: nutrition.fat ?? 0, unit: "g")
                    }
                }
                
                Section {
                    Button {
                        saveRecipe()
                    } label: {
                        Text(isEditing ? "Save Changes" : "Create Recipe")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(isValid ? .white : .secondary)
                    }
                    .listRowBackground(isValid ? Color.blue : Color.gray.opacity(0.3))
                    .disabled(!isValid)
                }
            }
            .navigationTitle(isEditing ? "Edit Recipe" : "Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingAddIngredient, onDismiss: {
            selectedFood = nil
            showingQuantityEntry = false
        }) {
            if let food = selectedFood, showingQuantityEntry {
                // Show quantity entry with unit selection
               RecipeQuantityEntryView(food: food) { quantity, unit in
                   let ingredient = RecipeIngredient(food: food, quantity: quantity, unit: unit)
                   addIngredient(ingredient)
                   showingAddIngredient = false
               }
            } else {
                // Show search
               SearchLogView(forRecipeIngredients: { food in
                   selectedFood = food
                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                       showingQuantityEntry = true
                   }
               })
            }
        }
        .actionSheet(isPresented: $showingServingWeightUnitPicker) {
            ActionSheet(
                title: Text("Select Unit"),
                message: Text("Choose the unit for serving weight"),
                buttons: weightUnits.map { unit in
                    .default(Text("\(unit.displayName) (\(unit.abbreviation))")) {
                        servingWeightUnit = unit
                    }
                } + [.cancel()]
            )
        }
        .alert(isEditing ? "Recipe Updated!" : "Recipe Created!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(successMessage)
        }
    }
    
    // Calculates recipe with current form values
    private var calculatedRecipe: Recipe {
        let servingCount = Int(servings) ?? 1
        let weight = hasServingWeight ? Double(servingWeight) : nil
        let weightUnit = hasServingWeight ? servingWeightUnit : nil
        
        if isEditing, let editingRecipe = editingRecipe {
            return Recipe(
                from: editingRecipe,
                name: recipeName,
                servings: servingCount,
                ingredients: ingredients,
                servingWeight: weight,
                servingWeightUnit: weightUnit
            )
        } else {
            return Recipe(
                name: recipeName,
                servings: servingCount,
                ingredients: ingredients,
                servingWeight: weight,
                servingWeightUnit: weightUnit
            )
        }
    }
    
    // Validates form is complete and ready to save
    private var isValid: Bool {
        let basicValid = !recipeName.trimmingCharacters(in: .whitespaces).isEmpty &&
                        !servings.isEmpty &&
                        Int(servings) != nil &&
                        Int(servings) ?? 0 > 0 &&
                        !ingredients.isEmpty
        
        if hasServingWeight {
            let weightValid = !servingWeight.isEmpty &&
                            Double(servingWeight) != nil &&
                            Double(servingWeight) ?? 0 > 0
            return basicValid && weightValid
        }
        
        return basicValid
    }
    
    private func addIngredient(_ ingredient: RecipeIngredient) {
        ingredients.append(ingredient)
    }
    
    private func removeIngredient(_ ingredient: RecipeIngredient) {
        ingredients.removeAll { $0.id == ingredient.id }
    }
    
    // Saves recipe to database and shows success message
    private func saveRecipe() {
        guard isValid else { return }
        
        let recipe = calculatedRecipe
        print(isEditing ? "Updating recipe: \(recipe.name) with ID: \(recipe.id)" : "Saving recipe: \(recipe.name)")
        
        // For debugging: Print the recipe ID to verify it's the same when editing
        if isEditing, let originalRecipe = editingRecipe {
            print("Original recipe ID: \(originalRecipe.id)")
            print("Updated recipe ID: \(recipe.id)")
            print("IDs match: \(originalRecipe.id == recipe.id)")
        }
        
        DatabaseManager.shared.saveRecipeAsync(recipe) {
            print(self.isEditing ? "Recipe updated successfully" : "Recipe saved successfully")
            
            // Send appropriate notification with the recipe object
            let notificationName = self.isEditing ? "RecipeUpdated" : "RecipeCreated"
            NotificationCenter.default.post(name: NSNotification.Name(notificationName), object: recipe)
            
            let actionText = self.isEditing ? "updated" : "created"
            self.successMessage = "\(recipe.name) has been \(actionText) with \(recipe.ingredients.count) ingredients!"
            self.showingSuccessAlert = true
        }
    }
}

// Dedicated view for entering ingredient quantities when adding to recipes
struct RecipeQuantityEntryView: View {
    let food: Food
    let onQuantitySelected: (Double, MeasurementUnit) -> Void
    
    @State private var quantity = ""
    @State private var selectedUnit: MeasurementUnit
    @State private var showingUnitPicker = false
    @Environment(\.presentationMode) var presentationMode
    
    // Available units for this food
    private var availableUnits: [MeasurementUnit] {
        let baseUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        return UnitConverter.shared.getSuggestedUnits(for: food)
    }
    
    init(food: Food, onQuantitySelected: @escaping (Double, MeasurementUnit) -> Void) {
        self.food = food
        self.onQuantitySelected = onQuantitySelected
        
        // Default to the food's original unit
        let defaultUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        self._selectedUnit = State(initialValue: defaultUnit)
        self._quantity = State(initialValue: String(food.servingSize))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(food.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(2)
                            
                            if let brand = food.brand {
                                Text(brand)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(food.sourceEmoji)
                                .font(.title2)
                            Text(food.source)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Base serving:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(food.servingSize.formattedNutrition) \(food.servingSizeUnit)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    HStack(spacing: 16) {
                        NutritionChip(label: "Cal", value: food.nutritionInfo.calories ?? 0, color: .orange)
                        NutritionChip(label: "P", value: food.nutritionInfo.protein ?? 0, color: .red)
                        NutritionChip(label: "C", value: food.nutritionInfo.carbohydrates ?? 0, color: .blue)
                        NutritionChip(label: "F", value: food.nutritionInfo.fat ?? 0, color: .purple)
                        Spacer()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recipe Quantity")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        TextField("Amount", text: $quantity)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        
                        Button {
                            showingUnitPicker = true
                        } label: {
                            VStack(spacing: 4) {
                                Text(selectedUnit.abbreviation)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text("tap to change")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Unit category info
                    if availableUnits.count > 1 {
                        Text("Available: \(availableUnits.map { $0.abbreviation }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("This is how much of this ingredient you'll use in the recipe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let quantityValue = Double(quantity), quantityValue > 0 {
                    VStack(spacing: 12) {
                        Text("Nutrition Contribution")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        let nutrition = calculateNutritionContribution(quantityValue, selectedUnit)
                        
                        HStack {
                            VStack(spacing: 4) {
                                Text("\(Int(nutrition.calories ?? 0))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                Text("calories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 20) {
                                VStack(spacing: 2) {
                                    Text("\((nutrition.protein ?? 0).formattedNutrition)g")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    Text("Protein")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\((nutrition.carbohydrates ?? 0).formattedNutrition)g")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    Text("Carbs")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\((nutrition.fat ?? 0).formattedNutrition)g")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.purple)
                                    Text("Fat")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Button {
                    if let quantityValue = Double(quantity), quantityValue > 0 {
                        onQuantitySelected(quantityValue, selectedUnit)
                        presentationMode.wrappedValue.dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Recipe")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValid ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isValid)
            }
            .padding()
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .actionSheet(isPresented: $showingUnitPicker) {
                ActionSheet(
                    title: Text("Select Unit"),
                    message: Text("Choose the measurement unit for this ingredient"),
                    buttons: availableUnits.map { unit in
                        .default(Text("\(unit.displayName) (\(unit.abbreviation))")) {
                            selectedUnit = unit
                        }
                    } + [.cancel()]
                )
            }
        }
    }
    
    private var isValid: Bool {
        guard let quantityValue = Double(quantity) else { return false }
        return quantityValue > 0
    }
    
    private func calculateNutritionContribution(_ quantity: Double, _ unit: MeasurementUnit) -> NutritionInfo {
        let originalUnit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        
        let convertedQuantity: Double
        if let converted = UnitConverter.shared.convert(value: quantity, from: unit, to: originalUnit) {
            convertedQuantity = converted
        } else {
            convertedQuantity = quantity
        }
        
        let scaleFactor = convertedQuantity / food.servingSize
        let baseNutrition = food.nutritionInfo
        
        return NutritionInfo(
            calories: (baseNutrition.calories ?? 0) * scaleFactor,
            protein: (baseNutrition.protein ?? 0) * scaleFactor,
            carbohydrates: (baseNutrition.carbohydrates ?? 0) * scaleFactor,
            fat: (baseNutrition.fat ?? 0) * scaleFactor,
            fiber: (baseNutrition.fiber ?? 0) * scaleFactor,
            sugar: (baseNutrition.sugar ?? 0) * scaleFactor,
            sodium: (baseNutrition.sodium ?? 0) * scaleFactor
        )
    }
}

struct NutritionChip: View {
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

struct IngredientRow: View {
    let ingredient: RecipeIngredient
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.food.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(ingredient.displayText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(ingredient.nutritionContribution.calories ?? 0))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("cal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

struct NutritionPreviewRow: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value.formattedNutrition) \(unit)")
                .foregroundColor(.secondary)
        }
    }
}
