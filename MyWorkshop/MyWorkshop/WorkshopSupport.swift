//
//  WorkshopSupport.swift
//  MyWorkshop
//
//  Small reusable UI pieces for the concurrency workshop.
//

import Combine
import SwiftUI

@MainActor
final class WorkshopLogStore: ObservableObject {
    @Published private(set) var lines: [String] = []

    func add(_ message: String) {
        print(message)
        lines.append(message)
    }

    func reset() {
        lines.removeAll()
    }
}

enum WorkshopTone {
    case bad
    case good
    case neutral
    case warning

    var tint: Color {
        switch self {
        case .bad:
            .red
        case .good:
            .green
        case .neutral:
            .blue
        case .warning:
            .orange
        }
    }
}

struct WorkshopScreen<Content: View>: View {
    let badge: String
    let title: String
    let subtitle: String
    let tone: WorkshopTone
    let content: Content

    init(
        badge: String,
        title: String,
        subtitle: String,
        tone: WorkshopTone,
        @ViewBuilder content: () -> Content
    ) {
        self.badge = badge
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tone.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tone.tint.opacity(0.12), in: Capsule())

                    Text(title)
                        .font(.title.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .frame(minWidth: 720, minHeight: 620)
    }
}

struct WorkshopMetric: View {
    let title: String
    let value: String
    var tone: WorkshopTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(12)
        .frame(minWidth: 116, alignment: .leading)
        .background(tone.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tone.tint.opacity(0.25))
        }
    }
}

struct WorkshopLogPanel: View {
    @ObservedObject var logStore: WorkshopLogStore
    var emptyMessage = "Run the demo to see events."
    var minHeight: CGFloat = 180

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if logStore.lines.isEmpty {
                        Text(emptyMessage)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(logStore.lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                }
                .padding(14)
            }
            .frame(minHeight: minHeight)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            }
            .onChange(of: logStore.lines.count) { _, count in
                guard count > 0 else { return }

                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(count - 1, anchor: .bottom)
                }
            }
        }
    }
}

struct WorkshopCodePanel: View {
    let title: String
    let code: String
    var tone: WorkshopTone = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tone.tint)

            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(tone.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(tone.tint.opacity(0.25))
        }
    }
}
