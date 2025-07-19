import SwiftUI

// MARK: - 🆕 NEW: Enhanced SearchLogView with Recipe Mode Support

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
    @State private var debugInfo = ""
   
   private let screenWidth = UIScreen.main.bounds.width
   private let screenHeight = UIScreen.main.bounds.height
    
    // FIXED: Add focus state to properly manage keyboard
    @FocusState private var isSearchFocused: Bool
    
    // 🆕 NEW: Recipe mode support
    let mode: SearchMode
    let preselectedMealType: MealType?
    let onFoodSelected: ((Food) -> Void)?  // For recipe mode
    
    // 🆕 NEW: Search modes
    enum SearchMode {
        case foodLogging(MealType?)  // Regular food logging with meal types
        case recipeIngredient        // Recipe ingredient selection (no meal types)
    }
    
    // 🆕 NEW: Multiple initializers for different use cases
    init(preselectedMealType: MealType? = nil) {
        self.mode = .foodLogging(preselectedMealType)
        self.preselectedMealType = preselectedMealType
        self.onFoodSelected = nil
    }
    
    init(forRecipeIngredients onFoodSelected: @escaping (Food) -> Void) {
        self.mode = .recipeIngredient
        self.preselectedMealType = nil
        self.onFoodSelected = onFoodSelected
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header - conditionally show meal type picker
                VStack(spacing: 12) {
                    // 🆕 UPDATED: Only show meal type picker in food logging mode
                    if case .foodLogging = mode {
                        Picker("Meal Type", selection: $selectedMealType) {
                            ForEach(MealType.allCases, id: \.self) { mealType in
                                Text("\(mealType.emoji) \(mealType.rawValue)")
                                    .tag(mealType)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Enhanced Search Bar with proper focus management
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
                                    if newValue.isEmpty {
                                        clearSearch()
                                    } else if newValue.count > 2 {
                                        // Use Task for delayed search
                                        Task {
                                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
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
                            print("📱 🎯 SEARCHLOGVIEW: Barcode scanner button tapped")
                            // Dismiss keyboard before showing scanner
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
                    
                    // Search Status
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
                    
                    // Debug info for troubleshooting
                    if !debugInfo.isEmpty {
                        Text(debugInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding()
                
                Divider()
                
                // Content
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
                    // 🆕 UPDATED: Show different content based on mode
                    if case .foodLogging = mode {
                        ImprovedRecentLogsView(
                            recentLogs: recentLogs,
                            selectedMealType: selectedMealType,
                            onFoodSelected: selectFood,
                            onRefresh: loadRecentLogs
                        )
                    } else {
                        // Recipe mode - show search instruction
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
            // 🆕 UPDATED: Add cancel button for recipe mode
            .navigationBarItems(
                leading: recipeModeCancelButton,
                trailing: EmptyView()
            )
            .onAppear {
                setupInitialState()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Add keyboard toolbar to properly dismiss keyboard
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
            print("📱 Scanner sheet dismissed")
            isSearchFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let _ = selectedFood {
                    print("📱 📱 SEARCHLOGVIEW: Scanner dismissed, handling food selection")
                    handleFoodSelection()
                }
            }
        }) {
            BarcodeScannerView { barcode in
                print("📱 🎉 SEARCHLOGVIEW: Barcode callback received: \(barcode)")
                
                Task { @MainActor in
                    print("📱 🚀 SEARCHLOGVIEW: Starting barcode lookup...")
                    self.searchByBarcode(barcode)
                }
            }
        }
        // 🆕 UPDATED: Different sheet behavior based on mode
        .sheet(isPresented: $showingQuantitySheet, onDismiss: {
            selectedFood = nil
            isSearchFocused = false
        }) {
            if let food = selectedFood {
                if case .foodLogging = mode {
                    // Regular quantity entry for meal logging
                    QuantityEntryView(
                        food: food,
                        mealType: selectedMealType
                    ) { quantity, unit in
                        addFoodToMeal(food: food, quantity: quantity, unit: unit)
                    }
                } else {
                    // Recipe quantity entry
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
    
    // MARK: - 🆕 NEW: Computed Properties for Mode-Specific UI
    
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
                // This will be handled by the parent view
            }
        }
    }
    
    // MARK: - Updated Methods with Mode Support
    
    private func setupInitialState() {
        print("🔍 SearchLogView: Setting up initial state")
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
            debugInfo = ""
            isSearchFocused = false
        }
        
        // Only load recent logs for food logging mode
        if case .foodLogging = mode {
            loadRecentLogs()
        }
    }
    
    private func selectFood(_ food: Food) {
        Task { @MainActor in
            self.selectedFood = food
            self.isSearchFocused = false // Dismiss keyboard
            
            // 🆕 UPDATED: Handle selection based on mode
            switch mode {
            case .foodLogging:
                self.showingQuantitySheet = true
            case .recipeIngredient:
                self.showingQuantitySheet = true
            }
        }
    }
    
    // 🆕 NEW: Handle food selection after barcode scan
    private func handleFoodSelection() {
        switch mode {
        case .foodLogging:
            showingQuantitySheet = true
        case .recipeIngredient:
            showingQuantitySheet = true
        }
    }
    
    // 🆕 NEW: Handle recipe ingredient selection
    private func handleRecipeIngredientSelection(food: Food, quantity: Double) {
        print("✅ Recipe ingredient selected: \(food.name) - \(quantity) \(food.servingSizeUnit)")
        onFoodSelected?(food)  // This will be handled by RecipeCreationView
    }
    
   private func performSearch() {
       guard !searchText.isEmpty else {
           clearSearch()
           return
       }

       Swift.print("\n🔍 ==> STARTING SEARCH FOR: '\(searchText)'")

       Task { @MainActor in
           self.isLoading = true
           self.searchResults = []
           self.debugInfo = "🔍 Searching locally..."
       }

       Task {
           // Step 1: Local DB search
          let localResults = await DatabaseManager.shared.searchFoodsAsync(query: searchText)
           Swift.print("📦 Local DB returned \(localResults.count) results")

           if localResults.count >= 1 {
               Swift.print("✅ Using local results only")
               Task { @MainActor in
                   self.searchResults = localResults
                   self.isLoading = false
                   self.debugInfo = "✅ Found \(localResults.count) local matches"
               }
               return
           }

           // Step 2: Fall back to OpenFoodFacts
           Swift.print("🌐 Not enough local results, searching OpenFoodFacts...")

           do {
               let apiResults = try await APIManager.shared.searchByText(searchText)
               Task { @MainActor in
                   self.searchResults = localResults + apiResults
                   self.isLoading = false
                   self.debugInfo = "✅ Found \(apiResults.count) from API + \(localResults.count) local"
               }
           } catch {
               Swift.print("❌ OpenFoodFacts failed: \(error)")
               Task { @MainActor in
                   self.searchResults = localResults
                   self.isLoading = false
                   self.debugInfo = "⚠️ API failed, showing \(localResults.count) local results"
                   self.errorMessage = "Could not fetch from OpenFoodFacts"
                   self.showingError = true
               }
           }
       }
   }


    
    private func clearSearch() {
        Task { @MainActor in
            self.searchText = ""
            self.searchResults = []
            self.isSearchFocused = false
        }
    }
    
    private func searchByBarcode(_ barcode: String) {
        Swift.print("📱 🔍 SEARCHLOGVIEW: Starting barcode lookup for: \(barcode)")
        
        Task { @MainActor in
            self.isLoading = true
            self.isSearchingAPI = true
            self.debugInfo = "🔍 Looking up barcode: \(barcode)"
            self.searchResults = []
            self.selectedFood = nil
        }
        
        DatabaseManager.shared.getFoodByBarcode(barcode) { food in
            Task { @MainActor in
                self.isLoading = false
                self.isSearchingAPI = false
                
                if let foundFood = food {
                    Swift.print("📱 ✅ SEARCHLOGVIEW: Success! Found: \(foundFood.name) from \(foundFood.source)")
                    self.debugInfo = "✅ Found: \(foundFood.name) (\(foundFood.source))"
                    
                    self.searchResults = [foundFood]
                    self.selectedFood = foundFood
                    
                    Swift.print("📱 📱 SEARCHLOGVIEW: Food found, waiting for scanner to dismiss...")
                } else {
                    Swift.print("📱 ❌ SEARCHLOGVIEW: No product found for barcode: \(barcode)")
                    self.debugInfo = "❌ No product found"
                    self.errorMessage = "No product found for barcode \(barcode). The product might not be in our database yet."
                    self.showingError = true
                }
            }
        }
    }
    
    private func loadRecentLogs() {
        Swift.print("🔍 Loading recent food logs...")
        
        Task { @MainActor in
            self.debugInfo = "Loading recent logs..."
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        DatabaseManager.shared.getAllFoodEntriesThreadSafe(from: startDate, to: endDate) { allEntries in
            Swift.print("🔍 Retrieved \(allEntries.count) entries from last 7 days")
            
            DispatchQueue.global(qos: .background).async {
                let sortedEntries = allEntries
                    .sorted { $0.dateLogged > $1.dateLogged }
                    .prefix(20)
                
                Task { @MainActor in
                    self.recentLogs = Array(sortedEntries)
                    self.debugInfo = "Loaded \(self.recentLogs.count) recent logs"
                    Swift.print("🔍 Loaded \(self.recentLogs.count) recent food logs")
                    
                    for (index, entry) in self.recentLogs.prefix(3).enumerated() {
                        Swift.print("🔍 Recent log \(index + 1): \(entry.food.name) - \(entry.mealType.rawValue) - \(DateFormatters.shared.timeFormatter.string(from: entry.dateLogged))")
                    }
                }
            }
        }
    }
    
    private func addFoodToMeal(food: Food, quantity: Double, unit: MeasurementUnit) {
        Swift.print("🔍 Adding \(food.name) to \(selectedMealType.rawValue): \(quantity) \(unit.abbreviation)")
        
        let entry = FoodEntry.create(
            food: food,
            quantity: quantity,
            unit: unit,
            mealType: selectedMealType
        )
        
        DatabaseManager.shared.saveFoodEntryThreadSafe(entry) { success in
            Task { @MainActor in
                if success {
                    Swift.print("✅ Food entry saved successfully")
                    
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


// MARK: - Rest of the SearchLogView components (unchanged)

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
                            // This will show the search interface
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
                                print("🔍 Selected recent log: \(entry.food.name)")
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
