import Foundation

/// Keeps the Mac awake by running /usr/bin/caffeinate. `-w <pid>` makes it exit with the app.
@MainActor
final class Caffeinator: ObservableObject {
    @Published private(set) var isOn = false
    private var process: Process?

    func toggle() { isOn ? stop() : start() }

    func start() {
        guard process == nil else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-dims", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        p.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                // Ignore a stale handler from a previous process after a quick off/on.
                guard let self, self.process === finished || self.process == nil else { return }
                self.process = nil
                self.isOn = false
            }
        }
        do {
            try p.run()
            process = p
            isOn = true
        } catch {
            isOn = false
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isOn = false
    }
}
