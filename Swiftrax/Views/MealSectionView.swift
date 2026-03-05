import SwiftUI

struct MealSectionView: View {
    let mealType: MealType
    let entries: [FoodEntry]
    let onDeleteEntry: (FoodEntry) -> Void
    let onEditEntry: ((FoodEntry) -> Void)?
    @Environment(\.colorScheme) var colorScheme
    
    // Calculates total nutrition for all entries in this meal
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
                    .foregroundColor(Color.adaptiveText)
                
                Spacer()
                
                if !entries.isEmpty {
                    Text("\(Int(mealNutrition.calories ?? 0)) cal")
                        .font(.subheadline)
                        .foregroundColor(Color.adaptiveSecondaryText)
                }
            }
            
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(Color.adaptiveSecondaryText)
                        .font(.title2)
                    
                    Text("No foods logged for \(mealType.rawValue.lowercased())")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.foodItemBackground)
                .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        FoodRowView(
                            entry: entry,
                            onDelete: {
                                onDeleteEntry(entry)
                            },
                            onEdit: onEditEntry.map { callback in
                                { callback(entry) }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.mealCardBackground)
        .cornerRadius(12)
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.12) :
                   Color.black.opacity(0.08),
            radius: 4, x: 0, y: 2
        )
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.04) :
                   Color.black.opacity(0.04),
            radius: 8, x: 0, y: 4
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(mealType.rawValue) meal section")
        .accessibilityValue(entries.isEmpty ? "No foods logged" : "\(entries.count) foods, \(Int(mealNutrition.calories ?? 0)) calories")
    }
}

struct FoodRowView: View {
    let entry: FoodEntry
    let onDelete: () -> Void
    let onEdit: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.food.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(Color.adaptiveText)
                
                HStack {
                    if let brand = entry.food.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(Color.adaptiveSecondaryText)
                    }
                    
                    // Show barcode indicator if food has barcode
                    if entry.food.barcode != nil {
                        Image(systemName: "barcode")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text("\(entry.quantity.formattedNutrition) \(entry.food.servingSizeUnit)")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.scaledNutrition.calories ?? 0))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.adaptiveText)
                
                Text("cal")
                    .font(.caption2)
                    .foregroundColor(Color.adaptiveSecondaryText)
            }
        }
        .padding(12)
        .background(Color.foodItemBackground)
        .cornerRadius(8)
        .shadow(
            color: colorScheme == .dark ?
                   Color.white.opacity(0.06) :
                   Color.black.opacity(0.06),
            radius: 2, x: 0, y: 1
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onEdit = onEdit {
                Button("Edit") {
                    onEdit()
                }
                .tint(.blue)
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
            .tint(Color.destructiveAction)
        }
        .contextMenu {
            if let onEdit = onEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.food.name), \(Int(entry.scaledNutrition.calories ?? 0)) calories")
        .accessibilityHint("Swipe to delete or double tap to edit")
    }
}
