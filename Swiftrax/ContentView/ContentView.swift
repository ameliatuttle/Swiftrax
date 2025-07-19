import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("app_theme") private var selectedTheme: String = AppTheme.system.rawValue
    
    // Convert theme string to AppTheme enum
    private var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }
    
    var body: some View {
        // Main tab navigation container
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
        .background(Color.appBackground)
        // Apply selected theme (light/dark/system)
        .preferredColorScheme(currentTheme.colorScheme)
        .onAppear {
            print("App started")
            loadUserTheme()
            // Initialize database connection
            DatabaseManager.shared.testDatabaseConnection()
        }
        .animation(.easeInOut(duration: 0.3), value: currentTheme.rawValue)
    }
    
    // Loads user theme preference from database and applies it
    private func loadUserTheme() {
        DatabaseManager.shared.getUserSettingsAsync { user in
            let themeToApply = user.theme.rawValue
            if selectedTheme != themeToApply {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTheme = themeToApply
                }
            }
        }
    }
}
