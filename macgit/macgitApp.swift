//
//  macgitApp.swift
//  macgit
//
//  Created by Thanh Tran on 26/5/26.
//

import SwiftUI
import CoreData

@main
struct macgitApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
