import AppKit
import SwiftUI

struct AboutPane: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 3) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .padding(.bottom, 4)
                    Text("LinkRouter")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                    Text("by Henrik Øgård")
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Links") {
                linkRow(
                    symbol: "chevron.left.forwardslash.chevron.right",
                    title: "GitHub",
                    detail: "Source code, issues and releases",
                    url: "https://github.com/henrikogaard/linkrouter"
                )
                linkRow(
                    symbol: "at",
                    title: "X",
                    detail: "@henrikogaard",
                    url: "https://x.com/henrikogaard"
                )
                linkRow(
                    symbol: "cup.and.saucer.fill",
                    title: "Buy Me a Coffee",
                    detail: "Support development",
                    url: "https://buymeacoffee.com/henrikogaard"
                )
            }
        }
        .formStyle(.grouped)
    }

    private func linkRow(symbol: String, title: String, detail: LocalizedStringKey, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
