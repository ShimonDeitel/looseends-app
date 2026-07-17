import Foundation

/// A deliberately plain, un-gamified summary of check-in honesty: a current
/// streak of consecutively-closed loops, plus flat totals. No score, no
/// levels, no badges.
struct HonestyStats: Equatable {
    let currentStreak: Int
    let totalClosed: Int
    let totalLetGo: Int
}

enum HonestyEngine {
    /// Computes honesty stats from every answered check-in, ordered by when
    /// it was answered (falling back to capture order if unanswered somehow
    /// slips through). The current streak counts trailing "yes" answers
    /// from the most recent backwards, resetting the instant a "no" is hit.
    static func stats(for items: [Item]) -> HonestyStats {
        let answered = items
            .filter { $0.checkInStatus == .answeredYes || $0.checkInStatus == .answeredNo }
            .sorted { lhs, rhs in
                (lhs.checkInAnsweredAt ?? lhs.createdAt) < (rhs.checkInAnsweredAt ?? rhs.createdAt)
            }

        let totalClosed = answered.filter { $0.checkInStatus == .answeredYes }.count
        let totalLetGo = answered.filter { $0.checkInStatus == .answeredNo }.count

        var streak = 0
        for item in answered.reversed() {
            guard item.checkInStatus == .answeredYes else { break }
            streak += 1
        }

        return HonestyStats(currentStreak: streak, totalClosed: totalClosed, totalLetGo: totalLetGo)
    }
}
