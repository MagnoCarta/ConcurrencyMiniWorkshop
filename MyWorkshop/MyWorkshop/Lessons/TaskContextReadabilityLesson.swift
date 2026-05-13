//
//  TaskContextReadabilityLesson.swift
//  MyWorkshop
//
//  Visual lesson:
//  Some concurrency issues are readability issues. Show the code side by side.
//

import SwiftUI

struct TaskContextReadabilityView: View {
    var body: some View {
        WorkshopScreen(
            badge: "STYLE: TASK CONTEXT",
            title: "Which Task Is Easier To Review?",
            subtitle: "This lesson is intentionally visual as code. The goal is to compare intent, not to force a runtime failure.",
            tone: .neutral
        ) {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 340), spacing: 16)],
                    alignment: .leading,
                    spacing: 16
                ) {
                    WorkshopCodePanel(
                        title: "Bad Style: Context Is Implicit",
                        code: badStyleCode,
                        tone: .bad
                    )

                    WorkshopCodePanel(
                        title: "Good Style: Context Is Declared",
                        code: goodStyleCode,
                        tone: .good
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Review question", systemImage: "questionmark.circle")
                        .font(.headline)

                    Text("Can a teammate see where API work runs and where UI state is published without reading every line inside the task?")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
    }

    private var badStyleCode: String {
        """
        @MainActor
        final class ProfileViewModel {
            private let endpoint = ProfileEndpoint()
            private(set) var title = "No profile"

            func loadProfile() {
                Task {
                    isLoading = true

                    do {
                        let profile = try await endpoint.fetchProfile()

                        await MainActor.run {
                            self.title = "Hello, \\(profile.name)"
                            self.isLoading = false
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                            self.isLoading = false
                        }
                    }
                }
            }
        }
        """
    }

    private var goodStyleCode: String {
        """
        @MainActor
        final class ProfileViewModel {
            private let endpoint = ProfileEndpoint()
            private(set) var title = "No profile"

            func loadProfile() {
                isLoading = true

                Task { @WorkshopNetworkAPI [endpoint] in
                    do {
                        let profile = try await endpoint.fetchProfile()

                        await Task { @MainActor in
                            self.title = "Hello, \\(profile.name)"
                            self.isLoading = false
                        }.value
                    } catch {
                        await Task { @MainActor in
                            self.errorMessage = error.localizedDescription
                            self.isLoading = false
                        }.value
                    }
                }
            }
        }
        """
    }
}
