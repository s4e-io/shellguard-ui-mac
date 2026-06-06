import SwiftUI
import AppKit

// MARK: - App Tab

enum AppTab: CaseIterable {
    case dashboard, policy, history, settings

    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .policy:    return "Policy"
        case .history:   return "Logs"
        case .settings:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .policy:    return "lock.shield"
        case .history:   return "list.bullet.clipboard"
        case .settings:  return "gearshape"
        }
    }

    var activeIcon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .policy:    return "lock.shield.fill"
        case .history:   return "list.bullet.clipboard.fill"
        case .settings:  return "gearshape.fill"
        }
    }
}

// MARK: - Root View

struct DashboardView: View {
    @ObservedObject var model: AppViewModel
    @State private var selectedTab: AppTab = .dashboard
    @State private var showDisableConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            AppTabBar(selected: $selectedTab)
            Divider()

            switch selectedTab {
            case .dashboard:
                DashboardTab(model: model, showDisableConfirm: $showDisableConfirm, selectedTab: $selectedTab)
            case .policy:
                PolicyTab(model: model)
            case .history:
                HistoryTab(events: model.blockedEvents, isLogOnly: model.selectedMode == .logOnly, onReload: { model.reloadEvents() })
            case .settings:
                SettingsTab(model: model)
            }
        }
        .frame(width: 380, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog(
            "Disable Protection?",
            isPresented: $showDisableConfirm,
            titleVisibility: .visible
        ) {
            Button("Disable", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) { model.isEnabled = false; model.saveState() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shell sessions will run without policy enforcement until you re-enable protection.")
        }
    }
}

// MARK: - Tab Bar

private struct AppTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabBarButton(tab: tab, isSelected: selected == tab) {
                    withAnimation(.easeInOut(duration: 0.15)) { selected = tab }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

private struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.activeIcon : tab.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dashboard Tab

private struct DashboardTab: View {
    @ObservedObject var model: AppViewModel
    @Binding var showDisableConfirm: Bool
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    StatusHero(model: model)
                    ModeSelectorSection(model: model)
                    RecentBlockedSection(
                        events: Array(model.blockedEvents.prefix(3)),
                        mode: model.selectedMode,
                        onViewAll: { withAnimation(.easeInOut(duration: 0.15)) { selectedTab = .history } },
                        onReload: { model.reloadEvents() }
                    )
                }
                .padding(16)
            }

            Divider()

            ToggleProtectionButton(isEnabled: model.isEnabled) {
                if model.isEnabled { showDisableConfirm = true }
                else { withAnimation(.easeInOut(duration: 0.25)) { model.isEnabled = true; model.saveState() } }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Status Hero

private struct StatusHero: View {
    @ObservedObject var model: AppViewModel

    private var heroColor: Color {
        guard model.isEnabled else { return .gray }
        return model.selectedMode.accent
    }

    private var iconName: String {
        guard model.isEnabled else { return "shield.slash.fill" }
        return model.selectedMode == .logOnly ? "eye.fill" : "shield.fill"
    }

    private var statusTitle: String {
        guard model.isEnabled else { return "Unprotected" }
        return model.selectedMode == .logOnly ? "Monitoring" : "Protected"
    }

    private var statusSubtitle: String {
        guard model.isEnabled else { return "Policy enforcement off" }
        return model.selectedMode == .logOnly
            ? "Logging all commands, blocking none"
            : "\(model.selectedMode.rawValue) mode active"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(heroColor)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.title3.weight(.bold))
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.isEnabled {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(model.selectedMode.isProtecting ? model.todayBlockedCount : model.todayEventCount)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(heroColor)
                    Text(model.selectedMode.isProtecting ? "blocked today" : "logged today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(14)
        .background(heroColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(heroColor.opacity(0.18), lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: model.isEnabled)
        .animation(.easeInOut(duration: 0.25), value: model.selectedMode)
    }
}

// MARK: - Mode Selector

private struct ModeSelectorSection: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Policy Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)

            HStack(spacing: 8) {
                ForEach(AppViewModel.GuardMode.allCases) { mode in
                    ModeButton(mode: mode, isSelected: model.selectedMode == mode, isDisabled: !model.isEnabled) {
                        withAnimation(.easeInOut(duration: 0.2)) { model.select(mode: mode) }
                    }
                }
            }

            if model.isEnabled {
                Text(model.selectedMode.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.2), value: model.selectedMode)
            }
        }
    }
}

private struct ModeButton: View {
    let mode: AppViewModel.GuardMode
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isDisabled ? .gray : mode.accent)
                    .frame(width: 7, height: 7)
                Text(mode.rawValue)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                isSelected && !isDisabled ? mode.accent.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected && !isDisabled ? mode.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }
}

// MARK: - Recent Blocked / Activity

private struct RecentBlockedSection: View {
    let events: [AppViewModel.Event]
    let mode: AppViewModel.GuardMode
    let onViewAll: () -> Void
    let onReload: () -> Void

    private var isLogOnly: Bool { mode == .logOnly }
    @State private var spinning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Logs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
                    .animation(.none, value: mode)
                Spacer()
                Button {
                    withAnimation(.linear(duration: 0.4)) { spinning = true }
                    onReload()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        spinning = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reload activity")

                if !events.isEmpty {
                    Button("View all") { onViewAll() }
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(.plain)
                }
            }

            if events.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { i, event in
                        EventRow(event: event)
                        if i < events.count - 1 { Divider().padding(.leading, 60) }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                if isLogOnly {
                    Image(systemName: "eye.fill")
                        .font(.title3)
                        .foregroundStyle(Color(nsColor: .systemTeal))
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Start a terminal session to begin logging.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    Text("All clear")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("No commands have been blocked yet.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 20)
            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct EventRow: View {
    let event: AppViewModel.Event

    var body: some View {
        HStack(spacing: 10) {
            Text(event.shortTime)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.command)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    StatusChip(kind: event.statusKind)
                    Text("·").foregroundStyle(.tertiary).font(.caption2)
                    Text(event.user)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary).font(.caption2)
                    Text(event.process)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }
}

// MARK: - Toggle Protection Button

private struct ToggleProtectionButton: View {
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        if isEnabled {
            Button(action: onTap) {
                Label("Disable Protection", systemImage: "shield.slash").font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else {
            Button(action: onTap) {
                Text("Enable Protection")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
        }
    }
}

// MARK: - Policy Tab

private struct PolicyTab: View {
    @ObservedObject var model: AppViewModel
    @State private var viewMode: AppViewModel.GuardMode = .logOnly
    @State private var reloading = false

    private var isPreviewing: Bool { viewMode != model.selectedMode }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker — no label
            Picker("", selection: $viewMode) {
                ForEach(AppViewModel.GuardMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Active / preview status badge
            HStack(spacing: 5) {
                if isPreviewing {
                    Image(systemName: "eye")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Previewing \(viewMode.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Switch to \(viewMode.rawValue)") {
                        withAnimation(.easeInOut(duration: 0.2)) { model.select(mode: viewMode) }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(viewMode.accent)
                } else {
                    Circle()
                        .fill(model.selectedMode.accent)
                        .frame(width: 6, height: 6)
                    Text("Active mode")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.2), value: isPreviewing)

            Divider()

            if viewMode == .logOnly {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(nsColor: .systemTeal))
                    Text("All commands pass through")
                        .font(.headline)
                    Text("Nothing is blocked in Log Only mode.\nEvery command is written to activity.log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        let allowed = model.allowedCommands(for: viewMode)
                        let blocked = model.blockedCommands(for: viewMode)
                        CommandListCard(title: "Allowed", count: allowed.count, icon: "checkmark.circle.fill", color: .green, commands: allowed)
                        CommandListCard(title: "Blocked", count: blocked.count, icon: "xmark.circle.fill",    color: .red,   commands: blocked)
                    }
                    .padding(14)
                }
            }
            Spacer(minLength: 0)
                .animation(.easeInOut(duration: 0.2), value: viewMode)

            Divider()

            // Footer: file path + reload + edit
            HStack(spacing: 8) {
                Image(systemName: "doc.plaintext").font(.caption2).foregroundStyle(.tertiary)
                Text(PolicyLoader.fileURL.path.replacingOccurrences(
                    of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"
                ))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                Spacer()
                Button {
                    withAnimation { reloading = true }
                    model.reloadPolicy()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation { reloading = false }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(reloading ? 360 : 0))
                        .animation(reloading ? .linear(duration: 0.6) : .default, value: reloading)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reload policy.yaml")

                Button {
                    PolicyLoader.openInEditor()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .onAppear { viewMode = model.selectedMode }
    }
}

private struct CommandListCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let commands: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(count) commands").font(.caption2).foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 6) {
                ForEach(commands, id: \.self) { cmd in
                    Text(cmd)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(color.opacity(0.9))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Status Chip

private struct StatusChip: View {
    let kind: AppViewModel.Event.StatusKind

    private var color: Color {
        switch kind {
        case .blocked:  return .red
        case .allowed:  return .secondary
        case .executed: return .green
        case .logged:   return Color(nsColor: .systemTeal)
        case .error:    return .orange
        }
    }

    var body: some View {
        Text(kind.label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

// MARK: - History Tab

private struct HistoryTab: View {
    let events: [AppViewModel.Event]
    let isLogOnly: Bool
    let onReload: () -> Void
    @State private var page = 0

    private let perPage = 5

    private var totalPages: Int { max(1, Int(ceil(Double(events.count) / Double(perPage)))) }

    private var pageEvents: [AppViewModel.Event] {
        let start = page * perPage
        guard start < events.count else { return [] }
        return Array(events[start..<min(start + perPage, events.count)])
    }

    // Clamp page when events list changes (e.g. after reload)
    private func clampedPage(_ newEvents: [AppViewModel.Event]) -> Int {
        let maxPage = max(0, Int(ceil(Double(newEvents.count) / Double(perPage))) - 1)
        return min(page, maxPage)
    }

    private var logFileURL: URL { PolicyLoader.logFileURL }

    var body: some View {
        VStack(spacing: 0) {
            if events.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    if isLogOnly {
                        Image(systemName: "eye.fill").font(.title2).foregroundStyle(Color(nsColor: .systemTeal))
                        Text("No activity yet").font(.subheadline).foregroundStyle(.secondary)
                        Text("Commands will appear here once you start a terminal session.")
                            .font(.caption).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    } else {
                        Image(systemName: "checkmark.shield.fill").font(.title2).foregroundStyle(.green)
                        Text("No blocked events").font(.subheadline).foregroundStyle(.secondary)
                        Text("Shell Guard is active and hasn't blocked any commands yet.")
                            .font(.caption).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(pageEvents.enumerated()), id: \.element.id) { i, event in
                            HistoryEventRow(event: event)
                            if i < pageEvents.count - 1 { Divider().padding(.leading, 16) }
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            Divider()

            // Pagination
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { page -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(page == 0)
                .opacity(page == 0 ? 0.3 : 1)

                Spacer()

                VStack(spacing: 1) {
                    Text("Page \(page + 1) of \(totalPages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(events.count >= LogStore.maxEvents
                         ? "last \(events.count) events"
                         : "\(events.count) events")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { page += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(page >= totalPages - 1)
                .opacity(page >= totalPages - 1 ? 0.3 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)

            Divider()

            // Open log file
            HStack(spacing: 8) {
                Image(systemName: "doc.text").font(.caption2).foregroundStyle(.tertiary)
                Text(PolicyLoader.logFileURL.path.replacingOccurrences(
                    of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"
                ))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                Spacer()
                Button { onReload() } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Button {
                    PolicyLoader.openLog()
                } label: {
                    Label("Open Log", systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .onChange(of: events.count) { _ in
            page = clampedPage(events)
        }
    }
}

private struct HistoryEventRow: View {
    let event: AppViewModel.Event
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                Text(event.command)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(event.command, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                StatusChip(kind: event.statusKind)
                if event.statusKind == .blocked || event.statusKind == .error {
                    Text(event.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 6) {
                Label(event.user, systemImage: "person")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("·").foregroundStyle(.tertiary).font(.caption2)
                Label(event.process, systemImage: "terminal")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("·").foregroundStyle(.tertiary).font(.caption2)
                Text("PID \(event.pid)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(event.relativeTime)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Settings Tab

private struct SettingsTab: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // AI Tool Hooks
                VStack(alignment: .leading, spacing: 10) {
                    Label("AI Tool Hooks", systemImage: "cpu")
                        .font(.subheadline.weight(.semibold))

                    let tools = AITool.allCases
                    VStack(spacing: 8) {
                        ForEach(stride(from: 0, to: tools.count, by: 2).map { $0 }, id: \.self) { i in
                            HStack(spacing: 8) {
                                ForEach(tools[i..<min(i+2, tools.count)], id: \.id) { tool in
                                    let enabled = model.toolHooks[tool] ?? false
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            model.toggleTool(tool)
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: tool.icon)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(enabled ? Color.green : Color.secondary.opacity(0.5))
                                            Text(tool.displayName)
                                                .font(.caption)
                                                .foregroundStyle(enabled ? .primary : .secondary)
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                if tools.count % 2 != 0 && i + 1 == tools.count - 1 {
                                    Spacer()
                                }
                            }
                        }
                    }

                    Text("Tap a tool to enable or disable its ShellGuard hook.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if model.toolHooks[.vscode] == true {
                        Label("VS Code: only Copilot agent commands are intercepted. Manual terminal input and blocking are not supported.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                // Files
                VStack(alignment: .leading, spacing: 12) {
                    Label("Files", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))

                    // Policy file row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Policy")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(PolicyLoader.fileURL.path.replacingOccurrences(
                                of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            Spacer()
                            Button("Open") { PolicyLoader.openInEditor() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("Reload") { model.reloadPolicy() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    Divider()

                    // Activity log row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Activity Log")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(PolicyLoader.logFileURL.path.replacingOccurrences(
                                of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            Spacer()
                            Button("Open") { PolicyLoader.openLog() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }

                    Divider()

                    // System log row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Log")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(PolicyLoader.errorLogURL.path.replacingOccurrences(
                                of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            Spacer()
                            Button("Open") { PolicyLoader.openErrorLog() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

                // Feedback
                FeedbackSection()

                // About
                AboutSection()
            }
            .padding(16)
        }
    }
}

// MARK: - About Section

private struct AboutSection: View {
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Label("About", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 6) {
                    SettingsRow(label: "Shell Guard", value: "v0.1.0")
                    Divider()
                    SettingsRow(label: "Platform", value: "macOS 14+")
                    Divider()
                    SettingsRow(label: "Mode", value: "Local-only")
                    Divider()
                    HStack {
                        Text("Developer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://s4e.io")!)
                        } label: {
                            Text("s4e.io")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ErrorLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).foregroundStyle(.orange).lineLimit(2)
        }
        .font(.caption2)
    }
}

private extension Date {
    var relativeFormatted: String {
        let s = Int(Date().timeIntervalSince(self))
        switch s {
        case 0..<60:      return "just now"
        case 60..<3600:   return "\(s / 60)m ago"
        case 3600..<86400: return "\(s / 3600)h ago"
        default:          return "\(s / 86400)d ago"
        }
    }
}

// MARK: - Feedback Section

private struct FeedbackSection: View {
    enum FeedbackKind: String, CaseIterable {
        case bug     = "Bug Report"
        case feature = "Feature Request"
        case other   = "General"

        var icon: String {
            switch self {
            case .bug:     return "ant"
            case .feature: return "sparkles"
            case .other:   return "bubble.left"
            }
        }
    }

    @State private var kind: FeedbackKind = .bug
    @State private var text: String = ""
    @State private var submitted = false
    @State private var expanded = false

    private var isReady: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 12 : 0) {
            // Header — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Label("Feedback", systemImage: "megaphone")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
            // Type picker
            HStack(spacing: 6) {
                ForEach(FeedbackKind.allCases, id: \.self) { k in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { kind = k }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: k.icon).font(.system(size: 10))
                            Text(k.rawValue).font(.caption)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .foregroundStyle(kind == k ? .primary : .secondary)
                        .background(
                            kind == k
                                ? Color.accentColor.opacity(0.15)
                                : Color(nsColor: .windowBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(kind == k ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Text editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(.caption, design: .default))
                    .frame(minHeight: 72, maxHeight: 72)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                if text.isEmpty {
                    Text("Describe the issue or idea…")
                        .font(.system(.caption))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Text("\(text.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if submitted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Sent!").foregroundStyle(.green)
                    }
                    .font(.caption.weight(.medium))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button {
                        sendFeedback()
                    } label: {
                        Label("Send", systemImage: "paperplane")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!isReady)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: submitted)
            } // end if expanded
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private func sendFeedback() {
        let body = "[\(kind.rawValue)]\n\n\(text)\n\n---\nShell Guard v0.1.0 | macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let subject = "[ShellGuard] \(kind.rawValue)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:info@s4e.io?subject=\(subject)&body=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
        withAnimation { submitted = true }
        text = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { submitted = false }
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.primary)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
