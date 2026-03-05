import SwiftUI

struct EditQuantityView: View {
    let entry: FoodEntry
    let onSave: (FoodEntry) -> Void
    
    @State private var quantity: String = ""
    @State private var selectedMealType: MealType
    @State private var showingSuccessAlert = false
    
    @Environment(\.presentationMode) var presentationMode
    
    init(entry: FoodEntry, onSave: @escaping (FoodEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        
        // Initialize with current entry values
        self._selectedMealType = State(initialValue: entry.mealType)
        self._quantity = State(initialValue: entry.quantity.formattedNutrition)
    }
    
    var isValidQuantity: Bool {
        guard let value = Double(quantity) else { return false }
        return value > 0
    }
    
    var calculatedNutrition: NutritionInfo {
        guard let quantityValue = Double(quantity) else {
            return NutritionInfo.zero
        }
        
        // Calculate nutrition based on the original serving size
        let scaleFactor = quantityValue / entry.food.servingSize
        return entry.food.nutritionInfo.scaled(by: scaleFactor)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Food header
                    foodHeaderView
                    
                    // Quantity input section
                    quantityInputSection
                    
                    // Meal type selection
                    mealTypeSection
                    
                    // Nutrition preview
                    nutritionPreviewSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidQuantity)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Entry Updated", isPresented: $showingSuccessAlert) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your food entry has been successfully updated.")
        }
    }
    
    private var foodHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.food.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.adaptiveText)
                        .lineLimit(2)
                    
                    if let brand = entry.food.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(Color.adaptiveSecondaryText)
                    }
                }
                
                Spacer()
            }
            
            // Original serving info
            VStack(alignment: .leading, spacing: 4) {
                Text("Original serving size:")
                    .font(.caption)
                    .foregroundColor(Color.adaptiveSecondaryText)
                
                Text("\(entry.food.servingSize.formattedNutrition) \(entry.food.servingSizeUnit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.adaptiveText)
            }
        }
        .padding()
        .background(Color.foodItemBackground)
        .cornerRadius(12)
    }
    
    private var quantityInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quantity (\(entry.food.servingSizeUnit))")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText)
            
            TextField("Enter quantity", text: $quantity)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .onChange(of: quantity) { newValue in
                    // Format input for better UX
                    let filtered = newValue.filter { "0123456789.".contains($0) }
                    if filtered != newValue {
                        quantity = filtered
                    }
                }
            
            if let servingsRatio = getServingsRatio() {
                Text("≈ \(servingsRatio) servings")
                    .font(.subheadline)
                    .foregroundColor(Color.adaptiveSecondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.foodItemBackground)
        .cornerRadius(12)
    }
    
    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Type")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMealType = mealType
                        }
                    }) {
                        HStack {
                            Text("\(mealType.emoji)")
                                .font(.title2)
                            
                            Text(mealType.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedMealType == mealType ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(selectedMealType == mealType ? .white : Color.adaptiveText)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color.foodItemBackground)
        .cornerRadius(12)
    }
    
    private var nutritionPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Preview")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                NutritionInfoCard(title: "Calories", value: calculatedNutrition.calories ?? 0, unit: "kcal")
                NutritionInfoCard(title: "Protein", value: calculatedNutrition.protein ?? 0, unit: "g")
                NutritionInfoCard(title: "Carbs", value: calculatedNutrition.carbohydrates ?? 0, unit: "g")
                NutritionInfoCard(title: "Fat", value: calculatedNutrition.fat ?? 0, unit: "g")
                
                if let fiber = calculatedNutrition.fiber, fiber > 0 {
                    NutritionInfoCard(title: "Fiber", value: fiber, unit: "g")
                }
                
                if let sugar = calculatedNutrition.sugar, sugar > 0 {
                    NutritionInfoCard(title: "Sugar", value: sugar, unit: "g")
                }
            }
        }
        .padding()
        .background(Color.foodItemBackground)
        .cornerRadius(12)
    }
    
    private func getServingsRatio() -> String? {
        guard let quantityValue = Double(quantity), entry.food.servingSize > 0 else {
            return nil
        }
        
        let ratio = quantityValue / entry.food.servingSize
        return String(format: "%.2f", ratio)
    }
    
    private func saveEntry() {
        guard let quantityValue = Double(quantity), quantityValue > 0 else {
            return
        }
        
        // Create updated entry with new values
        let updatedEntry = FoodEntry(
            id: entry.id, // Keep the same ID for update
            food: entry.food,
            quantity: quantityValue,
            mealType: selectedMealType,
            dateLogged: entry.dateLogged, // Keep original date
            notes: entry.notes // Keep original notes
        )
        
        onSave(updatedEntry)
        showingSuccessAlert = true
    }
}

struct NutritionInfoCard: View {
    let title: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptiveSecondaryText)
            
            Text("\(value.formattedNutrition)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Color.adaptiveText)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(Color.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}