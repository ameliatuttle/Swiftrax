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
        }
    }
}
