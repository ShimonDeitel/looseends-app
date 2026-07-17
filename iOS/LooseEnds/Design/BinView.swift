import SwiftUI

/// One of the four labeled bins at the bottom of the capture screen. Reports
/// its own frame via `BinFramePreferenceKey` so scattered notes know exactly
/// where to snap to, and glows briefly when a note lands (`isReceiving`).
struct BinView: View {
    let bucket: Bucket
    let count: Int
    var isReceiving: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: bucket.symbolName)
                    .font(.system(size: 18, weight: .bold))
                Text(bucket.shortLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(count)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(LooseEndsTheme.lime)
            }
            .foregroundStyle(LooseEndsTheme.offWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LooseEndsTheme.binFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(LooseEndsTheme.lime.opacity(isReceiving ? 1 : 0.55), lineWidth: isReceiving ? 3 : 1.5)
                    )
                    .shadow(color: LooseEndsTheme.lime.opacity(isReceiving ? 0.55 : 0), radius: isReceiving ? 14 : 0)
            )
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: BinFramePreferenceKey.self,
                    value: [bucket: geo.frame(in: .named("captureSpace"))]
                )
            }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isReceiving)
    }
}
