import SwiftUI

/// Curated announcements from the "ПИ объявления" Telegram channel.
struct UsefulInfoView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ChannelHeader(name: usefulInfoChannel, subtitle: "Связь: \(usefulInfoContact)", url: usefulInfoChannelURL)
                ForEach(usefulInfoPosts) { post in
                    PostCard(post: post)
                }
                Text("By Renata Ilyasova")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Полезная информация")
    }
}

/// Accreditation plaque shown atop channel-sourced tabs.
struct ChannelHeader: View {
    let name: String
    let subtitle: String
    let url: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 40)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.title3.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Link(destination: URL(string: url)!) {
                Label("Открыть канал", systemImage: "arrow.up.right")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.glassProminent).tint(Theme.accent)
        }
        .glassCard(cornerRadius: 22)
    }
}

private struct PostCard: View {
    let post: InfoPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Pill(text: post.date)
                Spacer(minLength: 0)
                if let url = post.url, let u = URL(string: url) {
                    Link(destination: u) { Image(systemName: "paperplane") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            Text(post.text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if !post.links.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(post.links) { link in
                        if let u = URL(string: link.href) {
                            Link(destination: u) {
                                Label(link.title, systemImage: "link")
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }
}
