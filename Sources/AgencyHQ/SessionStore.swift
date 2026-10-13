import SwiftUI
import SwiftTerm

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String
    @Published var exited = false
    let isClaude: Bool
    @Published var needsAttention = false
    let view: LocalProcessTerminalView
    var onExit: ((TerminalSession) -> Void)?
    /// Called when output has gone quiet for a few seconds after activity (agent finished or is waiting).
    var onIdle: ((TerminalSession) -> Void)?
    private var idleTask: Task<Void, Never>?
    private let createdAt = Date()
    private let delegateProxy = DelegateProxy()
    /// Claude and quick terminals keep their own title instead of the shell's.
    private(set) var fixedTitle: Bool

    /// `command` runs non-interactively-then-exits (quick terminal); nil gives a normal login shell.
    init(title: String, directory: String = NSHomeDirectory(), command: String? = nil, startClaude: Bool = false) {
        self.title = title
        self.isClaude = startClaude
        self.fixedTitle = startClaude || command != nil
        view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        // Runs on SwiftTerm's parse thread after each output batch; hop to main.
        view.setProcessOutputHandler { [weak self] in
            Task { @MainActor in self?.outputArrived() }
        }
        view.nativeBackgroundColor = NSColor(red: 0.055, green: 0.063, blue: 0.075, alpha: 1)
        view.nativeForegroundColor = NSColor(red: 0.79, green: 0.81, blue: 0.84, alpha: 1)
        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        delegateProxy.session = self
        view.processDelegate = delegateProxy
        // Claude runs as the shell command; when it exits you land in a normal shell.
        let run = startClaude ? "claude; exec zsh -l" : command
        let args = run.map { ["-l", "-i", "-c", $0] } ?? ["-l"]
        view.startProcess(executable: "/bin/zsh", args: args, environment: nil, execName: nil, currentDirectory: directory)
    }

    /// A name the user chose; it sticks even if the shell later sets its own title.
    func rename(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        title = trimmed
        fixedTitle = true
    }

    func shutDown() {
        onExit = nil
        onIdle = nil
        idleTask?.cancel()
        view.terminate()
    }

    private func outputArrived() {
        idleTask?.cancel()
        // Ignore the shell's own startup output.
        guard Date().timeIntervalSince(createdAt) > 5 else { return }
        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.onIdle?(self)
        }
    }

    @MainActor private final class DelegateProxy: NSObject, LocalProcessTerminalViewDelegate {
        weak var session: TerminalSession?
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async {
                guard let s = self.session, !s.fixedTitle else { return }
                s.title = title
            }
        }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async {
                guard let s = self.session else { return }
                s.exited = true
                s.onExit?(s)
            }
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var sessions: [TerminalSession] = []
    @Published var selection: UUID? {
        didSet {
            sessions.first { $0.id == selection }?.needsAttention = false
            if selection != nil { showFindings = false }
        }
    }
    @Published var showFindings = false
    @Published var showQuickSheet = false
    @Published var quickText = ""
    @Published var hasBegun = false
    private var counter = 0
    private var lastPhoneAlert: [String: Date] = [:]
    private let lastDirKey = "lastClaudeDirectory"
    static let autoCloseDelay: TimeInterval = 2

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.clearSelectedAttention() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sessions.forEach { $0.shutDown() } }
        }
    }

    /// Landing screen's Begin: opens the main UI and makes sure there is one terminal.
    func begin() {
        hasBegun = true
        if sessions.isEmpty { addSession() }
    }

    func promptRename(_ s: TerminalSession) {
        let alert = NSAlert()
        alert.messageText = "Rename terminal"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = s.title
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn { s.rename(to: field.stringValue) }
    }

    private func clearSelectedAttention() {
        sessions.first { $0.id == selection }?.needsAttention = false
    }

    var claudeCount: Int { sessions.filter { $0.isClaude && !$0.exited }.count }

    @discardableResult
    func addSession() -> TerminalSession {
        counter += 1
        return register(TerminalSession(title: "Terminal \(counter)"))
    }

    /// Asks for a project folder, then opens a shell there and starts `claude`.
    func addClaudeSession() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Start Claude here"
        if let last = UserDefaults.standard.string(forKey: lastDirKey) {
            panel.directoryURL = URL(fileURLWithPath: last)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: lastDirKey)
        register(TerminalSession(title: "Claude: \(url.lastPathComponent)", directory: url.path, startClaude: true))
    }

    /// Runs pasted text in a fresh terminal; the terminal closes itself shortly after the command ends.
    func runQuick(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        counter += 1
        let s = TerminalSession(title: "Quick \(counter)", command: trimmed)
        s.onExit = { [weak self] session in
            DispatchQueue.main.asyncAfter(deadline: .now() + SessionStore.autoCloseDelay) {
                self?.close(session.id)
            }
        }
        register(s)
    }

    private func isWatching(_ s: TerminalSession) -> Bool {
        hasBegun && NSApp.isActive && selection == s.id
    }

    private func alert(_ s: TerminalSession) {
        // Orange dot, plus an optional ntfy phone alert (off by default). No macOS notifications by design.
        guard !isWatching(s) else { return }
        s.needsAttention = true
        // At most one phone alert per terminal per kind (quiet / finished) per minute.
        let key = "\(s.id)-\(s.exited)"
        let now = Date()
        if let last = lastPhoneAlert[key], now.timeIntervalSince(last) < 60 { return }
        lastPhoneAlert[key] = now
        let name = Ntfy.clean(s.title)
        Ntfy.send(title: "Agency HQ", message: s.exited ? "\(name) finished" : "\(name) may be waiting for you")
    }

    @discardableResult
    private func register(_ s: TerminalSession) -> TerminalSession {
        s.onIdle = { [weak self] session in self?.alert(session) }
        let previousExit = s.onExit
        s.onExit = { [weak self] session in
            self?.alert(session)
            previousExit?(session)
        }
        sessions.append(s)
        selection = s.id
        return s
    }

    func close(_ id: UUID) {
        sessions.first { $0.id == id }?.shutDown()
        lastPhoneAlert = lastPhoneAlert.filter { !$0.key.hasPrefix("\(id)-") }
        sessions.removeAll { $0.id == id }
        if selection == id { selection = sessions.last?.id }
    }
}
