import SwiftUI

/// Optional phone alerts through ntfy (https://ntfy.sh). Off by default; sends only the terminal's name.
enum Ntfy {
    static let enabledKey = "ntfyEnabled"
    static let serverKey = "ntfyServer"
    static let topicKey = "ntfyTopic"
    static let defaultServer = "https://ntfy.sh"

    /// Builds the publish URL, or nil if the server or topic is unusable.
    /// https only (plain http is blocked by App Transport Security in a bundled app); topics follow ntfy's rule.
    static func publishURL(server: String, topic: String) -> URL? {
        let t = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...64).contains(t.utf8.count),
              t.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }),
              var base = URLComponents(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              base.scheme == "https", base.host != nil,
              base.user == nil, base.password == nil else { return nil }
        // Keep a subpath for self-hosted servers behind a reverse proxy.
        let prefix = base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path
        base.path = prefix + "/" + t
        base.query = nil
        base.fragment = nil
        return base.url
    }

    /// Terminal titles can be set by programs, so strip control characters and cap the length.
    static func clean(_ title: String) -> String {
        let flat = String(String.UnicodeScalarView(title.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }))
        return flat.count > 80 ? String(flat.prefix(80)) + "..." : flat
    }

    /// Fire and forget; failures are ignored (an alert is a convenience, not a guarantee).
    static func send(title: String, message: String) {
        let d = UserDefaults.standard
        guard d.bool(forKey: enabledKey),
              let url = publishURL(server: d.string(forKey: serverKey) ?? defaultServer,
                                   topic: d.string(forKey: topicKey) ?? "") else { return }
        post(url: url, title: title, message: message, completion: nil)
    }

    static func post(url: URL, title: String, message: String, completion: ((String) -> Void)?) {
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.httpBody = Data(message.utf8)
        // Header values must be ASCII-safe; ntfy accepts RFC 2047 encoded words for others.
        let ascii = title.unicodeScalars.allSatisfy { $0.isASCII }
        req.setValue(ascii ? title : "=?UTF-8?B?\(Data(title.utf8).base64EncodedString())?=", forHTTPHeaderField: "Title")
        URLSession.shared.dataTask(with: req) { _, resp, err in
            let result: String
            if let err { result = "Failed: \(err.localizedDescription)" }
            else if let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 { result = "Sent. Check your phone." }
            else { result = "Failed: server answered \((resp as? HTTPURLResponse)?.statusCode ?? 0)" }
            DispatchQueue.main.async { completion?(result) }
        }.resume()
    }
}

/// Plain ObservableObject instead of @State, which needs the SwiftUI macro plugin that Command Line Tools lack.
final class TestState: ObservableObject {
    @Published var result = ""
}

struct SettingsView: View {
    @AppStorage(Ntfy.enabledKey) private var enabled = false
    @AppStorage(Ntfy.serverKey) private var server = Ntfy.defaultServer
    @AppStorage(Ntfy.topicKey) private var topic = ""
    @StateObject private var test = TestState()

    var body: some View {
        Form {
            Toggle("Send phone alerts through ntfy", isOn: $enabled)
            TextField("Server", text: $server).disabled(!enabled)
            TextField("Topic", text: $topic).disabled(!enabled)
            HStack {
                Button("Send test") {
                    guard let url = Ntfy.publishURL(server: server, topic: topic) else {
                        test.result = "Enter a valid server and a topic (letters, numbers, - and _)."
                        return
                    }
                    test.result = "Sending..."
                    Ntfy.post(url: url, title: "Agency HQ", message: "Test alert") { test.result = $0 }
                }
                .disabled(!enabled)
                Text(test.result).font(.caption).foregroundStyle(.secondary)
            }
            Text("When a terminal goes quiet or finishes while you are not looking at it, Agency HQ sends the terminal's title to this topic. The title is usually a name like \"Claude: myproject\", but programs can set it, so it may show a folder or command. Terminal output is never sent. On ntfy.sh, anyone who knows the topic name can read it, so pick a long, hard-to-guess name.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460)
    }
}
