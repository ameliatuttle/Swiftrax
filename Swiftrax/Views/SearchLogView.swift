import SwiftUI

// Enhanced SearchLogView with Recipe Mode Support
struct SearchLogView: View {
   @State private var searchText = ""
   @State private var searchResults: [Food] = []
   @State private var isLoading = false
   @State private var selectedMealType: MealType = .breakfast
   @State private var showingQuantitySheet = false
   @State private var selectedFood: Food?
   @State private var showingSuccessAlert = false
   @State private var showingBarcodeScanner = false
   @State private var recentLogs: [FoodEntry] = []
   @State private var showingError = false
   @State private var errorMessage = ""
   @State private var isSearchingAPI = false
   
   @FocusState private var isSearchFocused: Bool
   
   // Recipe mode support
   let mode: SearchMode
   let preselectedMealType: MealType?
   let onFoodSelected: ((Food) -> Void)?
   
   // Search modes for different use cases
   enum SearchMode {
      case foodLogging(MealType?)
      case recipeIngredient
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
            // Header with conditional meal type picker
            VStack(spacing: 12) {
               if case .foodLogging = mode {
                  Picker("Meal Type", selection: $selectedMealType) {
                     ForEach(MealType.allCases, id: \.self) { mealType in
                        Text("\(mealType.emoji) \(mealType.rawValue)")
                           .tag(mealType)
                     }
                  }
                  .pickerStyle(SegmentedPickerStyle())
               }
               
               // Search bar with barcode scanner
               HStack(spacing: 12) {
                  HStack(spacing: 8) {
                     Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                     
                     TextField(searchPlaceholder, text: $searchText)
                        .focused($isSearchFocused)
                        .onSubmit {
                           performSearch()
                           clearSearch()
                        }
                        .onChange(of: searchText) { newValue in
                           if newValue.isEmpty {
                              clearSearch()
                           } else if newValue.count > 2 {
                              Task {
                                 try? await Task.sleep(nanoseconds: 500_000_000)
                                 if searchText == newValue {
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
                  
                  Button(action: {
                     isSearchFocused = false
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingBarcodeScanner = true
                     }
                  }) {
                     Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(.blue)
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 10)
                  .background(Color.blue.opacity(0.1))
                  .cornerRadius(10)
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
               } else if !searchText.isEmpty && searchResults.count > 0 {
                  HStack {
                     Text("Found \(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                     Spacer()
                  }
                  .padding(.vertical, 4)
               }
            }
            .padding()
            
            Divider()
            
            // Main content area
            if isLoading && searchResults.isEmpty {
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
            } else if searchResults.isEmpty && searchText.isEmpty {
               if case .foodLogging = mode {
                  ImprovedRecentLogsView(
                     recentLogs: recentLogs,
                     selectedMealType: selectedMealType,
                     onFoodSelected: selectFood,
                     onRefresh: loadRecentLogs
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
            } else if searchResults.isEmpty && !isLoading {
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
               // Search results list
               List {
                  ForEach(searchResults) { food in
                     EnhancedSearchResultRow(
                        food: food,
                        searchText: searchText,
                        onTap: {
                           selectFood(food)
                        }
                     )
                  }
               }
               .listStyle(PlainListStyle())
            }
         }
         .navigationTitle(navigationTitle)
         .navigationBarTitleDisplayMode(.inline)
         .navigationBarItems(
            leading: recipeModeCancelButton,
            trailing: EmptyView()
         )
         .onAppear {
            setupInitialState()
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
               Spacer()
               Button("Done") {
                  isSearchFocused = false
               }
            }
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
      .sheet(isPresented: $showingQuantitySheet, onDismiss: {
         selectedFood = nil
         isSearchFocused = false
      }) {
         if let food = selectedFood {
            if case .foodLogging = mode {
               QuantityEntryView(
                  food: food,
                  mealType: selectedMealType
               ) { quantity, unit in
                  addFoodToMeal(food: food, quantity: quantity, unit: unit)
               }
            } else {
               RecipeQuantityEntryView(food: food) { quantity in
                  handleRecipeIngredientSelection(food: food, quantity: quantity)
               }
            }
         }
      }
      .alert("Food Added!", isPresented: $showingSuccessAlert) {
         Button("OK") {
            isSearchFocused = false
         }
      } message: {
         if let food = selectedFood {
            Text("\(food.name) has been added to your \(selectedMealType.rawValue.lowercased())")
         }
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
   
   // Setup initial view state based on mode
   private func setupInitialState() {
      if let preselected = preselectedMealType {
         selectedMealType = preselected
      }
      
      Task { @MainActor in
         searchResults = []
         selectedFood = nil
         isLoading = false
         isSearchingAPI = false
         showingBarcodeScanner = false
         showingQuantitySheet = false
         isSearchFocused = false
      }
      
      if case .foodLogging = mode {
         loadRecentLogs()
      }
   }
   
   // Handle food selection from search results or recent logs
   private func selectFood(_ food: Food) {
      Task { @MainActor in
         self.selectedFood = food
         self.isSearchFocused = false
         self.showingQuantitySheet = true
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
   
   // Search for foods using local database first, then API fallback
   private func performSearch() {
      guard !searchText.isEmpty else {
         clearSearch()
         return
      }
      
      print("Searching for: '\(searchText)'")
      
      Task { @MainActor in
         self.isLoading = true
         self.searchResults = []
      }
      
      Task {
         // Search local database first
         let localResults = await DatabaseManager.shared.searchFoodsAsync(query: searchText)
         print("Found \(localResults.count) local results")
         
         if localResults.count >= 1 {
            Task { @MainActor in
               self.searchResults = localResults
               self.isLoading = false
            }
            return
         }
         
         // Search API if insufficient local results
         print("Searching API for additional results")
         do {
            let apiResults = try await APIManager.shared.searchByText(searchText)
            print("Found \(apiResults.count) API results")
            Task { @MainActor in
               self.searchResults = localResults + apiResults
               self.isLoading = false
            }
         } catch {
            print("API search failed: \(error.localizedDescription)")
            Task { @MainActor in
               self.searchResults = localResults
               self.isLoading = false
               self.errorMessage = "Could not fetch from OpenFoodFacts"
               self.showingError = true
            }
         }
      }
   }
   
   // Clear search text and results
   private func clearSearch() {
      Task { @MainActor in
         self.searchText = ""
         self.searchResults = []
         self.isSearchFocused = false
      }
   }
   
   // Search for food by barcode using database lookup
   private func searchByBarcode(_ barcode: String) {
      print("Looking up barcode: \(barcode)")
      
      Task { @MainActor in
         self.isLoading = true
         self.isSearchingAPI = true
         self.searchResults = []
         self.selectedFood = nil
      }
      
      DatabaseManager.shared.getFoodByBarcode(barcode) { food in
         Task { @MainActor in
            self.isLoading = false
            self.isSearchingAPI = false
            
            if let foundFood = food {
               print("Barcode found: \(foundFood.name)")
               self.searchResults = [foundFood]
               self.selectedFood = foundFood
            } else {
               print("No product found for barcode")
               self.errorMessage = "No product found for barcode \(barcode)"
               self.showingError = true
            }
         }
      }
   }
   
   // Load recent food entries from the last 7 days
   private func loadRecentLogs() {
      let calendar = Calendar.current
      let endDate = Date()
      let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
      
      DatabaseManager.shared.getAllFoodEntriesThreadSafe(from: startDate, to: endDate) { allEntries in
         DispatchQueue.global(qos: .background).async {
            let sortedEntries = allEntries
               .sorted { $0.dateLogged > $1.dateLogged }
               .prefix(20)
            
            Task { @MainActor in
               self.recentLogs = Array(sortedEntries)
               print("Loaded \(self.recentLogs.count) recent logs")
            }
         }
      }
   }
   
   // Add food to selected meal type and add to db when logged
   private func addFoodToMeal(food: Food, quantity: Double, unit: MeasurementUnit) {
      DatabaseManager.shared.saveFoodThreadSafe(food) { foodSaveSuccess in
         Task { @MainActor in
            guard foodSaveSuccess else {
               print("Failed to save food before logging entry")
               return
            }
            
            print("Adding \(food.name) to \(selectedMealType.rawValue)")
            
            let entry = FoodEntry.create(
               food: food,
               quantity: quantity,
               unit: unit,
               mealType: selectedMealType
            )
            
            DatabaseManager.shared.saveFoodEntryThreadSafe(entry) { success in
               Task { @MainActor in
                  if success {
                     print("Food entry saved successfully")
                     NotificationCenter.default.post(name: NSNotification.Name("FoodEntryAdded"), object: nil)
                     self.showingSuccessAlert = true
                     self.loadRecentLogs()
                  } else {
                     self.errorMessage = "Failed to save food entry."
                     self.showingError = true
                  }
               }
            }
         }
      }
   }
   
   
   // Recent logs view for food logging mode
   struct ImprovedRecentLogsView: View {
      let recentLogs: [FoodEntry]
      let selectedMealType: MealType
      let onFoodSelected: (Food) -> Void
      let onRefresh: () -> Void
      
      var body: some View {
         ScrollView {
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
                     HStack {
                        Text("Tap any item to quickly add to \(selectedMealType.emoji) \(selectedMealType.rawValue)")
                           .font(.caption)
                           .foregroundColor(.secondary)
                        Spacer()
                     }
                     .padding(.horizontal)
                     .padding(.bottom, 8)
                     
                     ForEach(Array(recentLogs.prefix(15).enumerated()), id: \.element.id) { index, entry in
                        RecentLogRow(entry: entry) {
                           onFoodSelected(entry.food)
                        }
                        .padding(.horizontal)
                        
                        if index < min(14, recentLogs.count - 1) {
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
   
   // Individual row for recent log entries
   struct RecentLogRow: View {
      let entry: FoodEntry
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
         Button(action: onTap) {
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
                  
                  Text("cal")
                     .font(.caption2)
                     .foregroundColor(.secondary)
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
   
   // Enhanced search result row with highlighting
   struct EnhancedSearchResultRow: View {
      let food: Food
      let searchText: String
      let onTap: () -> Void
      
      var body: some View {
         Button(action: onTap) {
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
               
               VStack(alignment: .trailing, spacing: 2) {
                  Text("\(Int(food.nutritionInfo.calories ?? 0))")
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
}
