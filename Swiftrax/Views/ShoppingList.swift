import Foundation

// MARK: - Shopping List Models

struct ShoppingList: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [ShoppingListItem]
    var dateCreated: Date
    var dateModified: Date
    var isCompleted: Bool
    
    init(name: String, items: [ShoppingListItem] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
        self.dateCreated = Date()
        self.dateModified = Date()
        self.isCompleted = false
    }
    
    // Database initializer
    init(id: UUID, name: String, items: [ShoppingListItem], dateCreated: Date, dateModified: Date, isCompleted: Bool) {
        self.id = id
        self.name = name
        self.items = items
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.isCompleted = isCompleted
    }
    
    // Computed properties
    var totalItems: Int {
        items.count
    }
    
    var completedItems: Int {
        items.filter { $0.isCompleted }.count
    }
    
    var progressPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }
    
    var incompletedItems: [ShoppingListItem] {
        items.filter { !$0.isCompleted }
    }
    
    var completedItemsList: [ShoppingListItem] {
        items.filter { $0.isCompleted }
    }
    
    // Update modified date
    mutating func updateModifiedDate() {
        dateModified = Date()
    }
}

struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: MeasurementUnit
    var category: ShoppingCategory
    var isCompleted: Bool
    var notes: String?
    var recipeId: UUID? // Reference to recipe if this item came from a recipe
    var recipeNames: [String] // List of recipe names this ingredient appears in
    
    init(name: String, quantity: Double, unit: MeasurementUnit, category: ShoppingCategory = .other, notes: String? = nil, recipeId: UUID? = nil, recipeNames: [String] = []) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.isCompleted = false
        self.notes = notes
        self.recipeId = recipeId
        self.recipeNames = recipeNames
    }
    
    // Database initializer
    init(id: UUID, name: String, quantity: Double, unit: MeasurementUnit, category: ShoppingCategory, isCompleted: Bool, notes: String?, recipeId: UUID?, recipeNames: [String]) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.isCompleted = isCompleted
        self.notes = notes
        self.recipeId = recipeId
        self.recipeNames = recipeNames
    }
    
    var displayText: String {
        return "\(quantity.formattedNutrition) \(unit.abbreviation) \(name)"
    }
    
    static func == (lhs: ShoppingListItem, rhs: ShoppingListItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Shopping Categories
enum ShoppingCategory: String, CaseIterable, Codable {
    case produce = "Produce"
    case dairy = "Dairy"
    case meat = "Meat & Seafood"
    case pantry = "Pantry"
    case frozen = "Frozen"
    case bakery = "Bakery"
    case beverages = "Beverages"
    case snacks = "Snacks"
    case condiments = "Condiments & Sauces"
    case spices = "Spices & Seasonings"
    case canned = "Canned Goods"
    case grains = "Grains & Cereals"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .produce: return "🥬"
        case .dairy: return "🥛"
        case .meat: return "🥩"
        case .pantry: return "🏺"
        case .frozen: return "🧊"
        case .bakery: return "🍞"
        case .beverages: return "🥤"
        case .snacks: return "🍿"
        case .condiments: return "🍯"
        case .spices: return "🌿"
        case .canned: return "🥫"
        case .grains: return "🌾"
        case .other: return "🛒"
        }
    }
    
    var color: String {
        switch self {
        case .produce: return "green"
        case .dairy: return "blue"
        case .meat: return "red"
        case .pantry: return "brown"
        case .frozen: return "cyan"
        case .bakery: return "orange"
        case .beverages: return "purple"
        case .snacks: return "yellow"
        case .condiments: return "indigo"
        case .spices: return "mint"
        case .canned: return "gray"
        case .grains: return "brown"
        case .other: return "gray"
        }
    }
    
    // Smart categorization based on ingredient name
    static func categorizeIngredient(_ ingredientName: String) -> ShoppingCategory {
        let name = ingredientName.lowercased()
        
        // Produce
        if name.contains("apple") || name.contains("banana") || name.contains("orange") || 
           name.contains("lettuce") || name.contains("tomato") || name.contains("onion") || 
           name.contains("garlic") || name.contains("potato") || name.contains("carrot") ||
           name.contains("spinach") || name.contains("broccoli") || name.contains("pepper") ||
           name.contains("cucumber") || name.contains("avocado") || name.contains("lemon") ||
           name.contains("lime") || name.contains("berry") || name.contains("grape") ||
           name.contains("celery") || name.contains("mushroom") || name.contains("herbs") {
            return .produce
        }
        
        // Dairy
        if name.contains("milk") || name.contains("cheese") || name.contains("yogurt") ||
           name.contains("butter") || name.contains("cream") || name.contains("sour cream") ||
           name.contains("cottage cheese") || name.contains("mozzarella") || name.contains("cheddar") {
            return .dairy
        }
        
        // Meat & Seafood
        if name.contains("chicken") || name.contains("beef") || name.contains("pork") ||
           name.contains("fish") || name.contains("salmon") || name.contains("turkey") ||
           name.contains("bacon") || name.contains("ham") || name.contains("sausage") ||
           name.contains("shrimp") || name.contains("tuna") {
            return .meat
        }
        
        // Pantry
        if name.contains("flour") || name.contains("sugar") || name.contains("oil") ||
           name.contains("vinegar") || name.contains("baking") || name.contains("vanilla") ||
           name.contains("honey") || name.contains("syrup") {
            return .pantry
        }
        
        // Spices
        if name.contains("salt") || name.contains("pepper") || name.contains("cinnamon") ||
           name.contains("paprika") || name.contains("cumin") || name.contains("oregano") ||
           name.contains("basil") || name.contains("thyme") || name.contains("rosemary") ||
           name.contains("garlic powder") || name.contains("onion powder") {
            return .spices
        }
        
        // Grains
        if name.contains("rice") || name.contains("pasta") || name.contains("bread") ||
           name.contains("cereal") || name.contains("oats") || name.contains("quinoa") ||
           name.contains("barley") || name.contains("noodles") {
            return .grains
        }
        
        // Canned goods
        if name.contains("canned") || name.contains("can of") || name.contains("beans") ||
           name.contains("corn") || name.contains("sauce") || name.contains("tomatoes") {
            return .canned
        }
        
        // Frozen
        if name.contains("frozen") {
            return .frozen
        }
        
        return .other
    }
}

// MARK: - Shopping List Creation from Recipes
struct RecipeShoppingListGenerator {
    
    // Generate shopping list from selected recipes
    static func generateShoppingList(from recipes: [Recipe], servingMultipliers: [UUID: Double] = [:]) -> [ShoppingListItem] {
        var consolidatedItems: [String: ShoppingListItem] = [:]
        
        for recipe in recipes {
            let multiplier = servingMultipliers[recipe.id] ?? 1.0
            
            for ingredient in recipe.ingredients {
                let adjustedQuantity = ingredient.quantity * multiplier
                let itemKey = "\(ingredient.food.name.lowercased())_\(ingredient.unit.rawValue)"
                
                if var existingItem = consolidatedItems[itemKey] {
                    // Combine quantities if same ingredient and unit
                    existingItem.quantity += adjustedQuantity
                    existingItem.recipeNames.append(recipe.name)
                    consolidatedItems[itemKey] = existingItem
                } else {
                    // Create new shopping list item
                    let category = ShoppingCategory.categorizeIngredient(ingredient.food.name)
                    let recipeNames = [recipe.name]
                    
                    let item = ShoppingListItem(
                        name: ingredient.food.name,
                        quantity: adjustedQuantity,
                        unit: ingredient.unit,
                        category: category,
                        notes: recipeNames.count > 1 ? "For: \(recipeNames.joined(separator: ", "))" : "For: \(recipe.name)",
                        recipeId: recipe.id,
                        recipeNames: recipeNames
                    )
                    consolidatedItems[itemKey] = item
                }
            }
        }
        
        return Array(consolidatedItems.values).sorted { $0.category.rawValue < $1.category.rawValue }
    }
}