import SwiftUI

// Main view for displaying and managing recipes
struct RecipesView: View {
    @StateObject private var viewModel = RecipesViewModel()
    @State private var showingCreateRecipe = false
    @State private var searchText = ""
    @State private var editingRecipe: Recipe? = nil
   
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return viewModel.recipes
        } else {
            return viewModel.recipes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !viewModel.recipes.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search recipes...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding()
                }
                
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading recipes...")
                        Spacer()
                    }
                } else if viewModel.recipes.isEmpty {
                    EmptyRecipesView {
                        showingCreateRecipe = true
                    }
                } else if filteredRecipes.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No recipes found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredRecipes) { recipe in
                            RecipeRow(recipe: recipe, onEdit: {
                                editingRecipe = recipe
                            }, onDelete: {
                                viewModel.deleteRecipe(recipe)
                            })
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Debug") {
                    // Debug menu for troubleshooting
                    viewModel.validateSync()
                    viewModel.performDatabaseCleanup()
                },
                trailing: Button(action: {
                    showingCreateRecipe = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .onAppear {
                viewModel.loadRecipes()
            }
            .refreshable {
                // Add pull-to-refresh functionality
                viewModel.forceRefresh()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingCreateRecipe) {
            RecipeCreationView()
        }
        .sheet(item: $editingRecipe) { recipe in
            RecipeCreationView(editingRecipe: recipe)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecipeCreated"))) { notification in
            if let recipe = notification.object as? Recipe {
                print("Received RecipeCreated notification for: \(recipe.name) (ID: \(recipe.id))")
                viewModel.addRecipe(recipe)
            } else {
                print("Received RecipeCreated notification without recipe object, reloading all")
                viewModel.loadRecipes()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecipeUpdated"))) { notification in
            if let recipe = notification.object as? Recipe {
                print("Received RecipeUpdated notification for: \(recipe.name) (ID: \(recipe.id))")
                viewModel.updateRecipe(recipe)
            } else {
                print("Received RecipeUpdated notification without recipe object, reloading all")
                viewModel.loadRecipes()
            }
            
            // Always validate sync after updates to catch any issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.validateSync()
            }
        }
    }
}

// Empty state view shown when no recipes exist
struct EmptyRecipesView: View {
    let onCreateRecipe: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Recipes Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("Create your first recipe to combine ingredients and calculate nutrition automatically")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onCreateRecipe) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Recipe")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
}

// Individual recipe row in the list
struct RecipeRow: View {
    let recipe: Recipe
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label("\(recipe.servings)", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(recipe.ingredients.count) ingredients")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(recipe.nutritionPerServing.calories ?? 0))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("cal/serving")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .onLongPressGesture {
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Trigger edit
            onEdit()
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: {
                onEdit()
            }) {
                Label("Edit Recipe", systemImage: "pencil")
            }
            
            Button(action: {
                onDelete()
            }) {
                Label("Delete Recipe", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Edit", action: onEdit)
                .tint(.orange)
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .sheet(isPresented: $showingDetail) {
            RecipeDetailView(recipe: recipe)
        }
    }
}

// Detailed view of a single recipe
struct RecipeDetailView: View {
    let recipe: Recipe
    @State private var showingLogOptions = false
    @State private var showingEditRecipe = false
    @State private var showingShoppingListOptions = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Makes \(recipe.servings) servings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition (per serving)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            NutritionCard(title: "Calories", value: recipe.nutritionPerServing.calories ?? 0, unit: "kcal", color: .orange)
                            NutritionCard(title: "Protein", value: recipe.nutritionPerServing.protein ?? 0, unit: "g", color: .red)
                            NutritionCard(title: "Carbs", value: recipe.nutritionPerServing.carbohydrates ?? 0, unit: "g", color: .blue)
                            NutritionCard(title: "Fat", value: recipe.nutritionPerServing.fat ?? 0, unit: "g", color: .purple)
                        }
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(recipe.ingredients) { ingredient in
                                RecipeIngredientDetailRow(ingredient: ingredient)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        showingLogOptions = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log Recipe")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        showingShoppingListOptions = true
                    }) {
                        HStack {
                            Image(systemName: "cart.badge.plus")
                            Text("Create Shopping List")
                        }
                        .font(.headline)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Edit") {
                    showingEditRecipe = true
                }
            )
        }
        .sheet(isPresented: $showingLogOptions) {
            LogRecipeView(recipe: recipe)
        }
        .sheet(isPresented: $showingEditRecipe) {
            RecipeCreationView(editingRecipe: recipe)
        }
        .sheet(isPresented: $showingShoppingListOptions) {
            ShoppingListCreationFromRecipeView(recipe: recipe)
        }
    }
}

struct NutritionCard: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(value))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct RecipeIngredientDetailRow: View {
    let ingredient: RecipeIngredient
    
    var body: some View {
        HStack {
            Text("•")
                .foregroundColor(.secondary)
            
            Text("\(ingredient.quantity.formattedNutrition) \(ingredient.food.servingSizeUnit) \(ingredient.food.name)")
                .font(.body)
            
            Spacer()
            
            Text("\(Int(ingredient.nutritionContribution.calories ?? 0)) cal")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// View for logging a recipe to a meal
struct LogRecipeView: View {
    let recipe: Recipe
    @State private var selectedMealType: MealType = .lunch
    @State private var servings = "1"
    @State private var showingSuccessAlert = false
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Recipe makes \(recipe.servings) servings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add to Meal")
                        .font(.headline)
                    
                    Picker("Meal Type", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            Text("\(mealType.emoji) \(mealType.rawValue)")
                                .tag(mealType)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Servings")
                        .font(.headline)
                    
                    HStack {
                        TextField("Servings", text: $servings)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("servings")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let servingCount = Double(servings), servingCount > 0 {
                    VStack {
                        Text("Nutrition (for \(servings) serving\(servingCount == 1 ? "" : "s"))")
                            .font(.headline)
                        
                        let totalCals = (recipe.nutritionPerServing.calories ?? 0) * servingCount
                        Text("\(Int(totalCals)) calories")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: logRecipe) {
                    Text("Add to \(selectedMealType.rawValue)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(servings.isEmpty || Double(servings) == nil || Double(servings) ?? 0 <= 0)
            }
            .padding()
            .navigationTitle("Log Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("Recipe Logged!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("\(servings) serving\(Double(servings) == 1 ? "" : "s") of \(recipe.name) added to your \(selectedMealType.rawValue.lowercased())")
        }
    }
    
    // Saves recipe as a food entry to the selected meal
    private func logRecipe() {
        guard let servingCount = Double(servings), servingCount > 0 else { return }
        
        let recipeAsFood = recipe.asFood()
        
        let entry = FoodEntry(
            food: recipeAsFood,
            quantity: servingCount,
            mealType: selectedMealType
        )
        
        DatabaseManager.shared.saveFoodEntryAsync(entry) {
            print("Recipe logged to meal")
            NotificationCenter.default.post(name: NSNotification.Name("FoodEntryAdded"), object: nil)
            showingSuccessAlert = true
        }
    }
}

// Manages recipe data and database operations
class RecipesViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    
    // Loads all recipes from database
    func loadRecipes() {
        isLoading = true
        print("Loading recipes from database")
        
        // Debug: List what's actually in the database
        DatabaseManager.shared.debugListAllRecipesAsync()
        
        DatabaseManager.shared.getRecipesAsync { [weak self] recipes in
            print("Loaded \(recipes.count) recipes")
            for recipe in recipes {
                print("📋 Loaded recipe: '\(recipe.name)' with ID: \(recipe.id)")
            }
            DispatchQueue.main.async {
                self?.recipes = recipes.sorted { $0.dateCreated > $1.dateCreated }
                self?.isLoading = false
                print("✅ Recipe loading completed. UI has \(self?.recipes.count ?? 0) recipes")
            }
        }
    }
    
    // Adds a new recipe to the local list
    func addRecipe(_ recipe: Recipe) {
        print("Adding new recipe to list: \(recipe.name) (ID: \(recipe.id))")
        
        // Make sure we don't add duplicates
        if recipes.contains(where: { $0.id == recipe.id }) {
            print("Recipe already exists in list, updating instead")
            updateRecipe(recipe)
            return
        }
        
        recipes.insert(recipe, at: 0) // Add to beginning since we sort by date created (newest first)
        print("Recipe added successfully. Total recipes: \(recipes.count)")
    }
    
    // Updates an existing recipe in the local list
    func updateRecipe(_ updatedRecipe: Recipe) {
        print("Updating recipe in list: \(updatedRecipe.name) with ID: \(updatedRecipe.id)")
        
        if let index = recipes.firstIndex(where: { $0.id == updatedRecipe.id }) {
            print("Found recipe at index \(index), updating in place")
            recipes[index] = updatedRecipe
            print("Recipe updated successfully")
        } else {
            print("Recipe not found in list with ID \(updatedRecipe.id)")
            print("Available recipe IDs: \(recipes.map { $0.id.uuidString })")
            print("Adding as new recipe instead")
            addRecipe(updatedRecipe)
        }
    }
    
    // Deletes recipe from local list and database
    func deleteRecipe(_ recipe: Recipe) {
        print("🗑️ DELETE REQUEST: Recipe '\(recipe.name)' with ID: \(recipe.id)")
        print("🗑️ Local recipes before deletion: \(recipes.count)")
        for (index, localRecipe) in recipes.enumerated() {
            let match = localRecipe.id == recipe.id ? " ✅" : ""
            print("  [\(index)] \(localRecipe.name) - \(localRecipe.id)\(match)")
        }
        
        // Check if recipe exists in local list first
        guard let existingRecipe = recipes.first(where: { $0.id == recipe.id }) else {
            print("❌ Recipe not found in local list!")
            print("Available recipe IDs: \(recipes.map { "\($0.name): \($0.id.uuidString)" })")
            // Try to reload recipes to fix sync issue
            loadRecipes()
            return
        }
        
        print("✅ Recipe found in local list, proceeding with deletion")
        
        // Remove from local list immediately to provide responsive UI
        recipes.removeAll { $0.id == recipe.id }
        print("Recipe removed from local list. Remaining: \(recipes.count)")
        
        // Then delete from database
        DatabaseManager.shared.deleteRecipeAsync(existingRecipe) {
            print("Recipe deletion completed from database")
            // If deletion failed, we might want to reload to restore consistency
            // For now, we trust the database operation succeeded
        }
    }
    
    // Force refresh recipes from database to fix sync issues
    func forceRefresh() {
        print("🔄 Force refreshing recipes from database to fix sync issues")
        loadRecipes()
    }
    
    // Helper method to check if local list is in sync with database
    func validateSync() {
        print("🔍 Validating recipe list sync...")
        DatabaseManager.shared.getRecipesAsync { [weak self] dbRecipes in
            DispatchQueue.main.async {
                let localCount = self?.recipes.count ?? 0
                let dbCount = dbRecipes.count
                
                print("📊 Sync check: Local=\(localCount), Database=\(dbCount)")
                
                // Check for detailed differences
                let localIds = Set(self?.recipes.map { $0.id } ?? [])
                let dbIds = Set(dbRecipes.map { $0.id })
                
                let onlyInLocal = localIds.subtracting(dbIds)
                let onlyInDb = dbIds.subtracting(localIds)
                
                if !onlyInLocal.isEmpty {
                    print("⚠️ Recipes only in UI (stale): \(onlyInLocal)")
                    // Remove stale recipes from UI
                    self?.recipes.removeAll { onlyInLocal.contains($0.id) }
                    print("🧹 Removed \(onlyInLocal.count) stale recipes from UI")
                }
                
                if !onlyInDb.isEmpty {
                    print("⚠️ Recipes only in database (missing from UI): \(onlyInDb)")
                    // Add missing recipes to UI
                    let missingRecipes = dbRecipes.filter { onlyInDb.contains($0.id) }
                    self?.recipes.append(contentsOf: missingRecipes)
                    self?.recipes = (self?.recipes ?? []).sorted { $0.dateCreated > $1.dateCreated }
                    print("➕ Added \(missingRecipes.count) missing recipes to UI")
                }
                
                if localCount != dbCount || !onlyInLocal.isEmpty || !onlyInDb.isEmpty {
                    print("🔄 Sync issues detected and fixed!")
                } else {
                    print("✅ Recipe list is perfectly in sync")
                }
            }
        }
    }
    
    // Clean up database and refresh
    func performDatabaseCleanup() {
        print("🧹 Performing database cleanup...")
        DatabaseManager.shared.cleanupRecipesDatabase()
        
        // Refresh after cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.forceRefresh()
        }
    }
}

// MARK: - Shopping List Creation From Recipe View
struct ShoppingListCreationFromRecipeView: View {
    let recipe: Recipe
    @Environment(\.presentationMode) var presentationMode
    @State private var listName: String = ""
    @State private var selectedIngredients: Set<UUID> = [] // Changed to track ingredient IDs
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Shopping List")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create a shopping list from \"\(recipe.name)\" ingredients")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Ingredients")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(recipe.ingredients) { ingredient in
                                IngredientSelectionRow(
                                    ingredient: ingredient,
                                    isSelected: selectedIngredients.contains(ingredient.id),
                                    onToggle: {
                                        if selectedIngredients.contains(ingredient.id) {
                                            selectedIngredients.remove(ingredient.id)
                                        } else {
                                            selectedIngredients.insert(ingredient.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button {
                    createShoppingList()
                } label: {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Create Shopping List")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canCreateList ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!canCreateList || isCreating)
                .padding(.horizontal)
            }
            .navigationTitle("New Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Initialize with recipe name and select all ingredients
            if listName.isEmpty {
                listName = "\(recipe.name) Shopping List"
            }
            selectedIngredients = Set(recipe.ingredients.map { $0.id })
        }
    }
    
    private var canCreateList: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedIngredients.isEmpty
    }
    
    private func createShoppingList() {
        guard canCreateList else { return }
        
        isCreating = true
        
        let shoppingListViewModel = ShoppingListViewModel.shared
        var newList = ShoppingList(name: listName.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Add selected ingredients as shopping list items
        let selectedRecipeIngredients = recipe.ingredients.filter { selectedIngredients.contains($0.id) }
        
        for recipeIngredient in selectedRecipeIngredients {
            let category = ShoppingCategory.categorizeIngredient(recipeIngredient.food.name)
            let item = ShoppingListItem(
                name: recipeIngredient.food.name,
                quantity: recipeIngredient.quantity,
                unit: recipeIngredient.unit,
                category: category,
                notes: "From \(recipe.name)"
            )
            newList.items.append(item)
        }
        
        // Update the modified date since we added items
        newList.updateModifiedDate()
        
        // Save the shopping list using the correct method
        shoppingListViewModel.saveShoppingList(newList)
        
        // Dismiss the view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCreating = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Ingredient Selection Row Helper View
struct IngredientSelectionRow: View {
    let ingredient: RecipeIngredient
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.food.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.body)
                
                Text("\(ingredient.quantity.formattedNutrition) \(ingredient.unit.abbreviation)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
