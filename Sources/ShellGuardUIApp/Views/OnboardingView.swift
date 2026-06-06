import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var model: AppViewModel
    var onComplete: () -> Void

    @State private var detectedTools: [AITool: Bool] = [:]
    @State private var selectedTools: Set<AITool> = []
    @State private var installing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                Text(">_!")
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                Text("Shell Guard")
                    .font(.title2.weight(.semibold))
                Text("Monitor and control shell commands\nexecuted by AI coding tools.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.bottom, 28)

            Divider()

            // Tool list
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Tools")
                    .font(.subheadline.weight(.semibold))
                    .padding(.bottom, 2)

                ForEach(AITool.allCases) { tool in
                    let installed = detectedTools[tool] ?? false
                    let selected  = selectedTools.contains(tool)
                    Button {
                        // Allow selecting any tool — even undetected ones can be enabled manually
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selected { selectedTools.remove(tool) }
                            else        { selectedTools.insert(tool) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: installed ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.title3)
                                .foregroundStyle(installed
                                    ? (selected ? Color.green : Color.secondary)
                                    : (selected ? Color.orange : Color.secondary.opacity(0.5)))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(installed
                                     ? (selected ? "Hook will be enabled" : "Detected — tap to include")
                                     : (selected ? "Not auto-detected — will try to enable" : "Not detected — tap to enable manually"))
                                    .font(.caption)
                                    .foregroundStyle(selected
                                        ? (installed ? Color.green : Color.orange)
                                        : Color.secondary.opacity(0.6))
                            }

                            Spacer()

                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selected ? (installed ? .green : .orange) : .secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            selected ? (installed ? Color.green.opacity(0.4) : Color.orange.opacity(0.4)) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selected)
                }

                // Note about Claude Code vs Claude Desktop
                if detectedTools[.claude] == false {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Claude Code CLI not found. Claude Desktop is a different app and doesn't support shell hooks. Install Claude Code from claude.ai/code to protect it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider()

            // Footer
            VStack(spacing: 10) {
                Button {
                    installing = true
                    // Install binary, enable hooks, mark onboarded
                    model.installBinaryIfNeeded()
                    for tool in selectedTools {
                        HookManager.setEnabled(true, for: tool)
                        model.toolHooks[tool] = true
                    }
                    model.completeOnboarding()
                    onComplete()
                } label: {
                    HStack {
                        if installing {
                            ProgressView().controlSize(.small).padding(.trailing, 4)
                        }
                        Text(selectedTools.isEmpty ? "Skip Setup" : "Enable & Continue")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedTools.isEmpty ? .secondary : .accentColor)
                .disabled(installing)

                Text("Hooks can be changed any time in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(width: 380)
        .onAppear {
            for tool in AITool.allCases {
                let installed = HookManager.isInstalled(tool)
                detectedTools[tool] = installed
                if installed { selectedTools.insert(tool) }
            }
        }
    }
}
