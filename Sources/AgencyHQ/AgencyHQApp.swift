import SwiftUI

@main
struct AgencyHQApp: App {
    @StateObject private var store = SessionStore()
    @StateObject private var caffeine = Caffeinator()
    @StateObject private var findings = FindingsStore()

    var body: some Scene {
        Window("Agency HQ", id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(caffeine)
                .environmentObject(findings)
                .frame(minWidth: 1000, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 700)
        Settings { SettingsView() }
        MenuBarExtra("Agency HQ", systemImage: caffeine.isOn ? "cup.and.saucer.fill" : "cup.and.saucer") {
            Toggle("Keep Mac awake", isOn: Binding(get: { caffeine.isOn }, set: { _ in caffeine.toggle() }))
        }
    }
}
