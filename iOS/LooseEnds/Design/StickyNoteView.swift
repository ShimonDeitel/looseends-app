import SwiftUI

/// A triangular fold in the top-right corner of a sticky note, drawn as a
/// small darker triangle so each note reads as a literal scrap of paper.
struct FoldedCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX - rect.width * 0.28, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28))
        path.closeSubpath()
        return path
    }
}

/// The literal sticky-note visual: a lime rounded rectangle, a folded top
/// corner, a soft shadow, and one or two lines suggesting handwriting. The
/// note itself carries no position or rotation state — its parent animates
/// those via `.offset` / `.rotationEffect` so the same view can represent
/// both the scattered "just captured" state and the mid-flight snap.
struct StickyNoteView: View {
    let item: Item
    var width: CGFloat = 132

    private var previewLine: String {
        let trimmed = item.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "..." : trimmed
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LooseEndsTheme.noteGradient)

            FoldedCorner()
                .fill(LooseEndsTheme.limeDeep)

            VStack(alignment: .leading, spacing: 5) {
                Text(previewLine)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LooseEndsTheme.ink)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if let bucket = item.bucket {
                    Label(bucket.shortLabel, systemImage: bucket.symbolName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(LooseEndsTheme.ink.opacity(0.65))
                }
            }
            .padding(10)
        }
        .frame(width: width, height: width)
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 6)
    }
}

#Preview {
    ZStack {
        LooseEndsTheme.charcoal.ignoresSafeArea()
        StickyNoteView(item: Item(rawText: "Call the dentist tomorrow at 3pm"))
            .rotationEffect(.degrees(-9))
    }
}
