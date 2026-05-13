//
//  ConcurrencyWorkshopExamples.swift
//  MyWorkshop
//
//  This is the presenter file for the workshop.
//
//  Use it like a code-driven slide deck:
//  1. Uncomment exactly ONE visible lesson view.
//  2. Run the app and show the visual behavior.
//  3. Read the documentation comments below that lesson.
//  4. Swap the bad view for the good view when you want to show the fix.
//

import SwiftUI

struct ConcurrencyWorkshopExamples: View {
    var body: some View {
        // MARK: - 1. @MainActor + Heavy Work

//        MainActorHeavyWorkBadView()

        // BAD:
        // The mistake is putting @MainActor on the heavy-work service:
        //
        //     @MainActor
        //     final class MainActorReportBuilder {
        //         func buildReport() -> Int {
        //             expensiveCPUSimulation()
        //         }
        //     }
        //
        // WHY IT FAILS:
        // MainActor is the UI actor. If the report builder is MainActor-isolated,
        // the CPU loop runs on the same actor that updates buttons, counters,
        // animations, and view state. Tap "Run Heavy Work" and the circle freezes.
        //
        // GOOD:
        // Keep the view model / UI publishing on MainActor, but keep the heavy
        // service as a normal Sendable type and run the CPU work away from UI:
        //
        //     final class BackgroundReportBuilder: Sendable {
        //         func buildReport() async -> Int {
        //             await Task.detached {
        //                 expensiveCPUSimulation()
        //             }.value
        //         }
        //     }
        //
        // Uncomment this view to show the fix:
        //
//         MainActorHeavyWorkGoodView()

        // MARK: - 2. Search Without Cancellation

//         SearchNoCancellationBadView()

        // BAD:
        // The mistake is starting a new Task on every search query and not
        // keeping the task handle:
        //
        //     Task {
        //         let results = try await api.search(query)
        //         self.results = results
        //     }
        //
        // WHY IT FAILS:
        // Old searches keep running. A slow old request can finish after the
        // newest request and overwrite the UI with stale results.
        //
        // GOOD:
        // Store the task, cancel the previous one, debounce a little, and check
        // cancellation before publishing:
        //
        //     searchTask?.cancel()
        //     searchTask = Task {
        //         try await Task.sleep(nanoseconds: 300_000_000)
        //         let results = try await api.search(query)
        //         try Task.checkCancellation()
        //         self.results = results
        //     }
        //
        // Uncomment this view to show the fix:
        //
        // SearchWithCancellationGoodView()

        // MARK: - 3. Task Context Readability

//         TaskContextReadabilityView()

        // BAD STYLE:
        // The mistake is not making the intended actor context obvious:
        //
        //     Task {
        //         let profile = try await endpoint.fetchProfile()
        //         await MainActor.run {
        //             self.title = profile.name
        //         }
        //     }
        //
        // WHY IT IS HARD TO REVIEW:
        // The code might work, but reviewers must infer which work is API work,
        // which work is UI work, and why MainActor.run appears inside the task.
        //
        // GOOD STYLE:
        // Declare intent at the task boundary and make the UI publish explicit:
        //
        //     Task { @WorkshopNetworkAPI in
        //         let profile = try await endpoint.fetchProfile()
        //         await Task { @MainActor in
        //             self.title = profile.name
        //         }.value
        //     }

        // MARK: - 4. Unsafe Escape Hatch vs Actor State

        // UnsafeConcurrencyCounterView()

        // BAD:
        // The mistake is using @unchecked Sendable to silence the compiler for
        // mutable shared reference state:
        //
        //     final class UnsafeCounter: @unchecked Sendable {
        //         var value = 0
        //     }
        //
        // WHY IT FAILS:
        // @unchecked Sendable means "trust me, I synchronized this." If there is
        // no lock, actor, queue, or other protection, concurrent tasks can lose
        // updates while mutating the same instance.
        //
        // GOOD:
        // Put the mutable state behind an actor:
        //
        //     actor SafeCounter {
        //         private var value = 0
        //         func increment() { value += 1 }
        //         func currentValue() -> Int { value }
        //     }
    }
}
