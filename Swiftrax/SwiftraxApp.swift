//
//  SwiftraxApp.swift
//  Swiftrax
//
//  Created by Amelia Tuttle on 5/17/25.
//

import SwiftUI

@main
struct SwiftraxApp: App {
   let persistenceController = PersistenceController.shared
   
   var body: some Scene {
      WindowGroup {
         ContentView()
         .environment(\.managedObjectContext, persistenceController.container.viewContext)
         .onAppear {
            initializeApp()
         }
      }
   }
   
   private func initializeApp() {
      print("🚀 SwiftraxApp: Initializing application...")
      
      // Initialize database connection
      DatabaseManager.shared.testDatabaseConnection()
      
      // 🆕 NEW: Check if this is a fresh install or upgrade
      checkForUpgradeAndCleanup()
      
      // Seed basic foods on first run (with duplicate prevention)
      Task {
         await seedBasicFoods()
      }
      
      print("✅ SwiftraxApp: Application initialized")
   }
   
   // 🆕 NEW: Check for app upgrade and perform cleanup if needed
   private func checkForUpgradeAndCleanup() {
      let userDefaults = UserDefaults.standard
      let currentAppVersion = "1.0.0"
      let lastRunVersion = userDefaults.string(forKey: "lastRunAppVersion")
      
      if lastRunVersion != currentAppVersion {
         print("🔄 App upgrade detected (from \(lastRunVersion ?? "new install") to \(currentAppVersion))")
         
         if lastRunVersion != nil {
            // This is an upgrade, not a fresh install
            print("🧹 Performing upgrade cleanup...")
            
            // Clean up duplicates from previous versions
            DatabaseManager.shared.cleanupDuplicatesAsync { cleanedCount in
               print("🧹 Upgrade cleanup: Removed \(cleanedCount) duplicates")
               
               // Force reseed basic foods to ensure we have the latest version
               BasicFoodsSeeder.shared.forceReseed()
            }
         }
         
         // Update the version
         userDefaults.set(currentAppVersion, forKey: "lastRunAppVersion")
      }
   }
   
   private func seedBasicFoods() async {
      print("🌱 SwiftraxApp: Starting basic foods seeding...")
      
      // Run seeding on background thread to avoid blocking UI
      await Task {
         BasicFoodsSeeder.shared.seedBasicFoodsIfNeeded()
      }.value
      
      print("🌱 SwiftraxApp: Basic foods seeding completed")
   }
}

// 🆕 NEW: Extension for app lifecycle management
extension SwiftraxApp {
   
   /// Perform maintenance tasks (call this from settings or on app updates)
   static func performMaintenance() {
      print("🔧 SwiftraxApp: Starting maintenance tasks...")
      
      // Clean up corrupted entries
      DatabaseManager.shared.cleanupCorruptedEntries()
      
      // Remove duplicates
      DatabaseManager.shared.cleanupDuplicatesAsync { cleanedCount in
         print("🧹 Maintenance: Cleaned up \(cleanedCount) duplicates")
         
         // Reseed basic foods if needed
         BasicFoodsSeeder.shared.seedBasicFoodsIfNeeded()
      }
   }
   
   /// Reset the app to fresh state (for testing or troubleshooting)
   static func resetToFreshState() {
      print("🔄 SwiftraxApp: Resetting to fresh state...")
      
      // Clear all data
      DatabaseManager.shared.clearAllData()
      
      // Reset user defaults
      let userDefaults = UserDefaults.standard
      userDefaults.removeObject(forKey: "hasSeededBasicFoods")
      userDefaults.removeObject(forKey: "basicFoodsSeedVersion")
      userDefaults.removeObject(forKey: "lastRunAppVersion")
      
      // Re-seed basic foods
      BasicFoodsSeeder.shared.seedBasicFoodsIfNeeded()
      
      print("✅ SwiftraxApp: Reset to fresh state completed")
   }
}
