import SwiftUI

enum BrandTheme {
    static let teal = Color(red: 0.10, green: 0.43, blue: 0.39)
    static let deepGreen = Color(red: 0.04, green: 0.25, blue: 0.20)
    static let mint = Color(red: 0.82, green: 0.94, blue: 0.90)
    static let mist = Color(red: 0.94, green: 0.98, blue: 0.97)
    static let gold = Color(red: 0.73, green: 0.59, blue: 0.28)
}

extension View {
    /// Mac 使用固定但紧凑的工具窗口；iPhone/iPad 始终交给系统按屏幕宽度排版。
    @ViewBuilder
    func adaptiveEditorSheet(macWidth: CGFloat, macHeight: CGFloat) -> some View {
        #if os(macOS)
        self.frame(width: macWidth, height: macHeight)
        #else
        self
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        #endif
    }

    @ViewBuilder
    func compactNavigationTitleOnPhone() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

struct BrandBackground: View {
    var body: some View {
        LinearGradient(
            colors: [BrandTheme.mist, platformBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var platformBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let note: String
    let icon: String
    var tint: Color = BrandTheme.teal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Spacer()
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        }
    }
}

struct StatusBadge: View {
    let text: String
    var color: Color = BrandTheme.teal

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
    }
}
