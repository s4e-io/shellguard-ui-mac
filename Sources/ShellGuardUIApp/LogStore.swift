import Foundation

// MARK: - Log Entry (JSON shape on disk)

struct LogEntry: Codable {
    let timestamp: String
    let command: String
    let reason: String
    let user: String
    let process: String
    let pid: String
    let blocked: Bool?   // optional: older log lines may not have this field
    let type: String?    // "execution" | "suggestion" | nil
}

// MARK: - Log Store

final class LogStore {

    static let maxEvents = 500

    /// Load the most recent events from the JSONL log file, newest first.
    static func load() -> [AppViewModel.Event] {
        guard let content = try? String(contentsOf: PolicyLoader.logFileURL, encoding: .utf8) else {
            return []
        }
        let decoder = JSONDecoder()
        let lines = content
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        return lines
            .suffix(maxEvents)
            .compactMap { line -> AppViewModel.Event? in
                guard let data = line.data(using: .utf8),
                      let entry = try? decoder.decode(LogEntry.self, from: data) else { return nil }
                return AppViewModel.Event(
                    timestamp: entry.timestamp,
                    command: entry.command,
                    reason: entry.reason,
                    user: entry.user,
                    process: entry.process,
                    pid: entry.pid
                )
            }
            .reversed()
    }

    /// All entries after a given timestamp (for sync). Pass nil to get all entries.
    /// ISO-8601 strings are lexicographically sortable, so string comparison is safe.
    static func entries(after timestamp: String?) -> [LogEntry] {
        guard let content = try? String(contentsOf: PolicyLoader.logFileURL, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.compactMap { line -> LogEntry? in
            guard let data = line.data(using: .utf8),
                  let entry = try? decoder.decode(LogEntry.self, from: data) else { return nil }
            if let after = timestamp {
                return entry.timestamp > after ? entry : nil
            }
            return entry
        }
    }

    /// Append a single event as a JSON line to the log file.
    static func append(_ event: AppViewModel.Event) {
        let entry = LogEntry(
            timestamp: event.timestamp,
            command: event.command,
            reason: event.reason,
            user: event.user,
            process: event.process,
            pid: event.pid,
            blocked: nil,
            type: nil
        )
        guard let data = try? JSONEncoder().encode(entry),
              let line = String(data: data, encoding: .utf8) else { return }

        let url = PolicyLoader.logFileURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(Data((line + "\n").utf8))
            }
        } else {
            try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Seed the log file with sample data when it doesn't exist yet (first run / demo).
    static func seedIfNeeded() {
        guard !FileManager.default.fileExists(atPath: PolicyLoader.logFileURL.path) else { return }
        let now = Date()
        let cal = Calendar.current
        func iso(_ secondsAgo: TimeInterval) -> String {
            let d = now.addingTimeInterval(-secondsAgo)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.string(from: d)
        }
        let samples: [AppViewModel.Event] = [
            .init(timestamp: iso(86400 * 2 + 3600),  command: "mv config.json config.bak",      reason: "File move ops blocked in Custom mode.",       user: "oa", process: "tmux",   pid: "26481"),
            .init(timestamp: iso(86400 + 7200),       command: "sudo npm install -g eslint",     reason: "Elevated privilege commands blocked.",         user: "oa", process: "claude", pid: "27650"),
            .init(timestamp: iso(86400 + 3600),       command: "ssh user@remote.host",           reason: "Remote shell connections blocked by policy.",  user: "oa", process: "zsh",    pid: "28774"),
            .init(timestamp: iso(3600 * 3),           command: "rm -rf ./node_modules",          reason: "Destructive file ops blocked in Custom mode.", user: "oa", process: "claude", pid: "31201"),
            .init(timestamp: iso(3600 * 2 + 600),     command: "osascript -e 'tell app Finder'", reason: "System automation not allowed.",               user: "oa", process: "zsh",    pid: "29301"),
            .init(timestamp: iso(3600),               command: "curl https://api.example.com",   reason: "Outbound network blocked by policy.",          user: "oa", process: "iTerm2", pid: "31842"),
            .init(timestamp: iso(300),                command: "git push origin main",           reason: "Git write ops blocked in Custom mode.",        user: "oa", process: "claude", pid: "31842"),
        ]
        samples.forEach { append($0) }
    }
}
