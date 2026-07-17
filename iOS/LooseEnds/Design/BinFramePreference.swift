import SwiftUI

/// Collects each bin's frame (in the shared "captureSpace" coordinate
/// space) so the capture screen can animate a note's position to land
/// exactly centered on its target bin.
struct BinFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Bucket: CGRect] = [:]

    static func reduce(value: inout [Bucket: CGRect], nextValue: () -> [Bucket: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
