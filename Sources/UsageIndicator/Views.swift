import SwiftUI

// MARK: - Popover Content

struct PopoverContentView: View {
    @ObservedObject var dataProvider: UsageDataProvider
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        let snap = dataProvider.snapshot
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("Claude Code")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                Spacer()
                Text(snap.planName)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.purple.opacity(0.12))
                            .overlay(Capsule().strokeBorder(.purple.opacity(0.2), lineWidth: 0.5))
                    )
            }
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            if dataProvider.isLoading {
                Spacer()
                ProgressView().scaleEffect(0.7)
                Spacer()
                    .frame(height: 80)
            } else {
                VStack(spacing: 12) {
                    UsageBar(label: "Current session", pct: snap.fiveHourPct,
                             resets: snap.fiveHourResets, color: usageBarColor(snap.fiveHourPct))
                    UsageBar(label: "Weekly (all models)", pct: snap.sevenDayPct,
                             resets: snap.sevenDayResets, color: usageBarColor(snap.sevenDayPct))
                    UsageBar(label: "Weekly (Sonnet)", pct: snap.sevenDaySonnetPct,
                             resets: snap.sevenDaySonnetResets, color: usageBarColor(snap.sevenDaySonnetPct))
                    if let opusPct = snap.sevenDayOpusPct {
                        UsageBar(label: "Weekly (Opus)", pct: opusPct,
                                 resets: snap.sevenDayOpusResets ?? "", color: usageBarColor(opusPct))
                    }
                }
                .padding(.horizontal, 18)

                Spacer().frame(height: 14)

                // Bottom stats
                HStack(spacing: 0) {
                    StatColumn(value: "\(snap.todayMessages)", label: "Msgs today")
                    dividerLine
                    StatColumn(value: "\(snap.todaySessions)", label: "Sessions today")
                    dividerLine
                    StatColumn(value: formatNumber(snap.totalMessages), label: "Msgs all time")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(.secondary.opacity(0.08)))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            Divider().padding(.horizontal, 12)

            // Footer: actions & settings
            HStack(spacing: 6) {
                Button(action: { dataProvider.refresh() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Menu {
                    Toggle("Launch at Login", isOn: $appSettings.launchAtLogin)

                    Menu("Refresh Interval") {
                        ForEach([30, 60, 120, 300], id: \.self) { sec in
                            Button {
                                appSettings.refreshInterval = Double(sec)
                            } label: {
                                HStack {
                                    Text(intervalLabel(sec))
                                    if Int(appSettings.refreshInterval) == sec {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "power")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    private var dividerLine: some View {
        Rectangle().fill(.secondary.opacity(0.15)).frame(width: 1, height: 28)
    }

    private func intervalLabel(_ seconds: Int) -> String {
        switch seconds {
        case 30: return "30 seconds"
        case 60: return "1 minute"
        case 120: return "2 minutes"
        case 300: return "5 minutes"
        default: return "\(seconds)s"
        }
    }
}

// MARK: - Usage Bar

struct UsageBar: View {
    let label: String
    let pct: Double
    let resets: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(pct))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                if !resets.isEmpty {
                    Text("resets \(resets)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(colors: [color.opacity(0.9), color],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(min(pct, 100) / 100)))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Stat Column

struct StatColumn: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Color Helpers

func usageColor(_ pct: Double) -> Color {
    if pct >= 80 { return Color(red: 1.0, green: 0.3, blue: 0.3) }
    if pct >= 50 { return Color(red: 1.0, green: 0.7, blue: 0.2) }
    if pct >= 20 { return Color(red: 0.3, green: 0.7, blue: 1.0) }
    return Color(red: 0.3, green: 0.9, blue: 0.5)
}

func usageBarColor(_ pct: Double) -> Color {
    if pct >= 80 { return Color(red: 1.0, green: 0.35, blue: 0.35) }
    if pct >= 50 { return Color(red: 1.0, green: 0.65, blue: 0.2) }
    return Color(red: 0.4, green: 0.6, blue: 1.0)
}

func formatNumber(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
    return "\(n)"
}
