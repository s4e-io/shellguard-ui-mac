import Foundation
import AppKit

// MARK: - BookmarkManager
//
// Stores and resolves security-scoped bookmarks so a sandboxed app can
// access user-granted directories across launches without re-prompting.
//
// Flow:
//   1. User toggles a tool ON in Settings
//   2. HookManager calls BookmarkManager.requestAccess(for: .claude)
//   3. If no bookmark exists → NSOpenPanel shown, user confirms ~/.claude/
//   4. Bookmark saved to UserDefaults
//   5. On subsequent launches, bookmark is resolved silently

final class BookmarkManager {

    static let shared = BookmarkManager()
    private init() {}

    private let defaults   = UserDefaults.standard
    private let keyPrefix  = "sg.bookmark."

    // Active security-scoped URLs that must remain open while in use
    private var activeURLs: [String: URL] = [:]

    // MARK: - Restore on launch

    /// Call once at app startup to resume access to previously granted directories.
    func restoreAll() {
        for tool in AITool.allCases {
            _ = resolveBookmark(for: tool)
        }
    }

    // MARK: - Request access (shows NSOpenPanel if needed)

    /// Returns true if we already have or successfully obtained access.
    @MainActor
    @discardableResult
    func requestAccess(for tool: AITool) -> Bool {
        // Already have a valid bookmark — nothing to do
        if resolveBookmark(for: tool) != nil { return true }

        // No bookmark yet — ask the user via NSOpenPanel
        let panel = NSOpenPanel()
        panel.message           = "ShellGuard needs access to \(tool.displayName)'s config folder to install the hook."
        panel.prompt            = "Grant Access"
        panel.canChooseFiles    = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL      = defaultDirectory(for: tool)

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        // Save security-scoped bookmark
        saveBookmark(url: url, for: tool)
        _ = url.startAccessingSecurityScopedResource()
        activeURLs[tool.rawValue] = url
        return true
    }

    // MARK: - Check & stop

    func hasAccess(for tool: AITool) -> Bool {
        defaults.data(forKey: keyPrefix + tool.rawValue) != nil
    }

    func stopAccessing(for tool: AITool) {
        activeURLs[tool.rawValue]?.stopAccessingSecurityScopedResource()
        activeURLs.removeValue(forKey: tool.rawValue)
    }

    func revokeBookmark(for tool: AITool) {
        stopAccessing(for: tool)
        defaults.removeObject(forKey: keyPrefix + tool.rawValue)
    }

    // MARK: - Private helpers

    @discardableResult
    private func resolveBookmark(for tool: AITool) -> URL? {
        guard let data = defaults.data(forKey: keyPrefix + tool.rawValue) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        if stale { saveBookmark(url: url, for: tool) }

        if url.startAccessingSecurityScopedResource() {
            activeURLs[tool.rawValue] = url
        }
        return url
    }

    private func saveBookmark(url: URL, for tool: AITool) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        defaults.set(data, forKey: keyPrefix + tool.rawValue)
    }

    /// The directory NSOpenPanel should open to by default for each tool.
    private func defaultDirectory(for tool: AITool) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch tool {
        case .claude: return home.appendingPathComponent(".claude")
        case .cursor: return home.appendingPathComponent(".cursor")
        case .codex:  return home.appendingPathComponent(".codex")
        case .gemini: return home.appendingPathComponent(".gemini")
        case .vscode: return home.appendingPathComponent("Library/Application Support/Code/User")
        }
    }
}
