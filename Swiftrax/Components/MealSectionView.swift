import SwiftUI

struct MealSectionView: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let onDeleteEntry: (FoodEntry) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var mealNutrition: NutritionInfo {
        return entries.reduce(NutritionInfo.zero) { result, entry in
            result + entry.scaledNutrition
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(mealType.emoji) \(mealType.rawValue)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText) // Using semantic text color
                
                Spacer()
                
                if !entries.isEmpty {
                    Text("\(Int(mealNutrition.calories ?? 0)) cal")
                        .font(.subheadline)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
                }
            }
            
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
                        .font(.title2)
                    
                    Text("No foods logged for \(mealType.rawValue.lowercased())")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.foodItemBackground) // Adapts to light/dark mode
                .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        FoodRowView(
                            entry: entry,
                            onDelete: {
                                onDeleteEntry(entry)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.mealCardBackground) // Consistent with dashboard cards
        .cornerRadius(12)
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.12) : // Slightly more visible in dark mode
                   Color.black.opacity(0.08),  // Subtle in light mode
            radius: 4, x: 0, y: 2
        )
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.04) :
                   Color.black.opacity(0.04),
            radius: 8, x: 0, y: 4
        )
        .accessibilityElement(children: .contain) // Better accessibility grouping
        .accessibilityLabel("\(mealType.rawValue) meal section")
        .accessibilityValue(entries.isEmpty ? "No foods logged" : "\(entries.count) foods, \(Int(mealNutrition.calories ?? 0)) calories")
    }
}

struct FoodRowView: View {
    let entry: FoodEntry
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.food.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(Color.adaptiveText) // Using semantic text color
                
                HStack {
                    if let brand = entry.food.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
                    }
                    
                    Spacer()
                    
                    Text("\(entry.quantity.formattedNutrition) \(entry.food.servingSizeUnit)")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.scaledNutrition.calories ?? 0))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText) // Using semantic text color
                
                Text("cal")
                    .font(.caption2)
                    .foregroundColor(Color.adaptiveSecondaryText) // Using semantic text color
            }
        }
        .padding(12)
        .background(Color.foodItemBackground) // Consistent background
        .cornerRadius(8)
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.06) : // More subtle shadow in dark mode
                   Color.black.opacity(0.06),
            radius: 2, x: 0, y: 1
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            .tint(Color.destructiveAction) // Using semantic destructive color
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            
            Button("Edit") {
                // TODO: Implement edit functionality
            }
            
            Button("Duplicate") {
                // TODO: Implement duplicate functionality
            }
        }
        .accessibilityElement(children: .combine) // Better accessibility
        .accessibilityLabel("\(entry.food.name), \(Int(entry.scaledNutrition.calories ?? 0)) calories")
        .accessibilityHint("Swipe to delete or double tap to edit")
    }
}

#Preview {
    let sampleFood = Food(
        name: "Grilled Chicken Breast",
        nutritionInfo: NutritionInfo(calories: 165, protein: 31, carbohydrates: 0, fat: 3.6),
        servingSize: 100,
        servingSizeUnit: "g",
        brand: "Generic"
    )
    
    let sampleEntry = FoodEntry(
        food: sampleFood,
        quantity: 150,
        mealType: .lunch
    )
    
    return VStack(spacing: 16) {
        // Light mode preview
        MealSectionView(
            mealType: .lunch,
            entries: [sampleEntry],
            onDeleteEntry: { _ in }
        )
        .preferredColorScheme(.light)
        
        // Dark mode preview
        MealSectionView(
            mealType: .dinner,
            entries: [],
            onDeleteEntry: { _ in }
        )
        .preferredColorScheme(.dark)
    }
    .padding()
    .background(Color.appBackground)
}
