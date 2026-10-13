import SwiftUI
import SwiftTerm

struct TerminalHost: NSViewRepresentable {
    let session: TerminalSession
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let v = session.view
        // Put the cursor in the terminal after switching to it.
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
        return v
    }
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @EnvironmentObject var caffeine: Caffeinator
    @EnvironmentObject var artifacts: ArtifactStore
    var body: some View {
        if store.hasBegun { mainView } else { LandingView() }
    }

    var mainView: some View {
        NavigationSplitView {
            List(selection: $store.selection) {
                Section {
                    Button {
                        store.selection = nil
                        store.showArtifacts = true
                    } label: {
                        HStack {
                            Image(systemName: "archivebox").foregroundStyle(Theme.amber)
                            Text("Artifacts\(artifacts.items.isEmpty ? "" : " (\(artifacts.items.count))")")
                                .font(Theme.mono(12))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("ARCHIVE").font(Theme.mono(10)).tracking(2).foregroundStyle(Theme.dim)
                }
                Section {
                    ForEach(store.sessions) { s in
                        SessionRow(session: s, onClose: { store.close(s.id) }, onRename: { store.promptRename(s) })
                            .tag(s.id)
                    }
                } header: {
                    Text("ACTIVE FILES").font(Theme.mono(10)).tracking(2).foregroundStyle(Theme.dim)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.panel)
            .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 380)
            .safeAreaInset(edge: .bottom) {
                if store.claudeCount > 2 {
                    Text("\(store.claudeCount) Claude terminals open")
                        .font(.caption).foregroundStyle(.orange).padding(6)
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button { store.addSession() } label: { Label("New terminal", systemImage: "plus") }
                        .keyboardShortcut("t", modifiers: .command)
                    Button { store.addClaudeSession() } label: { Label("Claude terminal", systemImage: "eye") }
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                    Button {
                        store.quickText = NSPasteboard.general.string(forType: .string) ?? ""
                        store.showQuickSheet = true
                    } label: { Label("Quick terminal", systemImage: "bolt") }
                        .keyboardShortcut("r", modifiers: [.command, .shift])
                    Toggle(isOn: Binding(get: { caffeine.isOn }, set: { _ in caffeine.toggle() })) {
                        Label("Keep awake", systemImage: caffeine.isOn ? "cup.and.saucer.fill" : "cup.and.saucer")
                    }
                    .help(caffeine.isOn ? "Mac is being kept awake (caffeinate -dims)" : "Keep Mac awake (caffeinate -dims)")
                }
            }
        } detail: {
            if store.showArtifacts {
                ArtifactsView()
            } else if let s = store.sessions.first(where: { $0.id == store.selection }) {
                TerminalHost(session: s).id(s.id)
            } else {
                VStack(spacing: 12) {
                    Text("NO OPEN FILES").font(Theme.mono(12)).tracking(3).foregroundStyle(Theme.dim)
                    Button("New terminal") { store.addSession() }
                        .buttonStyle(AmberButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
            }
        }
        .sheet(isPresented: $store.showQuickSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick terminal").font(.headline)
                Text("Review the text. It runs only when you click Run; the terminal closes \(Int(SessionStore.autoCloseDelay))s after it finishes.")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $store.quickText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 480, minHeight: 160)
                HStack {
                    Spacer()
                    Button("Cancel") { store.showQuickSheet = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Run") {
                        store.showQuickSheet = false
                        store.runQuick(store.quickText)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
        }
    }
}

struct SessionRow: View {
    @ObservedObject var session: TerminalSession
    let onClose: () -> Void
    let onRename: () -> Void
    var body: some View {
        HStack {
            Image(systemName: session.exited ? "stop.circle" : (session.isClaude ? "eye" : "terminal"))
                .foregroundStyle(session.isClaude ? Theme.amber : Theme.dim)
            Text(session.title).font(Theme.mono(12)).lineLimit(1)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onRename() }
                .contextMenu { Button("Rename…") { onRename() } }
            Spacer()
            if session.needsAttention {
                Circle().fill(Theme.amber).frame(width: 8, height: 8)
                    .accessibilityLabel("Needs attention")
            }
            Button(action: onClose) { Image(systemName: "xmark").padding(4) }
                .buttonStyle(.plain)
                .accessibilityLabel("Close terminal")
                .help("Close terminal")
        }
    }
}
