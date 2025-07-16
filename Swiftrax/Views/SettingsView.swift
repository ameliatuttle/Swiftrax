import SwiftUI

struct SettingsView: View {
    @State private var userSettings = User()
    @State private var showingClearDataAlert = false
    @State private var showingExportAlert = false
    @AppStorage("app_theme") private var selectedTheme: String = AppTheme.system.rawValue
    
    // FIXED: Add screen size properties
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var currentTheme: AppTheme {
        AppTheme(rawValue: selectedTheme) ?? .system
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Tracking Preferences
                Section("Nutrition Tracking") {
                    Toggle("Track Calories", isOn: $userSettings.trackingPreferences.trackCalories)
                    Toggle("Track Protein", isOn: $userSettings.trackingPreferences.trackProtein)
                    Toggle("Track Carbohydrates", isOn: $userSettings.trackingPreferences.trackCarbs)
                    Toggle("Track Fat", isOn: $userSettings.trackingPreferences.trackFat)
                    
                    DisclosureGroup("Additional Nutrients") {
                        Toggle("Track Fiber", isOn: $userSettings.trackingPreferences.trackFiber)
                        Toggle("Track Sugar", isOn: $userSettings.trackingPreferences.trackSugar)
                        Toggle("Track Sodium", isOn: $userSettings.trackingPreferences.trackSodium)
                        Toggle("Track Cholesterol", isOn: $userSettings.trackingPreferences.trackCholesterol)
                        Toggle("Track Saturated Fat", isOn: $userSettings.trackingPreferences.trackSaturatedFat)
                    }
                }
                
                // Nutrition Goals
                Section("Daily Goals") {
                    NavigationLink("Set Nutrition Goals", destination: NutritionGoalsView(userSettings: $userSettings))
                }
                
                // App Theme
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Label(theme.displayName, systemImage: theme.iconName)
                                .tag(theme.rawValue)
                        }
                    }
                    // FIXED: Prevent navigation reset by using Task and avoiding immediate state changes
                    .onChange(of: selectedTheme) { newTheme in
                        print("🎨 Settings: Theme changed to \(newTheme)")
                        
                        // FIXED: Use Task to delay the theme update slightly to prevent navigation disruption
                        Task { @MainActor in
                            // Update user settings theme without triggering immediate view rebuild
                            if let newAppTheme = AppTheme(rawValue: newTheme) {
                                userSettings.theme = newAppTheme
                                
                                // Save settings asynchronously to prevent blocking UI
                                Task {
                                    await saveSettingsAsync()
                                }
                                
                                print("🎨 Settings: Theme updated to \(newTheme) without navigation reset")
                            }
                        }
                    }
                }
                
                // Data Management
                Section("Data") {
                    Button("Export Data") {
                        exportData()
                    }
                    
                    Button("Clear All Data", role: .destructive) {
                        showingClearDataAlert = true
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Amelia Tuttle")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current Theme")
                        Spacer()
                        Text(currentTheme.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("⚙️ Settings: View appeared")
                loadSettings()
                // FIXED: Only sync theme if it's different to prevent unnecessary updates
                if selectedTheme != userSettings.theme.rawValue {
                    selectedTheme = userSettings.theme.rawValue
                    print("🎨 Settings: Synced theme to \(selectedTheme)")
                }
            }
            // FIXED: Add manual save triggers for specific changes instead of automatic onChange
            .onChange(of: userSettings.trackingPreferences.trackCalories) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackProtein) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackCarbs) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackFat) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackFiber) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackSugar) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackSodium) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackCholesterol) { _ in
                Task { await saveSettingsAsync() }
            }
            .onChange(of: userSettings.trackingPreferences.trackSaturatedFat) { _ in
                Task { await saveSettingsAsync() }
            }
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all your food entries and custom foods. This action cannot be undone.")
            }
            .alert("Export Complete", isPresented: $showingExportAlert) {
                Button("OK") { }
            } message: {
                Text("Your data has been exported successfully.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func loadSettings() {
        userSettings = DatabaseManager.shared.getUserSettings()
        print("⚙️ Settings: Loaded user settings with theme: \(userSettings.theme.rawValue)")
    }
    
    // FIXED: Make saveSettings async to prevent blocking UI and navigation
    private func saveSettingsAsync() async {
        print("⚙️ Settings: Saving user settings with theme: \(userSettings.theme.rawValue)")
        
        // Save asynchronously to prevent blocking UI and navigation
        await withCheckedContinuation { continuation in
            DatabaseManager.shared.saveUserSettingsAsync(userSettings) {
                continuation.resume()
            }
        }
    }
    
    private func exportData() {
        // TODO: Implement data export functionality
        showingExportAlert = true
    }
    
    private func clearAllData() {
        // Clear data in database
        DatabaseManager.shared.clearAllData()
        
        // Reset user settings
        userSettings = User()
        Task { await saveSettingsAsync() }
        
        // Post notification to refresh all views
        NotificationCenter.default.post(name: NSNotification.Name("DataCleared"), object: nil)
    }
}

// MARK: - Nutrition Goals View (unchanged)
struct NutritionGoalsView: View {
    @Binding var userSettings: User
    
    var body: some View {
        Form {
            Section("Daily Nutrition Goals") {
                if userSettings.trackingPreferences.trackCalories {
                    GoalInputView(
                        title: "Calories",
                        value: Binding(
                            get: {
                                if let goal = userSettings.nutritionGoals?.calorieGoal {
                                    return String(Int(goal))
                                } else {
                                    return ""
                                }
                            },
                            set: { newValue in
                                if userSettings.nutritionGoals == nil {
                                    userSettings.nutritionGoals = NutritionGoals()
                                }
                                userSettings.nutritionGoals?.calorieGoal = Double(newValue)
                            }
                        ),
                        unit: "kcal"
                    )
                }
                
                if userSettings.trackingPreferences.trackProtein {
                    GoalInputView(
                        title: "Protein",
                        value: Binding(
                            get: {
                                if let goal = userSettings.nutritionGoals?.proteinGoal {
                                    return String(Int(goal))
                                } else {
                                    return ""
                                }
                            },
                            set: { newValue in
                                if userSettings.nutritionGoals == nil {
                                    userSettings.nutritionGoals = NutritionGoals()
                                }
                                userSettings.nutritionGoals?.proteinGoal = Double(newValue)
                            }
                        ),
                        unit: "g"
                    )
                }
                
                if userSettings.trackingPreferences.trackCarbs {
                    GoalInputView(
                        title: "Carbohydrates",
                        value: Binding(
                            get: {
                                if let goal = userSettings.nutritionGoals?.carbGoal {
                                    return String(Int(goal))
                                } else {
                                    return ""
                                }
                            },
                            set: { newValue in
                                if userSettings.nutritionGoals == nil {
                                    userSettings.nutritionGoals = NutritionGoals()
                                }
                                userSettings.nutritionGoals?.carbGoal = Double(newValue)
                            }
                        ),
                        unit: "g"
                    )
                }
                
                if userSettings.trackingPreferences.trackFat {
                    GoalInputView(
                        title: "Fat",
                        value: Binding(
                            get: {
                                if let goal = userSettings.nutritionGoals?.fatGoal {
                                    return String(Int(goal))
                                } else {
                                    return ""
                                }
                            },
                            set: { newValue in
                                if userSettings.nutritionGoals == nil {
                                    userSettings.nutritionGoals = NutritionGoals()
                                }
                                userSettings.nutritionGoals?.fatGoal = Double(newValue)
                            }
                        ),
                        unit: "g"
                    )
                }
            }
            
            Section {
                Button("Reset All Goals") {
                    userSettings.nutritionGoals = nil
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Nutrition Goals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if userSettings.nutritionGoals == nil {
                userSettings.nutritionGoals = NutritionGoals()
            }
        }
    }
}

// MARK: - Goal Input View (unchanged)
struct GoalInputView: View {
    let title: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            TextField("Goal", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            
            Text(unit)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    SettingsView()
}
