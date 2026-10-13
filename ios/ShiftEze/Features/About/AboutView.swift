import SwiftUI

/// About the app: version, a short privacy summary, the full policy, the
/// TMDB and JustWatch credits their terms require, and how to reach us.
struct AboutView: View {
    var body: some View {
        List {
            Group {
                Section {
                    VStack(spacing: 6) {
                        Text(AppInfo.name)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.gradient)
                        Text("Pay only for the streaming you watch")
                            .foregroundStyle(.secondary)
                        Text("Version \(AppInfo.version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Label("Your subscriptions, watchlist and budget stay on this phone.", systemImage: "iphone")
                    Label("No accounts, ads, analytics or tracking.", systemImage: "hand.raised")
                    Label("Only title searches and lookups go out, to TMDB.", systemImage: "magnifyingglass")
                    NavigationLink("Privacy policy") { PrivacyPolicyView() }
                } header: {
                    Text("Your privacy")
                }

                Section {
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    Text("Streaming availability is provided by JustWatch.")
                    Link("themoviedb.org", destination: URL(string: "https://www.themoviedb.org")!)
                    Link("justwatch.com", destination: URL(string: "https://www.justwatch.com")!)
                } header: {
                    Text("Movie and TV data")
                } footer: {
                    Text("Where a title streams is sometimes wrong or out of date. Check before you subscribe.")
                }

                Section("Contact") {
                    Link(AppInfo.contactEmail, destination: URL(string: "mailto:\(AppInfo.contactEmail)")!)
                }
            }
            .themedRows()
        }
        .themedList()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum AppInfo {
    static let contactEmail = "support@flixshift.app"

    /// The name under the app icon.
    static var name: String { string("CFBundleDisplayName") ?? string("CFBundleName") ?? "" }

    /// e.g. "1.0 (3)".
    static var version: String {
        "\(string("CFBundleShortVersionString") ?? "?") (\(string("CFBundleVersion") ?? "?"))"
    }

    private static func string(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}

/// The full policy, from Resources/PrivacyPolicy.md so there's one copy of
/// the wording. Understands the little Markdown that file uses: `#` and
/// `###` headings, `-` bullets, and inline bold, italics and links.
struct PrivacyPolicyView: View {
    private let blocks = PrivacyPolicy.blocks

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks.indices, id: \.self) { index in
                    switch blocks[index] {
                    case .title(let text):
                        Text(text).font(.title.bold())
                    case .heading(let text):
                        Text(text).font(.headline).padding(.top, 8)
                    case .bullet(let text):
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").foregroundStyle(Theme.accent)
                            Text(text)
                        }
                    case .paragraph(let text):
                        Text(text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Privacy policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum PrivacyPolicy {
    enum Block {
        case title(AttributedString), heading(AttributedString)
        case bullet(AttributedString), paragraph(AttributedString)
    }

    static var blocks: [Block] {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    static func parse(_ markdown: String) -> [Block] {
        markdown.split(separator: "\n", omittingEmptySubsequences: true).map { line in
            if line.hasPrefix("### ") { return .heading(inline(line.dropFirst(4))) }
            if line.hasPrefix("# ") { return .title(inline(line.dropFirst(2))) }
            if line.hasPrefix("- ") { return .bullet(inline(line.dropFirst(2))) }
            return .paragraph(inline(line))
        }
    }

    private static func inline(_ text: Substring) -> AttributedString {
        (try? AttributedString(markdown: String(text))) ?? AttributedString(String(text))
    }
}

#Preview {
    NavigationStack { AboutView() }
}
