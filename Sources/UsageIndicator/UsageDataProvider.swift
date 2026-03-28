import Foundation
import Combine
import Security

// MARK: - API Response Models

struct UsageResponse: Codable {
    let five_hour: UsageBucket?
    let seven_day: UsageBucket?
    let seven_day_sonnet: UsageBucket?
    let seven_day_opus: UsageBucket?
    let extra_usage: ExtraUsage?
}

struct UsageBucket: Codable {
    let utilization: Double  // 0-100
    let resets_at: String    // ISO 8601
}

struct ExtraUsage: Codable {
    let is_enabled: Bool?
    let monthly_limit: Double?
    let used_credits: Double?
    let utilization: Double?
}

// MARK: - Local Stats Models

struct StatsCache: Codable {
    let version: Int?
    let lastComputedDate: String?
    let dailyActivity: [DailyActivity]?
    let dailyModelTokens: [DailyModelTokens]?
    let modelUsage: [String: ModelUsage]?
    let totalSessions: Int?
    let totalMessages: Int?
    let hourCounts: [String: Int]?
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
}

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]
}

struct ModelUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadInputTokens: Int
    let cacheCreationInputTokens: Int
}

// MARK: - Combined Snapshot

struct UsageSnapshot {
    // API usage (the important stuff)
    var fiveHourPct: Double = 0
    var fiveHourResets: String = ""
    var sevenDayPct: Double = 0
    var sevenDayResets: String = ""
    var sevenDaySonnetPct: Double = 0
    var sevenDaySonnetResets: String = ""
    var sevenDayOpusPct: Double? = nil
    var sevenDayOpusResets: String? = nil

    // Plan info
    var planName: String = "Max"
    var rateLimitTier: String = ""

    // Local stats
    var totalMessages: Int = 0
    var totalSessions: Int = 0
    var todayMessages: Int = 0
    var todaySessions: Int = 0
    var dailyActivity: [(date: String, messages: Int)] = []

    var hasAPIData: Bool = false
}

// MARK: - Data Provider

class UsageDataProvider: ObservableObject {
    @Published var snapshot = UsageSnapshot()
    @Published var isLoading = true
    @Published var error: String?

    private var timer: Timer?
    private let statsPath: String
    private var accessToken: String?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.statsPath = "\(home)/.claude/stats-cache.json"
        loadCredentials()
        refresh()
        // Refresh every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func loadCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauth = json["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String {
            self.accessToken = token

            if let tier = oauth["rateLimitTier"] as? String {
                DispatchQueue.main.async {
                    self.snapshot.rateLimitTier = tier
                    if tier.contains("20x") {
                        self.snapshot.planName = "Max 20x"
                    } else if tier.contains("5x") {
                        self.snapshot.planName = "Max 5x"
                    }
                }
            }
        }
    }

    func refresh() {
        loadLocalStats()
        fetchAPIUsage()
    }

    private func loadLocalStats() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Load stats-cache for historical data
            let cache: StatsCache? = {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: self.statsPath)) else { return nil }
                return try? JSONDecoder().decode(StatsCache.self, from: data)
            }()

            let todayStr = Self.dateString(Date())
            let fourteenDaysAgo = Self.dateString(Calendar.current.date(byAdding: .day, value: -14, to: Date())!)

            var recent: [(date: String, messages: Int)] = []
            for activity in cache?.dailyActivity ?? [] {
                if activity.date >= fourteenDaysAgo {
                    recent.append((date: activity.date, messages: activity.messageCount))
                }
            }
            recent.sort { $0.date < $1.date }

            // Count today's messages from live session JSONL files
            let (todayMsgs, todaySessions) = self.countTodayFromSessions(todayStr: todayStr)

            DispatchQueue.main.async {
                self.snapshot.totalMessages = (cache?.totalMessages ?? 0) + todayMsgs
                self.snapshot.totalSessions = cache?.totalSessions ?? 0
                self.snapshot.todayMessages = todayMsgs
                self.snapshot.todaySessions = todaySessions
                // Add today to the sparkline if not already there
                if let lastDate = recent.last?.date, lastDate < todayStr {
                    recent.append((date: todayStr, messages: todayMsgs))
                } else if recent.isEmpty {
                    recent.append((date: todayStr, messages: todayMsgs))
                }
                self.snapshot.dailyActivity = recent
            }
        }
    }

    private func countTodayFromSessions(todayStr: String) -> (messages: Int, sessions: Int) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let projectsDir = "\(home)/.claude/projects"
        let fm = FileManager.default

        var totalMsgs = 0
        var sessionCount = 0

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsDir) else {
            return (0, 0)
        }

        for projectDir in projectDirs {
            let fullDir = "\(projectsDir)/\(projectDir)"
            guard let files = try? fm.contentsOfDirectory(atPath: fullDir) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = "\(fullDir)/\(file)"
                guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date,
                      Self.dateString(modDate) == todayStr else { continue }

                var fileMessages = 0
                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { continue }
                for line in content.components(separatedBy: "\n") where !line.isEmpty {
                    if let data = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let type = json["type"] as? String,
                       type == "human" || type == "assistant" {
                        fileMessages += 1
                    }
                }
                if fileMessages > 0 {
                    totalMsgs += fileMessages
                    sessionCount += 1
                }
            }
        }

        return (totalMsgs, sessionCount)
    }

    private func fetchAPIUsage() {
        guard let token = accessToken else {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }

            if let usage = try? JSONDecoder().decode(UsageResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.snapshot.hasAPIData = true
                    if let fh = usage.five_hour {
                        self.snapshot.fiveHourPct = fh.utilization
                        self.snapshot.fiveHourResets = Self.relativeTime(fh.resets_at)
                    }
                    if let sd = usage.seven_day {
                        self.snapshot.sevenDayPct = sd.utilization
                        self.snapshot.sevenDayResets = Self.relativeTime(sd.resets_at)
                    }
                    if let ss = usage.seven_day_sonnet {
                        self.snapshot.sevenDaySonnetPct = ss.utilization
                        self.snapshot.sevenDaySonnetResets = Self.relativeTime(ss.resets_at)
                    }
                    if let so = usage.seven_day_opus {
                        self.snapshot.sevenDayOpusPct = so.utilization
                        self.snapshot.sevenDayOpusResets = Self.relativeTime(so.resets_at)
                    }
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
    }

    static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func relativeTime(_ isoString: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fAlt = ISO8601DateFormatter()
        fAlt.formatOptions = [.withInternetDateTime]

        guard let date = f.date(from: isoString) ?? fAlt.date(from: isoString) else { return isoString }
        let diff = date.timeIntervalSinceNow
        if diff < 0 { return "now" }
        let hours = Int(diff / 3600)
        let mins = Int(diff.truncatingRemainder(dividingBy: 3600) / 60)
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}
