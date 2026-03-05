import SwiftUI

// Main view for displaying and managing recipes
struct RecipesView: View {
    @StateObject private var viewModel = RecipesViewModel()
    @State private var showingCreateRecipe = false
    @State private var searchText = ""
   
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
                            RecipeRow(recipe: recipe) {
                                viewModel.deleteRecipe(recipe)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(action: {
                    showingCreateRecipe = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .onAppear {
                viewModel.loadRecipes()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingCreateRecipe) {
            RecipeCreationView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecipeCreated"))) { _ in
            viewModel.loadRecipes()
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
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingLogOptions) {
            LogRecipeView(recipe: recipe)
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
        DatabaseManager.shared.getRecipesAsync { recipes in
            print("Loaded \(recipes.count) recipes")
            self.recipes = recipes.sorted { $0.dateCreated > $1.dateCreated }
            self.isLoading = false
        }
    }
    
    // Deletes recipe from local list and database
    func deleteRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        DatabaseManager.shared.deleteRecipeAsync(recipe) {
            print("Recipe deleted from database")
        }
    }
}
