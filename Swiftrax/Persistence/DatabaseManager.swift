import Foundation
import SQLite3

class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    private let dbName = "swiftrax.db"
    private let operationQueue = OperationQueue()
    
    private init() {
        operationQueue.maxConcurrentOperationCount = 1 // Serialize database operations
        operationQueue.qualityOfService = .userInitiated
        
        Swift.print("🗄️ DatabaseManager initializing...")
        openDatabase()
        createTables()
        configureDatabase()
        migrateForAPISupport()
        Swift.print("🗄️ DatabaseManager initialization complete")
    }
    
    deinit {
        closeDatabase()
    }
    
    private func configureDatabase() {
        // Enable Write-Ahead Logging (WAL) mode for better concurrency
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        
        // Enable foreign keys
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        
        // Set busy timeout to handle concurrent access
        sqlite3_busy_timeout(db, 30000) // 30 seconds
        
        Swift.print("✅ Database configured for thread safety")
    }
    
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(dbName)
        
        Swift.print("🗄️ Database path: \(fileURL.path)")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            Swift.print("❌ Unable to open database")
        } else {
            Swift.print("✅ Database opened successfully")
        }
    }
    
    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            Swift.print("❌ Unable to close database")
        } else {
            Swift.print("✅ Database closed successfully")
        }
    }
    
    private func createTables() {
        Swift.print("🗄️ Creating database tables...")
        createFoodsTable()
        createFoodEntriesTable()
        createMealsTable()
        createMealItemsTable()
        createUserSettingsTable()
        createRecipesTable()
        createRecipeIngredientsTable()
        updateFoodsTableForRecipes()
        Swift.print("🗄️ Finished creating tables")
    }
    
    // MARK: - API Support Migration
    private func migrateForAPISupport() {
        Swift.print("🗄️ Migrating database for API support...")
        
        // Add new columns for API support
        let alterQueries = [
            "ALTER TABLE Foods ADD COLUMN source TEXT DEFAULT 'manual'",
            "ALTER TABLE Foods ADD COLUMN last_updated TEXT"
        ]
        
        for query in alterQueries {
            sqlite3_exec(db, query, nil, nil, nil) // Will fail silently if column already exists
        }
        
        // Create indexes for API features
        let indexQueries = [
            "CREATE INDEX IF NOT EXISTS idx_barcode ON Foods(barcode)",
            "CREATE INDEX IF NOT EXISTS idx_source ON Foods(source)",
            "CREATE INDEX IF NOT EXISTS idx_last_updated ON Foods(last_updated)"
        ]
        
        for query in indexQueries {
            if sqlite3_exec(db, query, nil, nil, nil) == SQLITE_OK {
                Swift.print("✅ Created index successfully")
            }
        }
        
        Swift.print("✅ API support migration completed")
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
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            Swift.print("❌ Error creating Foods table")
        } else {
            Swift.print("✅ Foods table created successfully")
        }
    }
    
    private func updateFoodsTableForRecipes() {
        // Add recipe columns if they don't exist (for existing databases)
        let alterSQL1 = "ALTER TABLE Foods ADD COLUMN recipe_id TEXT"
        sqlite3_exec(db, alterSQL1, nil, nil, nil) // Ignore errors if column exists
        
        let alterSQL2 = "ALTER TABLE Foods ADD COLUMN is_recipe INTEGER DEFAULT 0"
        sqlite3_exec(db, alterSQL2, nil, nil, nil) // Ignore errors if column exists
        
        let alterSQL3 = "ALTER TABLE Foods ADD COLUMN source TEXT DEFAULT 'manual'"
        sqlite3_exec(db, alterSQL3, nil, nil, nil) // Ignore errors if column exists
        
        let alterSQL4 = "ALTER TABLE Foods ADD COLUMN last_updated TEXT"
        sqlite3_exec(db, alterSQL4, nil, nil, nil) // Ignore errors if column exists
        
        Swift.print("✅ Foods table updated for recipe and API support")
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
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            Swift.print("❌ Error creating Recipes table")
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ SQL Error: \(errmsg)")
        } else {
            Swift.print("✅ Recipes table created successfully")
        }
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
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            Swift.print("❌ Error creating RecipeIngredients table")
        } else {
            Swift.print("✅ RecipeIngredients table created successfully")
        }
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
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            Swift.print("❌ Error creating FoodEntries table")
        } else {
            Swift.print("✅ FoodEntries table created successfully")
        }
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
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            Swift.print("❌ Error creating Meals table")
        } else {
            Swift.print("✅ Meals table created successfully")
        }
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
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            Swift.print("❌ Error creating MealItems table")
        } else {
            Swift.print("✅ MealItems table created successfully")
        }
    }
    
    private func createUserSettingsTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS UserSettings(
                id INTEGER PRIMARY KEY,
                settings_data TEXT NOT NULL
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            Swift.print("❌ Error creating UserSettings table")
        } else {
            Swift.print("✅ UserSettings table created successfully")
        }
    }
    
    // MARK: - Thread-Safe Public Interface (ONLY use these methods)
    
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
            Swift.print("🗄️ DatabaseManager: Getting all entries from \(startDate) to \(endDate)")
            
            var allEntries: [FoodEntry] = []
            var currentDate = startDate
            let calendar = Calendar.current
            
            while currentDate <= endDate {
                let dayEntries = self.getFoodEntriesSync(for: currentDate)
                allEntries.append(contentsOf: dayEntries)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
            }
            
            Swift.print("🗄️ DatabaseManager: Found \(allEntries.count) total entries")
            
            DispatchQueue.main.async {
                completion(allEntries)
            }
        }
    }
    
    func saveFoodThreadSafe(_ food: Food, completion: @escaping (Bool) -> Void = { _ in }) {
        operationQueue.addOperation {
            let success = self.saveFoodSync(food)
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
    
    // MARK: - Enhanced Search with Fuzzy Matching
    func searchFoodsWithFuzzyMatching(query: String, limit: Int = 20, completion: @escaping ([Food]) -> Void) {
        operationQueue.addOperation {
            var allResults: [Food] = []
            
            // 1. Exact matches first
            let exactResults = self.performExactSearch(query: query, limit: limit/4)
            allResults.append(contentsOf: exactResults)
            
            // 2. Starts with matches
            if allResults.count < limit {
                let startsWithResults = self.performStartsWithSearch(query: query, limit: limit/4)
                    .filter { food in !allResults.contains { $0.id == food.id } }
                allResults.append(contentsOf: startsWithResults)
            }
            
            // 3. Contains matches
            if allResults.count < limit {
                let containsResults = self.performContainsSearch(query: query, limit: limit/2)
                    .filter { food in !allResults.contains { $0.id == food.id } }
                allResults.append(contentsOf: containsResults)
            }
            
            // 4. Fuzzy matches (split terms)
            if allResults.count < limit {
                let fuzzyResults = self.performFuzzySearch(query: query, limit: limit)
                    .filter { food in !allResults.contains { $0.id == food.id } }
                allResults.append(contentsOf: fuzzyResults)
            }
            
            Swift.print("🔍 Found \(allResults.count) local results for '\(query)'")
            
            // 5. API search if needed
            if allResults.count < 5 {
                Task {
                    do {
                        let apiResults = try await APIManager.shared.searchByText(query)
                        Swift.print("🌐 Found \(apiResults.count) API results")
                        
                        // Save API results
                        for food in apiResults {
                            self.operationQueue.addOperation {
                                _ = self.saveFoodSync(food)
                            }
                        }
                        
                        // Filter duplicates
                        let newResults = apiResults.filter { apiFood in
                            !allResults.contains { localFood in
                                self.areFoodsSimilar(apiFood, localFood)
                            }
                        }
                        
                        allResults.append(contentsOf: newResults)
                        
                        DispatchQueue.main.async {
                            completion(allResults)
                        }
                    } catch {
                        Swift.print("❌ API search failed: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            completion(allResults)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(allResults)
                }
            }
        }
    }
    
    // MARK: - API Integration Methods
    func getFoodByBarcode(_ barcode: String, completion: @escaping (Food?) -> Void) {
        Swift.print("🔍 DatabaseManager: Starting barcode lookup for: \(barcode)")
        
        operationQueue.addOperation {
            // First check local database
            if let localFood = self.getFoodByBarcodeSync(barcode) {
                Swift.print("🗄️ Found food locally: \(localFood.name) (Source: \(localFood.source))")
                DispatchQueue.main.async {
                    completion(localFood)
                }
                return
            }
            
            // If not found locally, search OpenFoodFacts API
            Swift.print("🌐 Barcode not found locally, searching OpenFoodFacts API for: \(barcode)")
            Task {
                do {
                    if let apiFood = try await APIManager.shared.searchByBarcode(barcode) {
                        Swift.print("🌐 ✅ Found food via OpenFoodFacts API: \(apiFood.name)")
                        
                        // Save to database using thread-safe method
                        self.operationQueue.addOperation {
                            let saveSuccess = self.saveFoodSync(apiFood)
                            Swift.print("💾 Save to database: \(saveSuccess ? "SUCCESS" : "FAILED")")
                            
                            DispatchQueue.main.async {
                                completion(apiFood)
                            }
                        }
                    } else {
                        Swift.print("🌐 ❌ Food not found in OpenFoodFacts API for barcode: \(barcode)")
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                } catch {
                    Swift.print("❌ OpenFoodFacts API search failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    func debugBarcodeLookup(_ barcode: String) {
        Swift.print("🧪 DEBUG: Testing barcode lookup for: \(barcode)")
        
        // Check local database first
        operationQueue.addOperation {
            if let localFood = self.getFoodByBarcodeSync(barcode) {
                Swift.print("🧪 Found in local DB: \(localFood.name)")
            } else {
                Swift.print("🧪 Not found in local DB")
                
                // Check how many foods with barcodes we have
                let querySQL = "SELECT COUNT(*) FROM Foods WHERE barcode IS NOT NULL AND barcode != ''"
                var statement: OpaquePointer?
                if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
                    if sqlite3_step(statement) == SQLITE_ROW {
                        let count = sqlite3_column_int(statement, 0)
                        Swift.print("🧪 Database has \(count) foods with barcodes")
                    }
                }
                sqlite3_finalize(statement)
            }
        }
    }
    
    // MARK: - User Settings Operations
    func saveUserSettingsAsync(_ user: User, completion: @escaping () -> Void = {}) {
        operationQueue.addOperation {
            self.saveUserSettings(user)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    func saveUserSettings(_ user: User) {
        Swift.print("🗄️ Attempting to save user settings")
        
        let insertSQL = "INSERT OR REPLACE INTO UserSettings (id, settings_data) VALUES (1, ?)"
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            do {
                let encoder = JSONEncoder()
                let settingsData = try encoder.encode(user)
                guard let settingsString = String(data: settingsData, encoding: .utf8) else {
                    Swift.print("❌ Error converting user settings to string")
                    sqlite3_finalize(statement)
                    return
                }
                
                sqlite3_bind_text(statement, 1, settingsString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    Swift.print("✅ User settings saved successfully")
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    Swift.print("❌ Error saving user settings: \(errmsg)")
                }
            } catch {
                Swift.print("❌ Error encoding user settings: \(error)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error preparing save user settings statement: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
    }
    
    func getUserSettings() -> User {
        Swift.print("🗄️ Getting user settings")
        
        let querySQL = "SELECT settings_data FROM UserSettings WHERE id = 1"
        var statement: OpaquePointer?
        var user = User()
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                if let settingsString = sqlite3_column_text(statement, 0) {
                    guard let settingsData = String(cString: settingsString).data(using: .utf8) else {
                        Swift.print("❌ Error converting settings string to data")
                        sqlite3_finalize(statement)
                        return user
                    }
                    let decoder = JSONDecoder()
                    if let decodedUser = try? decoder.decode(User.self, from: settingsData) {
                        user = decodedUser
                        Swift.print("✅ User settings loaded successfully")
                    } else {
                        Swift.print("❌ Error decoding user settings")
                    }
                } else {
                    Swift.print("🗄️ No user settings found, using defaults")
                }
            } else {
                Swift.print("🗄️ No user settings row found, using defaults")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error preparing get user settings query: \(errmsg)")
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
    
    // MARK: - Legacy Method Compatibility (Safe Wrappers)
    
    func saveFood(_ food: Food) {
        saveFoodThreadSafe(food) { _ in }
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
    
    func saveFoodAsync(_ food: Food, completion: @escaping () -> Void = {}) {
        saveFoodThreadSafe(food) { _ in
            completion()
        }
    }
    
    func saveFoodEntryAsync(_ entry: FoodEntry, completion: @escaping () -> Void = {}) {
        saveFoodEntryThreadSafe(entry) { _ in
            completion()
        }
    }
    
    // MARK: - Private Sync Methods (Internal use only)
    
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
    
    private func saveFoodSync(_ food: Food) -> Bool {
        let insertSQL = "INSERT OR REPLACE INTO Foods (id, name, barcode, nutrition_info, serving_size, serving_size_unit, brand, is_custom, date_added, recipe_id, is_recipe, source, last_updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            do {
                let encoder = JSONEncoder()
                let nutritionData = try encoder.encode(food.nutritionInfo)
                guard let nutritionString = String(data: nutritionData, encoding: .utf8) else {
                    Swift.print("❌ Error converting nutrition data to string")
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
                    Swift.print("✅ Food saved successfully: \(food.name)")
                    success = true
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    Swift.print("❌ Error saving food: \(errmsg)")
                }
            } catch {
                Swift.print("❌ Error encoding nutrition info: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        return success
    }
    
    private func saveFoodEntrySync(_ entry: FoodEntry) -> Bool {
        let insertSQL = "INSERT INTO FoodEntries (id, food_data, quantity, meal_type, date_logged, notes) VALUES (?, ?, ?, ?, ?, ?)"
        
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            do {
                let encoder = JSONEncoder()
                let foodData = try encoder.encode(entry.food)
                guard let foodString = String(data: foodData, encoding: .utf8) else {
                    Swift.print("❌ Error converting food data to string")
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
                    Swift.print("✅ Food entry saved successfully: \(entry.food.name)")
                    success = true
                } else {
                    let errmsg = String(cString: sqlite3_errmsg(db))
                    Swift.print("❌ Error saving food entry: \(errmsg)")
                }
            } catch {
                Swift.print("❌ Error encoding food data: \(error)")
            }
        }
        
        sqlite3_finalize(statement)
        return success
    }
    
    private func deleteEntrySync(_ entry: FoodEntry) -> Bool {
        Swift.print("🗄️ DatabaseManager: Deleting entry: \(entry.id)")
        
        let deleteSQL = "DELETE FROM FoodEntries WHERE id = ?"
        var statement: OpaquePointer?
        var success = false
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, entry.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                Swift.print("✅ Entry deleted successfully: \(entry.id)")
                success = true
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db))
                Swift.print("❌ Error deleting entry: \(errmsg)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error preparing delete statement: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
        return success
    }
    
    private func getRecentFoodsSync(limit: Int) -> [Food] {
        Swift.print("🗄️ Getting recent foods (limit: \(limit))")
        
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
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error preparing recent foods query: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
        return foods
    }
    
    private func searchFoodsSync(query: String, limit: Int) -> [Food] {
        Swift.print("🔍 Searching foods with query: '\(query)'")
        
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
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error preparing search query: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
        return foods
    }
    
    private func getFoodByBarcodeSync(_ barcode: String) -> Food? {
        Swift.print("🗄️ Looking up food by barcode: \(barcode)")
        
        let querySQL = "SELECT * FROM Foods WHERE barcode = ?"
        var statement: OpaquePointer?
        var food: Food?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, barcode, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                food = createFoodFromRow(statement: statement!)
                if let foundFood = food {
                    Swift.print("✅ Found food by barcode: \(foundFood.name)")
                }
            } else {
                Swift.print("🗄️ No food found with barcode: \(barcode)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error preparing barcode query: \(errmsg)")
        }
        
        sqlite3_finalize(statement)
        return food
    }
    
    // MARK: - Search Implementations
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
    
    private func executeFoodSearch(sql: String, params: [String], limit: Int) -> [Food] {
        var foods: [Food] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            // Bind parameters
            for (index, param) in params.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), param, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            
            // Bind limit
            sqlite3_bind_int(statement, Int32(params.count + 1), Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let food = createFoodFromRow(statement: statement!) {
                    foods.append(food)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return foods
    }
    
    private func areFoodsSimilar(_ food1: Food, _ food2: Food) -> Bool {
        // Check if foods are similar to avoid duplicates
        if let barcode1 = food1.barcode, let barcode2 = food2.barcode {
            return barcode1 == barcode2
        }
        
        let charactersToRemove = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let name1 = food1.name.lowercased().trimmingCharacters(in: charactersToRemove)
        let name2 = food2.name.lowercased().trimmingCharacters(in: charactersToRemove)
        
        return name1 == name2 || levenshteinDistance(name1, name2) < 3
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count { matrix[i][0] = i }
        for j in 0...b.count { matrix[0][j] = j }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(matrix[i-1][j], matrix[i][j-1], matrix[i-1][j-1]) + 1
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
    
    private func createFoodFromRow(statement: OpaquePointer) -> Food? {
        guard let idString = sqlite3_column_text(statement, 0),
              let nameString = sqlite3_column_text(statement, 1),
              let nutritionString = sqlite3_column_text(statement, 3),
              let servingSizeUnitString = sqlite3_column_text(statement, 5),
              let dateString = sqlite3_column_text(statement, 8) else {
            Swift.print("❌ Missing required column data when creating food from row")
            return nil
        }
        
        let id = String(cString: idString)
        let name = String(cString: nameString)
        let barcode = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)!) : nil
        
        let nutritionJsonString = String(cString: nutritionString)
        
        guard let nutritionData = nutritionJsonString.data(using: .utf8) else {
            Swift.print("❌ Error converting nutrition string to data for food: \(name)")
            return nil
        }
        
        let servingSize = sqlite3_column_double(statement, 4)
        let servingSizeUnit = String(cString: servingSizeUnitString)
        let brand = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)!) : nil
        let isCustom = sqlite3_column_int(statement, 7) == 1
        
        // Recipe support (handle missing columns gracefully)
        var recipeId: UUID? = nil
        if sqlite3_column_count(statement) > 9 && sqlite3_column_text(statement, 9) != nil {
            let recipeIdString = String(cString: sqlite3_column_text(statement, 9)!)
            recipeId = UUID(uuidString: recipeIdString)
        }
        
        // API support (handle missing columns gracefully)
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
            Swift.print("❌ Error decoding nutrition info for food: \(name) - Error: \(error)")
            return nil
        }
    }
    
    private func createFoodEntryFromRow(statement: OpaquePointer) -> FoodEntry? {
        guard let idData = sqlite3_column_text(statement, 0),
              let foodData = sqlite3_column_text(statement, 1),
              let mealTypeData = sqlite3_column_text(statement, 3),
              let dateData = sqlite3_column_text(statement, 4) else {
            Swift.print("🗄️ Database: Missing required column data")
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
            Swift.print("🗄️ Database: Invalid meal type: \(mealTypeString)")
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        guard let dateLogged = formatter.date(from: dateString) else {
            Swift.print("🗄️ Database: Invalid date format: \(dateString)")
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
            Swift.print("🗄️ Database: Error decoding food JSON: \(error)")
            return nil
        }
    }
    
    // MARK: - Database Cleanup
    func cleanupCorruptedEntries() {
        Swift.print("🧹 Cleaning up corrupted database entries...")
        
        let cleanupFoodsSQL = "DELETE FROM Foods WHERE name = '' OR id = '' OR nutrition_info = ''"
        if sqlite3_exec(db, cleanupFoodsSQL, nil, nil, nil) == SQLITE_OK {
            Swift.print("✅ Cleaned up corrupted Foods entries")
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error cleaning Foods: \(errmsg)")
        }
        
        let cleanupEntriesSQL = "DELETE FROM FoodEntries WHERE id = '' OR food_data = ''"
        if sqlite3_exec(db, cleanupEntriesSQL, nil, nil, nil) == SQLITE_OK {
            Swift.print("✅ Cleaned up corrupted FoodEntries")
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error cleaning FoodEntries: \(errmsg)")
        }
        
        Swift.print("🧹 Database cleanup complete!")
    }
    
    func clearAllData() {
        Swift.print("🗑️ Clearing all database data...")
        
        let tables = ["FoodEntries", "Foods", "Meals", "MealItems", "UserSettings", "RecipeIngredients", "Recipes"]
        
        for table in tables {
            let deleteSQL = "DELETE FROM \(table)"
            if sqlite3_exec(db, deleteSQL, nil, nil, nil) == SQLITE_OK {
                Swift.print("✅ Cleared \(table) table")
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db))
                Swift.print("❌ Error clearing \(table): \(errmsg)")
            }
        }
        
        Swift.print("🗑️ Database cleared!")
    }
    
    // MARK: - Debug and Testing Methods
    func testDatabaseConnection() {
        operationQueue.addOperation {
            Swift.print("🗄️ Testing database connection...")
            let foods = self.searchFoodsSync(query: "test", limit: 1)
            Swift.print("🗄️ Database test: found \(foods.count) items")
            
            let recipes = self.getRecipes()
            Swift.print("🗄️ Database test: found \(recipes.count) recipes")
        }
    }
}

// MARK: - Recipe Operations
extension DatabaseManager {
   
   func saveRecipeAsync(_ recipe: Recipe, completion: @escaping () -> Void = {}) {
      operationQueue.addOperation {
         self.saveRecipe(recipe)
         DispatchQueue.main.async {
            completion()
         }
      }
   }
   
   func saveRecipe(_ recipe: Recipe) {
      Swift.print("🗄️ Attempting to save recipe: \(recipe.name)")
      
      // Insert recipe
      let insertRecipeSQL = "INSERT OR REPLACE INTO Recipes (id, name, servings, date_created) VALUES (?, ?, ?, ?)"
      
      var statement: OpaquePointer?
      
      if sqlite3_prepare_v2(db, insertRecipeSQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_bind_text(statement, 2, recipe.name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_bind_int(statement, 3, Int32(recipe.servings))
         
         let formatter = ISO8601DateFormatter()
         let dateString = formatter.string(from: recipe.dateCreated)
         sqlite3_bind_text(statement, 4, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         
         if sqlite3_step(statement) == SQLITE_DONE {
            Swift.print("✅ Recipe saved successfully: \(recipe.name)")
            
            // Save ingredients
            saveRecipeIngredients(recipe.ingredients, recipeId: recipe.id)
            
         } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error saving recipe: \(errmsg)")
         }
      } else {
         let errmsg = String(cString: sqlite3_errmsg(db))
         Swift.print("❌ Error preparing save recipe statement: \(errmsg)")
      }
      
      sqlite3_finalize(statement)
   }
   
   private func saveRecipeIngredients(_ ingredients: [RecipeIngredient], recipeId: UUID) {
      // Delete existing ingredients for this recipe
      let deleteSQL = "DELETE FROM RecipeIngredients WHERE recipe_id = ?"
      var deleteStatement: OpaquePointer?
      
      if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
         sqlite3_bind_text(deleteStatement, 1, recipeId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_step(deleteStatement)
      }
      sqlite3_finalize(deleteStatement)
      
      // Insert new ingredients
      let insertSQL = "INSERT INTO RecipeIngredients (id, recipe_id, food_data, quantity) VALUES (?, ?, ?, ?)"
      
      for ingredient in ingredients {
         var statement: OpaquePointer?
         
         if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            do {
               let encoder = JSONEncoder()
               let foodData = try encoder.encode(ingredient.food)
               guard let foodString = String(data: foodData, encoding: .utf8) else {
                  Swift.print("❌ Error converting ingredient food data to string")
                  sqlite3_finalize(statement)
                  continue
               }
               
               sqlite3_bind_text(statement, 1, ingredient.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
               sqlite3_bind_text(statement, 2, recipeId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
               sqlite3_bind_text(statement, 3, foodString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
               sqlite3_bind_double(statement, 4, ingredient.quantity)
               
               if sqlite3_step(statement) == SQLITE_DONE {
                  Swift.print("✅ Ingredient saved: \(ingredient.food.name)")
               } else {
                  let errmsg = String(cString: sqlite3_errmsg(db))
                  Swift.print("❌ Error saving ingredient: \(errmsg)")
               }
            } catch {
               Swift.print("❌ Error encoding ingredient food data: \(error)")
            }
         }
         sqlite3_finalize(statement)
      }
   }
   
   func getRecipesAsync(completion: @escaping ([Recipe]) -> Void) {
      operationQueue.addOperation {
         let recipes = self.getRecipes()
         DispatchQueue.main.async {
            completion(recipes)
         }
      }
   }
   
   func getRecipes() -> [Recipe] {
      Swift.print("🗄️ Loading recipes from database")
      
      let querySQL = "SELECT * FROM Recipes ORDER BY date_created DESC"
      var statement: OpaquePointer?
      var recipes: [Recipe] = []
      
      if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
         while sqlite3_step(statement) == SQLITE_ROW {
            if let recipe = createRecipeFromRow(statement: statement!) {
               recipes.append(recipe)
               Swift.print("🗄️ Found recipe: \(recipe.name)")
            }
         }
      } else {
         let errmsg = String(cString: sqlite3_errmsg(db))
         Swift.print("❌ Error preparing get recipes query: \(errmsg)")
      }
      
      sqlite3_finalize(statement)
      Swift.print("🗄️ Returning \(recipes.count) recipes")
      return recipes
   }
   
   private func createRecipeFromRow(statement: OpaquePointer) -> Recipe? {
      let columnCount = sqlite3_column_count(statement)
      Swift.print("🗄️ Recipe row has \(columnCount) columns")
      
      let dateColumnIndex: Int32
      if columnCount == 4 {
         dateColumnIndex = 3
      } else if columnCount == 7 {
         dateColumnIndex = 6
      } else {
         Swift.print("❌ Unexpected column count: \(columnCount)")
         return nil
      }
      
      guard let idString = sqlite3_column_text(statement, 0),
            let nameString = sqlite3_column_text(statement, 1),
            let dateString = sqlite3_column_text(statement, dateColumnIndex) else {
         Swift.print("❌ Missing required recipe column data")
         return nil
      }
      
      let idStr = String(cString: idString)
      let name = String(cString: nameString)
      let servings = Int(sqlite3_column_int(statement, 2))
      let dateStr = String(cString: dateString)
      
      Swift.print("🗄️ Creating recipe: ID=\(idStr), Name=\(name), Servings=\(servings)")
      
      guard let id = UUID(uuidString: idStr) else {
         Swift.print("❌ Invalid UUID: \(idStr)")
         return nil
      }
      
      let formatter = ISO8601DateFormatter()
      let dateCreated = formatter.date(from: dateStr) ?? Date()
      
      let ingredients = getIngredientsForRecipe(recipeId: id)
      Swift.print("🗄️ Loaded \(ingredients.count) ingredients for recipe: \(name)")
      
      return Recipe(
         name: name,
         servings: servings,
         ingredients: ingredients
      )
   }
   
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
      } else {
         let errmsg = String(cString: sqlite3_errmsg(db))
         Swift.print("❌ Error preparing get ingredients query: \(errmsg)")
      }
      
      sqlite3_finalize(statement)
      return ingredients
   }
   
   private func createIngredientFromRow(statement: OpaquePointer) -> RecipeIngredient? {
      guard let idString = sqlite3_column_text(statement, 0),
            let foodData = sqlite3_column_text(statement, 2) else {
         Swift.print("❌ Missing required ingredient column data")
         return nil
      }
      
      let id = UUID(uuidString: String(cString: idString)) ?? UUID()
      let quantity = sqlite3_column_double(statement, 3)
      
      let foodDataLength = sqlite3_column_bytes(statement, 2)
      let foodJsonData = Data(bytes: foodData, count: Int(foodDataLength))
      
      do {
         let decoder = JSONDecoder()
         let food = try decoder.decode(Food.self, from: foodJsonData)
         
         return RecipeIngredient(food: food, quantity: quantity)
      } catch {
         Swift.print("❌ Error decoding ingredient food JSON: \(error)")
         return nil
      }
   }
   
   func deleteRecipeAsync(_ recipe: Recipe, completion: @escaping () -> Void = {}) {
      operationQueue.addOperation {
         self.deleteRecipe(recipe)
         DispatchQueue.main.async {
            completion()
         }
      }
   }
   
   func deleteRecipe(_ recipe: Recipe) {
      Swift.print("🗄️ Deleting recipe: \(recipe.name)")
      
      let deleteIngredientsSQL = "DELETE FROM RecipeIngredients WHERE recipe_id = ?"
      var statement: OpaquePointer?
      
      if sqlite3_prepare_v2(db, deleteIngredientsSQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         sqlite3_step(statement)
      }
      sqlite3_finalize(statement)
      
      let deleteRecipeSQL = "DELETE FROM Recipes WHERE id = ?"
      if sqlite3_prepare_v2(db, deleteRecipeSQL, -1, &statement, nil) == SQLITE_OK {
         sqlite3_bind_text(statement, 1, recipe.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
         
         if sqlite3_step(statement) == SQLITE_DONE {
            Swift.print("✅ Recipe deleted successfully: \(recipe.name)")
         } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            Swift.print("❌ Error deleting recipe: \(errmsg)")
         }
      }
      sqlite3_finalize(statement)
   }
   
   func fixRecipeSchema() {
      operationQueue.addOperation {
         Swift.print("🔧 Fixing recipe schema without data loss...")
         
         let recipes = self.getRecipes()
         
         if recipes.isEmpty {
            let querySQL = "SELECT COUNT(*) FROM Recipes"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
               if sqlite3_step(statement) == SQLITE_ROW {
                  let count = sqlite3_column_int(statement, 0)
                  Swift.print("🔧 Found \(count) recipes in database that aren't being read correctly")
                  
                  if count > 0 {
                     Swift.print("🔧 Schema mismatch detected - recipes exist but can't be read")
                     return
                  }
               }
            }
            sqlite3_finalize(statement)
         }
         
         Swift.print("✅ Recipe schema is working correctly")
      }
   }
   
   func debugRecipes() {
      operationQueue.addOperation {
         Swift.print("🗄️ === DEBUG RECIPES ===")
         let recipes = self.getRecipes()
         Swift.print("🗄️ Total recipes in database: \(recipes.count)")
         for recipe in recipes {
            Swift.print("🗄️ Recipe: \(recipe.name), servings: \(recipe.servings), ingredients: \(recipe.ingredients.count)")
         }
         
         Swift.print("🗄️ === RAW DATABASE CHECK ===")
         let querySQL = "SELECT * FROM Recipes"
         var statement: OpaquePointer?
         
         if sqlite3_prepare_v2(self.db, querySQL, -1, &statement, nil) == SQLITE_OK {
            var rowCount = 0
            while sqlite3_step(statement) == SQLITE_ROW {
               rowCount += 1
               Swift.print("🗄️ Raw Row \(rowCount):")
               let columnCount = sqlite3_column_count(statement)
               for i in 0..<columnCount {
                  let columnName = String(cString: sqlite3_column_name(statement, i))
                  if let columnText = sqlite3_column_text(statement, i) {
                     let value = String(cString: columnText)
                     Swift.print("🗄️   \(columnName): \(value)")
                  } else {
                     Swift.print("🗄️   \(columnName): NULL")
                  }
               }
            }
            Swift.print("🗄️ Total raw rows: \(rowCount)")
         } else {
            let errmsg = String(cString: sqlite3_errmsg(self.db))
            Swift.print("❌ Error querying recipes: \(errmsg)")
         }
         sqlite3_finalize(statement)
         
         Swift.print("🗄️ === END DEBUG ===")
      }
   }
   
   func recreateRecipesTable() {
      operationQueue.addOperation {
         Swift.print("🗄️ Recreating recipes table...")
         
         let existingRecipes = self.getRecipes()
         Swift.print("🗄️ Backing up \(existingRecipes.count) existing recipes")
         
         sqlite3_exec(self.db, "DROP TABLE IF EXISTS RecipeIngredients", nil, nil, nil)
         sqlite3_exec(self.db, "DROP TABLE IF EXISTS Recipes", nil, nil, nil)
         
         self.createRecipesTable()
         self.createRecipeIngredientsTable()
         
         for recipe in existingRecipes {
            Swift.print("🗄️ Restoring recipe: \(recipe.name)")
            self.saveRecipe(recipe)
         }
         
         Swift.print("✅ Recipes table recreated with \(existingRecipes.count) recipes restored")
      }
   }
}
