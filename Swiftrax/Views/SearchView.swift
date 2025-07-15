import SwiftUI

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
               
               // Enhanced Search Bar
               EnhancedSearchBar(
                   searchText: $searchText,
                   isLoading: $isLoading,
                   onSearchSubmitted: performSearch,
                   onBarcodeScanner: {
                       print("📱 🎯 SEARCHLOGVIEW: Barcode scanner button tapped")
                       showingBarcodeScanner = true
                   },
                   onClear: clearSearch
               )
               
               // Search Status
               SearchStatusView(
                  isSearchingAPI: isSearchingAPI,
                  resultCount: searchResults.count,
                  hasSearchText: !searchText.isEmpty
               )
               
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
               LoadingView(isSearchingAPI: isSearchingAPI)
            } else if searchText.isEmpty {
               ImprovedRecentLogsView(
                  recentLogs: recentLogs,
                  selectedMealType: selectedMealType,
                  onFoodSelected: selectFood,
                  onRefresh: loadRecentLogs
               )
            } else if searchResults.isEmpty && !isLoading {
               NoResultsView(
                  searchText: searchText,
                  onManualEntry: {
                     // TODO: Navigate to manual entry
                  }
               )
            } else {
               SearchResultsList(
                  searchResults: searchResults,
                  searchText: searchText,
                  onFoodSelected: selectFood
               )
            }
         }
         .navigationTitle("Search & Log")
         .navigationBarTitleDisplayMode(.inline)
         .onAppear {
            setupInitialState()
            //testBarcodeSystem()
         }
      }
      .sheet(isPresented: $showingBarcodeScanner) {
          BarcodeScannerView { barcode in
              print("📱 🎉 SEARCHLOGVIEW: Barcode callback received: \(barcode)")
              
              // Process the barcode immediately
              DispatchQueue.main.async {
                  print("📱 🚀 SEARCHLOGVIEW: Starting barcode lookup...")
                  self.searchByBarcode(barcode)
              }
          }
      }
      .sheet(isPresented: $showingQuantitySheet) {
         if let food = selectedFood {
            QuantityEntryView(
               food: food,
               mealType: selectedMealType
            ) { quantity, unit in
               addFoodToMeal(food: food, quantity: quantity, unit: unit)
               showingSuccessAlert = true
               loadRecentLogs()
            }
         }
      }
      .alert("Food Added!", isPresented: $showingSuccessAlert) {
         Button("OK") { }
      } message: {
         if let food = selectedFood {
            Text("\(food.name) has been added to your \(selectedMealType.rawValue.lowercased())")
         }
      }
      .alert("Error", isPresented: $showingError) {
         Button("OK") { }
      } message: {
         Text(errorMessage)
      }
   }
   
   // MARK: - Private Methods
   private func setupInitialState() {
       print("🔍 SearchLogView: Setting up initial state")
       if let preselected = preselectedMealType {
           selectedMealType = preselected
       }
       
       // Clear any previous state
       searchResults = []
       selectedFood = nil
       isLoading = false
       isSearchingAPI = false
       showingBarcodeScanner = false
       showingQuantitySheet = false
       debugInfo = ""
       
       loadRecentLogs()
   }
   
   private func performSearch() {
      guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
         clearSearch()
         return
      }
      
      Swift.print("🔍 SearchLogView: Starting enhanced fuzzy search for '\(searchText)'")
      isLoading = true
      isSearchingAPI = false
      
      DatabaseManager.shared.searchFoodsWithFuzzyMatching(query: searchText) { foods in
         Swift.print("🔍 Found \(foods.count) results with fuzzy matching")
         
         let sortedFoods = foods.sorted { food1, food2 in
            let score1 = calculateRelevanceScore(food: food1, query: searchText)
            let score2 = calculateRelevanceScore(food: food2, query: searchText)
            return score1 > score2
         }
         
         DispatchQueue.main.async {
            self.searchResults = sortedFoods
            self.isLoading = false
            self.isSearchingAPI = false
         }
      }
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
         if isLoading {
            isSearchingAPI = true
         }
      }
   }
   
   private func calculateRelevanceScore(food: Food, query: String) -> Int {
      let queryLower = query.lowercased()
      let nameLower = food.name.lowercased()
      let brandLower = food.brand?.lowercased() ?? ""
      
      var score = 0
      
      if nameLower == queryLower { score += 100 }
      if nameLower.hasPrefix(queryLower) { score += 50 }
      if brandLower == queryLower { score += 30 }
      
      let queryWords = queryLower.components(separatedBy: .whitespaces)
      let matchingWords = queryWords.filter { word in
         nameLower.contains(word) || brandLower.contains(word)
      }
      score += matchingWords.count * 10
      
      if food.source == "manual" { score += 5 }
      
      return score
   }
   
   private func clearSearch() {
      searchText = ""
      searchResults = []
   }
   
   private func selectFood(_ food: Food) {
      selectedFood = food
      showingQuantitySheet = true
   }
   
   private func searchByBarcode(_ barcode: String) {
       Swift.print("📱 🔍 SEARCHLOGVIEW: Starting barcode lookup for: \(barcode)")
       
       // Clear state and show immediate feedback
       isLoading = true
       isSearchingAPI = true
       debugInfo = "🔍 Looking up barcode: \(barcode)"
       searchResults = []
       selectedFood = nil
       
       Swift.print("📱 📊 SEARCHLOGVIEW: State updated, calling database...")
       
       // Use thread-safe database lookup
       DatabaseManager.shared.getFoodByBarcode(barcode) { food in
           DispatchQueue.main.async {
               Swift.print("📱 📋 SEARCHLOGVIEW: Database callback received")
               
               self.isLoading = false
               self.isSearchingAPI = false
               
               if let foundFood = food {
                   Swift.print("📱 ✅ SEARCHLOGVIEW: Success! Found: \(foundFood.name) from \(foundFood.source)")
                   self.debugInfo = "✅ Found: \(foundFood.name) (\(foundFood.source))"
                   
                   // Update search results
                   self.searchResults = [foundFood]
                   self.selectedFood = foundFood
                   
                   // Show quantity entry after UI updates
                   DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                       Swift.print("📱 📱 SEARCHLOGVIEW: Showing quantity entry for: \(foundFood.name)")
                       self.showingQuantitySheet = true
                   }
               } else {
                   Swift.print("📱 ❌ SEARCHLOGVIEW: No product found for barcode: \(barcode)")
                   self.debugInfo = "❌ No product found"
                   self.errorMessage = "No product found for barcode \(barcode). The product might not be in our database yet."
                   self.showingError = true
               }
           }
       }
   }
   
   private func testBarcodeSystem() {
      print("🧪 Testing barcode system from SearchLogView...")
      
      // Test with the barcode that was detected
      searchByBarcode("0074401704324")
   }
   
   // MARK: - IMPROVED: Load Recent Logs
   private func loadRecentLogs() {
      Swift.print("🔍 Loading recent food logs...")
      debugInfo = "Loading recent logs..."
      
      // Get recent entries from the last 7 days
      let calendar = Calendar.current
      let endDate = Date()
      let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
      
      DispatchQueue.global(qos: .background).async {
         var allRecentEntries: [FoodEntry] = []
         var currentDate = startDate
         
         // Collect entries from the last 7 days
         while currentDate <= endDate {
            let dayEntries = DatabaseManager.shared.getFoodEntries(for: currentDate)
            allRecentEntries.append(contentsOf: dayEntries)
            Swift.print("🔍 Found \(dayEntries.count) entries for \(DateFormatters.shared.shortDateFormatter.string(from: currentDate))")
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
         }
         
         // Sort by most recent first and limit to 20 items
         let sortedEntries = allRecentEntries
            .sorted { $0.dateLogged > $1.dateLogged }
            .prefix(20)
         
         DispatchQueue.main.async {
            self.recentLogs = Array(sortedEntries)
            self.debugInfo = "Loaded \(self.recentLogs.count) recent logs"
            Swift.print("🔍 Loaded \(self.recentLogs.count) recent food logs")
            
            // Debug: Print some entries
            for (index, entry) in self.recentLogs.prefix(3).enumerated() {
               Swift.print("🔍 Recent log \(index + 1): \(entry.food.name) - \(entry.mealType.rawValue) - \(DateFormatters.shared.timeFormatter.string(from: entry.dateLogged))")
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
      
      // FIXED: Use thread-safe database operations
      DatabaseManager.shared.saveFoodEntryThreadSafe(entry) { success in
         if success {
            Swift.print("✅ Food entry saved successfully")
            
            // Post notification to refresh dashboard
            NotificationCenter.default.post(name: NSNotification.Name("FoodEntryAdded"), object: nil)
            
            // Refresh recent logs
            self.loadRecentLogs()
         } else {
            self.errorMessage = "Failed to save food entry."
            self.showingError = true
         }
      }
   }
   
   // MARK: - IMPROVED Recent Logs View
   struct ImprovedRecentLogsView: View {
      let recentLogs: [FoodEntry]
      let selectedMealType: MealType
      let onFoodSelected: (Food) -> Void
      let onRefresh: () -> Void
      
      var body: some View {
         ScrollView {
            VStack(spacing: 16) {
               // Debug info and refresh
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
                     // Quick add instructions
                     HStack {
                        Text("Tap any item to quickly add to \(selectedMealType.emoji) \(selectedMealType.rawValue)")
                           .font(.caption)
                           .foregroundColor(.secondary)
                        Spacer()
                     }
                     .padding(.horizontal)
                     .padding(.bottom, 8)
                     
                     // Recent logs list
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
   
   // MARK: - Enhanced Recent Log Row
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
                     // Meal type badge
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
   
   // MARK: - Enhanced Search Bar (unchanged but included for completeness)
   struct EnhancedSearchBar: View {
      @Binding var searchText: String
      @Binding var isLoading: Bool
      let onSearchSubmitted: () -> Void
      let onBarcodeScanner: () -> Void
      let onClear: () -> Void
      
      @FocusState private var isSearchFocused: Bool
      
      var body: some View {
         HStack(spacing: 12) {
            HStack(spacing: 8) {
               Image(systemName: "magnifyingglass")
                  .foregroundColor(.secondary)
               
               TextField("Search foods...", text: $searchText)
                  .focused($isSearchFocused)
                  .onSubmit {
                     onSearchSubmitted()
                  }
                  .onChange(of: searchText) { newValue in
                     if newValue.isEmpty {
                        onClear()
                     } else if newValue.count > 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                           if searchText == newValue {
                              onSearchSubmitted()
                           }
                        }
                     }
                  }
               
               if isLoading {
                  ProgressView()
                     .scaleEffect(0.8)
               } else if !searchText.isEmpty {
                  Button("Clear", action: onClear)
                     .font(.caption)
                     .foregroundColor(.blue)
               }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: onBarcodeScanner) {
               Image(systemName: "barcode.viewfinder")
                  .font(.title2)
                  .foregroundColor(.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
         }
      }
   }
   
   // MARK: - Search Status View (unchanged)
   struct SearchStatusView: View {
      let isSearchingAPI: Bool
      let resultCount: Int
      let hasSearchText: Bool
      
      var body: some View {
         if isSearchingAPI {
            HStack(spacing: 8) {
               ProgressView()
                  .scaleEffect(0.7)
               Text("Searching online databases...")
                  .font(.caption)
                  .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
         } else if hasSearchText && resultCount > 0 {
            HStack {
               Text("Found \(resultCount) result\(resultCount == 1 ? "" : "s")")
                  .font(.caption)
                  .foregroundColor(.secondary)
               Spacer()
            }
            .padding(.vertical, 4)
         }
      }
   }
   
   // MARK: - Loading View (unchanged)
   struct LoadingView: View {
      let isSearchingAPI: Bool
      
      var body: some View {
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
      }
   }
   
   // MARK: - No Results View (unchanged)
   struct NoResultsView: View {
      let searchText: String
      let onManualEntry: () -> Void
      
      var body: some View {
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
            
            Button(action: onManualEntry) {
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
      }
   }
   
   // MARK: - Search Results List (unchanged)
   struct SearchResultsList: View {
      let searchResults: [Food]
      let searchText: String
      let onFoodSelected: (Food) -> Void
      
      var body: some View {
         List {
            ForEach(searchResults) { food in
               EnhancedSearchResultRow(
                  food: food,
                  searchText: searchText,
                  onTap: {
                     onFoodSelected(food)
                  }
               )
            }
         }
         .listStyle(PlainListStyle())
      }
   }
   
   // MARK: - Enhanced Search Result Row (unchanged)
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
   
   // MARK: - Food Icon View (unchanged)
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

#Preview {
    SearchLogView()
}
