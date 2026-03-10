import SwiftUI

// Enhanced SearchLogView with Recipe Mode Support
struct SearchLogView: View {
   @State private var searchText = ""
   @State private var localSearchResults: [Food] = []
   @State private var apiSearchResults: [Food] = []
   @State private var recipeSearchResults: [Recipe] = []
   @State private var isLoading = false
   @State private var selectedMealType: MealType = .breakfast
   @State private var showingQuantitySheet = false
   @State private var selectedFood: Food?
   @State private var selectedRecentEntry: FoodEntry?
   @State private var showingSuccessAlert = false
   @State private var showingSuccessBanner = false
   @State private var showingBarcodeScanner = false
   @State private var recentLogs: [FoodEntry] = []
   @State private var frequentlyUsedFoods: [Food] = []
   @State private var showingError = false
   @State private var errorMessage = ""
   @State private var isSearchingAPI = false
   @State private var showingSourcesInfo = false
   @State private var searchDebounceTask: Task<Void, Never>?
   
   @FocusState private var isSearchFocused: Bool
   
   // Combined search results for inline display - local first, then API
   private var combinedSearchResults: [SearchableItem] {
      var combined: [SearchableItem] = []
      
      // Add recipes first (they tend to be more specific matches)
      combined.append(contentsOf: recipeSearchResults.map { SearchableItem.recipe($0) })
      
      // Add local foods first (immediate results)
      combined.append(contentsOf: localSearchResults.map { SearchableItem.food($0) })
      
      // Then add API results (filtered to avoid duplicates with local results)
      let localFoodNames = Set(localSearchResults.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
      let uniqueAPIResults = apiSearchResults.filter { apiFood in
         let apiName = apiFood.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
         return !localFoodNames.contains(apiName)
      }
      combined.append(contentsOf: uniqueAPIResults.map { SearchableItem.food($0) })
      
      return combined
   }
   
   // Enum to handle both foods and recipes in search results
   enum SearchableItem: Identifiable {
      case food(Food)
      case recipe(Recipe)
      
      var id: UUID {
         switch self {
         case .food(let food):
            return food.id
         case .recipe(let recipe):
            return recipe.id
         }
      }
   }
   
   // Recipe mode support
   let mode: SearchMode
   let preselectedMealType: MealType?
   let onFoodSelected: ((Food) -> Void)?
   
   // Search modes for different use cases
   enum SearchMode {
      case foodLogging(MealType?)
      case recipeIngredient
   }
   
   // Sheet state for quantity entry
   enum SheetState: Identifiable {
      case recentEntry(food: Food, entry: FoodEntry)
      case newEntry(food: Food, mealType: MealType)
      
      var id: String {
         switch self {
         case .recentEntry(let food, let entry):
            return "recent_\(food.id)_\(entry.id)"
         case .newEntry(let food, let mealType):
            return "new_\(food.id)_\(mealType.rawValue)"
         }
      }
   }
   
   // Initialize for regular food logging
   init(preselectedMealType: MealType? = nil) {
      self.mode = .foodLogging(preselectedMealType)
      self.preselectedMealType = preselectedMealType
      self.onFoodSelected = nil
   }
   
   // Initialize for recipe ingredient selection
   init(forRecipeIngredients onFoodSelected: @escaping (Food) -> Void) {
      self.mode = .recipeIngredient
      self.preselectedMealType = nil
      self.onFoodSelected = onFoodSelected
   }
   
   var body: some View {
      NavigationView {
         VStack(spacing: 0) {
            headerView
            Divider()
            mainContentView
         }
         .navigationTitle(navigationTitle)
         .navigationBarTitleDisplayMode(.inline)
         .onAppear {
            setupInitialState()
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
               recipeModeCancelButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
               nutritionSourcesButton
            }
         }
         .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
               Spacer()
               Button("Done") {
                  isSearchFocused = false
               }
            }
         }
      }
      .navigationViewStyle(StackNavigationViewStyle())
      .onAppear {
         if let preselected = preselectedMealType {
            selectedMealType = preselected
         }
      }
   }
   
   private var headerView: some View {
      VStack(spacing: 12) {
         searchBarView
      }
      .padding(.horizontal)
      .padding(.top)
   }
   
   private var searchBarView: some View {
      HStack(spacing: 12) {
         HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
               .foregroundColor(.secondary)
            
            TextField(searchPlaceholder, text: $searchText)
               .focused($isSearchFocused)
               .onSubmit {
                  performSearch()
               }
               .onChange(of: searchText) { newValue in
                  // Cancel any existing search task
                  searchDebounceTask?.cancel()
                  
                  if newValue.isEmpty {
                     clearSearch()
                  } else if newValue.count > 1 {
                     // Create a new debounced search task
                     searchDebounceTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay (reduced for faster response)
                        
                        // Check if the task was cancelled or search text changed
                        guard !Task.isCancelled, searchText == newValue else {
                           return
                        }
                        
                        // Perform the search on main actor
                        await MainActor.run {
                           performSearch()
                        }
                     }
                  }
               }
            
            if isLoading {
               ProgressView()
                  .scaleEffect(0.8)
            } else if !searchText.isEmpty {
               Button("Clear", action: clearSearch)
                  .font(.caption)
                  .foregroundColor(.blue)
            }
         }
         .padding(.horizontal, 12)
         .padding(.vertical, 10)
         .background(Color.gray.opacity(0.1))
         .cornerRadius(10)
         
         Button {
            isSearchFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
               showingBarcodeScanner = true
            }
         } label: {
            Image(systemName: "barcode.viewfinder")
               .font(.title2)
               .foregroundColor(.blue)
         }
         .accessibilityLabel("Scan barcode")
      }
   }
   
   private var mainContentView: some View {
      VStack(spacing: 0) {
         // Success banner
         if showingSuccessBanner {
            HStack {
               Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
               Text("Food added successfully!")
                  .font(.subheadline)
                  .fontWeight(.medium)
               Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .transition(.move(edge: .top).combined(with: .opacity))
         }
         
         // Search status indicator
         if isSearchingAPI {
            HStack(spacing: 8) {
               ProgressView()
                  .scaleEffect(0.7)
               Text("Searching online databases...")
                  .font(.caption)
                  .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
         } else if !searchText.isEmpty && (localSearchResults.count > 0 || apiSearchResults.count > 0 || recipeSearchResults.count > 0) {
            HStack {
               let totalCount = localSearchResults.count + apiSearchResults.count + recipeSearchResults.count
               Text("Found \(totalCount) result\(totalCount == 1 ? "" : "s")")
                  .font(.caption)
                  .foregroundColor(.secondary)
               
               Spacer()
            }
            .padding(.vertical, 4)
         }
         
         // Main content area
         if isLoading && localSearchResults.isEmpty && apiSearchResults.isEmpty && recipeSearchResults.isEmpty {
            VStack(spacing: 16) {
               Spacer()
               
               ProgressView()
                  .scaleEffect(1.2)
               
               Text("Searching...")
                  .font(.headline)
               
               if isSearchingAPI {
                  Text("Checking online food databases...")
                     .font(.caption)
                     .foregroundColor(.secondary)
                     .multilineTextAlignment(.center)
               }
               
               Spacer()
            }
            .padding()
         } else if localSearchResults.isEmpty && apiSearchResults.isEmpty && searchText.isEmpty {
            if case .foodLogging = mode {
               ImprovedRecentLogsView(
                  recentLogs: recentLogs,
                  frequentlyUsedFoods: frequentlyUsedFoods,
                  onFoodSelected: selectFood,
                  onRecentLogSelected: selectFoodFromRecentLog,
                  onRefresh: loadRecentLogs,
                  onShowSources: { showingSourcesInfo = true }
               )
            } else {
               // Recipe mode search instruction
               VStack(spacing: 20) {
                  Spacer()
                  
                  Image(systemName: "magnifyingglass")
                     .font(.system(size: 60))
                     .foregroundColor(.secondary)
                  
                  Text("Search for Ingredients")
                     .font(.title2)
                     .fontWeight(.semibold)
                     .foregroundColor(.secondary)
                  
                  Text("Search by name or scan a barcode to find ingredients for your recipe")
                     .font(.subheadline)
                     .foregroundColor(.secondary)
                     .multilineTextAlignment(.center)
                     .padding(.horizontal)
                  
                  Spacer()
               }
               .padding()
            }
         } else if localSearchResults.isEmpty && apiSearchResults.isEmpty && recipeSearchResults.isEmpty && !isLoading {
            // No results found state
            VStack(spacing: 20) {
               Spacer()
               
               Image(systemName: "exclamationmark.magnifyingglass")
                  .font(.system(size: 60))
                  .foregroundColor(.secondary)
               
               Text("No results found")
                  .font(.title2)
                  .fontWeight(.semibold)
                  .foregroundColor(.secondary)
               
               Text("Try different keywords or check spelling")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
               
               Spacer()
            }
            .padding()
         } else {
            // Search results list - show local results first, then API results
            List {
               // Show local results first (these appear immediately)
               if !recipeSearchResults.isEmpty {
                  Section(header: Text("Recipes").font(.caption).foregroundColor(.secondary)) {
                     ForEach(recipeSearchResults, id: \.id) { recipe in
                        RecipeSearchResultRow(
                           recipe: recipe,
                           searchText: searchText,
                           onTap: {
                              selectRecipe(recipe)
                           }
                        )
                     }
                  }
               }
               
               if !localSearchResults.isEmpty {
                  Section(header: localSearchResults.count > 0 ? Text("Local Results").font(.caption).foregroundColor(.secondary) : nil) {
                     ForEach(localSearchResults, id: \.id) { food in
                        SearchResultRow(
                           food: food,
                           searchText: searchText,
                           onShowSources: { showingSourcesInfo = true },
                           onTap: {
                              selectFood(food)
                           }
                        )
                     }
                  }
               }
               
               // Show API results below local results (these appear after API search completes)
               if !apiSearchResults.isEmpty {
                  Section(header: Text("Online Results").font(.caption).foregroundColor(.secondary)) {
                     ForEach(apiSearchResults, id: \.id) { food in
                        // Filter out duplicates that might match local results
                        let localFoodNames = Set(localSearchResults.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
                        let foodName = food.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !localFoodNames.contains(foodName) {
                           SearchResultRow(
                              food: food,
                              searchText: searchText,
                              onShowSources: { showingSourcesInfo = true },
                              onTap: {
                                 selectFood(food)
                              }
                           )
                        }
                     }
                  }
               }
               
               // Show loading indicator for API search at the bottom
               if isSearchingAPI && !localSearchResults.isEmpty {
                  Section {
                     HStack {
                        ProgressView()
                           .scaleEffect(0.8)
                        Text("Loading more results...")
                           .font(.caption)
                           .foregroundColor(.secondary)
                     }
                     .padding(.vertical, 8)
                  }
               }
            }
            .listStyle(PlainListStyle())
         }
      }
      .contentShape(Rectangle()) // Make the entire area tappable
      .onTapGesture {
         // Dismiss keyboard when tapping outside search field
         if isSearchFocused {
            isSearchFocused = false
         }
      }
      .sheet(isPresented: $showingBarcodeScanner, onDismiss: {
         isSearchFocused = false
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if selectedFood != nil {
               handleFoodSelection()
            }
         }
      }) {
         BarcodeScannerView { barcode in
            Task { @MainActor in
               searchByBarcode(barcode)
            }
         }
      }
      .sheet(item: Binding<SheetState?>(
         get: {
            if showingQuantitySheet, let food = selectedFood, case .foodLogging = mode {
               if let recentEntry = selectedRecentEntry {
                  return SheetState.recentEntry(food: food, entry: recentEntry)
               } else {
                  return SheetState.newEntry(food: food, mealType: selectedMealType)
               }
            }
            return nil
         },
         set: { newValue in
            showingQuantitySheet = newValue != nil
            if newValue == nil {
               // Clear state when sheet is dismissed
               selectedFood = nil
               selectedRecentEntry = nil
               isSearchFocused = false
            }
         }
      )) { sheetState in
         switch sheetState {
         case .recentEntry(let food, let entry):
            QuantityEntryView(
               food: food,
               mealType: entry.mealType,
               prefilledQuantity: entry.quantity
            ) { quantity, unit, mealType in
               addFoodToMeal(food: food, quantity: quantity, unit: unit, mealType: mealType)
            }
         case .newEntry(let food, let mealType):
            QuantityEntryView(
               food: food,
               mealType: mealType
            ) { quantity, unit, mealType in
               addFoodToMeal(food: food, quantity: quantity, unit: unit, mealType: mealType)
            }
         }
      }
      .sheet(isPresented: $showingSourcesInfo) {
         SearchLogView.NutritionSourcesView()
      }
      .alert("Error", isPresented: $showingError) {
         Button("OK") {
            isSearchFocused = false
         }
      } message: {
         Text(errorMessage)
      }
      .onDisappear {
         isSearchFocused = false
         // Clear search state when leaving the view
         clearSearchState()
      }
      .onAppear {
         // Clear any previous search state when returning to the view
         clearSearchState()
      }
   }
   
   // Computed properties for mode-specific UI
   private var searchPlaceholder: String {
      switch mode {
      case .foodLogging:
         return "Search foods..."
      case .recipeIngredient:
         return "Search ingredients..."
      }
   }
   
   private var navigationTitle: String {
      switch mode {
      case .foodLogging:
         return "Search & Log"
      case .recipeIngredient:
         return "Add Ingredient"
      }
   }
   
   @ViewBuilder
   private var recipeModeCancelButton: some View {
      if case .recipeIngredient = mode {
         Button("Cancel") {
            // Handled by parent view
         }
      }
   }
   
   @ViewBuilder
   private var nutritionSourcesButton: some View {
      if case .foodLogging = mode {
         Button {
            showingSourcesInfo = true
         } label: {
            Image(systemName: "info.circle")
               .font(.title3)
               .foregroundColor(.blue)
         }
      }
   }
   
   // Setup initial view state based on mode
   private func setupInitialState() {
      if let preselected = preselectedMealType {
         selectedMealType = preselected
      }
      
      // Use comprehensive state clearing
      clearSearchState()
      
      if case .foodLogging = mode {
         loadRecentLogs()
         loadFrequentlyUsedFoods()
      }
   }
   
   // Handle food selection from search results or recent logs
   private func selectFood(_ food: Food) {
      if case .recipeIngredient = mode {
         // For recipe mode, call callback directly (no sheet needed)
         onFoodSelected?(food)
      } else {
         // For food logging mode, show quantity sheet with default values
         selectedFood = food
         selectedRecentEntry = nil // Clear any recent entry state
         isSearchFocused = false
         showingQuantitySheet = true
      }
   }
   
   // Handle recipe selection from search results
   private func selectRecipe(_ recipe: Recipe) {
      if case .recipeIngredient = mode {
         // For recipe mode, convert recipe to food and call callback
         let recipeAsFood = recipe.asFood()
         onFoodSelected?(recipeAsFood)
      } else {
         // For food logging mode, show quantity sheet for recipe
         let recipeAsFood = recipe.asFood()
         selectedFood = recipeAsFood
         selectedRecentEntry = nil
         isSearchFocused = false
         showingQuantitySheet = true
      }
   }
   
   // Handle food selection from recent logs with pre-populated quantity and meal type
   private func selectFoodFromRecentLog(_ entry: FoodEntry) {
      if case .recipeIngredient = mode {
         // For recipe mode, call callback directly (no sheet needed)
         onFoodSelected?(entry.food)
      } else {
         // For food logging mode, set all state before showing sheet
         selectedFood = entry.food
         selectedRecentEntry = entry
         selectedMealType = entry.mealType
         isSearchFocused = false
         showingQuantitySheet = true
      }
   }
   
   // Handle food selection after barcode scan
   private func handleFoodSelection() {
      showingQuantitySheet = true
   }
   
   // Handle recipe ingredient selection with callback
   private func handleRecipeIngredientSelection(food: Food, quantity: Double) {
      print("Recipe ingredient selected: \(food.name)")
      onFoodSelected?(food)
   }
   
   // Search for foods using local database first, then API
   private func performSearch() {
      guard !searchText.isEmpty else {
         clearSearch()
         return
      }
      
      print("Searching for: '\(searchText)'")
      
      // Cancel any existing search task to prevent race conditions
      searchDebounceTask?.cancel()
      
      searchDebounceTask = Task {
         await MainActor.run {
            self.isLoading = true
            self.isSearchingAPI = false
         }
         
         // Run local and recipe searches concurrently
         async let localResults = DatabaseManager.shared.searchFoodsAsync(query: searchText)
         async let recipeResults: [Recipe] = await withCheckedContinuation { continuation in
            DatabaseManager.shared.searchRecipesAsync(query: searchText) { recipes in
               continuation.resume(returning: recipes)
            }
         }
         
         // Wait for local results
         let localFoods = await localResults
         let localRecipes = await recipeResults
         
         print("Found \(localFoods.count) local food results")
         print("Found \(localRecipes.count) recipe results")
         
         let deduplicatedLocal = deduplicateSearchResults(localFoods)
         
         // Update UI with local results immediately
         await MainActor.run {
            self.localSearchResults = deduplicatedLocal
            self.recipeSearchResults = localRecipes
            self.isLoading = false
            // Clear any previous API results
            self.apiSearchResults = []
         }
         
         // Always search API for more results (in parallel)
         print("Searching API for additional results")
         await MainActor.run {
            self.isSearchingAPI = true
         }
         
         do {
            let apiResults = try await APIManager.shared.searchByText(searchText)
            print("Found \(apiResults.count) API results")
            
            // Check if search text changed while we were searching API
            guard !Task.isCancelled, self.searchText == searchText else {
               print("Search cancelled or text changed, ignoring API results")
               await MainActor.run {
                  self.isSearchingAPI = false
               }
               return
            }
            
            // Deduplicate API results and update UI
            let deduplicatedAPI = deduplicateSearchResults(apiResults)
            print("After deduplication: \(deduplicatedAPI.count) unique API results")
            
            await MainActor.run {
               self.apiSearchResults = deduplicatedAPI
               self.isSearchingAPI = false
            }
         } catch {
            print("API search failed: \(error.localizedDescription)")
            print("Keeping local results only")
            
            await MainActor.run {
               self.isSearchingAPI = false
               // Local results are already displayed, don't show error
            }
         }
      }
   }
   
   // Helper function fro duplicate results
   private func deduplicateSearchResults(_ foods: [Food]) -> [Food] {
      var seen = Set<String>()
      var uniqueFoods: [Food] = []
      
      for food in foods {
         let key = food.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
         
         if !seen.contains(key) {
            seen.insert(key)
            uniqueFoods.append(food)
         }
      }
      
      return uniqueFoods
   }
   
   // Clear search text and results
   private func clearSearch() {
      // Cancel any pending search task
      searchDebounceTask?.cancel()
      
      Task { @MainActor in
         self.searchText = ""
         self.localSearchResults = []
         self.apiSearchResults = []
         self.recipeSearchResults = []
         self.isSearchFocused = false
      }
   }
   
   // Clear all search-related state
   private func clearSearchState() {
      // Cancel any pending search task
      searchDebounceTask?.cancel()
      
      Task { @MainActor in
         self.searchText = ""
         self.localSearchResults = []
         self.apiSearchResults = []
         self.recipeSearchResults = []
         self.isSearchFocused = false
         self.isLoading = false
         self.isSearchingAPI = false
         self.showingSuccessBanner = false
      }
   }
   
   // Search for food by barcode using database lookup
   private func searchByBarcode(_ barcode: String) {
      print("Looking up barcode: \(barcode)")
      
      Task { @MainActor in
         self.isLoading = true
         self.isSearchingAPI = true
         self.localSearchResults = []
         self.apiSearchResults = []
         self.recipeSearchResults = []
         self.selectedFood = nil
      }
      
      DatabaseManager.shared.getFoodByBarcode(barcode) { food in
         Task { @MainActor in
            self.isLoading = false
            self.isSearchingAPI = false
            
            if let foundFood = food {
               print("Barcode found: \(foundFood.name)")
               // Put barcode result in local results since it's from database
               self.localSearchResults = [foundFood]
               self.selectedFood = foundFood
            } else {
               print("No product found for barcode")
               self.errorMessage = "No product found for barcode \(barcode)"
               self.showingError = true
            }
         }
      }
   }
   
   // Load recent food entries - last 50 unique foods by log date
   private func loadRecentLogs() {
      DatabaseManager.shared.getAllFoodEntriesThreadSafe { allEntries in
         DispatchQueue.global(qos: .background).async {
            // Group entries by food name and keep only the most recent entry for each food
            let foodGroups = Dictionary(grouping: allEntries) { entry in
               entry.food.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            let uniqueRecentEntries = foodGroups.compactMap { (foodName, entries) -> FoodEntry? in
               // Return the most recent entry for this food
               return entries.sorted { $0.dateLogged > $1.dateLogged }.first
            }
            
            let sortedEntries = uniqueRecentEntries
               .sorted { $0.dateLogged > $1.dateLogged }
               .prefix(50)
            
            Task { @MainActor in
               self.recentLogs = Array(sortedEntries)
               print("Loaded \(self.recentLogs.count) unique recent foods")
            }
         }
      }
   }
   
   // Load frequently used foods from the past few days
   private func loadFrequentlyUsedFoods() {
      let calendar = Calendar.current
      let endDate = Date()
      let startDate = calendar.date(byAdding: .day, value: -5, to: endDate) ?? endDate // Past 5 days
      
      DatabaseManager.shared.getAllFoodEntriesThreadSafe(from: startDate, to: endDate) { allEntries in
         DispatchQueue.global(qos: .background).async {
            // Group entries by food name and count frequency
            let foodFrequency = Dictionary(grouping: allEntries) { entry in
               entry.food.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            }.mapValues { entries in
               (food: entries.first!.food, count: entries.count)
            }
            
            // Sort by frequency and take top items
            let frequentFoods = foodFrequency
               .values
               .sorted { $0.count > $1.count }
               .prefix(8)
               .map { $0.food }
            
            Task { @MainActor in
               self.frequentlyUsedFoods = Array(frequentFoods)
               print("Loaded \(self.frequentlyUsedFoods.count) frequently used foods")
            }
         }
      }
   }
   
   // Add food to selected meal type and add to db when logged
   private func addFoodToMeal(food: Food, quantity: Double, unit: MeasurementUnit, mealType: MealType) {
      DatabaseManager.shared.saveFoodThreadSafe(food) { foodSaveSuccess in
         Task { @MainActor in
            guard foodSaveSuccess else {
               print("Failed to save food before logging entry")
               return
            }
            
            print("Adding \(food.name) to \(mealType.rawValue)")
            
            let entry = FoodEntry.create(
               food: food,
               quantity: quantity,
               unit: unit,
               mealType: mealType
            )
            
            DatabaseManager.shared.saveFoodEntryThreadSafe(entry) { success in
               Task { @MainActor in
                  if success {
                     print("Food entry saved successfully")
                     NotificationCenter.default.post(name: NSNotification.Name("FoodEntryAdded"), object: nil)
                     
                     // Show success banner and clear search
                     withAnimation(.easeInOut(duration: 0.3)) {
                        self.showingSuccessBanner = true
                     }
                     
                     // Clear search results and text
                     self.clearSearch()
                     
                     // Auto-dismiss banner after 2 seconds
                     DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                           self.showingSuccessBanner = false
                        }
                     }
                     
                     self.loadRecentLogs()
                     self.loadFrequentlyUsedFoods()
                  } else {
                     self.errorMessage = "Failed to save food entry."
                     self.showingError = true
                  }
               }
            }
         }
      }
   }
   
   // Enhanced search result row with highlighting
   struct SearchResultRow: View {
      let food: Food
      let searchText: String
      let onShowSources: () -> Void
      let onTap: () -> Void
      
      var body: some View {
         Button {
            onTap()
         } label: {
            HStack(spacing: 12) {
               FoodIconView(food: food)
               
               VStack(alignment: .leading, spacing: 4) {
                  Text(food.name)
                     .font(.body)
                     .fontWeight(.medium)
                     .lineLimit(2)
                     .multilineTextAlignment(.leading)
                  
                  HStack {
                     if let brand = food.brand {
                        Text(brand)
                           .font(.caption)
                           .foregroundColor(.secondary)
                     }
                     
                     Spacer()
                     
                     if food.isFromAPI {
                        HStack(spacing: 2) {
                           Text(food.sourceEmoji)
                              .font(.caption2)
                           Text(food.source)
                              .font(.caption2)
                              .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(food.source == "OpenFoodFacts" ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(food.source == "OpenFoodFacts" ? .orange : .green)
                        .cornerRadius(4)
                     }
                  }
                  
                  Text("per \(food.servingSize.formattedNutrition) \(food.servingSizeUnit)")
                     .font(.caption2)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               VStack(alignment: .trailing, spacing: 4) {
                  Text("\(Int(food.nutritionInfo.calories ?? 0))")
                     .font(.title3)
                     .fontWeight(.bold)
                  
                  HStack(spacing: 4) {
                     Text("cal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                     
                     Button {
                        onShowSources()
                     } label: {
                        Image(systemName: "info.circle.fill")
                           .font(.caption)
                           .foregroundColor(.blue)
                     }
                     .buttonStyle(PlainButtonStyle())
                     .padding(4)
                  }
               }
            }
            .padding(.vertical, 8)
            .foregroundColor(.primary)
         }
         .buttonStyle(PlainButtonStyle())
      }
   }
   
   // Food icon view with source indicator
   struct FoodIconView: View {
      let food: Food
      
      var body: some View {
         ZStack {
            Circle()
               .fill(Color.blue.opacity(0.1))
               .frame(width: 44, height: 44)
            
            Text(String(food.name.prefix(1).uppercased()))
               .font(.headline)
               .fontWeight(.semibold)
               .foregroundColor(.blue)
            
            if food.isFromAPI {
               Text(food.sourceEmoji)
                  .font(.caption2)
                  .offset(x: 15, y: -15)
            }
         }
      }
   }
   
   // Recipe search result row
   struct RecipeSearchResultRow: View {
      let recipe: Recipe
      let searchText: String
      let onTap: () -> Void
      
      var body: some View {
         Button {
            onTap()
         } label: {
            HStack(spacing: 12) {
               // Recipe icon - similar to food icon but with recipe indicator
               ZStack {
                  Circle()
                     .fill(Color.blue.opacity(0.1))
                     .frame(width: 44, height: 44)
                  
                  Text(String(recipe.name.prefix(1).uppercased()))
                     .font(.headline)
                     .fontWeight(.semibold)
                     .foregroundColor(.blue)
                  
                  // Small recipe indicator
                  Image(systemName: "book.closed")
                     .font(.caption2)
                     .foregroundColor(.orange)
                     .offset(x: 15, y: -15)
               }
               
               VStack(alignment: .leading, spacing: 4) {
                  Text(recipe.name)
                     .font(.body)
                     .fontWeight(.medium)
                     .lineLimit(2)
                     .multilineTextAlignment(.leading)
                  
                  HStack {
                     Text("Recipe")
                        .font(.caption)
                        .foregroundColor(.secondary)
                     
                     Spacer()
                  }
                  
                  Text("per serving")
                     .font(.caption2)
                     .foregroundColor(.secondary)
               }
               
               Spacer()
               
               VStack(alignment: .trailing, spacing: 4) {
                  Text("\(Int(recipe.nutritionPerServing.calories ?? 0))")
                     .font(.title3)
                     .fontWeight(.bold)
                  
                  Text("cal")
                     .font(.caption2)
                     .foregroundColor(.secondary)
               }
            }
            .padding(.vertical, 8)
            .foregroundColor(.primary)
         }
         .buttonStyle(PlainButtonStyle())
      }
   }
   
   // Recent logs view for food logging mode
   struct ImprovedRecentLogsView: View {
      let recentLogs: [FoodEntry]
      let frequentlyUsedFoods: [Food]
      let onFoodSelected: (Food) -> Void
      let onRecentLogSelected: (FoodEntry) -> Void
      let onRefresh: () -> Void
      let onShowSources: () -> Void
      
      var body: some View {
         ScrollView {
            VStack(spacing: 20) {
               // Frequently Used Foods Section
               if !frequentlyUsedFoods.isEmpty {
                  VStack(spacing: 12) {
                     HStack {
                        VStack(alignment: .leading, spacing: 4) {
                           Text("Frequently Added")
                              .font(.headline)
                              .fontWeight(.semibold)
                           
                           Text("Your most-used foods from the past few days")
                              .font(.caption)
                              .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                     }
                     .padding(.horizontal)
                     
                     ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                           ForEach(frequentlyUsedFoods, id: \.id) { food in
                              FrequentFoodCard(
                                 food: food,
                                 onShowSources: onShowSources,
                                 onTap: { onFoodSelected(food) }
                              )
                           }
                        }
                        .padding(.horizontal)
                     }
                  }
               }
               
               // Recent Logs Section
               VStack(spacing: 16) {
                  HStack {
                     VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Logs")
                           .font(.headline)
                           .fontWeight(.semibold)
                        
                        Text("Found \(recentLogs.count) recent entries")
                           .font(.caption)
                           .foregroundColor(.secondary)
                     }
                     
                     Spacer()
                     
                     Button("Refresh") {
                        onRefresh()
                     }
                     .font(.caption)
                     .foregroundColor(.blue)
                  }
                  .padding(.horizontal)
                  
                  if recentLogs.isEmpty {
                     VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "clock")
                           .font(.largeTitle)
                           .foregroundColor(.secondary)
                        Text("No recent logs")
                           .font(.headline)
                           .foregroundColor(.secondary)
                        Text("Start logging foods to see your recent entries here")
                           .font(.subheadline)
                           .foregroundColor(.secondary)
                           .multilineTextAlignment(.center)
                        
                        Button("Log Your First Food") {
                           // Shows search interface
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        Spacer()
                     }
                     .padding()
                  } else {
                     LazyVStack(spacing: 0) {
                        ForEach(Array(recentLogs.prefix(50).enumerated()), id: \.element.id) { index, entry in
                           RecentLogRow(
                              entry: entry,
                              onShowSources: onShowSources
                           ) {
                              onRecentLogSelected(entry)
                           }
                           .padding(.horizontal)
                           
                           if index < min(49, recentLogs.count - 1) {
                              Divider()
                                 .padding(.leading, 60)
                           }
                        }
                     }
                  }
               }
            }
            .refreshable {
               onRefresh()
            }
         }
      }
      
      // Frequent Food Card for horizontal scrolling
      struct FrequentFoodCard: View {
         let food: Food
         let onShowSources: () -> Void
         let onTap: () -> Void
         
         var body: some View {
            Button {
               onTap()
            } label: {
               VStack(spacing: 8) {
                  ZStack {
                     Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                     
                     Text(String(food.name.prefix(1).uppercased()))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                     
                     if food.isFromAPI {
                        Text(food.sourceEmoji)
                           .font(.caption2)
                           .offset(x: 18, y: -18)
                     }
                  }
                  
                  VStack(spacing: 2) {
                     Text(food.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                     
                     if let brand = food.brand {
                        Text(brand)
                           .font(.caption2)
                           .foregroundColor(.secondary)
                           .lineLimit(1)
                     }
                     
                     Text("\(Int(food.nutritionInfo.calories ?? 0)) cal")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                  }
               }
               .frame(width: 90)
               .padding(.vertical, 8)
               .padding(.horizontal, 6)
               .background(Color.gray.opacity(0.05))
               .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
         }
      }
      
      // Individual row for recent log entries
      struct RecentLogRow: View {
         let entry: FoodEntry
         let onShowSources: () -> Void
         let onTap: () -> Void
         
         private var timeAgo: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: entry.dateLogged, relativeTo: Date())
         }
         
         private var hasBarcode: Bool {
            return entry.food.barcode != nil
         }
         
         var body: some View {
            Button {
               onTap()
            } label: {
               HStack(spacing: 12) {
                  FoodIconView(food: entry.food)
                  
                  VStack(alignment: .leading, spacing: 4) {
                     HStack {
                        Text(entry.food.name)
                           .font(.body)
                           .fontWeight(.medium)
                           .lineLimit(1)
                           .multilineTextAlignment(.leading)
                        
                        if hasBarcode {
                           Image(systemName: "barcode")
                              .font(.caption2)
                              .foregroundColor(.blue)
                        }
                        
                        Spacer()
                     }
                     
                     HStack {
                        Text("\(entry.mealType.emoji) \(entry.mealType.rawValue)")
                           .font(.caption)
                           .foregroundColor(.white)
                           .padding(.horizontal, 6)
                           .padding(.vertical, 2)
                           .background(Color.blue)
                           .cornerRadius(4)
                        
                        Text("• \(timeAgo)")
                           .font(.caption)
                           .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(entry.quantity.formattedNutrition) \(entry.food.servingSizeUnit)")
                           .font(.caption2)
                           .foregroundColor(.secondary)
                     }
                  }
                  
                  Spacer()
                  
                  VStack(alignment: .trailing, spacing: 2) {
                     Text("\(Int(entry.scaledNutrition.calories ?? 0))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                     
                     HStack(spacing: 4) {
                        Text("cal")
                           .font(.caption2)
                           .foregroundColor(.secondary)
                        Button {
                           onShowSources()
                        } label: {
                           Image(systemName: "info.circle.fill")
                              .font(.caption)
                              .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(4)
                     }
                  }
                  
                  Image(systemName: "plus.circle.fill")
                     .foregroundColor(.blue)
                     .font(.title2)
               }
               .padding(.vertical, 8)
               .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
         }
      }
   }
   
   // Nutrition Sources Information View
   struct NutritionSourcesView: View {
      @Environment(\.dismiss) private var dismiss
      
      var body: some View {
         NavigationView {
            ScrollView {
               VStack(alignment: .leading, spacing: 20) {
                  Text("Nutritional Data Sources")
                     .font(.title2)
                     .fontWeight(.bold)
                  
                  VStack(alignment: .leading, spacing: 16) {
                     SourceCard(
                        title: "Open Food Facts",
                        description: "Collaborative database of food products with ingredients and nutrition facts. All food information pulled from the internet is found here",
                        url: "https://world.openfoodfacts.org"
                     )
                     
                     SourceCard(
                        title: "USDA FoodData Central",
                        description: "Official nutritional database maintained by the U.S. Department of Agriculture. Foods that are preloaded to the database comply with a 95% accuracy to USDA foods on their official site",
                        url: "https://fdc.nal.usda.gov"
                     )
                  }
                  
                  Text("Data Accuracy")
                     .font(.headline)
                     .padding(.top)
                  
                  Text("Nutritional information is sourced from verified databases and product labels. Data accuracy may vary. Always consult nutrition labels on actual products and healthcare professionals for dietary advice.")
                     .font(.subheadline)
                     .foregroundColor(.secondary)
               }
               .padding()
            }
            .navigationTitle("Data Sources")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
         }
      }
   }
   
   struct SourceCard: View {
      let title: String
      let description: String
      let url: String
      
      var body: some View {
         VStack(alignment: .leading, spacing: 8) {
            Text(title)
               .font(.headline)
            Text(description)
               .font(.subheadline)
               .foregroundColor(.secondary)
            Link(url, destination: URL(string: url)!)
               .font(.caption)
               .foregroundColor(.blue)
         }
         .padding()
         .background(Color.gray.opacity(0.1))
         .cornerRadius(8)
      }
   }
}
