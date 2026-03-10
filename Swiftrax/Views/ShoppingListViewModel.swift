import Foundation
import Combine

class ShoppingListViewModel: ObservableObject {
    @Published var shoppingLists: [ShoppingList] = []
    @Published var isLoading = false
    
    static let shared = ShoppingListViewModel()
    private let databaseManager = DatabaseManager.shared
    
    // Load all shopping lists from database
    func loadShoppingLists() {
        isLoading = true
        print("Loading shopping lists from database")
        
        // For now, we'll use UserDefaults as a simple storage solution
        // You can later integrate this with your DatabaseManager
        loadShoppingListsFromUserDefaults()
    }
    
    // Save shopping list to storage
    func saveShoppingList(_ shoppingList: ShoppingList) {
        print("Saving shopping list: \(shoppingList.name)")
        
        // Add or update in local array
        if let index = shoppingLists.firstIndex(where: { $0.id == shoppingList.id }) {
            shoppingLists[index] = shoppingList
        } else {
            shoppingLists.insert(shoppingList, at: 0)
        }
        
        // Save to persistent storage
        saveShoppingListsToUserDefaults()
        
        print("Shopping list saved successfully")
    }
    
    // Update existing shopping list
    func updateShoppingList(_ updatedList: ShoppingList) {
        print("Updating shopping list: \(updatedList.name)")
        
        if let index = shoppingLists.firstIndex(where: { $0.id == updatedList.id }) {
            shoppingLists[index] = updatedList
            saveShoppingListsToUserDefaults()
            print("Shopping list updated successfully")
        } else {
            print("Shopping list not found for update, adding as new")
            saveShoppingList(updatedList)
        }
    }
    
    // Delete shopping list
    func deleteShoppingList(_ shoppingList: ShoppingList) {
        print("Deleting shopping list: \(shoppingList.name)")
        
        shoppingLists.removeAll { $0.id == shoppingList.id }
        saveShoppingListsToUserDefaults()
        
        print("Shopping list deleted successfully")
    }
    
    // MARK: - UserDefaults Storage (temporary solution)
    private func saveShoppingListsToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(shoppingLists)
            UserDefaults.standard.set(data, forKey: "SavedShoppingLists")
            print("Shopping lists saved to UserDefaults")
        } catch {
            print("Error saving shopping lists: \(error)")
        }
    }
    
    private func loadShoppingListsFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "SavedShoppingLists") else {
            print("No saved shopping lists found")
            isLoading = false
            return
        }
        
        do {
            let lists = try JSONDecoder().decode([ShoppingList].self, from: data)
            DispatchQueue.main.async {
                self.shoppingLists = lists.sorted { $0.dateModified > $1.dateModified }
                self.isLoading = false
                print("Loaded \(lists.count) shopping lists from UserDefaults")
            }
        } catch {
            print("Error loading shopping lists: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - Database Integration Methods
    // These methods can be implemented later to integrate with your existing DatabaseManager
    
    func saveShoppingListToDatabase(_ shoppingList: ShoppingList, completion: @escaping () -> Void) {
        // TODO: Implement database storage
        // This would involve adding shopping list tables to your SQLite database
        // For now, we'll stick with UserDefaults
        completion()
    }
    
    func loadShoppingListsFromDatabase(completion: @escaping ([ShoppingList]) -> Void) {
        // TODO: Implement database loading
        // This would query your shopping list tables from SQLite
        completion([])
    }
    
    func deleteShoppingListFromDatabase(_ shoppingList: ShoppingList, completion: @escaping () -> Void) {
        // TODO: Implement database deletion
        completion()
    }
    
    // MARK: - Helper Methods
    
    // Get shopping lists that are not completed
    var activeShoppingLists: [ShoppingList] {
        return shoppingLists.filter { !$0.isCompleted }
    }
    
    // Get shopping lists that are completed
    var completedShoppingLists: [ShoppingList] {
        return shoppingLists.filter { $0.isCompleted }
    }
    
    // Get total number of items across all active lists
    var totalActiveItems: Int {
        return activeShoppingLists.reduce(0) { $0 + $1.totalItems }
    }
    
    // Get total number of completed items across all active lists
    var totalCompletedItems: Int {
        return activeShoppingLists.reduce(0) { $0 + $1.completedItems }
    }
    
    // Create a quick shopping list from a single recipe
    func createQuickShoppingList(from recipe: Recipe, servingMultiplier: Double = 1.0) -> ShoppingList {
        let items = RecipeShoppingListGenerator.generateShoppingList(
            from: [recipe],
            servingMultipliers: [recipe.id: servingMultiplier]
        )
        
        let listName = "Shopping for \(recipe.name)"
        return ShoppingList(name: listName, items: items)
    }
    
    // Merge multiple shopping lists into one
    func mergeShoppingLists(_ lists: [ShoppingList], newName: String) -> ShoppingList {
        var consolidatedItems: [String: ShoppingListItem] = [:]
        
        for list in lists {
            for item in list.items {
                let itemKey = "\(item.name.lowercased())_\(item.unit.rawValue)"
                
                if var existingItem = consolidatedItems[itemKey] {
                    // Combine quantities if same ingredient and unit
                    existingItem.quantity += item.quantity
                    existingItem.recipeNames.append(contentsOf: item.recipeNames)
                    consolidatedItems[itemKey] = existingItem
                } else {
                    consolidatedItems[itemKey] = item
                }
            }
        }
        
        let mergedItems = Array(consolidatedItems.values).sorted { $0.category.rawValue < $1.category.rawValue }
        return ShoppingList(name: newName, items: mergedItems)
    }
    
    // Clean up old completed shopping lists
    func cleanupOldLists(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        shoppingLists.removeAll { list in
            list.isCompleted && list.dateModified < cutoffDate
        }
        
        saveShoppingListsToUserDefaults()
        print("Cleaned up old shopping lists")
    }
}

// MARK: - Extensions for easier use
extension ShoppingListViewModel {
    // Quick access methods for SwiftUI views
    func getShoppingList(by id: UUID) -> ShoppingList? {
        return shoppingLists.first { $0.id == id }
    }
    
    func hasActiveShoppingLists() -> Bool {
        return !activeShoppingLists.isEmpty
    }
    
    func getShoppingListsCount() -> Int {
        return shoppingLists.count
    }
}