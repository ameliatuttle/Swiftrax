import SwiftUI
// MARK: - Complete Updated SearchLogView with Navigation and State Fixes

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
    
    let preselectedMealType: MealType?
    
    init(preselectedMealType: MealType? = nil) {
        self.preselectedMealType = preselectedMealType
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with meal type picker
                VStack(spacing: 12) {
                    Picker("Meal Type", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            Text("\(mealType.emoji) \(mealType.rawValue)")
                                .tag(mealType)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // FIXED: Enhanced Search Bar with proper focus management
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Search foods...", text: $searchText)
                                .focused($isSearchFocused)
                                .onSubmit {
                                    performSearch()
                                }
                                .onChange(of: searchText) { newValue in
                                    if newValue.isEmpty {
                                        clearSearch()
                                    } else if newValue.count > 2 {
                                        // FIXED: Use Task for delayed search
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
                            // FIXED: Dismiss keyboard before showing scanner
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
                       
                       Button("Test OFF") {
                           testOpenFoodFactsAPI()
                       }
                       .padding(.horizontal, 8)
                       .padding(.vertical, 10)
                       .background(Color.green)
                       .foregroundColor(.white)
                       .cornerRadius(8)
                       .font(.caption)
                       
                       Button("Test Seeds") {
                           testBasicFoodsSeeding()
                       }
                       .padding(.horizontal, 8)
                       .padding(.vertical, 10)
                       .background(Color.blue)
                       .foregroundColor(.white)
                       .cornerRadius(8)
                       .font(.caption)
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
                    ImprovedRecentLogsView(
                        recentLogs: recentLogs,
                        selectedMealType: selectedMealType,
                        onFoodSelected: selectFood,
                        onRefresh: loadRecentLogs
                    )
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
                        
                        Button(action: {
                            // TODO: Navigate to manual entry
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add '\(searchText)' manually")
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
            .navigationTitle("Search & Log")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                setupInitialState()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // FIXED: Add keyboard toolbar to properly dismiss keyboard
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
            // FIXED: Proper sheet dismissal handling
            print("📱 Scanner sheet dismissed")
            // FIXED: Reset keyboard and navigation state
            isSearchFocused = false
            // Check if we should show quantity entry after scanner dismisses
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let _ = selectedFood {
                    print("📱 📱 SEARCHLOGVIEW: Scanner dismissed, showing quantity entry")
                    showingQuantitySheet = true
                }
            }
        }) {
            BarcodeScannerView { barcode in
                print("📱 🎉 SEARCHLOGVIEW: Barcode callback received: \(barcode)")
                
                // FIXED: Ensure barcode processing happens with proper state management
                Task { @MainActor in
                    print("📱 🚀 SEARCHLOGVIEW: Starting barcode lookup...")
                    self.searchByBarcode(barcode)
                }
            }
        }
        .sheet(isPresented: $showingQuantitySheet, onDismiss: {
            // FIXED: Reset state after quantity sheet dismissal
            selectedFood = nil
            isSearchFocused = false
        }) {
            if let food = selectedFood {
                QuantityEntryView(
                    food: food,
                    mealType: selectedMealType
                ) { quantity, unit in
                    addFoodToMeal(food: food, quantity: quantity, unit: unit)
                }
            }
        }
        .alert("Food Added!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                // FIXED: Reset focus state when alert dismisses
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
        // FIXED: Add onDisappear to clean up state
        .onDisappear {
            isSearchFocused = false
        }
    }
    
    // MARK: - Updated Methods with Better State Management
    
    private func setupInitialState() {
        print("🔍 SearchLogView: Setting up initial state")
        if let preselected = preselectedMealType {
            selectedMealType = preselected
        }
        
        // FIXED: Use Task for state updates to prevent modification during view update
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
        
        loadRecentLogs()
    }
    
   private func performSearch() {
       guard !searchText.isEmpty else {
           clearSearch()
           return
       }
       
       Swift.print("\n🔍 ==> STARTING SEARCH FOR: '\(searchText)'")
       
       // FIXED: Use Task for state updates
       Task { @MainActor in
           self.isLoading = true
           self.isSearchingAPI = true
           self.debugInfo = "🔍 Smart searching for '\(searchText)'..."
           self.searchResults = []
       }
       
       Task {
           Swift.print("🧠 Using SmartSearchManager with OpenFoodFacts...")
           let smartResults = await SmartSearchManager.shared.searchFood(searchText)
           Swift.print("🎯 SmartSearchManager returned \(smartResults.count) results:")
           
           for (index, food) in smartResults.prefix(10).enumerated() {
               Swift.print("  \(index + 1). '\(food.name)' - \(food.servingSize) \(food.servingSizeUnit) - \(Int(food.nutritionInfo.calories ?? 0)) cal - Source: '\(food.source)'")
           }
           
           // Apply unit normalization
           let normalizedResults = smartResults.map { UnitNormalizer.shared.normalizeFood($0) }
           Swift.print("\n✨ After normalization: \(normalizedResults.count) results")
           
           for (index, food) in normalizedResults.prefix(5).enumerated() {
               Swift.print("  \(index + 1). '\(food.name)' - \(food.servingSize) \(food.servingSizeUnit) - \(Int(food.nutritionInfo.calories ?? 0)) cal - Source: '\(food.source)'")
           }
           
           // Count results by source for debug info
           let basicCount = normalizedResults.filter { $0.source == "BasicFoods" }.count
           let openFoodFactsCount = normalizedResults.filter { $0.source == "OpenFoodFacts" }.count
           let customCount = normalizedResults.filter { $0.source == "manual" }.count
           
           Task { @MainActor in
               self.searchResults = normalizedResults
               self.isLoading = false
               self.isSearchingAPI = false
               self.debugInfo = "✅ Found \(normalizedResults.count) results (\(basicCount) basic, \(openFoodFactsCount) OpenFoodFacts, \(customCount) custom)"
           }
       }
   }
   
   private func testOpenFoodFactsAPI() {
       print("🧪 Testing OpenFoodFacts API...")
       
       Task {
           do {
               // Test text search
               let results = try await APIManager.shared.searchByText("apple")
               print("🧪 OpenFoodFacts text search returned \(results.count) results for 'apple':")
               
               for (index, food) in results.prefix(5).enumerated() {
                   print("  \(index + 1). '\(food.name)' - \(Int(food.nutritionInfo.calories ?? 0)) cal/\(food.servingSize)\(food.servingSizeUnit)")
               }
               
               // Test barcode search
               let barcodeResult = try await APIManager.shared.searchByBarcode("3017620422003")
               if let food = barcodeResult {
                   print("🧪 OpenFoodFacts barcode search found: '\(food.name)' - \(Int(food.nutritionInfo.calories ?? 0)) cal")
               }
               
               Task { @MainActor in
                   self.debugInfo = "🧪 OpenFoodFacts test: Found \(results.count) apple products via text search"
               }
               
           } catch {
               print("❌ OpenFoodFacts test error: \(error)")
               Task { @MainActor in
                   self.debugInfo = "❌ OpenFoodFacts test failed: \(error.localizedDescription)"
               }
           }
       }
   }
   
   private func testBasicFoodsSeeding() {
       print("🧪 Testing basic foods seeding...")
       
       Task {
           // Test that basic foods are in the database
           DatabaseManager.shared.searchFoodsThreadSafe(query: "", limit: 100) { foods in
               let basicFoods = foods.filter { $0.source == "BasicFoods" }
               let openFoodFacts = foods.filter { $0.source == "OpenFoodFacts" }
               let customFoods = foods.filter { $0.source == "manual" }
               
               print("🧪 Database contents:")
               print("  Basic foods: \(basicFoods.count)")
               print("  OpenFoodFacts: \(openFoodFacts.count)")
               print("  Custom foods: \(customFoods.count)")
               
               // Test specific basic foods
               let testFoods = ["Apple", "Chicken Breast", "White Rice", "Egg"]
               for testFood in testFoods {
                   let found = basicFoods.contains { $0.name == testFood }
                   print("  \(testFood): \(found ? "✅ Found" : "❌ Missing")")
               }
               
               Task { @MainActor in
                   self.debugInfo = "🧪 Database has \(basicFoods.count) basic foods, \(openFoodFacts.count) OpenFoodFacts, \(customFoods.count) custom"
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
    
    private func selectFood(_ food: Food) {
        Task { @MainActor in
            self.selectedFood = food
            self.isSearchFocused = false // Dismiss keyboard
            self.showingQuantitySheet = true
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
    
    // FIXED: Update loadRecentLogs method with thread-safe database access
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
    
    // FIXED: Enhanced relevance scoring for better search results
    private func calculateRelevanceScore(food: Food, query: String) -> Int {
        let queryLower = query.lowercased()
        let nameLower = food.name.lowercased()
        let brandLower = food.brand?.lowercased() ?? ""
        
        var score = 0
        
        // HEAVILY prioritize exact matches
        if nameLower == queryLower { score += 1000 }
        
        // Prioritize simple foods (fewer words = more basic)
        let wordCount = nameLower.components(separatedBy: .whitespacesAndNewlines).count
        if wordCount <= 2 { score += 300 }
        else if wordCount <= 3 { score += 100 }
        else if wordCount > 5 { score -= 200 }
        else if wordCount > 8 { score -= 500 }
        
        // Boost USDA basic foods over branded
        if food.source == "USDA" { score += 200 }
        if food.source == "manual" { score += 150 }
        if food.source == "OpenFoodFacts" { score += 50 }
        
        // Prioritize foods that start with the query
        if nameLower.hasPrefix(queryLower) { score += 500 }
        
        // Penalize overly branded/processed foods
        if brandLower.contains("inc") || brandLower.contains("llc") || brandLower.contains("company") || brandLower.contains("corp") {
            score -= 300
        }
        
        // Penalize foods with weird brand names in the food name itself
        let commercialWords = ["frozen", "organic", "natural", "premium", "gourmet", "artisan", "deluxe"]
        for word in commercialWords {
            if nameLower.contains(word) && !queryLower.contains(word) {
                score -= 50
            }
        }
        
        // Boost for reasonable calorie ranges (avoid weird outliers)
        let calories = food.nutritionInfo.calories ?? 0
        if calories > 0 && calories < 1000 { score += 50 }
        if calories > 1000 { score -= 100 }
        if calories == 0 { score -= 200 } // Penalize zero-calorie oddities
        
        // Boost basic food patterns
        let basicFoodPatterns = ["egg", "milk", "sugar", "flour", "butter", "salt", "rice", "chicken", "beef", "apple", "banana", "bread", "cheese"]
        for pattern in basicFoodPatterns {
            if queryLower.contains(pattern) && nameLower.contains(pattern) {
                // Check if this is a simple version of the food
                if nameLower == pattern || nameLower == "\(pattern)s" || nameLower.hasPrefix("\(pattern),") {
                    score += 400
                }
                // Penalize complex versions when looking for basic foods
                else if wordCount > 4 {
                    score -= 100
                }
            }
        }
        
        // Penalize foods with numbers in weird places (often processed foods)
        if nameLower.contains(#"\d+"#) && !queryLower.contains(#"\d+"#) {
            score -= 100
        }
        
        // Basic containment (lowest priority)
        if nameLower.contains(queryLower) { score += 25 }
        
        return score
    }
}

// MARK: - Rest of SearchLogView components (keep your existing ones)

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
