import SwiftUI

struct WakeSleepRows: View {
    @AppStorage(Pet.taxKeyWake) private var wakeMinutes: Int = Pet.taxDefaultWake
    @AppStorage(Pet.taxKeySleep) private var sleepMinutes: Int = Pet.taxDefaultSleep

    var body: some View {
        Group {
            DatePicker(
                "Wake up",
                selection: wakeBinding,
                displayedComponents: .hourAndMinute
            )
            DatePicker(
                "Bedtime",
                selection: sleepBinding,
                in: sleepRange,
                displayedComponents: .hourAndMinute
            )
        }
        .onChange(of: wakeMinutes) { _, newValue in
            // Keep bedtime at least 1 minute after wake, never past 23:59.
            if sleepMinutes <= newValue {
                sleepMinutes = min(WakeSleepRows.maxMinutes, newValue + 60)
            }
        }
    }

    static let maxMinutes = 23 * 60 + 59

    private var wakeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: wakeMinutes) },
            set: { wakeMinutes = Self.minutes(fromDate: $0) }
        )
    }

    private var sleepBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: sleepMinutes) },
            set: { sleepMinutes = min(WakeSleepRows.maxMinutes, Self.minutes(fromDate: $0)) }
        )
    }

    private var sleepRange: ClosedRange<Date> {
        let lower = Self.date(fromMinutes: min(wakeMinutes + 1, WakeSleepRows.maxMinutes))
        let upper = Self.date(fromMinutes: WakeSleepRows.maxMinutes)
        return lower...upper
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return start.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private static func minutes(fromDate date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
