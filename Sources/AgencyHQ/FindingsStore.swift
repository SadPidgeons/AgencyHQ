import SwiftUI

struct ReviewFinding: Codable, Identifiable {
    let id = UUID()
    let file: String
    let line: Int?
    let summary: String
    let scenario: String?
    let category: String?
    let verdict: String?

    private enum CodingKeys: String, CodingKey {
        case file, line, summary, scenario, category, verdict
    }
}

struct ReviewReport: Codable {
    let title: String?
    let updated: String?
    let findings: [ReviewFinding]
}

/// Reads review findings from a JSON file that Claude writes after an ultrareview finishes.
/// Location: ~/Library/Application Support/AgencyHQ/findings.json
@MainActor
final class FindingsStore: ObservableObject {
    @Published var report: ReviewReport?
    @Published var loadError: String?
    private var lastStamp: Date?
    private var timer: Timer?

    static let fileURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AgencyHQ/findings.json")

    init() {
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    var count: Int { report?.findings.count ?? 0 }

    func reload() {
        let url = Self.fileURL
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let stamp = attrs[.modificationDate] as? Date else {
            report = nil; loadError = nil; lastStamp = nil
            return
        }
        guard stamp != lastStamp else { return }
        lastStamp = stamp
        do {
            report = try JSONDecoder().decode(ReviewReport.self, from: Data(contentsOf: url))
            loadError = nil
        } catch {
            loadError = "Could not read findings.json: \(error.localizedDescription)"
        }
    }
}

struct FindingsView: View {
    @EnvironmentObject var findings: FindingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text((findings.report?.title ?? "REVIEW FINDINGS").uppercased())
                    .font(Theme.mono(12)).tracking(3).foregroundStyle(Theme.dim)
                if let err = findings.loadError {
                    Text(err).font(Theme.mono(12)).foregroundStyle(.orange)
                } else if let report = findings.report {
                    if report.findings.isEmpty {
                        Text("No findings.").font(Theme.mono(13)).foregroundStyle(Theme.text)
                    }
                    ForEach(report.findings) { f in
                        FindingCard(finding: f)
                    }
                } else {
                    Text("No findings yet. When the review finishes, Claude saves them to\n\(FindingsStore.fileURL.path)")
                        .font(Theme.mono(12)).foregroundStyle(Theme.dim)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.bg)
    }
}

struct FindingCard: View {
    let finding: ReviewFinding
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(finding.line.map { "\(finding.file):\($0)" } ?? finding.file)
                    .font(Theme.mono(11, weight: .semibold)).foregroundStyle(Theme.amber)
                Spacer()
                if let v = finding.verdict {
                    Text(v).font(Theme.mono(10)).foregroundStyle(Theme.dim)
                }
            }
            Text(finding.summary).font(Theme.mono(13)).foregroundStyle(Theme.text)
            if let s = finding.scenario, !s.isEmpty {
                Text(s).font(Theme.mono(11)).foregroundStyle(Theme.dim)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .textSelection(.enabled)
    }
}
