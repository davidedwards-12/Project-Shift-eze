import RotationEngine
import SwiftUI
import TMDB

/// One watchlist title: where it streams, when that was last checked, and a
/// way to say TMDB is wrong about a service.
struct TitleDetailView: View {
    @Environment(AppModel.self) private var model
    let id: String
    @State private var checkResult: AppModel.CheckResult?
    @State private var checkedAt: Date?

    private var title: Title? { model.titles.first { $0.id == id } }
    private var fromTMDB: Bool { SearchResult.reference(fromID: id) != nil }

    var body: some View {
        if let title {
            List {
                Section {
                    let listed = (title.services + title.notOn).sorted()
                    if listed.isEmpty {
                        Text("Not on any service we track").foregroundStyle(.secondary)
                    }
                    ForEach(listed, id: \.self) { service in
                        ServiceAvailabilityRow(
                            service: service,
                            isNotOn: title.notOn.contains(service),
                            toggle: { model.setNotOn(service, !title.notOn.contains(service), titleID: id) }
                        )
                    }
                } header: {
                    Text("Streaming on")
                } footer: {
                    Text("Tap \"Not there?\" if you checked and it isn't on that service. We'll plan around it.")
                }

                if !title.free.isEmpty || !title.library.isEmpty {
                    Section("Free") {
                        if !title.free.isEmpty {
                            LabeledContent("With ads", value: title.free.formatted())
                        }
                        if !title.library.isEmpty {
                            LabeledContent("With a library card", value: title.library.formatted())
                        }
                    }
                }

                Section {
                    LabeledContent("Last checked", value: title.checkedOn?.short ?? "Never")
                    if fromTMDB {
                        let checking = model.refreshing.contains(id)
                        Button {
                            checkResult = nil
                            Task {
                                checkResult = await model.checkNow(id)
                                checkedAt = .now
                            }
                        } label: {
                            HStack {
                                Text(checking ? "Checking…" : "Check again now")
                                Spacer()
                                if checking { ProgressView() }
                            }
                            .contentShape(.rect)
                        }
                        .disabled(checking || AppConfig.tmdbClient == nil)
                        if let checkResult, let checkedAt, !checking {
                            CheckResultRow(result: checkResult, at: checkedAt)
                        }
                    }
                } footer: {
                    Text(fromTMDB
                         ? "Streaming availability from JustWatch via TMDB. It's sometimes wrong or out of date, so we re-check it every week, and daily before you're due to subscribe for it."
                         : "This title was added from sample data, so it can't be re-checked. Remove it and add it again with + to get live availability.")
                }
            }
            .navigationTitle(title.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Not on your watchlist", systemImage: "questionmark.circle")
        }
    }
}

private struct CheckResultRow: View {
    let result: AppModel.CheckResult
    /// Shown so a repeat check visibly differs from the last one.
    let at: Date

    private var time: String { at.formatted(date: .omitted, time: .shortened) }

    var body: some View {
        switch result {
        case .unchanged:
            Label("Up to date as of \(time). Nothing has changed.", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case .changed:
            Label("Updated at \(time). Where it streams has changed.", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}

private struct ServiceAvailabilityRow: View {
    let service: String
    let isNotOn: Bool
    let toggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(service)
                    .strikethrough(isNotOn)
                    .foregroundStyle(isNotOn ? .secondary : .primary)
                if isNotOn {
                    Text("You said it isn't here").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(isNotOn ? "Undo" : "Not there?", action: toggle)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(isNotOn ? "Undo: it is on \(service)" : "It's not on \(service)")
        }
    }
}

#Preview {
    NavigationStack { TitleDetailView(id: "Stranger Things") }.environment(AppModel.sample())
}
