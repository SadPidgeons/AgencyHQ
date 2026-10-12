import SwiftUI

@main
struct AgencyHQApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var caffeine = Caffeinator()

    var body: some Scene {
        WindowGroup("Agency HQ") {
            ContentView()
                .environmentObject(store)
                .environmentObject(caffeine)
                .frame(minWidth: 800, minHeight: 500)
                .preferredColorScheme(.dark)
        }
        MenuBarExtra("Agency HQ", systemImage: caffeine.isOn ? "cup.and.saucer.fill" : "cup.and.saucer") {
            Toggle("Keep Mac awake", isOn: Binding(get: { caffeine.isOn }, set: { _ in caffeine.toggle() }))
        }
    }
}
