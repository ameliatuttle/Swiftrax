import Foundation
import SQLite3

class DatabaseManager: ObservableObject {
   static let shared = DatabaseManager()
   
   private var db: OpaquePointer?
   private let dbName = "swiftrax.db"
   private let operationQueue = OperationQueue()
   
   private init() {
      operationQueue.maxConcurrentOperationCount = 1
      operationQueue.qualityOfService = .userInitiated
      
      print("📱 DatabaseManager initializing...")
      openDatabase()
      createTables()
      configureDatabase()
      migrateForAPISupport()
      migrateRecipesForServingWeight()
      
      // Log initial database stats
      let totalFoods = getTotalFoodCount()
      print("📊 DatabaseManager initialized with \(totalFoods) foods")
   }
   
   deinit {
      closeDatabase()
   }
   
   // Configure database settings for optimal performance and safety
   private func configureDatabase() {
      sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
      sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
      sqlite3_busy_timeout(db, 30000)
   }
   
   // Open SQLite database connection
   private func openDatabase() {
      let fileURL = try! FileManager.default
         .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
         .appendingPathComponent(dbName)
      
      sqlite3_open(fileURL.path, &db)
   }
   
   // Close database connection
   private func closeDatabase() {
      sqlite3_close(db)
   }
   
   // Create all required database tables
   private func createTables() {
      createFoodsTable()
      createFoodEntriesTable()
      createMealsTable()
      createMealItemsTable()
      createUserSettingsTable()
      createRecipesTable()
      createRecipeIngredientsTable()
      updateFoodsTableForRecipes()
   }
   
   // Add API support columns and indexes to existing database
   private func migrateForAPISupport() {
      let alterQueries = [
         "ALTER TABLE Foods ADD COLUMN source TEXT DEFAULT 'manual'",
         "ALTER TABLE Foods ADD COLUMN last_updated TEXT"
      ]
      
      for query in alterQueries {
         sqlite3_exec(db, query, nil, nil, nil)
      }
      
      let indexQueries = [
         "CREATE INDEX IF NOT EXISTS idx_barcode ON Foods(barcode)",
         "CREATE INDEX IF NOT EXISTS idx_source ON Foods(source)",
         "CREATE INDEX IF NOT EXISTS idx_last_updated ON Foods(last_updated)",
         "CREATE INDEX IF NOT EXISTS idx_name_source ON Foods(name, source)",
         "CREATE INDEX IF NOT EXISTS idx_name_serving ON Foods(name, serving_size, serving_size_unit)"
      ]
      
      for query in indexQueries {
         sqlite3_exec(db, query, nil, nil, nil)
      }
   }
   
   // Add serving weight columns to existing recipes
   private func migrateRecipesForServingWeight() {
      let alterQueries = [
         "ALTER TABLE Recipes ADD COLUMN serving_weight REAL",
         "ALTER TABLE Recipes ADD COLUMN serving_weight_unit TEXT",
         "ALTER TABLE RecipeIngredients ADD COLUMN unit TEXT DEFAULT 'g'"
      ]
      
      for query in alterQueries {
         sqlite3_exec(db, query, nil, nil, nil)
      }
   }
   
   private func createFoodsTable() {
      let createTableSQL = """
           CREATE TABLE IF NOT EXISTS Foods(
               id TEXT PRIMARY KEY,
               name TEXT NOT NULL,
               barcode TEXT,
               nutrition_info TEXT NOT NULL,
               serving_size REAL NOT NULL,
               serving_size_unit TEXT NOT NULL,
               brand TEXT,
               is_custom INTEGER NOT NULL,
               date_added TEXT NOT NULL,
               recipe_id TEXT,
               is_recipe INTEGER DEFAULT 0,
               source TEXT DEFAULT 'manual',
               last_updated TEXT
           );
       """
      
      sqlite3_exec(db, createTableSQL, nil, nil, nil)
   }
   
   // Add recipe and API support columns to existing Foods table
   private func updateFoodsTableForRecipes() {
      let alterSQL1 = "ALTER TABLE Foods ADD COLUMN recipe_id TEXT"
      sqlite3_exec(db, alterSQL1, nil, nil, nil)
      
      let alterSQL2 = "ALTER TABLE Foods ADD COLUMN is_recipe INTEGER DEFAULT 0"
      sqlite3_exec(db, alterSQL2, nil, nil, nil)
      
      let alterSQL3 = "ALTER TABLE Foods ADD COLUMN source TEXT DEFAULT 'manual'"
      sqlite3_exec(db, alterSQL3, nil, nil, nil)
      
      let alterSQL4 = "ALTER TABLE Foods ADD COLUMN last_updated TEXT"
      sqlite3_exec(db, alterSQL4, nil, nil, nil)
   }
   
   private func createRecipesTable() {
      let createTableSQL = """
           CREATE TABLE IF NOT EXISTS Recipes(
               id TEXT PRIMARY KEY,
               name TEXT NOT NULL,
               servings INTEGER NOT NULL,
               date_created TEXT NOT NULL
           );
       """
      
      sqlite3_exec(db, createTableSQL, nil, nil, nil)
   }
   
   private func createRecipeIngredientsTable() {
      let createTableSQL = """
           CREATE TABLE IF NOT EXISTS RecipeIngredients(
               id TEXT PRIMARY KEY,
               recipe_id TEXT NOT NULL,
               food_data TEXT NOT NULL,
               quantity REAL NOT NULL,
               FOREIGN KEY(recipe_id) REFERENCES Recipes(id) ON DELETE CASCADE
           );
       """
      
      sqlite3_exec(db, createTableSQL, nil, nil, nil)
   }
   
   private func createFoodEntriesTable() {
      let createTableSQL = """
           CREATE TABLE IF NOT EXISTS FoodEntries(
               id TEXT PRIMARY KEY,
               food_data TEXT NOT NULL,
               quantity REAL NOT NULL,
               meal_type TEXT NOT NULL,
               date_logged TEXT NOT NULL,
               notes TEXT
           );
       """
      
      sqlite3_exec(db, createTableSQL, nil, nil, nil)
   }
   
   private func createMealsTable() {
      let createTableSQL = """
           CREATE TABLE IF NOT EXISTS Meals(
               id TEXT PRIMARY KEY,
               name TEXT NOT NULL,
               is_custom INTEGER NOT NULL,
               date_created TEXT NOT NULL
           );
       """
      
      sqlite3_exec(db, createTableSQL, nil, nil, nil)
   }
   
   private func createMealItemsTable() {
      let createTableSQL = """
           CREATE TABLE IF NOT EXISTS MealItems(
               id TEXT PRIMARY KEY,
               meal_id TEXT NOT NULL,
               food_data TEXT NOT NULL,
               quantity REAL NOT NULL,
               FOREIGN KEY(meal_id) REFERENCES Meals(id)
           );
       """
      
      sqlite3_exec(db, createTableSQL, nil, nil, nil)
   }
   
   private func createUserSettingsTable() {
      let createTableSQL = """
           CREATE TABLE IF NOT EXISTS UserSettings(
               id INTEGER PRIMARY KEY,
               settings_data TEXT NOT NULL
           );
       """
      
      sqlite3_exec(db, createTableSQL, nil, nil, nil)
   }
   
   // Get source priority for duplicate resolution
   private func getSourcePriority(_ source: String) -> Int {
      switch source {
      case "BasicFoods": return 100
      case "OpenFoodFacts": return 50
      case "USDA": return 80
      case "manual": return 30
      default: return 10
      }
   }
   
   // Find potential duplicate foods in database
   private func findPotentialDuplicatesSync(_ food: Food) -> [Food] {
      let cleanName = cleanFoodNameForDuplicateCheck(food.name)
      let tolerance = 0.2
      
      let querySQL = """
           SELECT * FROM Foods 
           WHERE LOWER(TRIM(name)) = LOWER(TRIM(?))
              OR (LOWER(TRIM(name)) LIKE LOWER(TRIM(?)) AND serving_size_unit = ?)
       """
      
      var statement: OpaquePointer?
      var potentialDuplicates: [Food] = []
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, cleanName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_bind_text(statement, 2, "%\(cleanName)%", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_bind_text(statement, 3, food.servingSizeUnit, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         
         while sqlite3_step(statement) == SQLITE_ROW {
            if let existingFood = createFoodFromRow(statement: statement!) {
               if areFoodsDuplicates(food, existingFood, tolerance: tolerance) {
                  potentialDuplicates.append(existingFood)
               }
            }
         }
      }
      
      sqlite3_finalize(statement)
      return potentialDuplicates
   }
   
   // Clean food name for duplicate detection
   private func cleanFoodNameForDuplicateCheck(_ name: String) -> String {
      var cleaned = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      
      let removeWords = ["raw", "cooked", "fresh", "frozen", "organic", "natural"]
      for word in removeWords {
         cleaned = cleaned.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: .regularExpression)
      }
      
      if cleaned.hasSuffix("s") && cleaned.count > 3 {
         let singular = String(cleaned.dropLast())
         cleaned = singular
      }
      
      cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      
      return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
   }
   
   // Determine if two foods are duplicates based on multiple criteria
   private func areFoodsDuplicates(_ food1: Food, _ food2: Food, tolerance: Double) -> Bool {
      if food1.id == food2.id { return false }
      
      let name1 = cleanFoodNameForDuplicateCheck(food1.name)
      let name2 = cleanFoodNameForDuplicateCheck(food2.name)
      
      let namesMatch = name1 == name2 ||
      name1.contains(name2) ||
      name2.contains(name1)
      
      if !namesMatch { return false }
      
      let unit1 = MeasurementUnit(rawValue: food1.servingSizeUnit) ?? .grams
      let unit2 = MeasurementUnit(rawValue: food2.servingSizeUnit) ?? .grams
      
      if unit1.category != unit2.category { return false }
      
      let sizeDifference = abs(food1.servingSize - food2.servingSize) / max(food1.servingSize, food2.servingSize)
      if sizeDifference > tolerance { return false }
      
      if let barcode1 = food1.barcode, let barcode2 = food2.barcode {
         if barcode1 != barcode2 { return false }
      }
      
      return true
   }
   
   // Save food with intelligent duplicate handling
   private func saveFoodWithDuplicateHandlingSync(_ food: Food) -> Bool {
      let duplicates = findPotentialDuplicatesSync(food)
      
      if duplicates.isEmpty {
         return saveFoodSync(food)
      }
      
      let bestDuplicate = duplicates.max { food1, food2 in
         getSourcePriority(food1.source) < getSourcePriority(food2.source)
      }!
      
      let newFoodPriority = getSourcePriority(food.source)
      let existingFoodPriority = getSourcePriority(bestDuplicate.source)
      
      if newFoodPriority > existingFoodPriority {
         var updatedFood = food
         updatedFood.id = bestDuplicate.id
         return saveFoodSync(updatedFood)
      } else if newFoodPriority == existingFoodPriority {
         if isFoodMoreComplete(food, thanFood: bestDuplicate) {
            var updatedFood = food
            updatedFood.id = bestDuplicate.id
            return saveFoodSync(updatedFood)
         } else {
            return true
         }
      } else {
         return true
      }
   }
   
   // Check if one food has more complete information than another
   private func isFoodMoreComplete(_ food1: Food, thanFood food2: Food) -> Bool {
      var score1 = 0
      var score2 = 0
      
      if food1.nutritionInfo.protein != nil { score1 += 1 }
      if food1.nutritionInfo.carbohydrates != nil { score1 += 1 }
      if food1.nutritionInfo.fat != nil { score1 += 1 }
      if food1.nutritionInfo.fiber != nil { score1 += 1 }
      if food1.nutritionInfo.sugar != nil { score1 += 1 }
      if food1.nutritionInfo.sodium != nil { score1 += 1 }
      
      if food2.nutritionInfo.protein != nil { score2 += 1 }
      if food2.nutritionInfo.carbohydrates != nil { score2 += 1 }
      if food2.nutritionInfo.fat != nil { score2 += 1 }
      if food2.nutritionInfo.fiber != nil { score2 += 1 }
      if food2.nutritionInfo.sugar != nil { score2 += 1 }
      if food2.nutritionInfo.sodium != nil { score2 += 1 }
      
      if food1.brand != nil { score1 += 1 }
      if food1.barcode != nil { score1 += 1 }
      
      if food2.brand != nil { score2 += 1 }
      if food2.barcode != nil { score2 += 1 }
      
      return score1 > score2
   }
   
   // Clean up existing duplicates in the database
   func cleanupDuplicatesAsync(completion: @escaping (Int) -> Void) {
      operationQueue.addOperation {
         let allFoods = self.getAllFoodsSync()
         var duplicateGroups: [[Food]] = []
         var processedIds = Set<UUID>()
         
         for food in allFoods {
            if processedIds.contains(food.id) { continue }
            
            let duplicates = self.findPotentialDuplicatesSync(food)
            if !duplicates.isEmpty {
               var group = [food]
               group.append(contentsOf: duplicates)
               duplicateGroups.append(group)
               
               for duplicate in group {
                  processedIds.insert(duplicate.id)
               }
            }
         }
         
         var cleanedCount = 0
         
         for group in duplicateGroups {
            let bestFood = group.max { food1, food2 in
               let priority1 = self.getSourcePriority(food1.source)
               let priority2 = self.getSourcePriority(food2.source)
               
               if priority1 != priority2 {
                  return priority1 < priority2
               }
               
               return !self.isFoodMoreComplete(food1, thanFood: food2)
            }!
            
            for food in group {
               if food.id != bestFood.id {
                  if self.deleteFoodSync(food.id) {
                     cleanedCount += 1
                  }
               }
            }
         }
         
         DispatchQueue.main.async {
            completion(cleanedCount)
         }
      }
   }
   
   // Get all foods from database
   private func getAllFoodsSync() -> [Food] {
      let querySQL = "SELECT * FROM Foods"
      var statement: OpaquePointer?
      var foods: [Food] = []
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         while sqlite3_step(statement) == SQLITE_ROW {
            if let food = createFoodFromRow(statement: statement!) {
               foods.append(food)
            }
         }
      }
      
      sqlite3_finalize(statement)
      return foods
   }
   
   // Delete a food by ID
   private func deleteFoodSync(_ foodId: UUID) -> Bool {
      let deleteSQL = "DELETE FROM Foods WHERE id = ?"
      var statement: OpaquePointer?
      var success = false
      
      if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, foodId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         
         if sqlite3_step(statement) == SQLITE_DONE {
            success = true
         }
      }
      
      sqlite3_finalize(statement)
      return success
   }
   
   func getFoodEntriesThreadSafe(for date: Date, completion: @escaping ([FoodEntry]) -> Void) {
      operationQueue.addOperation {
         let entries = self.getFoodEntriesSync(for: date)
         DispatchQueue.main.async {
            completion(entries)
         }
      }
   }
   
   func getAllFoodEntriesThreadSafe(from startDate: Date, to endDate: Date, completion: @escaping ([FoodEntry]) -> Void) {
      operationQueue.addOperation {
         var allEntries: [FoodEntry] = []
         var currentDate = startDate
         let calendar = Calendar.current
         
         while currentDate <= endDate {
            let dayEntries = self.getFoodEntriesSync(for: currentDate)
            allEntries.append(contentsOf: dayEntries)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
         }
         
         DispatchQueue.main.async {
            completion(allEntries)
         }
      }
   }
   
   // Get ALL food entries (no date filtering)
   func getAllFoodEntriesThreadSafe(completion: @escaping ([FoodEntry]) -> Void) {
      operationQueue.addOperation {
         let allEntries = self.getAllFoodEntriesSync()
         DispatchQueue.main.async {
            completion(allEntries)
         }
      }
   }
   
   func saveFoodThreadSafe(_ food: Food, completion: @escaping (Bool) -> Void = { _ in }) {
      operationQueue.addOperation {
         let success = self.saveFoodWithDuplicateHandlingSync(food)
         DispatchQueue.main.async {
            completion(success)
         }
      }
   }
   
   func saveFoodEntryThreadSafe(_ entry: FoodEntry, completion: @escaping (Bool) -> Void = { _ in }) {
      operationQueue.addOperation {
         let success = self.saveFoodEntrySync(entry)
         DispatchQueue.main.async {
            completion(success)
         }
      }
   }
   
   func deleteEntryThreadSafe(_ entry: FoodEntry, completion: @escaping (Bool) -> Void) {
      operationQueue.addOperation {
         let success = self.deleteEntrySync(entry)
         DispatchQueue.main.async {
            completion(success)
         }
      }
   }
   
   func updateFoodEntryThreadSafe(_ entry: FoodEntry, completion: @escaping (Bool) -> Void) {
      operationQueue.addOperation {
         let success = self.updateFoodEntrySync(entry)
         DispatchQueue.main.async {
            completion(success)
         }
      }
   }
   
   func searchFoodsThreadSafe(query: String, limit: Int = 20, completion: @escaping ([Food]) -> Void) {
      operationQueue.addOperation {
         let foods = self.searchFoodsSync(query: query, limit: limit)
         DispatchQueue.main.async {
            completion(foods)
         }
      }
   }
   
   func getRecentFoodsThreadSafe(limit: Int = 10, completion: @escaping ([Food]) -> Void) {
      operationQueue.addOperation {
         let foods = self.getRecentFoodsSync(limit: limit)
         DispatchQueue.main.async {
            completion(foods)
         }
      }
   }
   
   // Enhanced search with fuzzy matching and non-blocking API integration
   func searchFoodsWithFuzzyMatching(query: String, limit: Int = 20, completion: @escaping ([Food]) -> Void) {
      operationQueue.addOperation {
         print("🔍 Searching for: '\(query)'")
         var allResults: [Food] = []
         var hasCompletedOnce = false
         
         let exactResults = self.performExactSearch(query: query, limit: limit/4)
         print("📍 Exact search found: \(exactResults.count) results")
         allResults.append(contentsOf: exactResults)
         
         if allResults.count < limit {
            let startsWithResults = self.performStartsWithSearch(query: query, limit: limit/4)
               .filter { food in !allResults.contains { $0.id == food.id } }
            print("🔤 Starts with search found: \(startsWithResults.count) results")
            allResults.append(contentsOf: startsWithResults)
         }
         
         if allResults.count < limit {
            let containsResults = self.performContainsSearch(query: query, limit: limit/2)
               .filter { food in !allResults.contains { $0.id == food.id } }
            print("📝 Contains search found: \(containsResults.count) results")
            allResults.append(contentsOf: containsResults)
         }
         
         if allResults.count < limit {
            let fuzzyResults = self.performFuzzySearch(query: query, limit: limit)
               .filter { food in !allResults.contains { $0.id == food.id } }
            print("🧩 Fuzzy search found: \(fuzzyResults.count) results")
            allResults.append(contentsOf: fuzzyResults)
         }
         
         print("📊 Total local results: \(allResults.count)")
         
         // Return local results immediately
         let localResults = self.sortFoodsByRelevance(allResults, query: query)
         let shouldFetchAPI = allResults.count < 3
         
         // If we have sufficient local results or shouldn't fetch API, return immediately
         if !shouldFetchAPI {
            DispatchQueue.main.async {
               completion(localResults)
            }
            return
         }
         
         // Return local results first, then try to enhance with API results
         DispatchQueue.main.async {
            hasCompletedOnce = true
            completion(localResults)
         }
         
         // Fetch API results asynchronously without blocking
         Task {
            do {
               let apiResults = try await APIManager.shared.searchByText(query)
               let filteredAPIResults = self.filterAPIResultsForDuplicates(apiResults, existingResults: allResults)
               
               if !filteredAPIResults.isEmpty && hasCompletedOnce {
                  let combinedResults = allResults + filteredAPIResults
                  let finalResults = self.sortFoodsByRelevance(combinedResults, query: query)
                  
                  DispatchQueue.main.async {
                     completion(finalResults)
                  }
               }
            } catch {
               print("⚠️ API search failed for '\(query)': \(error.localizedDescription)")
               // Don't call completion again - local results were already returned
            }
         }
      }
   }
   
   // Filter API results to remove duplicates of existing foods
   private func filterAPIResultsForDuplicates(_ apiResults: [Food], existingResults: [Food]) -> [Food] {
      return apiResults.filter { apiFood in
         return !existingResults.contains { existingFood in
            areFoodsDuplicates(apiFood, existingFood, tolerance: 0.3)
         }
      }
   }
   
   private func sortFoodsByRelevance(_ foods: [Food], query: String) -> [Food] {
      return foods.sorted { food1, food2 in
         let score1 = calculateFinalRelevanceScore(food1, query: query)
         let score2 = calculateFinalRelevanceScore(food2, query: query)
         return score1 > score2
      }
   }
   
   private func calculateFinalRelevanceScore(_ food: Food, query: String) -> Int {
      let queryLower = query.lowercased()
      let nameLower = food.name.lowercased()
      var score = 0
      
      if nameLower == queryLower { score += 2000 }
      
      score += getSourcePriority(food.source)
      
      let wordCount = nameLower.components(separatedBy: " ").count
      if wordCount <= 2 { score += 800 }
      else if wordCount <= 3 { score += 400 }
      else if wordCount > 5 { score -= 300 }
      
      if nameLower.hasPrefix(queryLower) { score += 600 }
      
      if nameLower.contains(queryLower) { score += 100 }
      
      let calories = food.nutritionInfo.calories ?? 0
      if calories > 0 && calories < 800 { score += 50 }
      if calories > 1200 { score -= 100 }
      if calories == 0 { score -= 500 }
      
      return score
   }
   
   // Get food by barcode from local database or API
   func getFoodByBarcode(_ barcode: String, completion: @escaping (Food?) -> Void) {
      operationQueue.addOperation {
         if let localFood = self.getFoodByBarcodeSync(barcode) {
            DispatchQueue.main.async {
               completion(localFood)
            }
            return
         }
         
         Task {
            do {
               if let apiFood = try await APIManager.shared.searchByBarcode(barcode) {
                  self.operationQueue.addOperation {
                     let saveSuccess = self.saveFoodWithDuplicateHandlingSync(apiFood)
                     
                     DispatchQueue.main.async {
                        completion(apiFood)
                     }
                  }
               } else {
                  DispatchQueue.main.async {
                     completion(nil)
                  }
               }
            } catch {
               DispatchQueue.main.async {
                  completion(nil)
               }
            }
         }
      }
   }
   
   func saveUserSettingsAsync(_ user: User, completion: @escaping () -> Void = {}) {
      operationQueue.addOperation {
         self.saveUserSettings(user)
         DispatchQueue.main.async {
            completion()
         }
      }
   }
   
   func saveUserSettings(_ user: User) {
      let insertSQL = "INSERT OR REPLACE INTO UserSettings (id, settings_data) VALUES (1, ?)"
      
      var statement: OpaquePointer?
      
      if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
         do {
            let encoder = JSONEncoder()
            let settingsData = try encoder.encode(user)
            guard let settingsString = String(data: settingsData, encoding: .utf8) else {
               sqlite3_finalize(statement)
               return
            }
            
            sqlite3_bind_text(statement, 1, settingsString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            sqlite3_step(statement)
         } catch {
            // Handle error silently
         }
      }
      
      sqlite3_finalize(statement)
   }
   
   func getUserSettings() -> User {
      let querySQL = "SELECT settings_data FROM UserSettings WHERE id = 1"
      var statement: OpaquePointer?
      var user = User()
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         if sqlite3_step(statement) == SQLITE_ROW {
            if let settingsString = sqlite3_column_text(statement, 0) {
               guard let settingsData = String(cString: settingsString).data(using: .utf8) else {
                  sqlite3_finalize(statement)
                  return user
               }
               let decoder = JSONDecoder()
               if let decodedUser = try? decoder.decode(User.self, from: settingsData) {
                  user = decodedUser
               }
            }
         }
      }
      
      sqlite3_finalize(statement)
      return user
   }
   
   func getUserSettingsAsync(completion: @escaping (User) -> Void) {
      operationQueue.addOperation {
         let user = self.getUserSettings()
         DispatchQueue.main.async {
            completion(user)
         }
      }
   }
   
   func saveFoodEntry(_ entry: FoodEntry) {
      saveFoodEntryThreadSafe(entry) { _ in }
   }
   
   func getFoodEntriesAsync(for date: Date, completion: @escaping ([FoodEntry]) -> Void) {
      getFoodEntriesThreadSafe(for: date, completion: completion)
   }
   
   func searchFoodsAsync(query: String, completion: @escaping ([Food]) -> Void) {
      searchFoodsWithFuzzyMatching(query: query, completion: completion)
   }
   
   func saveFoodEntryAsync(_ entry: FoodEntry, completion: @escaping () -> Void = {}) {
      saveFoodEntryThreadSafe(entry) { _ in
         completion()
      }
   }
   
   // Get food entries for specific date
   private func getFoodEntriesSync(for date: Date) -> [FoodEntry] {
      let calendar = Calendar.current
      let startOfDay = calendar.startOfDay(for: date)
      let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
      
      let formatter = ISO8601DateFormatter()
      let startString = formatter.string(from: startOfDay)
      let endString = formatter.string(from: endOfDay)
      
      let querySQL = "SELECT * FROM FoodEntries WHERE date_logged >= ? AND date_logged < ? ORDER BY date_logged"
      var statement: OpaquePointer?
      var entries: [FoodEntry] = []
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, startString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_bind_text(statement, 2, endString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         
         while sqlite3_step(statement) == SQLITE_ROW {
            if let entry = createFoodEntryFromRow(statement: statement!) {
               entries.append(entry)
            }
         }
      }
      
      sqlite3_finalize(statement)
      return entries
   }
   
   // Get ALL food entries from database (no date filtering)
   private func getAllFoodEntriesSync() -> [FoodEntry] {
      let querySQL = "SELECT * FROM FoodEntries ORDER BY date_logged DESC"
      var statement: OpaquePointer?
      var entries: [FoodEntry] = []
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         while sqlite3_step(statement) == SQLITE_ROW {
            if let entry = createFoodEntryFromRow(statement: statement!) {
               entries.append(entry)
            }
         }
      }
      
      sqlite3_finalize(statement)
      return entries
   }
   
   // Save food to database
   private func saveFoodSync(_ food: Food) -> Bool {
      let insertSQL = "INSERT OR REPLACE INTO Foods (id, name, barcode, nutrition_info, serving_size, serving_size_unit, brand, is_custom, date_added, recipe_id, is_recipe, source, last_updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      
      var statement: OpaquePointer?
      var success = false
      
      if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
         do {
            let encoder = JSONEncoder()
            let nutritionData = try encoder.encode(food.nutritionInfo)
            guard let nutritionString = String(data: nutritionData, encoding: .utf8) else {
               sqlite3_finalize(statement)
               return false
            }
            
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: food.dateAdded)
            let lastUpdatedString = formatter.string(from: food.lastUpdated)
            
            sqlite3_bind_text(statement, 1, food.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, food.name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if let barcode = food.barcode {
               sqlite3_bind_text(statement, 3, barcode, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
               sqlite3_bind_null(statement, 3)
            }
            
            sqlite3_bind_text(statement, 4, nutritionString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_double(statement, 5, food.servingSize)
            sqlite3_bind_text(statement, 6, food.servingSizeUnit, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if let brand = food.brand {
               sqlite3_bind_text(statement, 7, brand, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
               sqlite3_bind_null(statement, 7)
            }
            
            sqlite3_bind_int(statement, 8, food.isCustom ? 1 : 0)
            sqlite3_bind_text(statement, 9, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if let recipeId = food.recipeId {
               sqlite3_bind_text(statement, 10, recipeId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
               sqlite3_bind_int(statement, 11, 1)
            } else {
               sqlite3_bind_null(statement, 10)
               sqlite3_bind_int(statement, 11, 0)
            }
            
            sqlite3_bind_text(statement, 12, food.source, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 13, lastUpdatedString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if sqlite3_step(statement) == SQLITE_DONE {
               success = true
            }
         } catch {
            // Handle error silently
         }
      }
      
      sqlite3_finalize(statement)
      return success
   }
   
   // Save food entry to database
   private func saveFoodEntrySync(_ entry: FoodEntry) -> Bool {
      let insertSQL = "INSERT INTO FoodEntries (id, food_data, quantity, meal_type, date_logged, notes) VALUES (?, ?, ?, ?, ?, ?)"
      
      var statement: OpaquePointer?
      var success = false
      
      if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
         do {
            let encoder = JSONEncoder()
            let foodData = try encoder.encode(entry.food)
            guard let foodString = String(data: foodData, encoding: .utf8) else {
               sqlite3_finalize(statement)
               return false
            }
            
            sqlite3_bind_text(statement, 1, entry.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, foodString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_double(statement, 3, entry.quantity)
            sqlite3_bind_text(statement, 4, entry.mealType.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: entry.dateLogged)
            sqlite3_bind_text(statement, 5, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if let notes = entry.notes {
               sqlite3_bind_text(statement, 6, notes, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
               sqlite3_bind_null(statement, 6)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
               success = true
            }
         } catch {
            // Handle error silently
         }
      }
      
      sqlite3_finalize(statement)
      return success
   }
   
   // Update existing food entry in database
   private func updateFoodEntrySync(_ entry: FoodEntry) -> Bool {
      let updateSQL = "UPDATE FoodEntries SET food_data = ?, quantity = ?, meal_type = ?, notes = ? WHERE id = ?"
      
      var statement: OpaquePointer?
      var success = false
      
      if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
         do {
            let encoder = JSONEncoder()
            let foodData = try encoder.encode(entry.food)
            guard let foodString = String(data: foodData, encoding: .utf8) else {
               sqlite3_finalize(statement)
               return false
            }
            
            sqlite3_bind_text(statement, 1, foodString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_double(statement, 2, entry.quantity)
            sqlite3_bind_text(statement, 3, entry.mealType.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if let notes = entry.notes {
               sqlite3_bind_text(statement, 4, notes, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
               sqlite3_bind_null(statement, 4)
            }
            
            sqlite3_bind_text(statement, 5, entry.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if sqlite3_step(statement) == SQLITE_DONE {
               success = true
            }
         } catch {
            // Handle error silently
         }
      }
      
      sqlite3_finalize(statement)
      return success
   }
   
   // Delete food entry from database
   private func deleteEntrySync(_ entry: FoodEntry) -> Bool {
      let deleteSQL = "DELETE FROM FoodEntries WHERE id = ?"
      var statement: OpaquePointer?
      var success = false
      
      if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, entry.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         
         if sqlite3_step(statement) == SQLITE_DONE {
            success = true
         }
      }
      
      sqlite3_finalize(statement)
      return success
   }
   
   // Get recent foods from database
   private func getRecentFoodsSync(limit: Int) -> [Food] {
      let querySQL = "SELECT * FROM Foods ORDER BY date_added DESC LIMIT ?"
      var statement: OpaquePointer?
      var foods: [Food] = []
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_int(statement, 1, Int32(limit))
         
         while sqlite3_step(statement) == SQLITE_ROW {
            if let food = createFoodFromRow(statement: statement!) {
               foods.append(food)
            }
         }
      }
      
      sqlite3_finalize(statement)
      return foods
   }
   
   // Search foods in database
   private func searchFoodsSync(query: String, limit: Int) -> [Food] {
      let searchQuery = "%\(query)%"
      let querySQL = "SELECT * FROM Foods WHERE name LIKE ? OR brand LIKE ? ORDER BY source ASC, name LIMIT ?"
      var statement: OpaquePointer?
      var foods: [Food] = []
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, searchQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_bind_text(statement, 2, searchQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_bind_int(statement, 3, Int32(limit))
         
         while sqlite3_step(statement) == SQLITE_ROW {
            if let food = createFoodFromRow(statement: statement!) {
               foods.append(food)
            }
         }
      }
      
      sqlite3_finalize(statement)
      return foods
   }
   
   // Get food by barcode from database
   private func getFoodByBarcodeSync(_ barcode: String) -> Food? {
      let querySQL = "SELECT * FROM Foods WHERE barcode = ?"
      var statement: OpaquePointer?
      var food: Food?
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, barcode, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         
         if sqlite3_step(statement) == SQLITE_ROW {
            food = createFoodFromRow(statement: statement!)
         }
      }
      
      sqlite3_finalize(statement)
      return food
   }
   
   private func performExactSearch(query: String, limit: Int) -> [Food] {
      let sql = "SELECT * FROM Foods WHERE LOWER(name) = LOWER(?) OR LOWER(brand) = LOWER(?) ORDER BY source ASC, name LIMIT ?"
      return executeFoodSearch(sql: sql, params: [query, query], limit: limit)
   }
   
   private func performStartsWithSearch(query: String, limit: Int) -> [Food] {
      let sql = "SELECT * FROM Foods WHERE LOWER(name) LIKE LOWER(?) OR LOWER(brand) LIKE LOWER(?) ORDER BY source ASC, name LIMIT ?"
      let searchPattern = "\(query.lowercased())%"
      return executeFoodSearch(sql: sql, params: [searchPattern, searchPattern], limit: limit)
   }
   
   private func performContainsSearch(query: String, limit: Int) -> [Food] {
      let sql = "SELECT * FROM Foods WHERE LOWER(name) LIKE LOWER(?) OR LOWER(brand) LIKE LOWER(?) ORDER BY source ASC, name LIMIT ?"
      let searchPattern = "%\(query.lowercased())%"
      return executeFoodSearch(sql: sql, params: [searchPattern, searchPattern], limit: limit)
   }
   
   private func performFuzzySearch(query: String, limit: Int) -> [Food] {
      let words = query.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
      guard !words.isEmpty else { return [] }
      
      var conditions: [String] = []
      var params: [String] = []
      
      for word in words {
         conditions.append("(LOWER(name) LIKE ? OR LOWER(brand) LIKE ?)")
         params.append("%\(word)%")
         params.append("%\(word)%")
      }
      
      let sql = "SELECT * FROM Foods WHERE \(conditions.joined(separator: " AND ")) ORDER BY source ASC, name LIMIT ?"
      return executeFoodSearch(sql: sql, params: params, limit: limit)
   }
   
   // Execute food search with given SQL and parameters
   private func executeFoodSearch(sql: String, params: [String], limit: Int) -> [Food] {
      var foods: [Food] = []
      var statement: OpaquePointer?
      
      print("🔍 Executing SQL: \(sql)")
      print("🔍 With params: \(params)")
      
      if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
         for (index, param) in params.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         }
         
         sqlite3_bind_int(statement, Int32(params.count + 1), Int32(limit))
         
         while sqlite3_step(statement) == SQLITE_ROW {
            if let food = createFoodFromRow(statement: statement!) {
               foods.append(food)
               print("🍎 Found food: \(food.name)")
            }
         }
      } else {
         let errorMessage = String(cString: sqlite3_errmsg(db))
         print("❌ SQL Error: \(errorMessage)")
      }
      
      sqlite3_finalize(statement)
      print("📊 SQL returned \(foods.count) results")
      return foods
   }
   
   // Create Food object from database row
   private func createFoodFromRow(statement: OpaquePointer) -> Food? {
      guard let idString = sqlite3_column_text(statement, 0),
            let nameString = sqlite3_column_text(statement, 1),
            let nutritionString = sqlite3_column_text(statement, 3),
            let servingSizeUnitString = sqlite3_column_text(statement, 5),
            let dateString = sqlite3_column_text(statement, 8) else {
         return nil
      }
      
      let id = String(cString: idString)
      let name = String(cString: nameString)
      let barcode = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)!) : nil
      
      let nutritionJsonString = String(cString: nutritionString)
      
      guard let nutritionData = nutritionJsonString.data(using: .utf8) else {
         return nil
      }
      
      let servingSize = sqlite3_column_double(statement, 4)
      let servingSizeUnit = String(cString: servingSizeUnitString)
      let brand = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)!) : nil
      let isCustom = sqlite3_column_int(statement, 7) == 1
      
      var recipeId: UUID? = nil
      if sqlite3_column_count(statement) > 9 && sqlite3_column_text(statement, 9) != nil {
         let recipeIdString = String(cString: sqlite3_column_text(statement, 9)!)
         recipeId = UUID(uuidString: recipeIdString)
      }
      
      var source = "manual"
      var lastUpdated = Date()
      
      let columnCount = sqlite3_column_count(statement)
      if columnCount > 11 && sqlite3_column_text(statement, 11) != nil {
         source = String(cString: sqlite3_column_text(statement, 11)!)
      }
      
      if columnCount > 12 && sqlite3_column_text(statement, 12) != nil {
         let lastUpdatedString = String(cString: sqlite3_column_text(statement, 12)!)
         let formatter = ISO8601DateFormatter()
         lastUpdated = formatter.date(from: lastUpdatedString) ?? Date()
      }
      
      let decoder = JSONDecoder()
      do {
         let nutritionInfo = try decoder.decode(NutritionInfo.self, from: nutritionData)
         
         let formatter = ISO8601DateFormatter()
         let dateAdded = formatter.date(from: String(cString: dateString)) ?? Date()
         
         var food = Food(name: name, barcode: barcode, nutritionInfo: nutritionInfo, servingSize: servingSize, servingSizeUnit: servingSizeUnit, brand: brand, isCustom: isCustom, source: source)
         food.dateAdded = dateAdded
         food.lastUpdated = lastUpdated
         food.recipeId = recipeId
         
         return food
      } catch {
         return nil
      }
   }
   
   // Create FoodEntry object from database row
   private func createFoodEntryFromRow(statement: OpaquePointer) -> FoodEntry? {
      guard let idData = sqlite3_column_text(statement, 0),
            let foodData = sqlite3_column_text(statement, 1),
            let mealTypeData = sqlite3_column_text(statement, 3),
            let dateData = sqlite3_column_text(statement, 4) else {
         return nil
      }
      
      let idString = String(cString: idData)
      let mealTypeString = String(cString: mealTypeData)
      let dateString = String(cString: dateData)
      
      let quantity = sqlite3_column_double(statement, 2)
      
      var notes: String?
      if let notesData = sqlite3_column_text(statement, 5) {
         notes = String(cString: notesData)
      }
      
      guard let mealType = MealType(rawValue: mealTypeString) else {
         return nil
      }
      
      let formatter = ISO8601DateFormatter()
      guard let dateLogged = formatter.date(from: dateString) else {
         return nil
      }
      
      let foodDataLength = sqlite3_column_bytes(statement, 1)
      let foodJsonData = Data(bytes: foodData, count: Int(foodDataLength))
      
      do {
         let decoder = JSONDecoder()
         let food = try decoder.decode(Food.self, from: foodJsonData)
         
         return FoodEntry(
            id: UUID(uuidString: idString) ?? UUID(),
            food: food,
            quantity: quantity,
            mealType: mealType,
            dateLogged: dateLogged,
            notes: notes
         )
      } catch {
         return nil
      }
   }
   
   // Clean up corrupted database entries
   func cleanupCorruptedEntries() {
      let cleanupFoodsSQL = "DELETE FROM Foods WHERE name = '' OR id = '' OR nutrition_info = ''"
      sqlite3_exec(db, cleanupFoodsSQL, nil, nil, nil)
      
      let cleanupEntriesSQL = "DELETE FROM FoodEntries WHERE id = '' OR food_data = ''"
      sqlite3_exec(db, cleanupEntriesSQL, nil, nil, nil)
   }
   
   // Clear all data from database
   func clearAllData() {
      let tables = ["FoodEntries", "Foods", "Meals", "MealItems", "UserSettings", "RecipeIngredients", "Recipes"]
      
      for table in tables {
         let deleteSQL = "DELETE FROM \(table)"
         sqlite3_exec(db, deleteSQL, nil, nil, nil)
      }
   }
   
   func testDatabaseConnection() {
      operationQueue.addOperation {
         let foods = self.searchFoodsSync(query: "test", limit: 1)
         let recipes = self.getRecipes()
         let totalFoodCount = self.getTotalFoodCount()
         print("📊 Database stats - Total foods: \(totalFoodCount), Recipes: \(recipes.count)")
      }
   }
   
   private func getTotalFoodCount() -> Int {
      let querySQL = "SELECT COUNT(*) FROM Foods"
      var statement: OpaquePointer?
      var count = 0
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         if sqlite3_step(statement) == SQLITE_ROW {
            count = Int(sqlite3_column_int(statement, 0))
         }
      }
      
      sqlite3_finalize(statement)
      return count
   }
   
   // Add some test foods if database is empty (for debugging)
   func addTestFoodsIfEmpty() {
      guard getTotalFoodCount() == 0 else { return }
      
      print("📦 Adding test foods for debugging...")
      
      let testFoods = [
         Food(
            name: "Subway Turkey Breast Sandwich",
            barcode: nil,
            nutritionInfo: NutritionInfo(
               calories: 280, protein: 18.0, carbohydrates: 46.0, fat: 3.5,
               fiber: 5.0, sugar: 5.0, sodium: 790.0
            ),
            servingSize: 227, servingSizeUnit: "g",
            brand: "Subway", isCustom: false, source: "test"
         ),
         Food(
            name: "Apple",
            barcode: nil,
            nutritionInfo: NutritionInfo(
               calories: 95, protein: 0.5, carbohydrates: 25.0, fat: 0.3,
               fiber: 4.0, sugar: 19.0, sodium: 2.0
            ),
            servingSize: 182, servingSizeUnit: "g",
            brand: nil, isCustom: false, source: "test"
         ),
         Food(
            name: "Banana",
            barcode: nil,
            nutritionInfo: NutritionInfo(
               calories: 105, protein: 1.3, carbohydrates: 27.0, fat: 0.4,
               fiber: 3.1, sugar: 14.0, sodium: 1.0
            ),
            servingSize: 118, servingSizeUnit: "g",
            brand: nil, isCustom: false, source: "test"
         )
      ]
      
      for food in testFoods {
         _ = saveFoodSync(food)
      }
      
      print("✅ Added \(testFoods.count) test foods")
   }
   
   // MARK: - Async Search Methods
   func searchFoodsAsync(query: String) async -> [Food] {
       return await withCheckedContinuation { (continuation: CheckedContinuation<[Food], Never>) in
           print("🔍 Starting async search for query: '\(query)'")
           
           var hasResumed = false
           let safeCompletion: ([Food]) -> Void = { results in
               guard !hasResumed else {
                   print("⚠️ Attempted to resume continuation twice - ignoring")
                   return
               }
               hasResumed = true
               print("📊 Search completed with \(results.count) results")
               continuation.resume(returning: results)
           }
           
           // Use the thread-safe search method that calls completion only once
           self.searchFoodsThreadSafe(query: query, completion: safeCompletion)
       }
   }
}

extension DatabaseManager {
func saveRecipeAsync(_ recipe: Recipe, completion: @escaping () -> Void = {}) {
    operationQueue.addOperation {
        self.saveRecipe(recipe)
        DispatchQueue.main.async {
            completion()
        }
    }
}

func debugListAllRecipesAsync() {
    operationQueue.addOperation {
        self.debugListAllRecipes()
    }
}

func saveRecipe(_ recipe: Recipe) {
    print("💾 Saving recipe to database: \(recipe.name) (ID: \(recipe.id))")
    
    let insertRecipeSQL = "INSERT OR REPLACE INTO Recipes (id, name, servings, date_created, serving_weight, serving_weight_unit) VALUES (?, ?, ?, ?, ?, ?)"
    
    var statement: OpaquePointer?
    
    if sqlite3_prepare_v2(db, insertRecipeSQL, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, recipe.name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(statement, 3, Int32(recipe.servings))
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: recipe.dateCreated)
        sqlite3_bind_text(statement, 4, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        // Handle serving weight and unit
        if let weight = recipe.servingWeight {
            sqlite3_bind_double(statement, 5, weight)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        
        if let weightUnit = recipe.servingWeightUnit {
            sqlite3_bind_text(statement, 6, weightUnit.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE {
            let changes = sqlite3_changes(db)
            print("✅ Recipe saved successfully. Changes: \(changes)")
            saveRecipeIngredients(recipe.ingredients, recipeId: recipe.id)
        } else {
            print("❌ Failed to save recipe: \(String(cString: sqlite3_errmsg(db)))")
        }
    } else {
        print("❌ Failed to prepare recipe save statement: \(String(cString: sqlite3_errmsg(db)))")
    }
    
    sqlite3_finalize(statement)
}

// Save recipe ingredients to database
private func saveRecipeIngredients(_ ingredients: [RecipeIngredient], recipeId: UUID) {
    print("💾 Saving \(ingredients.count) ingredients for recipe ID: \(recipeId)")
    
    let deleteSQL = "DELETE FROM RecipeIngredients WHERE recipe_id = ?"
    var deleteStatement: OpaquePointer?
    
    if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
        sqlite3_bind_text(deleteStatement, 1, recipeId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        let result = sqlite3_step(deleteStatement)
        if result == SQLITE_DONE {
            let deletedCount = sqlite3_changes(db)
            print("🗑️ Deleted \(deletedCount) existing ingredients for recipe")
        }
    }
    sqlite3_finalize(deleteStatement)
    
    let insertSQL = "INSERT INTO RecipeIngredients (id, recipe_id, food_data, quantity, unit) VALUES (?, ?, ?, ?, ?)"
    var savedCount = 0
    
    for ingredient in ingredients {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            do {
                let encoder = JSONEncoder()
                let foodData = try encoder.encode(ingredient.food)
                guard let foodString = String(data: foodData, encoding: .utf8) else {
                    print("❌ Failed to encode food data for ingredient: \(ingredient.food.name)")
                    sqlite3_finalize(statement)
                    continue
                }
                
                sqlite3_bind_text(statement, 1, ingredient.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(statement, 2, recipeId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(statement, 3, foodString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_double(statement, 4, ingredient.quantity)
                sqlite3_bind_text(statement, 5, ingredient.unit.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE {
                    savedCount += 1
                } else {
                    print("❌ Failed to save ingredient \(ingredient.food.name): \(String(cString: sqlite3_errmsg(db)))")
                }
            } catch {
                print("❌ Error encoding ingredient \(ingredient.food.name): \(error)")
            }
        } else {
            print("❌ Failed to prepare ingredient insert statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
    }
    
    print("✅ Saved \(savedCount)/\(ingredients.count) ingredients successfully")
}

// Debug function to list all recipes in database
func debugListAllRecipes() {
    print("🔍 DEBUG: Listing all recipes in database...")
    let querySQL = "SELECT id, name FROM Recipes ORDER BY name"
    var statement: OpaquePointer?
    var count = 0
    
    if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
        while sqlite3_step(statement) == SQLITE_ROW {
            if let idString = sqlite3_column_text(statement, 0),
               let nameString = sqlite3_column_text(statement, 1) {
                let id = String(cString: idString)
                let name = String(cString: nameString)
                print("🍽️ Recipe: '\(name)' - ID: \(id)")
                count += 1
            }
        }
    }
    sqlite3_finalize(statement)
    print("🔍 Total recipes in database: \(count)")
}

func getRecipesAsync(completion: @escaping ([Recipe]) -> Void) {
    operationQueue.addOperation {
        let recipes = self.getRecipes()
        DispatchQueue.main.async {
            completion(recipes)
        }
    }
}

func searchRecipesAsync(query: String, completion: @escaping ([Recipe]) -> Void) {
    operationQueue.addOperation {
        let recipes = self.searchRecipesSync(query: query)
        DispatchQueue.main.async {
            completion(recipes)
        }
    }
}

func getRecipes() -> [Recipe] {
    let querySQL = "SELECT * FROM Recipes ORDER BY date_created DESC"
    var statement: OpaquePointer?
    var recipes: [Recipe] = []
    
    if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
        while sqlite3_step(statement) == SQLITE_ROW {
            if let recipe = createRecipeFromRow(statement: statement!) {
                recipes.append(recipe)
            }
        }
    }
    
    sqlite3_finalize(statement)
    return recipes
}

// Create Recipe object from database row
private func createRecipeFromRow(statement: OpaquePointer) -> Recipe? {
    let columnCount = sqlite3_column_count(statement)
    
    guard let idString = sqlite3_column_text(statement, 0),
          let nameString = sqlite3_column_text(statement, 1) else {
        return nil
    }
    
    let idStr = String(cString: idString)
    let name = String(cString: nameString)
    let servings = Int(sqlite3_column_int(statement, 2))
    
    guard let id = UUID(uuidString: idStr) else {
        return nil
    }
    
    // Handle different column layouts for backward compatibility
    var dateCreated = Date()
    var servingWeight: Double? = nil
    var servingWeightUnit: MeasurementUnit? = nil
    
    if columnCount >= 4 {
        // Get date from appropriate column
        let dateColumnIndex: Int32 = columnCount >= 6 ? 3 : columnCount - 1
        if let dateString = sqlite3_column_text(statement, dateColumnIndex) {
            let dateStr = String(cString: dateString)
            let formatter = ISO8601DateFormatter()
            dateCreated = formatter.date(from: dateStr) ?? Date()
        }
        
        // Get serving weight fields if they exist (columns 4 and 5)
        if columnCount >= 6 {
            if sqlite3_column_type(statement, 4) != SQLITE_NULL {
                servingWeight = sqlite3_column_double(statement, 4)
            }
            
            if let unitString = sqlite3_column_text(statement, 5) {
                let unitStr = String(cString: unitString)
                servingWeightUnit = MeasurementUnit(rawValue: unitStr)
            }
        }
    }
    
    let ingredients = getIngredientsForRecipe(recipeId: id)
    
    let recipe = Recipe(
        id: id,
        name: name,
        servings: servings,
        ingredients: ingredients,
        dateCreated: dateCreated,
        servingWeight: servingWeight,
        servingWeightUnit: servingWeightUnit
    )
    
    print("📖 Created recipe from database: '\(name)' with ID: \(id)")
    
    return recipe
}

// Get ingredients for specific recipe
private func getIngredientsForRecipe(recipeId: UUID) -> [RecipeIngredient] {
    let querySQL = "SELECT * FROM RecipeIngredients WHERE recipe_id = ?"
    var statement: OpaquePointer?
    var ingredients: [RecipeIngredient] = []
    
    if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, recipeId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let ingredient = createIngredientFromRow(statement: statement!) {
                ingredients.append(ingredient)
            }
        }
    }
    
    sqlite3_finalize(statement)
    return ingredients
}

// Create RecipeIngredient object from database row
private func createIngredientFromRow(statement: OpaquePointer) -> RecipeIngredient? {
    guard let idString = sqlite3_column_text(statement, 0),
          let foodData = sqlite3_column_text(statement, 2) else {
        return nil
    }
    
    let id = UUID(uuidString: String(cString: idString)) ?? UUID()
    let quantity = sqlite3_column_double(statement, 3)
    
    // Handle unit field (backward compatibility)
    var unit: MeasurementUnit = .grams
    let columnCount = sqlite3_column_count(statement)
    if columnCount >= 5 && sqlite3_column_text(statement, 4) != nil {
        let unitString = String(cString: sqlite3_column_text(statement, 4)!)
        unit = MeasurementUnit(rawValue: unitString) ?? .grams
    }
    
    let foodDataLength = sqlite3_column_bytes(statement, 2)
    let foodJsonData = Data(bytes: foodData, count: Int(foodDataLength))
    
    do {
        let decoder = JSONDecoder()
        let food = try decoder.decode(Food.self, from: foodJsonData)
        
        // If no unit was stored, use the food's original unit for backward compatibility
        if columnCount < 5 {
            unit = MeasurementUnit(rawValue: food.servingSizeUnit) ?? .grams
        }
        
        return RecipeIngredient(id: id, food: food, quantity: quantity, unit: unit)
    } catch {
        return nil
    }
}

// Search recipes in database by name
private func searchRecipesSync(query: String, limit: Int = 20) -> [Recipe] {
    let searchQuery = "%\(query)%"
    let querySQL = "SELECT * FROM Recipes WHERE name LIKE ? ORDER BY date_created DESC LIMIT ?"
    var statement: OpaquePointer?
    var recipes: [Recipe] = []
    
    if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, searchQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let recipe = createRecipeFromRow(statement: statement!) {
                recipes.append(recipe)
            }
        }
    }
    
    sqlite3_finalize(statement)
    return recipes
}

func deleteRecipeAsync(_ recipe: Recipe, completion: @escaping () -> Void = {}) {
    operationQueue.addOperation {
        let success = self.deleteRecipe(recipe)
        DispatchQueue.main.async {
            if success {
                print("✅ Recipe deletion successful: \(recipe.name)")
            } else {
                print("❌ Recipe deletion failed: \(recipe.name)")
            }
            completion()
        }
    }
}

// Delete recipe from database
@discardableResult
func deleteRecipe(_ recipe: Recipe) -> Bool {
    print("🗑️ Deleting recipe from database: \(recipe.name) (ID: \(recipe.id))")
    
    // First, let's check if the recipe actually exists in the database
    let checkSQL = "SELECT COUNT(*) FROM Recipes WHERE id = ?"
    var statement: OpaquePointer?
    var recipeExists = false
    
    if sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_int(statement, 0)
            recipeExists = count > 0
            print("🔍 Recipe exists in database: \(recipeExists ? "YES" : "NO") (count: \(count))")
        }
    }
    sqlite3_finalize(statement)
    
    // Also check ingredients
    let checkIngredientsSQL = "SELECT COUNT(*) FROM RecipeIngredients WHERE recipe_id = ?"
    if sqlite3_prepare_v2(db, checkIngredientsSQL, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        if sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_int(statement, 0)
            print("🔍 Recipe has \(count) ingredients in database")
        }
    }
    sqlite3_finalize(statement)
    
    if !recipeExists {
        print("❌ Recipe doesn't exist in database, but removing from UI anyway")
        return true // Return true so UI removes it anyway
    }
    
    var success = true
    
    // Delete ingredients first
    let deleteIngredientsSQL = "DELETE FROM RecipeIngredients WHERE recipe_id = ?"
    
    if sqlite3_prepare_v2(db, deleteIngredientsSQL, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        let result = sqlite3_step(statement)
        if result != SQLITE_DONE {
            print("❌ Failed to delete recipe ingredients: \(String(cString: sqlite3_errmsg(db)))")
            success = false
        } else {
            let deletedIngredients = sqlite3_changes(db)
            print("🗑️ Deleted \(deletedIngredients) recipe ingredients")
        }
    } else {
        print("❌ Failed to prepare ingredients deletion statement: \(String(cString: sqlite3_errmsg(db)))")
        success = false
    }
    sqlite3_finalize(statement)
    
    // Delete recipe
    let deleteRecipeSQL = "DELETE FROM Recipes WHERE id = ?"
    if sqlite3_prepare_v2(db, deleteRecipeSQL, -1, &statement, nil) == SQLITE_OK {
        sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        let result = sqlite3_step(statement)
        if result != SQLITE_DONE {
            print("❌ Failed to delete recipe: \(String(cString: sqlite3_errmsg(db)))")
            success = false
        } else {
            let deletedRecipes = sqlite3_changes(db)
            print("🗑️ Deleted \(deletedRecipes) recipe(s)")
            if deletedRecipes == 0 {
                print("⚠️ Warning: No recipe was deleted. Recipe may not exist in database.")
                // Still return success since we want UI to remove the stale entry
                success = true
            }
        }
    } else {
        print("❌ Failed to prepare recipe deletion statement: \(String(cString: sqlite3_errmsg(db)))")
        success = false
    }
    sqlite3_finalize(statement)
    
    return success
}

// Clean up any orphaned or duplicate recipes
func cleanupRecipesDatabase() {
    operationQueue.addOperation {
        print("🧹 Starting recipe database cleanup...")
        
        // Find recipes without ingredients
        let orphanedRecipesSQL = """
            SELECT r.id, r.name FROM Recipes r 
            LEFT JOIN RecipeIngredients ri ON r.id = ri.recipe_id 
            WHERE ri.recipe_id IS NULL
        """
        
        var statement: OpaquePointer?
        var orphanedRecipes: [(String, String)] = []
        
        if sqlite3_prepare_v2(self.db, orphanedRecipesSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let idString = sqlite3_column_text(statement, 0),
                   let nameString = sqlite3_column_text(statement, 1) {
                    let id = String(cString: idString)
                    let name = String(cString: nameString)
                    orphanedRecipes.append((id, name))
                }
            }
        }
        sqlite3_finalize(statement)
        
        print("🔍 Found \(orphanedRecipes.count) recipes without ingredients")
        
        // Find duplicate recipe names (same name, different IDs)
        let duplicatesSQL = """
            SELECT name, COUNT(*) as count FROM Recipes 
            GROUP BY LOWER(name) 
            HAVING count > 1
        """
        
        if sqlite3_prepare_v2(self.db, duplicatesSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let nameString = sqlite3_column_text(statement, 0) {
                    let name = String(cString: nameString)
                    let count = sqlite3_column_int(statement, 1)
                    print("🔍 Found \(count) recipes with name: \(name)")
                }
            }
        }
        sqlite3_finalize(statement)
        
        print("✅ Recipe database cleanup completed")
    }
}

// Find all recipes with the same name (potential duplicates)
func findDuplicateRecipes(completion: @escaping ([(String, [Recipe])]) -> Void) {
    operationQueue.addOperation {
        let allRecipes = self.getRecipes()
        var duplicateGroups: [String: [Recipe]] = [:]
        
        for recipe in allRecipes {
            let normalizedName = recipe.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if duplicateGroups[normalizedName] == nil {
                duplicateGroups[normalizedName] = []
            }
            duplicateGroups[normalizedName]?.append(recipe)
        }
        
        let duplicates = duplicateGroups.filter { $0.value.count > 1 }
        let result = duplicates.map { ($0.key, $0.value) }
        
        DispatchQueue.main.async {
            completion(result)
        }
    }
}

func fixRecipeSchema() {
    operationQueue.addOperation {
        let recipes = self.getRecipes()
        
        if recipes.isEmpty {
            let querySQL = "SELECT COUNT(*) FROM Recipes"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_ROW {
                    let count = sqlite3_column_int(statement, 0)
                    
                    if count > 0 {
                        return
                    }
                }
            }
            sqlite3_finalize(statement)
        }
    }
}

func recreateRecipesTable() {
    operationQueue.addOperation {
        let existingRecipes = self.getRecipes()
        
        sqlite3_exec(self.db, "DROP TABLE IF EXISTS RecipeIngredients", nil, nil, nil)
        sqlite3_exec(self.db, "DROP TABLE IF EXISTS Recipes", nil, nil, nil)
        
        self.createRecipesTable()
        self.createRecipeIngredientsTable()
        
        for recipe in existingRecipes {
            self.saveRecipe(recipe)
        }
    }
}
}
