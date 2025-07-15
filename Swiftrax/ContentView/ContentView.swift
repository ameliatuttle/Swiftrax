import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("app_theme") private var selectedTheme: String = AppTheme.system.rawValue
    
    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            SearchLogView()
                .tabItem {
                    Image(systemName: "magnifyingglass.circle.fill")
                    Text("Search & Log")
                }
                .tag(1)
            
            ManualEntryView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Manual Entry")
                }
                .tag(2)
            
            RecipesView()
                .tabItem {
                    Image(systemName: "book.closed")
                    Text("Recipes")
                }
                .tag(3)
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(4)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(5)
        }
        .background(Color.appBackground) // This will now work properly
        .frame(width: screenWidth, height: screenHeight)
        .accentColor(Color.primaryAccent) // Using semantic accent color
        // FIXED: Only apply preferredColorScheme when user explicitly chooses light/dark
        // Let system handle it when set to "system"
        .apply { view in
            switch currentTheme {
            case .system:
                view // Don't override system - let it work naturally
            case .light:
                view.preferredColorScheme(.light)
            case .dark:
                view.preferredColorScheme(.dark)
            }
        }
        .onAppear {
            print("🚀 APP STARTED - Theme: \(currentTheme.displayName)")
            print("🎨 Color scheme override: \(currentTheme == .system ? "NONE (system)" : currentTheme.rawValue)")
            
            // Load user theme preference immediately
            loadUserTheme()
            
            // Test the enhanced database functionality
            DatabaseManager.shared.testDatabaseConnection()
            DatabaseManager.shared.debugBarcodeLookup("0074401704324")
            
            // Print available units for debugging
            print("📏 Available measurement units: \(MeasurementUnit.allCases.map { $0.displayName }.joined(separator: ", "))")
        }
    }
    
    private func loadUserTheme() {
        // Load user settings and apply theme
        DatabaseManager.shared.getUserSettingsAsync { user in
            let themeToApply = user.theme.rawValue
            if selectedTheme != themeToApply {
                selectedTheme = themeToApply
                print("🎨 Updated theme from user settings: \(themeToApply)")
            }
        }
    }
    
    private func testBarcodeAPICall() {
        Task {
            do {
                print("🧪 Testing OpenFoodFacts API with barcode: 0074401704324")
                if let food = try await APIManager.shared.searchByBarcode("0074401704324") {
                    print("🧪 ✅ API Test Success: \(food.name)")
                    print("🧪 Calories: \(food.nutritionInfo.calories ?? 0)")
                    print("🧪 Brand: \(food.brand ?? "No brand")")
                } else {
                    print("🧪 ❌ API Test: No food found")
                }
            } catch {
                print("🧪 ❌ API Test Error: \(error)")
            }
        }
    }
}

// MARK: - Helper Extension for Conditional View Modifiers
extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V {
        block(self)
    }
}

#Preview {
    ContentView()
}
