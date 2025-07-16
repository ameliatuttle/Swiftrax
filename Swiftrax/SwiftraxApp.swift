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
      
      // Seed basic foods on first run
      Task {
         await seedBasicFoods()
      }
      
      print("✅ SwiftraxApp: Application initialized")
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
