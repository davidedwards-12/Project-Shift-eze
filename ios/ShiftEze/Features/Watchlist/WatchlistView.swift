import RotationEngine
import SwiftUI

/// What the user wants to watch, in priority order, and where each title streams.
struct WatchlistView: View {
    @Environment(AppModel.self) private var model
    @State private var addingTitle = false

    var body: some View {
        @Bindable var model = model
        let titles = Dictionary(model.titles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        NavigationStack {
            List {
                Section {
                    ForEach(model.watchlist, id: \.id) { entry in
                        NavigationLink {
                            TitleDetailView(id: entry.id)
                        } label: {
                            WatchlistRow(title: titles[entry.id], isChecking: model.refreshing.contains(entry.id))
                        }
                    }
                    .onDelete { model.watchlist.remove(atOffsets: $0) }
                    .onMove { model.watchlist.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Higher in the list is planned sooner. New titles go at the bottom; tap Edit to reorder or remove.")
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") { addingTitle = true }
                }
            }
            .sheet(isPresented: $addingTitle) { AddTitleView() }
        }
    }
}

private struct WatchlistRow: View {
    let title: Title?
    let isChecking: Bool

    var body: some View {
        if let title {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.name).font(.headline)
                Text(whereToWatch(title)).font(.subheadline).foregroundStyle(.secondary)
                if isChecking {
                    Text("Checking…").font(.caption).foregroundStyle(.tertiary)
                } else if let checked = title.checkedOn {
                    Text("Checked \(checked.short)").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func whereToWatch(_ title: Title) -> String {
        var parts: [String] = []
        if !title.services.isEmpty { parts.append(title.services.formatted()) }
        if !title.free.isEmpty { parts.append("Free on \(title.free.formatted())") }
        if !title.library.isEmpty { parts.append("Library: \(title.library.formatted())") }
        return parts.isEmpty ? "Not on a tracked service" : parts.joined(separator: " · ")
    }
}

#Preview {
    WatchlistView().environment(AppModel.sample())
}
