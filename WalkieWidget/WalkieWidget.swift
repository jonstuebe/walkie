import WidgetKit
import SwiftUI

struct PetEntry: TimelineEntry {
    let date: Date
    let snapshot: PetSnapshot?
}

struct PetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetEntry {
        PetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetEntry) -> Void) {
        completion(PetEntry(date: Date(), snapshot: PetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetEntry>) -> Void) {
        let entry = PetEntry(date: Date(), snapshot: PetSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct WalkieWidget: Widget {
    let kind = "WalkieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PetProvider()) { entry in
            WalkieWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackdrop()
                }
        }
        .configurationDisplayName("Walkie")
        .description("Check on your koala and today's steps.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WalkieWidgetView: View {
    var entry: PetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:
                SmallWidget(snapshot: snapshot)
            default:
                MediumWidget(snapshot: snapshot)
            }
        } else {
            EmptyStateView()
        }
    }
}

private struct SmallWidget: View {
    var snapshot: PetSnapshot

    var body: some View {
        VStack(spacing: 4) {
            KoalaView(
                color: Color(hex: snapshot.colorHex),
                bodyScale: snapshot.bodyScale,
                animated: false
            )
            .scaleEffect(0.46)
            .frame(height: 100)

            VStack(spacing: 1) {
                Text(snapshot.stepsToday, format: .number)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Label("\(snapshot.leavesAvailable)", systemImage: "leaf.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.7))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MediumWidget: View {
    var snapshot: PetSnapshot

    private var progress: Double {
        guard snapshot.stepGoal > 0 else { return 0 }
        return min(1.0, Double(snapshot.stepsToday) / Double(snapshot.stepGoal))
    }

    var body: some View {
        HStack(spacing: 12) {
            KoalaView(
                color: Color(hex: snapshot.colorHex),
                bodyScale: snapshot.bodyScale,
                animated: false
            )
            .scaleEffect(0.52)
            .frame(width: 110, height: 130)

            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11, weight: .bold))
                        Text(snapshot.stepsToday, format: .number)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                        Text("/ \(snapshot.stepGoal)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .foregroundStyle(.white)

                    ProgressBar(progress: progress)
                        .frame(height: 6)
                }

                HStack(spacing: 10) {
                    StatPill(
                        icon: "leaf.fill",
                        value: "\(snapshot.leavesAvailable)",
                        tint: Color(red: 0.5, green: 0.9, blue: 0.6)
                    )
                    HeartRow(halfHearts: snapshot.halfHearts, size: 11, spacing: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.5, green: 0.9, blue: 0.6),
                            Color(red: 0.35, green: 0.75, blue: 0.5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(6, geo.size.width * progress))
            }
        }
    }
}

private struct StatPill: View {
    var icon: String
    var value: String
    var tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.12), in: Capsule())
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Open Walkie to adopt a koala")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct WidgetBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.26, blue: 0.20),
                    Color(red: 0.04, green: 0.14, blue: 0.11)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.95, blue: 0.65).opacity(0.18),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.85),
                startRadius: 10,
                endRadius: 200
            )
        }
    }
}

#Preview(as: .systemSmall) {
    WalkieWidget()
} timeline: {
    PetEntry(date: Date(), snapshot: .placeholder)
}

#Preview(as: .systemMedium) {
    WalkieWidget()
} timeline: {
    PetEntry(date: Date(), snapshot: .placeholder)
    PetEntry(date: Date(), snapshot: nil)
}
