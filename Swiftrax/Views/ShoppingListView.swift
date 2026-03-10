import SwiftUI

struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel.shared
    @State private var showingCreateList = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading shopping lists...")
                        Spacer()
                    }
                } else if viewModel.shoppingLists.isEmpty {
                    // Empty state
                    EmptyShoppingListsView {
                        showingCreateList = true
                    }
                } else {
                    // Lists content
                    List {
                        Section("My Lists") {
                            ForEach(viewModel.shoppingLists) { shoppingList in
                                ShoppingListRowView(
                                    shoppingList: shoppingList,
                                    onDelete: {
                                        viewModel.deleteShoppingList(shoppingList)
                                    }
                                )
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Shopping Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                viewModel.loadShoppingLists()
            }
        }
        .sheet(isPresented: $showingCreateList) {
            CombinedCreateShoppingListView()
        }
    }
}

// MARK: - Empty State View
struct EmptyShoppingListsView: View {
    let onCreateManual: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Shopping Lists")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first shopping list to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                Button {
                    onCreateManual()
                } label: {
                    Label("Create Manual List", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    onCreateManual()
                } label: {
                    Label("Create from Recipes", systemImage: "book.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Shopping List Row
struct ShoppingListRowView: View {
    @ObservedObject private var viewModel = ShoppingListViewModel.shared
    let shoppingList: ShoppingList
    let onDelete: () -> Void
    @State private var showingDetail = false
    
    private var isCompleted: Bool {
        shoppingList.totalItems > 0 && shoppingList.completedItems == shoppingList.totalItems
    }
    
    var body: some View {
        Button(action: {
            if !isCompleted {
                showingDetail = true
            }
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(shoppingList.name)
                            .font(.headline)
                            .strikethrough(isCompleted)
                            .foregroundColor(isCompleted ? .secondary : .primary)
                        
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(shoppingList.completedItems)/\(shoppingList.totalItems) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if shoppingList.totalItems > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(shoppingList.progressPercentage * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isCompleted {
                        HStack(spacing: 12) {
                            Button(action: {
                                print("Reuse button tapped for list: \(shoppingList.name)")
                                // Reuse list - mark all as incomplete
                                var updatedItems = shoppingList.items
                                for index in updatedItems.indices {
                                    updatedItems[index].isCompleted = false
                                }
                                let updatedList = ShoppingList(
                                    id: shoppingList.id,
                                    name: shoppingList.name,
                                    items: updatedItems,
                                    dateCreated: shoppingList.dateCreated,
                                    dateModified: Date(),
                                    isCompleted: false
                                )
                                viewModel.updateShoppingList(updatedList)
                            }) {
                                Label("Reuse", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                print("Delete button tapped for list: \(shoppingList.name)")
                                onDelete()
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                if shoppingList.totalItems > 0 {
                    CircularProgressView(
                        progress: shoppingList.progressPercentage,
                        lineWidth: 3,
                        size: 40
                    )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            if !isCompleted {
                Button {
                    onDelete()
                } label: {
                    Label("Delete List", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            ShoppingListDetailView(shoppingList: shoppingList)
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(progress: Double, lineWidth: CGFloat = 3, size: CGFloat = 40) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress == 1.0 ? Color.green : Color.blue, lineWidth: lineWidth)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            if progress == 1.0 {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.bold)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Create Manual Shopping List View  
struct CreateManualShoppingListView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var listName = ""
    @State private var items: [ShoppingListItem] = []
    @State private var showingAddItem = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Items")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            showingAddItem = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    
                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cart")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            
                            Text("No items added yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button {
                                showingAddItem = true
                            } label: {
                                Text("Add First Item")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        List {
                            ForEach(items) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Text("\(item.quantity.formattedNutrition) \(item.unit.abbreviation)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onDelete(perform: deleteItem)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                
                Spacer()
                
                Button {
                    createList()
                } label: {
                    Text("Create List")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canCreate ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canCreate)
                .padding(.horizontal)
            }
            .navigationTitle("New Manual List")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddShoppingItemView { item in
                items.append(item)
            }
        }
    }
    
    private var canCreate: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !items.isEmpty
    }
    
    private func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    private func createList() {
        guard canCreate else { return }
        
        let newList = ShoppingList(name: listName.trimmingCharacters(in: .whitespacesAndNewlines), items: items)
        ShoppingListViewModel.shared.saveShoppingList(newList)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Create Shopping List From Recipes View
struct CreateShoppingListFromRecipesView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var recipesViewModel = RecipesViewModel()
    @State private var listName = ""
    @State private var selectedRecipes: Set<UUID> = []
    @State private var servingMultipliers: [UUID: Double] = [:]
    @State private var searchText = ""
    
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipesViewModel.recipes
        } else {
            return recipesViewModel.recipes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Recipes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search recipes...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    if filteredRecipes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            
                            Text("No recipes available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Create some recipes first to generate shopping lists from them")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        List {
                            ForEach(filteredRecipes) { recipe in
                                RecipeSelectionRow(
                                    recipe: recipe,
                                    isSelected: selectedRecipes.contains(recipe.id),
                                    servingMultiplier: servingMultipliers[recipe.id] ?? 1.0,
                                    onToggle: {
                                        if selectedRecipes.contains(recipe.id) {
                                            selectedRecipes.remove(recipe.id)
                                            servingMultipliers.removeValue(forKey: recipe.id)
                                        } else {
                                            selectedRecipes.insert(recipe.id)
                                            servingMultipliers[recipe.id] = 1.0
                                        }
                                    },
                                    onServingChange: { multiplier in
                                        servingMultipliers[recipe.id] = multiplier
                                    }
                                )
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                
                Spacer()
                
                Button {
                    createList()
                } label: {
                    Text("Create Shopping List")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canCreate ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!canCreate)
                .padding(.horizontal)
            }
            .navigationTitle("From Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            recipesViewModel.loadRecipes()
            if listName.isEmpty {
                listName = "Recipe Shopping List"
            }
        }
    }
    
    private var canCreate: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedRecipes.isEmpty
    }
    
    private func createList() {
        guard canCreate else { return }
        
        let selectedRecipeObjects = recipesViewModel.recipes.filter { selectedRecipes.contains($0.id) }
        let items = RecipeShoppingListGenerator.generateShoppingList(
            from: selectedRecipeObjects,
            servingMultipliers: servingMultipliers
        )
        
        let newList = ShoppingList(name: listName.trimmingCharacters(in: .whitespacesAndNewlines), items: items)
        ShoppingListViewModel.shared.saveShoppingList(newList)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Recipe Selection Row
struct RecipeSelectionRow: View {
    let recipe: Recipe
    let isSelected: Bool
    let servingMultiplier: Double
    let onToggle: () -> Void
    let onServingChange: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.body)
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    Text("\(recipe.ingredients.count) ingredients • \(recipe.servings) servings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if isSelected {
                HStack {
                    Text("Servings:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Stepper(
                        value: Binding(
                            get: { servingMultiplier },
                            set: { onServingChange($0) }
                        ),
                        in: 0.5...10,
                        step: 0.5
                    ) {
                        Text("\(servingMultiplier, specifier: "%.1f")x")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Add Shopping Item View
struct AddShoppingItemView: View {
    @Environment(\.presentationMode) var presentationMode
    let onAdd: (ShoppingListItem) -> Void
    
    @State private var itemName = ""
    @State private var quantity = ""
    @State private var selectedUnit: MeasurementUnit = .pieces
    @State private var selectedCategory: ShoppingCategory = .other
    @State private var showingFoodSearch = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $itemName)
                    
                    HStack {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                                Text(unit.abbreviation).tag(unit)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ShoppingCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: "circle")
                                .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section {
                    Button("Search Foods") {
                        showingFoodSearch = true
                    }
                }
                
                Section {
                    Button("Add Item") {
                        addItem()
                    }
                    .disabled(!canAdd)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingFoodSearch) {
            // Food search integration would go here
            Text("Food search coming soon")
        }
    }
    
    private var canAdd: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(quantity) != nil
    }
    
    private func addItem() {
        guard canAdd, let quantityValue = Double(quantity) else { return }
        
        let item = ShoppingListItem(
            name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantityValue,
            unit: selectedUnit,
            category: selectedCategory
        )
        
        onAdd(item)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Combined Create Shopping List View
struct CombinedCreateShoppingListView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    @State private var listName = ""
    @State private var showingNameInput = false
    @State private var showingAddItem = false
    
    // Manual items
    @State private var manualItems: [ShoppingListItem] = []
    
    // Recipe-based items  
    @State private var selectedRecipes: [UUID: Double] = [:]
    @StateObject private var recipesViewModel = RecipesViewModel()
    
    private var combinedItems: [ShoppingListItem] {
        var items = manualItems
        
        // Add items from selected recipes
        for (recipeId, multiplier) in selectedRecipes {
            if let recipe = recipesViewModel.recipes.first(where: { $0.id == recipeId }) {
                let recipeItems = recipe.ingredients.map { ingredient in
                    ShoppingListItem(
                        name: ingredient.food.name,
                        quantity: ingredient.quantity * multiplier,
                        unit: ingredient.unit,
                        category: .other // Default category since Food doesn't have category
                    )
                }
                items.append(contentsOf: recipeItems)
            }
        }
        
        return items
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Creation Method", selection: $selectedTab) {
                    Text("Manual").tag(0)
                    Text("From Recipes").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    // Manual tab
                    VStack {
                        if manualItems.isEmpty {
                            VStack(spacing: 16) {
                                Spacer()
                                
                                Image(systemName: "list.bullet")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                
                                Text("No items yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Tap the + button to add items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(manualItems) { item in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(item.name)
                                                .font(.body)
                                            Text("\(item.quantity, specifier: "%.1f") \(item.unit.abbreviation)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                                .onDelete(perform: deleteManualItems)
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingAddItem = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                    .tag(0)
                    
                    // Recipe tab
                    VStack {
                        if recipesViewModel.recipes.isEmpty {
                            VStack(spacing: 16) {
                                Spacer()
                                
                                Image(systemName: "book")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                
                                Text("No recipes available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Create some recipes first")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(recipesViewModel.recipes) { recipe in
                                    RecipeSelectionRow(
                                        recipe: recipe,
                                        isSelected: selectedRecipes.contains(where: { $0.key == recipe.id }),
                                        servingMultiplier: selectedRecipes[recipe.id] ?? 1.0,
                                        onToggle: {
                                            if selectedRecipes[recipe.id] != nil {
                                                selectedRecipes.removeValue(forKey: recipe.id)
                                            } else {
                                                selectedRecipes[recipe.id] = 1.0
                                            }
                                        },
                                        onServingChange: { multiplier in
                                            selectedRecipes[recipe.id] = multiplier
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Create button
                if !combinedItems.isEmpty {
                    VStack {
                        Divider()
                        
                        Button("Create Shopping List") {
                            showingNameInput = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
            }
            .navigationTitle("New Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                recipesViewModel.loadRecipes()
            }
            .alert("Name Your List", isPresented: $showingNameInput) {
                TextField("Shopping list name", text: $listName)
                Button("Create") {
                    createShoppingList()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for your shopping list")
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddShoppingItemView { item in
                manualItems.append(item)
            }
        }
    }
    
    private func deleteManualItems(at offsets: IndexSet) {
        manualItems.remove(atOffsets: offsets)
    }
    
    private func createShoppingList() {
        guard !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newList = ShoppingList(
            name: listName.trimmingCharacters(in: .whitespacesAndNewlines),
            items: combinedItems
        )
        
        ShoppingListViewModel.shared.saveShoppingList(newList)
        presentationMode.wrappedValue.dismiss()
    }
}