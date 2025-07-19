import SwiftUI

// Main view for creating new recipes with ingredients and nutrition tracking
struct RecipeCreationView: View {
    @State private var recipeName = ""
    @State private var servings = "4"
    @State private var ingredients: [RecipeIngredient] = []
    @State private var showingAddIngredient = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingQuantityEntry = false
    @State private var selectedFood: Food?
    
    @Environment(\.presentationMode) var presentationMode
    
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
                    Button(action: {
                        showingAddIngredient = true
                    }) {
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
                    Button(action: saveRecipe) {
                        Text("Create Recipe")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(isValid ? .white : .secondary)
                    }
                    .listRowBackground(isValid ? Color.blue : Color.gray.opacity(0.3))
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingAddIngredient) {
            SearchLogView(forRecipeIngredients: { food in
                selectedFood = food
                showingAddIngredient = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showingQuantityEntry = true
                }
            })
        }
        .sheet(isPresented: $showingQuantityEntry) {
            if let food = selectedFood {
                RecipeQuantityEntryView(food: food) { quantity in
                    let ingredient = RecipeIngredient(food: food, quantity: quantity)
                    addIngredient(ingredient)
                    selectedFood = nil
                }
            }
        }
        .alert("Recipe Created!", isPresented: $showingSuccessAlert) {
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
        return Recipe(
            name: recipeName,
            servings: servingCount,
            ingredients: ingredients
        )
    }
    
    // Validates form is complete and ready to save
    private var isValid: Bool {
        !recipeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !servings.isEmpty &&
        Int(servings) != nil &&
        Int(servings) ?? 0 > 0 &&
        !ingredients.isEmpty
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
        print("Saving recipe: \(recipe.name)")
        
        DatabaseManager.shared.saveRecipeAsync(recipe) {
            print("Recipe saved successfully")
            NotificationCenter.default.post(name: NSNotification.Name("RecipeCreated"), object: nil)
            
            successMessage = "\(recipe.name) has been created with \(recipe.ingredients.count) ingredients!"
            showingSuccessAlert = true
        }
    }
}

// Dedicated view for entering ingredient quantities when adding to recipes
struct RecipeQuantityEntryView: View {
    let food: Food
    let onQuantitySelected: (Double) -> Void
    
    @State private var quantity = ""
    @State private var selectedUnit: String
    @Environment(\.presentationMode) var presentationMode
    
    init(food: Food, onQuantitySelected: @escaping (Double) -> Void) {
        self.food = food
        self.onQuantitySelected = onQuantitySelected
        self._selectedUnit = State(initialValue: food.servingSizeUnit)
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
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        
                        VStack(spacing: 4) {
                            Text(selectedUnit)
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("unit")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
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
                        
                        let scale = quantityValue / food.servingSize
                        let scaledCalories = (food.nutritionInfo.calories ?? 0) * scale
                        let scaledProtein = (food.nutritionInfo.protein ?? 0) * scale
                        let scaledCarbs = (food.nutritionInfo.carbohydrates ?? 0) * scale
                        let scaledFat = (food.nutritionInfo.fat ?? 0) * scale
                        
                        HStack {
                            VStack(spacing: 4) {
                                Text("\(Int(scaledCalories))")
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
                                    Text("\(scaledProtein.formattedNutrition)g")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    Text("Protein")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\(scaledCarbs.formattedNutrition)g")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    Text("Carbs")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\(scaledFat.formattedNutrition)g")
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
                
                Button(action: {
                    if let quantityValue = Double(quantity), quantityValue > 0 {
                        onQuantitySelected(quantityValue)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
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
        }
    }
    
    private var isValid: Bool {
        guard let quantityValue = Double(quantity) else { return false }
        return quantityValue > 0
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
                
                Text("\(ingredient.quantity.formattedNutrition) \(ingredient.food.servingSizeUnit)")
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
            
            Button(action: onDelete) {
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
