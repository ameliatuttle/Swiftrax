import SwiftUI

// MARK: - Shopping List Detail View
struct ShoppingListDetailView: View {
    @ObservedObject private var viewModel = ShoppingListViewModel.shared
    @State private var shoppingList: ShoppingList
    @State private var showingAddItem = false
    @State private var showingExportOptions = false
    @Environment(\.presentationMode) var presentationMode
    
    init(shoppingList: ShoppingList) {
        self._shoppingList = State(initialValue: shoppingList)
    }
    
    var groupedItems: [(ShoppingCategory, [ShoppingListItem])] {
        let grouped = Dictionary(grouping: shoppingList.items) { $0.category }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }.map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress header
                if shoppingList.totalItems > 0 {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(shoppingList.completedItems) of \(shoppingList.totalItems) items")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(shoppingList.progressPercentage == 1.0 ? "Shopping completed!" : "Keep going!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            CircularProgressView(progress: shoppingList.progressPercentage)
                                .frame(width: 50, height: 50)
                        }
                        
                        ProgressView(value: shoppingList.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: shoppingList.progressPercentage == 1.0 ? .green : .blue))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                }
                
                // Items list
                List {
                    ForEach(groupedItems, id: \.0) { category, items in
                        Section(header: CategoryHeader(category: category)) {
                            ForEach(items) { item in
                                ShoppingListItemRow(
                                    item: item,
                                    onToggle: { toggleItemCompletion(item) },
                                    onDelete: { deleteItem(item) }
                                )
                            }
                        }
                    }
                    
                    // Add item button at bottom
                    Section {
                        Button {
                            showingAddItem = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Add Item")
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle(shoppingList.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingExportOptions = true
                        } label: {
                            Label("Export List", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { clearCompletedItems() }) {
                            Label("Clear Completed", systemImage: "checkmark.circle")
                        }
                        .disabled(shoppingList.completedItems == 0)
                        
                        Button {
                            markAllAsCompleted()
                        } label: {
                            Label("Mark All Complete", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(shoppingList.completedItems == shoppingList.totalItems)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddShoppingItemView { item in
                var updatedList = shoppingList
                updatedList.items.append(item)
                updatedList.updateModifiedDate()
                updateShoppingList(updatedList)
            }
        }
        .actionSheet(isPresented: $showingExportOptions) {
            ActionSheet(
                title: Text("Export Shopping List"),
                message: Text("Choose how to export your list"),
                buttons: [
                    .default(Text("Copy to Clipboard")) {
                        copyToClipboard()
                    },
                    .default(Text("Share")) {
                        shareList()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func toggleItemCompletion(_ item: ShoppingListItem) {
        var updatedList = shoppingList
        if let index = updatedList.items.firstIndex(where: { $0.id == item.id }) {
            updatedList.items[index].isCompleted.toggle()
            updatedList.updateModifiedDate()
            updateShoppingList(updatedList)
        }
    }
    
    private func deleteItem(_ item: ShoppingListItem) {
        var updatedList = shoppingList
        updatedList.items.removeAll { $0.id == item.id }
        updatedList.updateModifiedDate()
        updateShoppingList(updatedList)
    }
    
    private func updateShoppingList(_ updatedList: ShoppingList) {
        shoppingList = updatedList
        viewModel.updateShoppingList(updatedList)
    }
    
    private func clearCompletedItems() {
        var updatedList = shoppingList
        updatedList.items = updatedList.items.filter { !$0.isCompleted }
        updatedList.updateModifiedDate()
        updateShoppingList(updatedList)
    }
    
    private func markAllAsCompleted() {
        var updatedList = shoppingList
        for index in updatedList.items.indices {
            updatedList.items[index].isCompleted = true
        }
        updatedList.isCompleted = true
        updatedList.updateModifiedDate()
        updateShoppingList(updatedList)
    }
    
    private func copyToClipboard() {
        let listText = formatShoppingListAsText()
        UIPasteboard.general.string = listText
    }
    
    private func shareList() {
        let listText = formatShoppingListAsText()
        let activityVC = UIActivityViewController(activityItems: [listText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func formatShoppingListAsText() -> String {
        var text = "🛒 \(shoppingList.name)\n\n"
        
        for (category, items) in groupedItems {
            text += "\(category.icon) \(category.rawValue)\n"
            for item in items {
                let checkmark = item.isCompleted ? "✅" : "☐"
                text += "\(checkmark) \(item.displayText)\n"
                if let notes = item.notes {
                    text += "   💬 \(notes)\n"
                }
            }
            text += "\n"
        }
        
        text += "Generated by Nutrition Tracker"
        return text
    }
}

// MARK: - Category Header
struct CategoryHeader: View {
    let category: ShoppingCategory
    
    var body: some View {
        HStack {
            Text(category.icon)
            Text(category.rawValue)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Shopping List Item Row
struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayText)
                    .font(.body)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                
                if let notes = item.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !item.recipeNames.isEmpty {
                    HStack {
                        Image(systemName: "book.closed")
                            .font(.caption2)
                        Text(item.recipeNames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .contextMenu {
            Button {
                onToggle()
            } label: {
                Label(item.isCompleted ? "Mark as Incomplete" : "Mark as Complete", 
                      systemImage: item.isCompleted ? "circle" : "checkmark.circle")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Item", systemImage: "trash")
            }
        }
    }
}

// MARK: - Recipe Selection for Shopping View
struct RecipeSelectionForShoppingView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var recipesViewModel = RecipesViewModel()
    @State private var selectedRecipes: Set<UUID> = []
    @State private var servingMultipliers: [UUID: Double] = [:]
    @State private var shoppingListName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Shopping List Name")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextField("Enter list name", text: $shoppingListName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color.gray.opacity(0.05))
                
                if recipesViewModel.recipes.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No recipes available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Create some recipes first to generate shopping lists")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(recipesViewModel.recipes) { recipe in
                            DetailRecipeSelectionRow(
                                recipe: recipe,
                                isSelected: selectedRecipes.contains(recipe.id),
                                servingMultiplier: servingMultipliers[recipe.id] ?? 1.0,
                                onSelectionChange: { isSelected in
                                    if isSelected {
                                        selectedRecipes.insert(recipe.id)
                                        servingMultipliers[recipe.id] = 1.0
                                    } else {
                                        selectedRecipes.remove(recipe.id)
                                        servingMultipliers.removeValue(forKey: recipe.id)
                                    }
                                },
                                onMultiplierChange: { multiplier in
                                    servingMultipliers[recipe.id] = multiplier
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Select Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Generate") {
                    generateShoppingList()
                }
                .disabled(selectedRecipes.isEmpty || shoppingListName.isEmpty)
            )
        }
        .onAppear {
            recipesViewModel.loadRecipes()
            shoppingListName = "Shopping List \(DateFormatter.shortDate.string(from: Date()))"
        }
    }
    
    private func generateShoppingList() {
        let selectedRecipeObjects = recipesViewModel.recipes.filter { selectedRecipes.contains($0.id) }
        let items = RecipeShoppingListGenerator.generateShoppingList(
            from: selectedRecipeObjects,
            servingMultipliers: servingMultipliers
        )
        
        let shoppingList = ShoppingList(name: shoppingListName, items: items)
        ShoppingListViewModel.shared.saveShoppingList(shoppingList)
        
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Recipe Selection Row
struct DetailRecipeSelectionRow: View {
    let recipe: Recipe
    let isSelected: Bool
    let servingMultiplier: Double
    let onSelectionChange: (Bool) -> Void
    let onMultiplierChange: (Double) -> Void
    
    @State private var multiplierText = "1"
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    onSelectionChange(!isSelected)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    Text("\(recipe.ingredients.count) ingredients • \(recipe.servings) servings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if isSelected {
                HStack {
                    Text("Serving multiplier:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    TextField("1", text: $multiplierText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .onChange(of: multiplierText) { newValue in
                            if let multiplier = Double(newValue), multiplier > 0 {
                                onMultiplierChange(multiplier)
                            }
                        }
                    
                    Text("x")
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 32)
                .transition(.opacity)
            }
        }
        .onAppear {
            multiplierText = String(servingMultiplier)
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}