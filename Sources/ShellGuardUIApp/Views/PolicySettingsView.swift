import SwiftUI

struct PolicySettingsView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: AppViewModel.GuardMode

    init(model: AppViewModel) {
        self.model = model
        self._selectedMode = State(initialValue: model.selectedMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Policy Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            Divider()

            // Mode picker
            Picker("Mode", selection: $selectedMode) {
                ForEach(AppViewModel.GuardMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            // Mode summary
            Text(selectedMode.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    CommandListSection(
                        title: "Allowed",
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        commands: selectedMode.allowedCommands
                    )

                    CommandListSection(
                        title: "Blocked",
                        icon: "xmark.circle.fill",
                        iconColor: .red,
                        commands: selectedMode.blockedCommands
                    )

                    SessionScopeSection(toolHooks: model.toolHooks)
                }
                .padding(16)
            }

            Divider()

            // Apply button
            HStack {
                if model.selectedMode != selectedMode {
                    Text("Switching to \(selectedMode.rawValue) mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Apply Mode") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        model.select(mode: selectedMode)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedMode.accent)
                .disabled(model.selectedMode == selectedMode)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 380, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: selectedMode)
    }
}

// MARK: - Command List Section

private struct CommandListSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let commands: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            FlowLayout(spacing: 6) {
                ForEach(commands, id: \.self) { cmd in
                    CommandChip(label: cmd, color: iconColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            iconColor.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(iconColor.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct CommandChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(color.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Session Scope Section

private struct SessionScopeSection: View {
    let toolHooks: [AITool: Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Text("AI Tool Hooks")
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 8) {
                ForEach(AITool.allCases) { tool in
                    let enabled = toolHooks[tool] ?? false
                    HStack(spacing: 5) {
                        Circle()
                            .fill(enabled ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text(tool.displayName)
                            .font(.caption)
                            .foregroundStyle(enabled ? .primary : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
            }

            Text("ShellGuard hooks are active for highlighted tools.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
