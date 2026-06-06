import Foundation
import SwiftUI

private extension DateFormatter {
    static let shortTime: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    /// Parses Python isoformat() output: "2026-03-30T14:08:23.412731" (no tz)
    static let isoNoTZ: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()
}

final class AppViewModel: ObservableObject {
    enum GuardMode: String, CaseIterable, Identifiable {
        case logOnly = "Log Only"
        case custom  = "Custom"
        case dev     = "Dev"
        case locked  = "Read Only"

        var id: String { rawValue }

        var summary: String {
            switch self {
            case .logOnly:
                return "Nothing is blocked. All commands are logged so you can review before restricting."
            case .custom:
                return "Your personal policy. Edit policy.yaml to define exactly what's allowed."
            case .dev:
                return "Built for development. Git, build tools, and scripts allowed. Network blocked."
            case .locked:
                return "Read-only commands only. All writes, network, and automation blocked."
            }
        }

        var allowedCommands: [String] {
            switch self {
            case .logOnly:
                return []  // all commands pass through

            case .custom:
                return [
                    // Navigation & info
                    "ls", "ll", "la", "find", "pwd", "tree", "du", "df", "stat", "file",
                    // Reading
                    "cat", "head", "tail", "less", "more", "grep", "rg", "ag", "wc", "diff",
                    // Git (read)
                    "git status", "git diff", "git log", "git show", "git branch", "git stash list",
                    // Misc
                    "echo", "which", "type", "env", "printenv", "date", "whoami", "id", "uname",
                    "jq", "yq", "sort", "uniq", "cut", "tr", "awk", "sed",
                ]

            case .dev:
                return [
                    // Navigation & info
                    "ls", "ll", "la", "find", "pwd", "tree", "du", "df", "stat", "file",
                    // Reading & text
                    "cat", "head", "tail", "less", "more", "grep", "rg", "ag", "wc", "diff",
                    "jq", "yq", "sort", "uniq", "cut", "tr", "awk", "sed",
                    // Git (full except push/reset --hard)
                    "git status", "git diff", "git log", "git show", "git branch",
                    "git add", "git commit", "git checkout", "git switch", "git restore",
                    "git merge", "git rebase", "git stash", "git tag", "git fetch",
                    "git cherry-pick", "git blame", "git shortlog",
                    // Package managers
                    "npm", "npx", "yarn", "pnpm", "bun",
                    "pip", "pip3", "poetry", "uv",
                    "cargo", "go", "swift build", "swift test", "swift run",
                    "mvn", "gradle", "make", "cmake", "ninja",
                    "gem", "bundle", "composer",
                    // Runtimes
                    "node", "python", "python3", "ruby", "java", "deno",
                    // Containers & tools
                    "docker", "docker compose", "docker-compose",
                    "kubectl", "helm",
                    // Build & test
                    "xcodebuild", "xcrun", "swiftlint", "swiftformat",
                    "jest", "pytest", "mocha", "vitest", "rspec",
                    // Misc dev tools
                    "echo", "which", "type", "env", "printenv", "date", "whoami",
                    "uname", "lsof", "ps", "top", "htop",
                    "code", "cursor", "vim", "nvim", "nano",
                ]

            case .locked:
                return [
                    // Read-only navigation
                    "ls", "ll", "la", "find", "pwd", "tree",
                    // Read-only file viewing
                    "cat", "head", "tail", "less", "more",
                    "grep", "rg", "ag", "wc", "diff", "stat", "file",
                    // Git read-only
                    "git status", "git log", "git diff", "git show", "git branch",
                    // System info only
                    "echo", "which", "type", "date", "whoami", "id", "uname",
                    "env", "printenv", "df", "du", "ps", "uptime",
                ]
            }
        }

        var blockedCommands: [String] {
            switch self {
            case .logOnly:
                return []  // nothing blocked

            case .custom:
                return [
                    // Destructive file ops
                    "rm", "rmdir", "shred", "dd",
                    // Privilege escalation
                    "sudo", "su", "doas",
                    // Permission changes
                    "chmod", "chown", "chgrp",
                    // Network transfer
                    "curl", "wget", "nc", "ncat", "nmap",
                    // Remote access
                    "ssh", "scp", "sftp", "rsync", "telnet", "ftp",
                    // Git danger
                    "git push", "git reset --hard", "git clean",
                    // System automation
                    "osascript", "launchctl", "crontab", "at",
                    // Process control
                    "kill", "killall", "pkill",
                ]

            case .dev:
                return [
                    // Network (AI should not make arbitrary outbound calls)
                    "curl", "wget", "nc", "ncat", "nmap", "dig", "nslookup",
                    // Remote access (prevent data exfiltration)
                    "ssh", "scp", "sftp", "rsync", "telnet", "ftp",
                    // Privilege escalation
                    "sudo", "su", "doas",
                    // Destructive
                    "rm -rf", "shred", "dd",
                    // Permission changes
                    "chmod", "chown", "chgrp",
                    // Git danger
                    "git push", "git reset --hard", "git clean -f",
                    // System automation
                    "osascript", "launchctl", "crontab",
                    // Process danger
                    "killall", "pkill",
                ]

            case .locked:
                return [
                    // Any file modification
                    "rm", "rmdir", "mv", "cp", "touch", "mkdir", "ln", "shred", "dd",
                    // Privilege escalation
                    "sudo", "su", "doas",
                    // Permission changes
                    "chmod", "chown", "chgrp",
                    // All network
                    "curl", "wget", "nc", "ncat", "nmap", "ssh", "scp", "sftp",
                    "rsync", "telnet", "ftp", "dig", "nslookup",
                    // All git writes
                    "git push", "git add", "git commit", "git reset",
                    "git clean", "git rm", "git stash drop",
                    // Package managers (no installs)
                    "npm", "npx", "yarn", "pnpm", "bun",
                    "pip", "pip3", "poetry", "cargo", "go get",
                    // Runtimes (no execution)
                    "python", "python3", "node", "ruby", "java", "deno",
                    // System automation
                    "osascript", "launchctl", "crontab", "at",
                    // Process control
                    "kill", "killall", "pkill",
                    // Launch
                    "open", "xdg-open",
                    // Truncation bypass
                    ": >",
                ]
            }
        }

        var accent: Color {
            switch self {
            case .logOnly: return Color(nsColor: .systemTeal)
            case .custom:  return .blue
            case .dev:     return .orange
            case .locked:  return .purple
            }
        }

        /// True if this mode actually blocks commands
        var isProtecting: Bool { self != .logOnly }
    }

    struct StatusMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let detail: String
    }

    struct Event: Identifiable {
        let id: UUID
        let timestamp: String       // ISO-8601 with microseconds, e.g. "2026-03-30T14:08:23.412731"
        let command: String
        let reason: String
        let user: String
        let process: String
        let pid: String

        init(timestamp: String, command: String, reason: String, user: String, process: String, pid: String) {
            self.id        = UUID()
            self.timestamp = timestamp
            self.command   = command
            self.reason    = reason
            self.user      = user
            self.process   = process
            self.pid       = pid
        }

        /// Parse timestamp — handles ISO-8601 with/without timezone and plain "HH:mm"
        private var parsedDate: Date? {
            // "2026-03-30T14:08:23.412731" (no tz, from Python)
            let noTZ = DateFormatter.isoNoTZ.date(from: timestamp)
            if let d = noTZ { return d }
            // "2026-03-30T14:08:23.412731Z" (with Z)
            let withTZ = ISO8601DateFormatter()
            withTZ.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = withTZ.date(from: timestamp) { return d }
            // "HH:mm" fallback (legacy seed data)
            return DateFormatter.shortTime.date(from: timestamp)
        }

        /// "Today 14:08" · "Yesterday 09:21" · "2 days ago" · "1 week ago" · "Mar 5"
        var relativeTime: String {
            guard let date = parsedDate else { return timestamp }
            let cal = Calendar.current
            let now = Date()
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                           to: cal.startOfDay(for: now)).day ?? 0
            switch days {
            case 0:  return "Today \(DateFormatter.shortTime.string(from: date))"
            case 1:  return "Yesterday \(DateFormatter.shortTime.string(from: date))"
            case 2...6:  return "\(days) days ago"
            case 7...13: return "1 week ago"
            case 14...29: return "\(days / 7) weeks ago"
            case 30...59: return "1 month ago"
            case 60...364: return "\(days / 30) months ago"
            default: return days >= 365 ? "\(days / 365) year\(days / 365 > 1 ? "s" : "") ago"
                                        : DateFormatter.shortDate.string(from: date)
            }
        }

        /// Public accessor for date filtering
        var parsedDatePublic: Date? { parsedDate }

        /// "14:08" for compact rows
        var shortTime: String {
            guard let date = parsedDate else { return timestamp }
            return DateFormatter.shortTime.string(from: date)
        }

        enum StatusKind {
            case blocked, allowed, executed, logged, error
            var label: String {
                switch self {
                case .blocked:  return "Blocked"
                case .allowed:  return "Allowed"
                case .executed: return "Executed"
                case .logged:   return "Logged"
                case .error:    return "Error"
                }
            }
        }

        var statusKind: StatusKind {
            let r = reason.lowercased()
            if r.contains("blocked") { return .blocked }
            if r == "allowed"        { return .allowed }
            if r == "executed"       { return .executed }
            if r.hasPrefix("logged") { return .logged }
            if r.hasPrefix("error")  { return .error }
            return .logged
        }
    }

    @Published var isEnabled = true
    @Published var selectedMode: GuardMode = .logOnly
    @Published var toolHooks: [AITool: Bool] = {
        Dictionary(uniqueKeysWithValues: AITool.allCases.map { ($0, HookManager.isEnabled($0)) })
    }()
    @Published var policyConfig: PolicyConfig?
    @Published var blockedEvents: [Event] = []

    init() {
        PolicyLoader.ensureDefault()
        self.policyConfig = PolicyLoader.load()
        LogStore.seedIfNeeded()
        self.blockedEvents = LogStore.load()
        reloadState()
    }

    func reloadState() {
        let url = PolicyLoader.configDir.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if let modeRaw = json["mode"] as? String,
           let mode = GuardMode.allCases.first(where: {
               $0.rawValue.lowercased() == modeRaw.lowercased()
               || $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "_") == modeRaw.lowercased()
               || $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "") == modeRaw.lowercased()
           }) {
            selectedMode = mode
        }
        if let enabled = json["enabled"] as? Bool {
            isEnabled = enabled
        }
    }

    func reloadPolicy() {
        policyConfig = PolicyLoader.load()
    }

    func reloadEvents() {
        blockedEvents = LogStore.load()
    }

    /// Count of today's events (all kinds)
    var todayEventCount: Int {
        let cal = Calendar.current
        return blockedEvents.filter { cal.isDateInToday($0.parsedDatePublic ?? .distantPast) }.count
    }

    /// Count of today's blocked-only events
    var todayBlockedCount: Int {
        let cal = Calendar.current
        return blockedEvents.filter {
            cal.isDateInToday($0.parsedDatePublic ?? .distantPast) && $0.statusKind == .blocked
        }.count
    }

    func allowedCommands(for mode: GuardMode) -> [String] {
        policyConfig?.modes[mode.rawValue.lowercased()]?.allowed ?? mode.allowedCommands
    }

    func blockedCommands(for mode: GuardMode) -> [String] {
        policyConfig?.modes[mode.rawValue.lowercased()]?.blocked ?? mode.blockedCommands
    }

    @Published var metrics: [StatusMetric] = [
        .init(title: "Protected Sessions", value: "12", detail: "Sessions launched under Shell Guard today"),
        .init(title: "Blocked Commands",   value: "7",  detail: "High-risk attempts stopped before execution"),
        .init(title: "Policy Preset",      value: "Custom", detail: "Current command policy profile"),
        .init(title: "Network Access",     value: "Denied", detail: "curl, ssh, scp, wget are blocked")
    ]


    // MARK: - Binary installation

    /// Stable installed path for the shellguard CLI binary.
    /// Lives in Application Support so App Store sandbox can write here without issues.
    static let installedBinaryPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ShellGuard/shellguard").path
    }()

    /// Installs (or updates) the bundled shellguard binary to
    /// ~/Library/Application Support/ShellGuard/shellguard on every launch.
    /// This ensures the CLI binary is always in sync with the app version.
    func installBinaryIfNeeded() {
        let target = Self.installedBinaryPath
        let fm = FileManager.default

        guard let execPath = Bundle.main.executablePath else { return }
        let bundled = URL(fileURLWithPath: execPath)
            .deletingLastPathComponent()
            .appendingPathComponent("shellguard")
        guard fm.fileExists(atPath: bundled.path) else { return }

        let targetURL = URL(fileURLWithPath: target)
        try? fm.createDirectory(at: targetURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        // Always overwrite so the CLI version stays in sync with the app.
        try? fm.removeItem(at: targetURL)
        try? fm.copyItem(at: bundled, to: targetURL)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target)
    }

    // MARK: - Onboarding

    var isOnboarded: Bool {
        let url = PolicyLoader.configDir.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return json["onboarded"] as? Bool ?? false
    }

    func completeOnboarding() {
        let url = PolicyLoader.configDir.appendingPathComponent("state.json")
        var json: [String: Any] = ["mode": "log only", "enabled": true]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        json["onboarded"] = true
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    @MainActor
    func toggleTool(_ tool: AITool) {
        let newValue = !(toolHooks[tool] ?? false)
        HookManager.setEnabled(newValue, for: tool)
        toolHooks[tool] = newValue
    }

    func select(mode: GuardMode) {
        selectedMode = mode
        if let i = metrics.firstIndex(where: { $0.title == "Policy Preset" }) {
            metrics[i] = .init(title: "Policy Preset", value: mode.rawValue, detail: mode.summary)
        }
        saveState()
    }

    func saveState() {
        let url = PolicyLoader.configDir.appendingPathComponent("state.json")
        // Read existing state first to preserve keys we don't manage (e.g. "onboarded").
        var state: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            state = existing
        }
        state["mode"]    = selectedMode.rawValue.lowercased()
        state["enabled"] = isEnabled
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: .sortedKeys),
              let str  = String(data: data, encoding: .utf8) else { return }
        try? FileManager.default.createDirectory(at: PolicyLoader.configDir, withIntermediateDirectories: true)
        try? str.write(to: url, atomically: true, encoding: .utf8)
    }
}
