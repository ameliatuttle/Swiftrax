import SwiftUI

struct RecipeCreationView: View {
    @State private var recipeName = ""
    @State private var servings = "4"
    @State private var ingredients: [RecipeIngredient] = []
    @State private var showingAddIngredient = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                // Recipe Basic Info
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
                
                // Ingredients Section
                Section {
                    Button(action: {
                        print("🔍 Add Ingredient button tapped")
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
                
                // Nutrition Preview
                if !ingredients.isEmpty && isValid {
                    Section("Nutrition (per serving)") {
                        let nutrition = calculatedRecipe.nutritionPerServing
                        
                        NutritionPreviewRow(label: "Calories", value: nutrition.calories ?? 0, unit: "kcal")
                        NutritionPreviewRow(label: "Protein", value: nutrition.protein ?? 0, unit: "g")
                        NutritionPreviewRow(label: "Carbohydrates", value: nutrition.carbohydrates ?? 0, unit: "g")
                        NutritionPreviewRow(label: "Fat", value: nutrition.fat ?? 0, unit: "g")
                    }
                }
                
                // Save Button
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
            RecipeIngredientSearchView { ingredient in
                print("✅ Ingredient selected: \(ingredient.food.name)")
                addIngredient(ingredient)
            }
        }
        .alert("Recipe Created!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                // Close the recipe creation view
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text(successMessage)
        }
    }
    
    private var calculatedRecipe: Recipe {
        let servingCount = Int(servings) ?? 1
        return Recipe(
            name: recipeName,
            servings: servingCount,
            ingredients: ingredients
        )
    }
    
    private var isValid: Bool {
        !recipeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !servings.isEmpty &&
        Int(servings) != nil &&
        Int(servings) ?? 0 > 0 &&
        !ingredients.isEmpty
    }
    
    private func addIngredient(_ ingredient: RecipeIngredient) {
        ingredients.append(ingredient)
        showingAddIngredient = false // Close the sheet
        print("✅ Added ingredient: \(ingredient.food.name) - \(ingredient.quantity) \(ingredient.food.servingSizeUnit)")
    }
    
    private func removeIngredient(_ ingredient: RecipeIngredient) {
        ingredients.removeAll { $0.id == ingredient.id }
        print("🗑️ Removed ingredient: \(ingredient.food.name)")
    }
    
    private func saveRecipe() {
        guard isValid else {
            print("❌ Recipe form is not valid")
            return
        }
        
        let recipe = calculatedRecipe
        print("💾 Saving recipe: \(recipe.name) with \(recipe.ingredients.count) ingredients")
        
        // Save recipe to database
        DatabaseManager.shared.saveRecipeAsync(recipe) {
            print("✅ Recipe saved successfully: \(recipe.name)")
            
            // Post notification to refresh recipes list
            NotificationCenter.default.post(name: NSNotification.Name("RecipeCreated"), object: nil)
            
            successMessage = "\(recipe.name) has been created with \(recipe.ingredients.count) ingredients!"
            showingSuccessAlert = true
        }
    }
}

// MARK: - SIMPLIFIED Ingredient Search View (Navigation-based)
struct RecipeIngredientSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [Food] = []
    @State private var isLoading = false
    
    let onIngredientAdded: (RecipeIngredient) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Simple SwiftUI Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search ingredients...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            searchFoods()
                        }
                        .onChange(of: searchText) { newValue in
                            if newValue.count > 2 {
                                searchFoods()
                            } else if newValue.isEmpty {
                                searchResults = []
                            }
                        }
                }
                .padding()
                
                Divider()
                
                // Search Results
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Searching ingredients...")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                } else if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Search for ingredients")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Type a food name to find ingredients")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if searchResults.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No ingredients found")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(searchResults) { food in
                            NavigationLink(destination: RecipeQuantityEntryView(food: food) { quantity in
                                let ingredient = RecipeIngredient(food: food, quantity: quantity)
                                onIngredientAdded(ingredient)
                            }) {
                                IngredientSearchRow(food: food)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                print("🔍 RecipeIngredientSearchView appeared")
            }
        }
    }
    
    private func searchFoods() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        print("🔍 Searching for ingredients: '\(searchText)'")
        
        DatabaseManager.shared.searchFoodsAsync(query: searchText) { foods in
            self.searchResults = foods
            self.isLoading = false
            print("🔍 Found \(foods.count) ingredient results")
        }
    }
}

// MARK: - Recipe Quantity Entry View (Now navigation-based)
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
        VStack(spacing: 20) {
            // Food Info
            VStack(alignment: .leading, spacing: 8) {
                Text(food.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let brand = food.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("Base serving: \(food.servingSize.formattedNutrition) \(food.servingSizeUnit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Quantity Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Quantity for Recipe")
                    .font(.headline)
                
                HStack {
                    TextField("Amount", text: $quantity)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text(selectedUnit)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            
            // Nutrition Preview
            if let quantityValue = Double(quantity), quantityValue > 0 {
                VStack(spacing: 8) {
                    Text("Nutrition for \(quantity) \(selectedUnit)")
                        .font(.headline)
                    
                    let scale = quantityValue / food.servingSize
                    let scaledCalories = (food.nutritionInfo.calories ?? 0) * scale
                    
                    Text("\(Int(scaledCalories)) calories")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Add Button
            Button(action: {
                if let quantityValue = Double(quantity), quantityValue > 0 {
                    print("✅ Adding ingredient: \(food.name) - \(quantityValue) \(selectedUnit)")
                    onQuantitySelected(quantityValue)
                    // Navigate back to root (recipe creation)
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Text("Add to Recipe")
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
        .onAppear {
            print("📏 RecipeQuantityEntryView appeared for: \(food.name)")
        }
    }
    
    private var isValid: Bool {
        guard let quantityValue = Double(quantity) else { return false }
        return quantityValue > 0
    }
}

// MARK: - Helper components
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

struct IngredientSearchRow: View {
    let food: Food
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let brand = food.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("per \(food.servingSize.formattedNutrition) \(food.servingSizeUnit)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(food.nutritionInfo.calories ?? 0))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("cal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RecipeCreationView()
}
