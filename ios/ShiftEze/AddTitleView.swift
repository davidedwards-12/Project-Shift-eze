import RotationEngine
import SwiftUI
import TMDB

/// The + sheet on the Watchlist tab. Stays open so several titles can be
/// added in a row.
struct AddTitleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TitleSearchView()
                .navigationTitle("Add a title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

/// Search TMDB and add movies and shows to the watchlist; tapping a checked
/// title removes it again. Used by the + sheet and by onboarding.
struct TitleSearchView: View {
    @Environment(AppModel.self) private var model
    /// Put the cursor in the search field straight away.
    var autoFocus = true

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var status: Status = .idle
    /// The result whose streaming info is being fetched.
    @State private var adding: SearchResult.ID?
    @State private var addError: String?
    @FocusState private var searchFocused: Bool

    private enum Status: Equatable {
        case idle, searching, done
        case failed(String)
    }

    private let client = AppConfig.tmdbClient

    var body: some View {
        Group {
            if client == nil {
                ContentUnavailableView(
                    "TMDB key not set",
                    systemImage: "key",
                    description: Text("Add TMDB_API_KEY to ios/Secrets.xcconfig to search.")
                )
            } else {
                resultsList
            }
        }
        // A plain field rather than .searchable: the system search bar
        // hides the title and Done while it's active, which looked like a
        // second sheet opening.
        .safeAreaInset(edge: .top) {
            if client != nil {
                SearchField(text: $query, focused: $searchFocused)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .onAppear { searchFocused = autoFocus && client != nil }
        .task(id: query) { await search() }
        .alert("Couldn't add it", isPresented: .constant(addError != nil)) {
            Button("OK") { addError = nil }
        } message: {
            Text(addError ?? "")
        }
    }

    private var resultsList: some View {
        List {
            switch status {
            case .searching where results.isEmpty:
                Section { ProgressView().frame(maxWidth: .infinity) }
            case .done where results.isEmpty:
                ContentUnavailableView.search(text: query)
            case .failed(let message):
                Section { Label(message, systemImage: "exclamationmark.triangle") }
            default:
                EmptyView()
            }

            if !results.isEmpty {
                Section {
                    ForEach(results) { result in
                        ResultRow(
                            result: result,
                            onWatchlist: model.watchlist.contains { $0.id == result.id },
                            isAdding: adding == result.id
                        ) {
                            Task { await toggle(result) }
                        }
                        .disabled(adding != nil)
                    }
                } footer: {
                    Text("Search by TMDB. This product uses the TMDB API but is not endorsed or certified by TMDB. Streaming availability from JustWatch.")
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard let client, !text.isEmpty else {
            results = []
            status = .idle
            return
        }
        // Wait for typing to pause; a new keystroke cancels this task.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        status = .searching
        do {
            let found = try await client.search(text)
            guard !Task.isCancelled else { return }
            results = found
            status = .done
        } catch {
            guard !Task.isCancelled else { return }
            status = .failed(error.userMessage)
        }
    }

    /// Add the title, or take it back off if it's already on the watchlist
    /// (e.g. tapped by mistake).
    private func toggle(_ result: SearchResult) async {
        if model.watchlist.contains(where: { $0.id == result.id }) {
            model.watchlist.removeAll { $0.id == result.id }
        } else {
            await add(result)
        }
    }

    private func add(_ result: SearchResult) async {
        guard let client else { return }
        adding = result.id
        defer { adding = nil }
        do {
            let providers = try await client.providers(for: result)
            model.watchlist.append(result.watchlistEntry(providers: providers, checkedOn: model.today))
        } catch {
            addError = error.userMessage
        }
    }

}

private struct SearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Movies and TV shows", text: $text)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.fill.tertiary, in: .capsule)
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let onWatchlist: Bool
    let isAdding: Bool
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            HStack(spacing: 12) {
                AsyncImage(url: result.posterURL()) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                        .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                }
                .frame(width: 46, height: 69)
                .clipShape(.rect(cornerRadius: 6))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title).font(.headline)
                    Text(details).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if onWatchlist {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        .accessibilityLabel("On your watchlist. Tap to remove.")
                } else if isAdding {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle").foregroundStyle(.tint)
                        .accessibilityLabel("Add")
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var details: String {
        [result.year, result.mediaType == .tv ? "TV show" : "Movie"].compactMap { $0 }.joined(separator: " · ")
    }
}

#Preview {
    AddTitleView().environment(AppModel.sample())
}
