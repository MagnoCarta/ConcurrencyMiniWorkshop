//
//  SearchCancellationLesson.swift
//  MyWorkshop
//
//  Visual lesson:
//  UI-triggered async work needs cancellation when older work becomes obsolete.
//

import Combine
import Foundation
import SwiftUI

struct SearchNoCancellationBadView: View {
    @StateObject private var viewModel = BadSearchViewModel()

    var body: some View {
        SearchLessonScreen(
            badge: "BAD: NO CANCELLATION",
            title: "Search Can Publish Stale Results",
            subtitle: "Type quickly or run the simulator. Old requests keep running and can overwrite the newest results.",
            tone: .bad,
            viewModel: viewModel
        )
    }
}

struct SearchWithCancellationGoodView: View {
    @StateObject private var viewModel = GoodSearchViewModel()

    var body: some View {
        SearchLessonScreen(
            badge: "GOOD: CANCEL OLD TASK",
            title: "Search Publishes Only Latest Results",
            subtitle: "The previous task is canceled before starting the next query, and cancellation is checked before publishing.",
            tone: .good,
            viewModel: viewModel
        )
    }
}

private struct SearchLessonScreen<ViewModel: SearchLessonViewModel>: View {
    let badge: String
    let title: String
    let subtitle: String
    let tone: WorkshopTone
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        WorkshopScreen(
            badge: badge,
            title: title,
            subtitle: subtitle,
            tone: tone
        ) {
            VStack(alignment: .leading, spacing: 18) {
                searchInput
                resultPanel
                WorkshopLogPanel(
                    logStore: viewModel.logStore,
                    emptyMessage: "Type in the search field or press Simulate Fast Typing.",
                    minHeight: 190
                )
            }
        }
    }

    private var searchInput: some View {
        HStack(spacing: 12) {
            TextField("Search for Swift topics", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.query) { _, query in
                    viewModel.queryChanged(query)
                }

            Button {
                Task { @MainActor in
                    await viewModel.simulateFastTyping()
                }
            } label: {
                Label("Simulate Fast Typing", systemImage: "keyboard")
            }
            .buttonStyle(.borderedProminent)

            Button {
                viewModel.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.displayedQuery.isEmpty ? "No results yet" : "Showing: \(viewModel.displayedQuery)")
                    .font(.headline)

                Spacer()

                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if viewModel.results.isEmpty {
                Text("Results will appear here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.results, id: \.self) { result in
                    Label(result, systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary)
        }
    }
}

@MainActor
private protocol SearchLessonViewModel: ObservableObject {
    var query: String { get set }
    var displayedQuery: String { get }
    var results: [String] { get }
    var isSearching: Bool { get }
    var logStore: WorkshopLogStore { get }

    func queryChanged(_ query: String)
    func simulateFastTyping() async
    func reset()
}

private actor WorkshopSearchAPI {
    func search(_ query: String, logStore: WorkshopLogStore) async throws -> [String] {
        let delay = deterministicDelay(for: query)
        let delayText = String(format: "%.2f", Double(delay) / 1_000_000_000)

        await logStore.add("API: started '\(query)' with \(delayText)s delay.")
        try await Task.sleep(nanoseconds: delay)
        try Task.checkCancellation()
        await logStore.add("API: finished '\(query)'.")

        return [
            "\(query) result 1",
            "\(query) result 2",
            "\(query) result 3"
        ]
    }

    private func deterministicDelay(for query: String) -> UInt64 {
        let count = min(max(query.count, 1), 5)
        let seconds = 1.55 - (Double(count) * 0.22)
        return UInt64(seconds * 1_000_000_000)
    }
}

@MainActor
private final class BadSearchViewModel: SearchLessonViewModel {
    @Published var query = ""
    @Published private(set) var displayedQuery = ""
    @Published private(set) var results: [String] = []
    @Published private(set) var isSearching = false

    let logStore = WorkshopLogStore()

    private let api = WorkshopSearchAPI()

    func queryChanged(_ query: String) {
        guard !query.isEmpty else {
            displayedQuery = ""
            results = []
            isSearching = false
            return
        }

        isSearching = true
        logStore.add("BAD UI: launching search for '\(query)' without canceling older tasks.")

        Task {
            do {
                let newResults = try await api.search(query, logStore: logStore)
                displayedQuery = query
                results = newResults
                isSearching = false
                logStore.add("BAD UI: published '\(query)' results.")
            } catch {
                logStore.add("BAD UI: '\(query)' failed with \(error).")
            }
        }
    }

    func simulateFastTyping() async {
        reset()

        for value in ["s", "sw", "swi", "swif", "swift"] {
            query = value
            queryChanged(value)
            try? await Task.sleep(nanoseconds: 160_000_000)
        }
    }

    func reset() {
        query = ""
        displayedQuery = ""
        results = []
        isSearching = false
        logStore.reset()
    }
}

@MainActor
private final class GoodSearchViewModel: SearchLessonViewModel {
    @Published var query = ""
    @Published private(set) var displayedQuery = ""
    @Published private(set) var results: [String] = []
    @Published private(set) var isSearching = false

    let logStore = WorkshopLogStore()

    private let api = WorkshopSearchAPI()
    private var searchTask: Task<Void, Never>?

    func queryChanged(_ query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            displayedQuery = ""
            results = []
            isSearching = false
            logStore.add("GOOD UI: cleared empty query.")
            return
        }

        isSearching = true
        logStore.add("GOOD UI: canceled previous task, preparing '\(query)'.")

        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                let newResults = try await api.search(query, logStore: logStore)
                try Task.checkCancellation()

                displayedQuery = query
                results = newResults
                isSearching = false
                logStore.add("GOOD UI: published latest '\(query)' results.")
            } catch is CancellationError {
                logStore.add("GOOD UI: canceled outdated '\(query)' search.")
            } catch {
                isSearching = false
                logStore.add("GOOD UI: '\(query)' failed with \(error).")
            }
        }
    }

    func simulateFastTyping() async {
        reset()

        for value in ["s", "sw", "swi", "swif", "swift"] {
            query = value
            queryChanged(value)
            try? await Task.sleep(nanoseconds: 160_000_000)
        }
    }

    func reset() {
        searchTask?.cancel()
        searchTask = nil
        query = ""
        displayedQuery = ""
        results = []
        isSearching = false
        logStore.reset()
    }
}
