import Foundation

class BasicFoodsSeeder {
    static let shared = BasicFoodsSeeder()
    
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let hasSeededKey = "hasSeededBasicFoods"
    private let seedVersionKey = "basicFoodsSeedVersion"
    private let currentSeedVersion = 2
    
    // Seeds basic foods if not already done or if version has changed
    func seedBasicFoodsIfNeeded() {
        let hasSeeded = userDefaults.bool(forKey: hasSeededKey)
        let currentVersion = userDefaults.integer(forKey: seedVersionKey)
        
        if !hasSeeded || currentVersion < currentSeedVersion {
            print("Seeding basic foods database...")
            
            DispatchQueue.global(qos: .background).async {
                self.seedBasicFoodsWithDeduplication()
                
                DispatchQueue.main.async {
                    self.userDefaults.set(true, forKey: self.hasSeededKey)
                    self.userDefaults.set(self.currentSeedVersion, forKey: self.seedVersionKey)
                    print("Basic foods seeding completed")
                }
            }
        }
    }
    
    // Forces a complete reseed of basic foods
    func forceReseed() {
        userDefaults.set(false, forKey: hasSeededKey)
        userDefaults.set(0, forKey: seedVersionKey)
        
        DatabaseManager.shared.cleanupDuplicatesAsync { cleanedCount in
            if cleanedCount > 0 {
                print("Cleaned up \(cleanedCount) duplicates before reseeding")
            }
            self.seedBasicFoodsIfNeeded()
        }
    }
    
    // Seeds basic foods with duplicate prevention
    private func seedBasicFoodsWithDeduplication() {
        let basicFoods = createBasicFoodsData()
        let dispatchGroup = DispatchGroup()
        var successCount = 0
        var errorCount = 0
        
        for food in basicFoods {
            dispatchGroup.enter()
            
            DatabaseManager.shared.saveFoodThreadSafe(food) { success in
                if success {
                    successCount += 1
                } else {
                    errorCount += 1
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.wait()
        
        print("Basic foods seeded: \(successCount) successful, \(errorCount) errors")
    }
    
    // Checks if foods are similar enough to be considered duplicates for seeding
    private func areFoodsSimilarForSeeding(_ food1: Food, _ food2: Food) -> Bool {
        let name1 = cleanNameForComparison(food1.name)
        let name2 = cleanNameForComparison(food2.name)
        
        let namesMatch = name1 == name2 ||
                        (name1.contains(name2) && name1.count - name2.count <= 2) ||
                        (name2.contains(name1) && name2.count - name1.count <= 2)
        
        if !namesMatch { return false }
        
        let unit1 = MeasurementUnit(rawValue: food1.servingSizeUnit) ?? .grams
        let unit2 = MeasurementUnit(rawValue: food2.servingSizeUnit) ?? .grams
        
        if unit1.category != unit2.category { return false }
        
        let bothBasic = (food1.source == "BasicFoods" || food1.source == "manual") &&
                       (food2.source == "BasicFoods" || food2.source == "manual")
        
        return bothBasic
    }
    
    // Normalizes food names for comparison by removing common descriptors
    private func cleanNameForComparison(_ name: String) -> String {
        var cleaned = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let removeWords = ["the", "a", "an", "fresh", "raw", "cooked", "organic", "natural"]
        for word in removeWords {
            cleaned = cleaned.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: .regularExpression)
        }
        
        if cleaned.hasSuffix("s") && cleaned.count > 3 {
            let singular = String(cleaned.dropLast())
            let commonFoods = ["egg", "apple", "banana", "grape", "carrot", "almond", "walnut"]
            if commonFoods.contains(singular) {
                cleaned = singular
            }
        }
        
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Creates the complete list of basic foods with nutrition data
    private func createBasicFoodsData() -> [Food] {
        return [
            // Proteins
            createFood(name: "Chicken Breast", calories: 165, protein: 31, carbs: 0, fat: 3.6, size: 100, unit: "g"),
            createFood(name: "Ground Beef", calories: 250, protein: 26, carbs: 0, fat: 15, size: 100, unit: "g"),
            createFood(name: "Salmon", calories: 208, protein: 25, carbs: 0, fat: 12, size: 100, unit: "g"),
            createFood(name: "Eggs", calories: 155, protein: 13, carbs: 1.1, fat: 11, size: 100, unit: "g"),
            createFood(name: "Egg", calories: 70, protein: 6, carbs: 0.5, fat: 5, size: 1, unit: "piece"),
            createFood(name: "Tuna", calories: 132, protein: 28, carbs: 0, fat: 1.3, size: 100, unit: "g"),
            createFood(name: "Greek Yogurt", calories: 97, protein: 10, carbs: 3.6, fat: 0.4, size: 100, unit: "g"),
            createFood(name: "Cottage Cheese", calories: 98, protein: 11, carbs: 3.4, fat: 4.3, size: 100, unit: "g"),
            createFood(name: "Tofu", calories: 144, protein: 17, carbs: 3, fat: 9, size: 100, unit: "g"),
            
            // Carbohydrates
            createFood(name: "White Rice", calories: 130, protein: 2.7, carbs: 28, fat: 0.3, size: 100, unit: "g"),
            createFood(name: "Brown Rice", calories: 112, protein: 2.6, carbs: 23, fat: 0.9, size: 100, unit: "g"),
            createFood(name: "Quinoa", calories: 120, protein: 4.4, carbs: 22, fat: 1.9, size: 100, unit: "g"),
            createFood(name: "Oats", calories: 389, protein: 17, carbs: 66, fat: 7, size: 100, unit: "g"),
            createFood(name: "Whole Wheat Pasta", calories: 124, protein: 5, carbs: 25, fat: 1.1, size: 100, unit: "g"),
            createFood(name: "Sweet Potato", calories: 86, protein: 1.6, carbs: 20, fat: 0.1, size: 100, unit: "g"),
            createFood(name: "Potato", calories: 77, protein: 2, carbs: 17, fat: 0.1, size: 100, unit: "g"),
            createFood(name: "Bread", calories: 75, protein: 2.3, carbs: 14, fat: 1, size: 1, unit: "slice"),
            
            // Fruits
            createFood(name: "Apple", calories: 95, protein: 0.5, carbs: 25, fat: 0.3, size: 1, unit: "piece"),
            createFood(name: "Banana", calories: 105, protein: 1.3, carbs: 27, fat: 0.4, size: 1, unit: "piece"),
            createFood(name: "Orange", calories: 62, protein: 1.2, carbs: 15, fat: 0.2, size: 1, unit: "piece"),
            createFood(name: "Strawberries", calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3, size: 100, unit: "g"),
            createFood(name: "Blueberries", calories: 57, protein: 0.7, carbs: 14, fat: 0.3, size: 100, unit: "g"),
            createFood(name: "Grapes", calories: 62, protein: 0.6, carbs: 16, fat: 0.2, size: 100, unit: "g"),
            createFood(name: "Avocado", calories: 160, protein: 2, carbs: 9, fat: 15, size: 100, unit: "g"),
            
            // Vegetables
            createFood(name: "Broccoli", calories: 34, protein: 2.8, carbs: 7, fat: 0.4, size: 100, unit: "g"),
            createFood(name: "Spinach", calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, size: 100, unit: "g"),
            createFood(name: "Carrots", calories: 41, protein: 0.9, carbs: 10, fat: 0.2, size: 100, unit: "g"),
            createFood(name: "Bell Pepper", calories: 31, protein: 1, carbs: 7, fat: 0.3, size: 100, unit: "g"),
            createFood(name: "Tomatoes", calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2, size: 100, unit: "g"),
            createFood(name: "Cucumber", calories: 16, protein: 0.7, carbs: 4, fat: 0.1, size: 100, unit: "g"),
            createFood(name: "Lettuce", calories: 15, protein: 1.4, carbs: 2.9, fat: 0.2, size: 100, unit: "g"),
            
            // Dairy
            createFood(name: "Milk", calories: 42, protein: 3.4, carbs: 5, fat: 1, size: 100, unit: "ml"),
            createFood(name: "Cheddar Cheese", calories: 403, protein: 25, carbs: 1.3, fat: 33, size: 100, unit: "g"),
            createFood(name: "Mozzarella", calories: 280, protein: 28, carbs: 3.1, fat: 17, size: 100, unit: "g"),
            createFood(name: "Butter", calories: 717, protein: 0.9, carbs: 0.1, fat: 81, size: 100, unit: "g"),
            
            // Nuts and Seeds
            createFood(name: "Almonds", calories: 576, protein: 21, carbs: 22, fat: 49, size: 100, unit: "g"),
            createFood(name: "Walnuts", calories: 654, protein: 15, carbs: 14, fat: 59, size: 100, unit: "g"),
            createFood(name: "Peanuts", calories: 567, protein: 26, carbs: 16, fat: 49, size: 100, unit: "g"),
            createFood(name: "Sunflower Seeds", calories: 584, protein: 21, carbs: 20, fat: 51, size: 100, unit: "g"),
            createFood(name: "Chia Seeds", calories: 486, protein: 17, carbs: 42, fat: 31, size: 100, unit: "g"),
            
            // Legumes
            createFood(name: "Black Beans", calories: 132, protein: 8.9, carbs: 24, fat: 0.5, size: 100, unit: "g"),
            createFood(name: "Chickpeas", calories: 164, protein: 8.9, carbs: 27, fat: 2.6, size: 100, unit: "g"),
            createFood(name: "Lentils", calories: 116, protein: 9, carbs: 20, fat: 0.4, size: 100, unit: "g"),
            
            // Oils and Fats
            createFood(name: "Olive Oil", calories: 884, protein: 0, carbs: 0, fat: 100, size: 100, unit: "ml"),
            createFood(name: "Coconut Oil", calories: 862, protein: 0, carbs: 0, fat: 100, size: 100, unit: "ml"),
            
            // Condiments and Basics
            createFood(name: "Salt", calories: 0, protein: 0, carbs: 0, fat: 0, size: 1, unit: "tsp"),
            createFood(name: "Sugar", calories: 16, protein: 0, carbs: 4, fat: 0, size: 1, unit: "tsp"),
            createFood(name: "Honey", calories: 64, protein: 0.1, carbs: 17, fat: 0, size: 1, unit: "tbsp"),
            createFood(name: "Garlic", calories: 4, protein: 0.2, carbs: 1, fat: 0, size: 1, unit: "clove"),
            createFood(name: "Onion", calories: 40, protein: 1.1, carbs: 9, fat: 0.1, size: 100, unit: "g"),
            
            // Beverages
            createFood(name: "Water", calories: 0, protein: 0, carbs: 0, fat: 0, size: 1, unit: "cup"),
            createFood(name: "Black Coffee", calories: 2, protein: 0.3, carbs: 0.5, fat: 0, size: 1, unit: "cup"),
            createFood(name: "Green Tea", calories: 2, protein: 0.5, carbs: 0.5, fat: 0, size: 1, unit: "cup"),
        ]
    }
    
    // Creates a Food object with the specified nutrition values
    private func createFood(name: String, calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, size: Double, unit: String) -> Food {
        let nutritionInfo = NutritionInfo(
            calories: calories,
            protein: protein,
            carbohydrates: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium
        )
        
        var food = Food(
            name: name,
            nutritionInfo: nutritionInfo,
            servingSize: size,
            servingSizeUnit: unit,
            brand: nil,
            isCustom: false,
            source: "BasicFoods"
        )
        
        food.dateAdded = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        return food
    }
}

extension BasicFoodsSeeder {
    
    // Cleans up duplicate basic foods and reseeds if needed
    func cleanupAndReseed() {
        print("Starting database cleanup and reseed...")
        
        DatabaseManager.shared.cleanupDuplicatesAsync { cleanedCount in
            print("Cleaned up \(cleanedCount) duplicates")
            self.forceReseed()
        }
    }
    
    // Returns status information about basic foods in the database
    func checkBasicFoodsStatus(completion: @escaping (Int, Int, Int) -> Void) {
        DatabaseManager.shared.searchFoodsThreadSafe(query: "", limit: 1000) { allFoods in
            let basicFoods = allFoods.filter { $0.source == "BasicFoods" }
            let duplicateGroups = self.findDuplicateGroups(in: basicFoods)
            let totalDuplicates = duplicateGroups.reduce(0) { total, group in
                total + (group.count - 1)
            }
            
            completion(basicFoods.count, duplicateGroups.count, totalDuplicates)
        }
    }
    
    // Finds groups of duplicate foods for cleanup
    private func findDuplicateGroups(in foods: [Food]) -> [[Food]] {
        var groups: [[Food]] = []
        var processed = Set<UUID>()
        
        for food in foods {
            if processed.contains(food.id) { continue }
            
            var group = [food]
            processed.insert(food.id)
            
            for otherFood in foods {
                if otherFood.id != food.id &&
                   !processed.contains(otherFood.id) &&
                   areFoodsSimilarForSeeding(food, otherFood) {
                    group.append(otherFood)
                    processed.insert(otherFood.id)
                }
            }
            
            if group.count > 1 {
                groups.append(group)
            }
        }
        
        return groups
    }
}
