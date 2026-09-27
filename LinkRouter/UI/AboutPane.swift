import AppKit
import SwiftUI

struct AboutPane: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "About",
                    subtitle: "Version, links, and supporting development."
                )

                VStack(spacing: 4) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .padding(.bottom, 6)
                    Text("LinkRouter")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Henrik Øgård")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Version \(version)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

                group("Links") {
                    linkRow(
                        symbol: "chevron.left.forwardslash.chevron.right",
                        title: "GitHub",
                        detail: "Source, issues and releases",
                        url: "https://github.com/henrikogaard/linkrouter"
                    )
                    hairline
                    linkRow(
                        symbol: "at",
                        title: "X",
                        detail: "@henrikogaard",
                        url: "https://x.com/henrikogaard"
                    )
                    hairline
                    linkRow(
                        symbol: "cup.and.saucer.fill",
                        title: "Buy Me a Coffee",
                        detail: "Support development",
                        url: "https://buymeacoffee.com/henrikogaard"
                    )
                }

                group("Details") {
                    HStack {
                        Text("Bundle")
                        Spacer()
                        Text(Bundle.main.bundleIdentifier ?? "app.linkrouter.LinkRouter")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
            .padding(.bottom, 28)
        }
        .background(LR.pageFill)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LR.rowFill, in: RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LR.rowRadius, style: .continuous)
                    .strokeBorder(LR.hairline, lineWidth: 1)
            }
        }
        .padding(.horizontal, LR.pageInset)
    }

    private func linkRow(symbol: String, title: String, detail: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var hairline: some View {
        Rectangle()
            .fill(LR.hairline)
            .frame(height: 1)
            .padding(.leading, 54)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
