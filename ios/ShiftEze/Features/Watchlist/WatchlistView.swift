import RotationEngine
import SwiftUI

/// What the user wants to watch, in priority order, and where each title streams.
struct WatchlistView: View {
    @Environment(AppModel.self) private var model
    @State private var addingTitle = false

    var body: some View {
        @Bindable var model = model
        let titles = Dictionary(model.titles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let toWatch = model.watchlist.filter { $0.watchedOn == nil }
        let watched = model.watchlist.filter { $0.watchedOn != nil }
        NavigationStack {
            List {
                Group {
                    Section {
                        ForEach(toWatch, id: \.id) { entry in
                            NavigationLink {
                                TitleDetailView(id: entry.id)
                            } label: {
                                WatchlistRow(title: titles[entry.id], isChecking: model.refreshing.contains(entry.id))
                            }
                            .swipeActions(edge: .leading) {
                                Button("Watched", systemImage: "checkmark") {
                                    withAnimation { model.setWatched(true, titleID: entry.id) }
                                }
                                .tint(Theme.Palette.violet)
                            }
                        }
                        .onDelete { offsets in model.removeFromWatchlist(ids: offsets.map { toWatch[$0].id }) }
                        .onMove { model.moveToWatch(fromOffsets: $0, toOffset: $1) }
                    } footer: {
                        Text("Higher in the list is planned sooner. Swipe right when you've watched something; tap Edit to reorder or remove.")
                    }

                    if !watched.isEmpty {
                        Section {
                            ForEach(watched, id: \.id) { entry in
                                NavigationLink {
                                    TitleDetailView(id: entry.id)
                                } label: {
                                    WatchlistRow(title: titles[entry.id], isChecking: false, watchedOn: entry.watchedOn)
                                }
                                .swipeActions(edge: .leading) {
                                    Button("Not watched", systemImage: "arrow.uturn.backward") {
                                        withAnimation { model.setWatched(false, titleID: entry.id) }
                                    }
                                    .tint(.gray)
                                }
                            }
                            .onDelete { offsets in model.removeFromWatchlist(ids: offsets.map { watched[$0].id }) }
                        } header: {
                            Text("Watched")
                        } footer: {
                            Text("Not in your plan any more. Swipe right to put one back.")
                        }
                    }
                }
                .themedRows()
            }
            .themedList()
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
    var watchedOn: CalendarDate? = nil

    var body: some View {
        if let title {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.name).font(.headline)
                    .foregroundStyle(watchedOn == nil ? .primary : .secondary)
                Text(whereToWatch(title)).font(.subheadline).foregroundStyle(.secondary)
                if let watchedOn {
                    Text("Watched \(watchedOn.short)").font(.caption).foregroundStyle(.tertiary)
                } else if isChecking {
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
