import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ArtifactItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var location: String   // https URL or local file path
    var added = Date()

    var url: URL? {
        if location.hasPrefix("http://") || location.hasPrefix("https://") { return URL(string: location) }
        return URL(fileURLWithPath: (location as NSString).expandingTildeInPath)
    }
}

/// Archive of artifacts (links or local files) the user wants to reopen later.
/// Stored at ~/Library/Application Support/AgencyHQ/artifacts.json
@MainActor
final class ArtifactStore: ObservableObject {
    @Published private(set) var items: [ArtifactItem] = []

    static let fileURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AgencyHQ/artifacts.json")

    init() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode([ArtifactItem].self, from: data) else { return }
        items = decoded
    }

    func add(title: String, location: String) {
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loc.isEmpty else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = URL(string: loc)?.lastPathComponent ?? loc
        items.insert(ArtifactItem(title: name.isEmpty ? fallback : name, location: loc), at: 0)
        save()
    }

    func remove(_ item: ArtifactItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func open(_ item: ArtifactItem) {
        guard let url = item.url else { return }
        NSWorkspace.shared.open(url)
    }

    private func save() {
        let url = Self.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: url, options: .atomic) }
    }
}

/// Plain ObservableObject instead of @State, which needs the SwiftUI macro plugin that Command Line Tools lack.
final class AddArtifactState: ObservableObject {
    @Published var showSheet = false
    @Published var title = ""
    @Published var location = ""
    func reset() { title = ""; location = "" }
}

struct ArtifactsView: View {
    @EnvironmentObject var artifacts: ArtifactStore
    @StateObject private var form = AddArtifactState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ARTIFACT ARCHIVE").font(Theme.mono(12)).tracking(3).foregroundStyle(Theme.dim)
                    Spacer()
                    Button { form.reset(); form.showSheet = true } label: { Label("Add", systemImage: "plus") }
                        .font(Theme.mono(12))
                }
                if artifacts.items.isEmpty {
                    Text("Nothing saved yet. Add a link or file to keep it one click away.")
                        .font(Theme.mono(12)).foregroundStyle(Theme.dim)
                }
                ForEach(artifacts.items) { item in
                    ArtifactRow(item: item,
                                onOpen: { artifacts.open(item) },
                                onDelete: { artifacts.remove(item) })
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.bg)
        .sheet(isPresented: $form.showSheet) { AddArtifactSheet(form: form) }
    }
}

struct ArtifactRow: View {
    let item: ArtifactItem
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(Theme.mono(13, weight: .semibold)).foregroundStyle(Theme.amber)
                    Text(item.location).font(Theme.mono(11)).foregroundStyle(Theme.dim)
                        .lineLimit(1).truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open")
            Button(action: onDelete) {
                Image(systemName: "xmark").foregroundStyle(Theme.dim)
            }
            .buttonStyle(.plain)
            .help("Remove from archive")
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct AddArtifactSheet: View {
    @EnvironmentObject var artifacts: ArtifactStore
    @ObservedObject var form: AddArtifactState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add artifact").font(Theme.mono(14, weight: .semibold))
            TextField("Name (optional)", text: $form.title).textFieldStyle(.roundedBorder)
            HStack {
                TextField("Link or file path", text: $form.location).textFieldStyle(.roundedBorder)
                Button("Choose file…") {
                    let panel = NSOpenPanel()
                    if panel.runModal() == .OK, let url = panel.url {
                        form.location = url.path
                        if form.title.isEmpty { form.title = url.lastPathComponent }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { form.showSheet = false }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    artifacts.add(title: form.title, location: form.location)
                    form.showSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(form.location.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
