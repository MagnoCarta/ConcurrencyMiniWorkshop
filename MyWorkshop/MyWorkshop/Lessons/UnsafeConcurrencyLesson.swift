//
//  UnsafeConcurrencyLesson.swift
//  MyWorkshop
//
//  Visual lesson:
//  @unchecked Sendable can hide a real race. Actors protect mutable state.
//

import SwiftUI

struct UnsafeConcurrencyCounterView: View {
    @StateObject private var logStore = WorkshopLogStore()
    @State private var unsafeResult: Int?
    @State private var safeResult: Int?
    @State private var isRunningUnsafe = false
    @State private var isRunningSafe = false

    private let expectedCount = 1_000

    var body: some View {
        WorkshopScreen(
            badge: "UNSAFE VS ACTOR",
            title: "Shared Mutable State",
            subtitle: "Run the unsafe counter, then run the actor counter. Both try to perform 1,000 increments.",
            tone: .warning
        ) {
            VStack(alignment: .leading, spacing: 18) {
                metricRow
                controls
                WorkshopLogPanel(
                    logStore: logStore,
                    emptyMessage: "Press one of the counter buttons.",
                    minHeight: 190
                )
            }
        }
    }

    private var metricRow: some View {
        HStack(spacing: 12) {
            WorkshopMetric(title: "Expected", value: "\(expectedCount)", tone: .neutral)
            WorkshopMetric(title: "Unsafe", value: unsafeResult.map(String.init) ?? "-", tone: unsafeTone)
            WorkshopMetric(title: "Actor", value: safeResult.map(String.init) ?? "-", tone: safeTone)
        }
    }

    private var unsafeTone: WorkshopTone {
        guard let unsafeResult else { return .warning }
        return unsafeResult == expectedCount ? .warning : .bad
    }

    private var safeTone: WorkshopTone {
        guard let safeResult else { return .good }
        return safeResult == expectedCount ? .good : .bad
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                runUnsafeCounterButton()
            } label: {
                Label(isRunningUnsafe ? "Running Unsafe" : "Run Unsafe Counter", systemImage: "exclamationmark.triangle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunningUnsafe || isRunningSafe)

            Button {
                runSafeCounterButton()
            } label: {
                Label(isRunningSafe ? "Running Actor" : "Run Actor Counter", systemImage: "checkmark.shield.fill")
            }
            .buttonStyle(.bordered)
            .disabled(isRunningUnsafe || isRunningSafe)

            Button {
                reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isRunningUnsafe || isRunningSafe)
        }
    }

    private func runUnsafeCounterButton() {
        isRunningUnsafe = true
        unsafeResult = nil
        logStore.add("BAD: starting 1,000 increments on shared mutable class state.")

        Task { @MainActor in
            let value = await runUnsafeCounter(iterations: expectedCount)
            unsafeResult = value
            isRunningUnsafe = false

            if value == expectedCount {
                logStore.add("BAD: got \(value). Try again; races are timing-dependent.")
            } else {
                logStore.add("BAD: got \(value), so \(expectedCount - value) increments were lost.")
            }
        }
    }

    private func runSafeCounterButton() {
        isRunningSafe = true
        safeResult = nil
        logStore.add("GOOD: starting 1,000 increments through an actor.")

        Task { @MainActor in
            let value = await runActorCounter(iterations: expectedCount)
            safeResult = value
            isRunningSafe = false
            logStore.add("GOOD: got \(value). Actor isolation serialized the mutation.")
        }
    }

    private func reset() {
        unsafeResult = nil
        safeResult = nil
        logStore.reset()
    }
}

private final class UnsafeCounter: @unchecked Sendable {
    var value = 0
}

private actor SafeCounter {
    private var value = 0

    func increment() {
        value += 1
    }

    func currentValue() -> Int {
        value
    }
}

private func runUnsafeCounter(iterations: Int) async -> Int {
    let counter = UnsafeCounter()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<iterations {
            group.addTask {
                let oldValue = counter.value
                await Task.yield()
                counter.value = oldValue + 1
            }
        }
    }

    return counter.value
}

private func runActorCounter(iterations: Int) async -> Int {
    let counter = SafeCounter()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<iterations {
            group.addTask {
                await counter.increment()
            }
        }
    }

    return await counter.currentValue()
}
