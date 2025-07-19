//
//  SwiftraxApp.swift
//  Swiftrax
//
//  Created by Amelia Tuttle on 7/18/2025
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
   
   // Sets up database connection and seeds initial data
   private func initializeApp() {
      DatabaseManager.shared.testDatabaseConnection()
      checkForUpgradeAndCleanup()
      
      Task {
         await seedBasicFoods()
      }
   }
   
   // Handles app upgrades and cleanup for version changes
   private func checkForUpgradeAndCleanup() {
      let userDefaults = UserDefaults.standard
      let currentAppVersion = "1.0.0"
      let lastRunVersion = userDefaults.string(forKey: "lastRunAppVersion")
      
      if lastRunVersion != currentAppVersion {
         if lastRunVersion != nil {
            DatabaseManager.shared.cleanupDuplicatesAsync { cleanedCount in
               BasicFoodsSeeder.shared.forceReseed()
            }
         }
         
         userDefaults.set(currentAppVersion, forKey: "lastRunAppVersion")
      }
   }
   
   private func seedBasicFoods() async {
      await Task {
         BasicFoodsSeeder.shared.seedBasicFoodsIfNeeded()
      }.value
   }
}

extension SwiftraxApp {
   
   // Performs database cleanup and maintenance tasks
   static func performMaintenance() {
      DatabaseManager.shared.cleanupCorruptedEntries()
      
      DatabaseManager.shared.cleanupDuplicatesAsync { cleanedCount in
         BasicFoodsSeeder.shared.seedBasicFoodsIfNeeded()
      }
   }
   
   // Resets app to fresh install state for troubleshooting
   static func resetToFreshState() {
      DatabaseManager.shared.clearAllData()
      
      let userDefaults = UserDefaults.standard
      userDefaults.removeObject(forKey: "hasSeededBasicFoods")
      userDefaults.removeObject(forKey: "basicFoodsSeedVersion")
      userDefaults.removeObject(forKey: "lastRunAppVersion")
      
      BasicFoodsSeeder.shared.seedBasicFoodsIfNeeded()
   }
}
