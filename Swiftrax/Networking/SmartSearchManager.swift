import Foundation

class SmartSearchManager {
    static let shared = SmartSearchManager()
    
    private init() {}
    
    func searchFood(_ query: String) async -> [Food] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTrailingSpace = query.hasSuffix(" ") && !trimmedQuery.isEmpty
        
        print("🔍 Smart Search: '\(query)' (trailing space: \(hasTrailingSpace))")
        
        // Step 1: Search local database first (includes basic foods and custom foods)
        let localResults = await searchLocalDatabase(trimmedQuery, allowExpansion: hasTrailingSpace)
        
        if localResults.count >= 5 {
            print("✅ Found \(localResults.count) local results, stopping here")
            return localResults
        }
        
        // Step 2: If insufficient local results, search OpenFoodFacts
        print("🔍 Only \(localResults.count) local results, searching OpenFoodFacts...")
        let apiResults = await searchOpenFoodFacts(trimmedQuery)
        
        // Combine results, prioritizing local ones
        let combinedResults = (localResults + apiResults).removingDuplicates()
        
        if combinedResults.count >= 8 {
            print("✅ Found \(combinedResults.count) combined results")
            return Array(combinedResults.prefix(15))
        }
        
        // Step 3: If still insufficient, try broader OpenFoodFacts search
        if combinedResults.count < 5 {
            print("🔍 Still only \(combinedResults.count) results, trying broader search...")
            let broaderResults = await searchOpenFoodFactsBroader(trimmedQuery)
            let finalResults = (combinedResults + broaderResults).removingDuplicates()
            return Array(finalResults.prefix(15))
        }
        
        return combinedResults
    }
    
    // MARK: - Step 1: Local Database Search
    private func searchLocalDatabase(_ query: String, allowExpansion: Bool) async -> [Food] {
        return await withCheckedContinuation { continuation in
            DatabaseManager.shared.searchFoodsWithFuzzyMatching(query: query, limit: 25) { foods in
                let filteredFoods = self.filterLocalResults(foods, query: query, allowExpansion: allowExpansion)
                continuation.resume(returning: filteredFoods)
            }
        }
    }
    
   private func filterLocalResults(_ foods: [Food], query: String, allowExpansion: Bool) -> [Food] {
       let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
       
       let filtered = foods.filter { food in
           let foodWords = food.name.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
           
           if !allowExpansion {
               // Strict mode: food name should be close to query
               return isStrictLocalMatch(foodWords: foodWords, queryWords: queryWords)
           } else {
               // Expansion mode: first words must match, but can have more words
               return isExpansionMatch(foodWords: foodWords, queryWords: queryWords)
           }
       }
       
       // Remove duplicates BEFORE sorting
       let uniqueFiltered = filtered.removingDuplicates()
       
       return uniqueFiltered.sorted { food1, food2 in
           let score1 = calculateLocalScore(food1, query: query)
           let score2 = calculateLocalScore(food2, query: query)
           return score1 > score2
       }
   }
    
    private func isStrictLocalMatch(foodWords: [String], queryWords: [String]) -> Bool {
        // For single word queries, prefer basic foods
        if queryWords.count == 1 {
            let queryWord = queryWords[0]
            
            // Must contain the query word
            guard foodWords.contains(where: { $0.contains(queryWord) || queryWord.contains($0) }) else {
                return false
            }
            
            // Prefer shorter, simpler names
            return foodWords.count <= 3
        }
        
        // For multi-word queries, check if first words match
        return firstWordsMatch(foodWords: foodWords, queryWords: queryWords)
    }
    
    private func isExpansionMatch(foodWords: [String], queryWords: [String]) -> Bool {
        return firstWordsMatch(foodWords: foodWords, queryWords: queryWords)
    }
    
    private func firstWordsMatch(foodWords: [String], queryWords: [String]) -> Bool {
        guard !foodWords.isEmpty && !queryWords.isEmpty else { return false }
        
        for (index, queryWord) in queryWords.enumerated() {
            guard index < foodWords.count else { return false }
            
            let foodWord = foodWords[index]
            if !wordsAreSimilar(foodWord, queryWord) {
                return false
            }
        }
        
        return true
    }
    
    private func wordsAreSimilar(_ word1: String, _ word2: String) -> Bool {
        // Exact match
        if word1 == word2 { return true }
        
        // One contains the other (handles plurals)
        if word1.contains(word2) || word2.contains(word1) { return true }
        
        // Handle common variations
        let variations: [String: [String]] = [
            "egg": ["eggs", "egg"],
            "banana": ["bananas", "banana"],
            "apple": ["apples", "apple"],
            "chicken": ["chickens", "chicken"],
            "beef": ["beef", "beefs"],
            "potato": ["potatoes", "potato"],
            "tomato": ["tomatoes", "tomato"]
        ]
        
        for (base, vars) in variations {
            if vars.contains(word1) && vars.contains(word2) {
                return true
            }
        }
        
        return false
    }
    
    private func calculateLocalScore(_ food: Food, query: String) -> Int {
        let nameLower = food.name.lowercased()
        let queryLower = query.lowercased()
        var score = 0
        
        // Huge bonus for exact matches
        if nameLower == queryLower { score += 2000 }
        
        // Big bonus for basic foods
        if food.source == "BasicFoods" { score += 1000 }
        
        // Bonus for custom foods
        if food.source == "manual" { score += 500 }
        
        // Bonus for simple names
        let wordCount = nameLower.components(separatedBy: " ").count
        if wordCount == 1 { score += 800 }
        else if wordCount == 2 { score += 400 }
        else if wordCount >= 4 { score -= 100 }
        
        // Bonus for starting with query
        if nameLower.hasPrefix(queryLower) { score += 600 }
        
        // Bonus for containing query as whole word
        if nameLower.contains(" \(queryLower) ") || nameLower.hasPrefix("\(queryLower) ") || nameLower.hasSuffix(" \(queryLower)") {
            score += 400
        }
        
        // Bonus for reasonable calories
        let calories = food.nutritionInfo.calories ?? 0
        if calories > 0 && calories < 600 { score += 100 }
        else if calories > 1000 { score -= 100 }
        
        return score
    }
    
    // MARK: - Step 2: OpenFoodFacts Search
   private func searchOpenFoodFacts(_ query: String) async -> [Food] {
       do {
           let foods = try await OpenFoodFactsAPI.searchByText(query, pageSize: 20, using: APIManager.shared)
           
           // Filter, validate, and enhance OpenFoodFacts results
           let filteredFoods = filterOpenFoodFactsResults(foods, query: query)
           
           // Validate nutrition data to prevent NaN errors
           let validatedFoods = filteredFoods.map { validateNutritionData($0) }
           
           // Save good results to database for future use
           for food in validatedFoods.prefix(5) {
               DatabaseManager.shared.saveFoodThreadSafe(food) { _ in }
           }
           
           return validatedFoods
       } catch {
           print("❌ OpenFoodFacts search failed: \(error)")
           return []
       }
   }
    
    private func searchOpenFoodFactsBroader(_ query: String) async -> [Food] {
        // Try variations of the query
        let queryVariations = generateQueryVariations(query)
        var allResults: [Food] = []
        
        for variation in queryVariations.prefix(3) {
            let results = await searchOpenFoodFacts(variation)
            allResults.append(contentsOf: results)
            
            if allResults.count >= 10 { break }
        }
        
        return allResults.removingDuplicates()
    }
    
    private func generateQueryVariations(_ query: String) -> [String] {
        var variations: [String] = []
        
        // Add singular/plural variations
        if query.hasSuffix("s") {
            variations.append(String(query.dropLast()))
        } else {
            variations.append(query + "s")
        }
        
        // Add common food variations
        let commonVariations: [String: [String]] = [
            "chicken": ["chicken breast", "chicken thigh", "poultry"],
            "beef": ["ground beef", "beef steak", "meat"],
            "apple": ["apple fruit", "apples"],
            "banana": ["banana fruit", "bananas"],
            "egg": ["eggs", "chicken egg"],
            "milk": ["dairy milk", "cow milk"],
            "cheese": ["dairy cheese", "cheddar"],
            "bread": ["wheat bread", "white bread"],
            "rice": ["white rice", "brown rice"],
            "pasta": ["wheat pasta", "noodles"]
        ]
        
        let queryLower = query.lowercased()
        for (key, vars) in commonVariations {
            if queryLower.contains(key) {
                variations.append(contentsOf: vars)
            }
        }
        
        return variations
    }
    
    private func filterOpenFoodFactsResults(_ foods: [Food], query: String) -> [Food] {
        return foods.filter { food in
            // Basic quality filters
            let hasValidNutrition = (food.nutritionInfo.calories ?? 0) > 0
            let hasValidServing = food.servingSize > 0 && food.servingSize <= 2000
            let hasValidName = food.name.count >= 3
            
            // Not too processed (reasonable word count)
            let wordCount = food.name.components(separatedBy: .whitespacesAndNewlines).count
            let notTooProcessed = wordCount <= 8
            
            return hasValidNutrition && hasValidServing && hasValidName && notTooProcessed
        }
        .sorted { food1, food2 in
            let score1 = calculateOpenFoodFactsScore(food1, query: query)
            let score2 = calculateOpenFoodFactsScore(food2, query: query)
            return score1 > score2
        }
    }
    
    private func calculateOpenFoodFactsScore(_ food: Food, query: String) -> Int {
        let nameLower = food.name.lowercased()
        let queryLower = query.lowercased()
        var score = 0
        
        // Exact match
        if nameLower == queryLower { score += 1000 }
        
        // Starts with query
        if nameLower.hasPrefix(queryLower) { score += 500 }
        
        // Contains query
        if nameLower.contains(queryLower) { score += 200 }
        
        // Prefer simpler names
        let wordCount = nameLower.components(separatedBy: " ").count
        if wordCount <= 3 { score += 300 }
        else if wordCount <= 5 { score += 100 }
        else if wordCount > 7 { score -= 200 }
        
        // Reasonable calories
        let calories = food.nutritionInfo.calories ?? 0
        if calories > 10 && calories < 800 { score += 100 }
        else if calories > 1000 { score -= 100 }
        
        // Standard serving size bonus
        if food.servingSize == 100 { score += 50 }
        
        return score
    }
    
    // MARK: - Validation
    private func isValidFood(_ food: Food) -> Bool {
        let calories = food.nutritionInfo.calories ?? 0
        
        // Basic validation
        if calories <= 0 || calories > 5000 { return false }
        if food.servingSize <= 0 || food.servingSize > 10000 { return false }
        if food.name.count < 2 { return false }
        
        // Check for reasonable nutrition values
        let protein = food.nutritionInfo.protein ?? 0
        let carbs = food.nutritionInfo.carbohydrates ?? 0
        let fat = food.nutritionInfo.fat ?? 0
        
        // Rough calorie calculation check (protein and carbs = 4 cal/g, fat = 9 cal/g)
        let calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9)
        
        // Allow some variance in calorie calculations
        if calculatedCalories > 0 && abs(calories - calculatedCalories) > (calories * 0.5) {
            return false
        }
        
        return true
    }
   
   private func validateNutritionData(_ food: Food) -> Food {
       var validatedFood = food
       
       // Fix any NaN or infinite values in nutrition data
       var validatedNutrition = food.nutritionInfo
       
       // Helper function to validate a Double value
       func validateDouble(_ value: Double?) -> Double? {
           guard let value = value else { return nil }
           if value.isNaN || value.isInfinite || value < 0 {
               return nil
           }
           return value
       }
       
       validatedNutrition.calories = validateDouble(validatedNutrition.calories)
       validatedNutrition.protein = validateDouble(validatedNutrition.protein)
       validatedNutrition.carbohydrates = validateDouble(validatedNutrition.carbohydrates)
       validatedNutrition.fat = validateDouble(validatedNutrition.fat)
       validatedNutrition.fiber = validateDouble(validatedNutrition.fiber)
       validatedNutrition.sugar = validateDouble(validatedNutrition.sugar)
       validatedNutrition.sodium = validateDouble(validatedNutrition.sodium)
       validatedNutrition.cholesterol = validateDouble(validatedNutrition.cholesterol)
       validatedNutrition.saturatedFat = validateDouble(validatedNutrition.saturatedFat)
       validatedNutrition.transFat = validateDouble(validatedNutrition.transFat)
       validatedNutrition.calcium = validateDouble(validatedNutrition.calcium)
       validatedNutrition.iron = validateDouble(validatedNutrition.iron)
       validatedNutrition.vitaminA = validateDouble(validatedNutrition.vitaminA)
       validatedNutrition.vitaminC = validateDouble(validatedNutrition.vitaminC)
       
       // Also validate serving size
       if validatedFood.servingSize.isNaN || validatedFood.servingSize.isInfinite || validatedFood.servingSize <= 0 {
           validatedFood.servingSize = 100 // Default to 100g
       }
       
       validatedFood.nutritionInfo = validatedNutrition
       return validatedFood
   }
}

// MARK: - Helper Extension
extension Array where Element == Food {
    func removingDuplicates() -> [Food] {
        var seen = Set<String>()
        return filter { food in
            // Create a more specific key that includes source to avoid removing different source foods
            let key = "\(food.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))-\(food.servingSize)-\(food.servingSizeUnit.lowercased())-\(food.source)"
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}
