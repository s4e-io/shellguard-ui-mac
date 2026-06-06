import Foundation

// MARK: - AI Tool definition

enum AITool: String, CaseIterable, Identifiable {
    case claude = "claude"
    case cursor = "cursor"
    case codex  = "codex"
    case gemini = "gemini"
    case vscode = "vscode"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .cursor: return "Cursor"
        case .codex:  return "Codex"
        case .gemini: return "Gemini CLI"
        case .vscode: return "VS Code"
        }
    }

    var icon: String {
        switch self {
        case .claude: return "sparkle"
        case .cursor: return "cursorarrow.rays"
        case .codex:  return "chevron.left.forwardslash.chevron.right"
        case .gemini: return "star.circle"
        case .vscode: return "curlybraces"
        }
    }
}

// MARK: - Hook manager

enum HookManager {

    // Canonical installed path for the shellguard CLI binary.
    // The app copies the bundled binary here on first launch.
    // All hook configs point to this path.
    static let binaryPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ShellGuard/shellguard").path
    }()

    // Shell-safe path: wraps in quotes when path contains spaces.
    // Use this for hook "command" fields. Do NOT use for VS Code "path" fields.
    private static var quotedBinaryPath: String {
        binaryPath.contains(" ") ? "\"\(binaryPath)\"" : binaryPath
    }

    // MARK: - Detection

    /// Returns true if the given AI tool appears to be installed on this machine.
    static func isInstalled(_ tool: AITool) -> Bool {
        let fm   = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        switch tool {
        case .claude:
            // Claude Code CLI installs to /usr/local/bin or ~/.local/bin.
            // NOTE: sandbox restricts ~/.claude visibility, so check explicit binary paths
            // and fall back to an already-granted bookmark (user previously enabled it).
            // Claude Desktop (/Applications/Claude.app) is a different product — it does
            // NOT use shell hooks. Only Claude Code CLI is relevant here.
            return fm.fileExists(atPath: "/usr/local/bin/claude")
                || fm.fileExists(atPath: "/opt/homebrew/bin/claude")
                || fm.fileExists(atPath: home.appendingPathComponent(".local/bin/claude").path)
                || BookmarkManager.shared.hasAccess(for: .claude)
                || which("claude") != nil
        case .cursor:
            return fm.fileExists(atPath: "/Applications/Cursor.app")
                || fm.fileExists(atPath: home.appendingPathComponent("Applications/Cursor.app").path)
        case .codex:
            return fm.fileExists(atPath: "/Applications/Codex.app")
                || fm.fileExists(atPath: home.appendingPathComponent("Applications/Codex.app").path)
                || which("codex") != nil
        case .gemini:
            return fm.fileExists(atPath: "/Applications/Antigravity.app")
                || which("gemini") != nil
        case .vscode:
            return fm.fileExists(atPath: "/Applications/Visual Studio Code.app")
                || fm.fileExists(atPath: home.appendingPathComponent("Applications/Visual Studio Code.app").path)
                || which("code") != nil
        }
    }

    private static func which(_ binary: String) -> String? {
        // Sandbox apps may have a minimal PATH — search common install locations explicitly.
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments  = ["-c", "which \(binary)"]
        task.environment = [
            "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" +
                    ":\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin"
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()
        try? task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }

    // MARK: - Public API

    static func isEnabled(_ tool: AITool) -> Bool {
        switch tool {
        case .claude: return isClaudeEnabled()
        case .cursor: return isCursorEnabled()
        case .codex:  return isCodexEnabled()
        case .gemini: return isGeminiEnabled()
        case .vscode: return isVSCodeEnabled()
        }
    }

    /// Enable/disable a tool hook.
    /// No sandbox — writes directly to hook config files.
    @MainActor
    static func setEnabled(_ enabled: Bool, for tool: AITool) {
        if enabled { enable(tool) } else { disable(tool) }
    }

    // MARK: - Private helpers

    private static func enable(_ tool: AITool) {
        switch tool {
        case .claude: patchClaudeHooks(adding: true)
        case .cursor: patchCursorHooks(adding: true)
        case .codex:  patchCodexHooks(adding: true)
        case .gemini: patchGeminiHooks(adding: true)
        case .vscode: patchVSCodeHooks(adding: true)
        }
    }

    private static func disable(_ tool: AITool) {
        switch tool {
        case .claude: patchClaudeHooks(adding: false)
        case .cursor: patchCursorHooks(adding: false)
        case .codex:  patchCodexHooks(adding: false)
        case .gemini: patchGeminiHooks(adding: false)
        case .vscode: patchVSCodeHooks(adding: false)
        }
    }

    // MARK: - Claude Code (~/.claude/settings.json)
    // Format: { ..., "hooks": { "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "..." }] }] } }

    private static func isClaudeEnabled() -> Bool {
        guard let json = readJSON(at: claudeURL),
              let hooks = json["hooks"] as? [String: Any],
              let arr   = hooks["PreToolUse"] as? [[String: Any]] else { return false }
        return arr.contains { containsShellguard($0) }
    }

    private static func patchClaudeHooks(adding: Bool) {
        var json = readJSON(at: claudeURL) ?? [:]
        var hooks = json["hooks"] as? [String: Any] ?? [:]

        for event in ["PreToolUse", "PostToolUse"] {
            var arr = hooks[event] as? [[String: Any]] ?? []
            if adding {
                if !arr.contains(where: { containsShellguard($0) }) {
                    arr.append(makeShellguardEntry())
                }
            } else {
                arr = arr.filter { !containsShellguard($0) }
            }
            hooks[event] = arr
        }

        json["hooks"] = hooks
        writeJSON(json, to: claudeURL)
    }

    private static var claudeURL: URL {
        home.appendingPathComponent(".claude/settings.json")
    }

    // MARK: - Cursor (~/.cursor/hooks.json)
    // Format: { "beforeShellExecution": { "command": "..." } }

    private static func isCursorEnabled() -> Bool {
        guard let json = readJSON(at: cursorURL),
              let bse  = json["beforeShellExecution"] as? [String: Any],
              let cmd  = bse["command"] as? String else { return false }
        let unquoted = cmd.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return unquoted == binaryPath || unquoted.hasSuffix("/shellguard")
    }

    private static func patchCursorHooks(adding: Bool) {
        var json = readJSON(at: cursorURL) ?? [:]
        if adding {
            json["beforeShellExecution"] = ["command": quotedBinaryPath]
        } else {
            json.removeValue(forKey: "beforeShellExecution")
        }
        writeJSON(json, to: cursorURL)
    }

    private static var cursorURL: URL {
        home.appendingPathComponent(".cursor/hooks.json")
    }

    // MARK: - Codex (~/.codex/hooks.json)
    // Format: { "hooks": { "PreToolUse": [{ "matcher": "shell_command", "hooks": [{ "type": "command", "command": "..." }] }] } }
    // Note: Codex CLI uses tool_name="shell_command" (not "Bash") — confirmed from v0.131 binary.

    private static func isCodexEnabled() -> Bool {
        guard let json  = readJSON(at: codexURL),
              let outer = json["hooks"] as? [String: Any],
              let arr   = outer["PreToolUse"] as? [[String: Any]] else { return false }
        return arr.contains { containsShellguard($0) }
    }

    private static func patchCodexHooks(adding: Bool) {
        var json  = readJSON(at: codexURL) ?? [:]
        var outer = json["hooks"] as? [String: Any] ?? [:]

        for event in ["PreToolUse", "PostToolUse"] {
            var arr = outer[event] as? [[String: Any]] ?? []
            if adding {
                if !arr.contains(where: { containsShellguard($0) }) {
                    arr.append(makeCodexEntry()) // Codex uses matcher: "shell_command"
                }
            } else {
                arr = arr.filter { !containsShellguard($0) }
            }
            outer[event] = arr
        }

        json["hooks"] = outer
        writeJSON(json, to: codexURL)
    }

    private static var codexURL: URL {
        home.appendingPathComponent(".codex/hooks.json")
    }

    // MARK: - Gemini / Antigravity (~/.gemini/settings.json)
    // Format: { "hooks": { "BeforeTool": [{ "matcher": "run_shell_command", "hooks": [{ "type": "command", "command": "..." }] }] } }

    private static func isGeminiEnabled() -> Bool {
        guard let json = readJSON(at: geminiURL),
              let hooks = json["hooks"] as? [String: Any],
              let arr   = hooks["BeforeTool"] as? [[String: Any]] else { return false }
        return arr.contains { containsShellguard($0) }
    }

    private static func patchGeminiHooks(adding: Bool) {
        var json  = readJSON(at: geminiURL) ?? [:]
        var hooks = json["hooks"] as? [String: Any] ?? [:]

        var arr = hooks["BeforeTool"] as? [[String: Any]] ?? []
        if adding {
            if !arr.contains(where: { containsShellguard($0) }) {
                arr.append(makeGeminiEntry())
            }
        } else {
            arr = arr.filter { !containsShellguard($0) }
        }
        hooks["BeforeTool"] = arr

        json["hooks"] = hooks
        writeJSON(json, to: geminiURL)
    }

    private static var geminiURL: URL {
        home.appendingPathComponent(".gemini/settings.json")
    }

    private static func makeGeminiEntry() -> [String: Any] {
        ["matcher": "run_shell_command", "hooks": [["type": "command", "command": quotedBinaryPath]]]
    }

    // MARK: - VS Code (~/Library/Application Support/Code/User/settings.json)
    // Registers ShellGuard as a terminal profile so Copilot/Cline/Continue commands pass through it.
    // Format: { "terminal.integrated.defaultProfile.osx": "ShellGuard",
    //           "terminal.integrated.profiles.osx": { "ShellGuard": { "path": "...", "args": [] } } }

    private static func isVSCodeEnabled() -> Bool {
        guard let json = readJSON(at: vscodeURL),
              let profiles = json["terminal.integrated.profiles.osx"] as? [String: Any],
              let sg = profiles["ShellGuard"] as? [String: Any],
              let path = sg["path"] as? String else { return false }
        return path == binaryPath || path.hasSuffix("/shellguard")
    }

    private static func patchVSCodeHooks(adding: Bool) {
        var json = readJSON(at: vscodeURL) ?? [:]

        if adding {
            var profiles = json["terminal.integrated.profiles.osx"] as? [String: Any] ?? [:]
            profiles["ShellGuard"] = ["path": binaryPath, "args": [String]()]
            json["terminal.integrated.profiles.osx"] = profiles
            json["terminal.integrated.defaultProfile.osx"] = "ShellGuard"
        } else {
            var profiles = json["terminal.integrated.profiles.osx"] as? [String: Any] ?? [:]
            profiles.removeValue(forKey: "ShellGuard")
            if profiles.isEmpty {
                json.removeValue(forKey: "terminal.integrated.profiles.osx")
            } else {
                json["terminal.integrated.profiles.osx"] = profiles
            }
            // Only clear default if it was set to ShellGuard
            if json["terminal.integrated.defaultProfile.osx"] as? String == "ShellGuard" {
                json.removeValue(forKey: "terminal.integrated.defaultProfile.osx")
            }
        }

        writeJSON(json, to: vscodeURL)
    }

    private static var vscodeURL: URL {
        home.appendingPathComponent("Library/Application Support/Code/User/settings.json")
    }

    // MARK: - Shared helpers

    private static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    private static func makeShellguardEntry() -> [String: Any] {
        ["matcher": "Bash", "hooks": [["type": "command", "command": quotedBinaryPath]]]
    }

    /// Codex CLI uses tool_name="shell_command" (not "Bash") — confirmed from v0.131 binary.
    private static func makeCodexEntry() -> [String: Any] {
        ["matcher": "shell_command", "hooks": [["type": "command", "command": quotedBinaryPath]]]
    }

    private static func containsShellguard(_ entry: [String: Any]) -> Bool {
        guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
        // Strip surrounding quotes before comparing — paths with spaces are stored quoted.
        return inner.contains {
            guard let cmd = $0["command"] as? String else { return false }
            let unquoted = cmd.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return unquoted == binaryPath || unquoted.hasSuffix("/shellguard")
        }
    }

    private static func readJSON(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func writeJSON(_ json: [String: Any], to url: URL) {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
