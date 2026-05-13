//
//  MainActorHeavyWorkLesson.swift
//  MyWorkshop
//
//  Visual lesson:
//  @MainActor is correct for UI state, but wrong for expensive CPU services.
//

import Foundation
import SwiftUI

struct MainActorHeavyWorkBadView: View {
    var body: some View {
        MainActorHeavyWorkDemo(mode: .bad)
    }
}

struct MainActorHeavyWorkGoodView: View {
    var body: some View {
        MainActorHeavyWorkDemo(mode: .good)
    }
}

private enum MainActorHeavyWorkMode {
    case bad
    case good

    var badge: String {
        switch self {
        case .bad:
            "BAD: HEAVY SERVICE IS @MainActor"
        case .good:
            "GOOD: HEAVY SERVICE IS NOT @MainActor"
        }
    }

    var title: String {
        switch self {
        case .bad:
            "MainActor Freeze"
        case .good:
            "MainActor Stays Responsive"
        }
    }

    var subtitle: String {
        switch self {
        case .bad:
            "Tap the heavy-work button. The animation and tick counter freeze because CPU work runs on the UI actor."
        case .good:
            "Tap the heavy-work button. The animation and tick counter continue because CPU work runs away from the UI actor."
        }
    }

    var tone: WorkshopTone {
        switch self {
        case .bad:
            .bad
        case .good:
            .good
        }
    }

    var buttonTitle: String {
        switch self {
        case .bad:
            "Run Heavy Work on MainActor"
        case .good:
            "Run Heavy Work Off MainActor"
        }
    }
}

private struct MainActorHeavyWorkDemo: View {
    let mode: MainActorHeavyWorkMode

    @StateObject private var logStore = WorkshopLogStore()
    @State private var uiTicks = 0
    @State private var tapCount = 0
    @State private var checksum: Int?
    @State private var isWorking = false
    @State private var tickerTask: Task<Void, Never>?
    @State private var workTask: Task<Void, Never>?

    var body: some View {
        WorkshopScreen(
            badge: mode.badge,
            title: mode.title,
            subtitle: mode.subtitle,
            tone: mode.tone
        ) {
            VStack(alignment: .leading, spacing: 18) {
                liveSurface
                controls
                WorkshopLogPanel(
                    logStore: logStore,
                    emptyMessage: "Press the heavy-work button. Try pressing Tap Counter before and after.",
                    minHeight: 170
                )
            }
        }
        .onAppear {
            startTicker()
        }
        .onDisappear {
            tickerTask?.cancel()
            workTask?.cancel()
        }
    }

    private var liveSurface: some View {
        HStack(alignment: .center, spacing: 22) {
            spinningCircle

            VStack(alignment: .leading, spacing: 14) {
                Text(isWorking ? "Heavy work running" : "Ready")
                    .font(.headline)
                    .foregroundStyle(isWorking ? mode.tone.tint : .primary)

                HStack(spacing: 12) {
                    WorkshopMetric(title: "UI ticks", value: "\(uiTicks)", tone: mode.tone)
                    WorkshopMetric(title: "Taps", value: "\(tapCount)", tone: .neutral)
                    WorkshopMetric(title: "Checksum", value: checksum.map(String.init) ?? "-", tone: .neutral)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary)
        }
    }

    private var spinningCircle: some View {
        TimelineView(.animation) { context in
            let seconds = context.date.timeIntervalSinceReferenceDate

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 10)

                Circle()
                    .trim(from: 0.05, to: 0.85)
                    .stroke(
                        mode.tone.tint,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(seconds * 180))

                Text(isWorking ? "Work" : "Live")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 112, height: 112)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                tapCount += 1
                logStore.add("UI: tap counter is now \(tapCount).")
            } label: {
                Label("Tap Counter", systemImage: "hand.tap.fill")
            }
            .buttonStyle(.bordered)

            Button {
                runHeavyWork()
            } label: {
                Label(mode.buttonTitle, systemImage: "cpu")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking)

            Button {
                reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func startTicker() {
        guard tickerTask == nil else { return }

        tickerTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    return
                }

                uiTicks += 1
            }
        }
    }

    private func runHeavyWork() {
        workTask?.cancel()
        checksum = nil
        isWorking = true
        logStore.add("UI: heavy-work button tapped.")

        workTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                isWorking = false
                return
            }

            switch mode {
            case .bad:
                logStore.add("BAD: calling @MainActor service. UI actor is blocked now.")
                checksum = MainActorReportBuilder.shared.buildReport()
                logStore.add("BAD: finished. The missing tick gap is the frozen UI.")
            case .good:
                logStore.add("GOOD: calling normal service. CPU work leaves MainActor.")
                checksum = await BackgroundReportBuilder.shared.buildReport()
                logStore.add("GOOD: finished. UI kept ticking while work ran.")
            }

            isWorking = false
        }
    }

    private func reset() {
        workTask?.cancel()
        workTask = nil
        isWorking = false
        uiTicks = 0
        tapCount = 0
        checksum = nil
        logStore.reset()
    }
}

@MainActor
private final class MainActorReportBuilder {
    static let shared = MainActorReportBuilder()

    private init() {}

    func buildReport() -> Int {
        expensiveCPUSimulation(label: "MainActor report")
    }
}

private final class BackgroundReportBuilder: Sendable {
    static let shared = BackgroundReportBuilder()

    private init() {}

    func buildReport() async -> Int {
        await Task.detached(priority: .userInitiated) {
            expensiveCPUSimulation(label: "Background report")
        }.value
    }
}

private func expensiveCPUSimulation(label: String) -> Int {
    var checksum = 0
    let start = Date()

    for i in 0..<170_000_000 {
        checksum &+= (i &* 31)

        if i % 4_000_000 == 0, Date().timeIntervalSince(start) > 2.5 {
            break
        }
    }

    print("CPU: \(label) finished with checksum \(checksum).")
    return checksum
}
