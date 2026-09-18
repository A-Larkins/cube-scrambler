import Foundation

/// Turns a deal number into the scramble that produces it, and picks fresh ones.
///
/// Both scramblers work the same way round: take a position, solve it, and reverse the
/// solution. The only difference here is where the position comes from - a deal number
/// rather than a throw of the dice - and since the numbering covers every position exactly
/// once, drawing a random number is drawing a random position. Uniformity is unchanged.
enum Dealer {

    /// The scramble for one deal, and always the same one: the 2x2's solutions are optimal,
    /// and the 3x3's search is budgeted in nodes rather than seconds, so neither depends on
    /// how busy the machine is.
    static func moves(forDeal number: UInt128, puzzle: PuzzleKind) -> [Move] {
        let cube = Deal.cube(for: number, puzzle: puzzle)
        switch puzzle {
        case .three:
            return Scrambler333.solve(cube).inverted
        case .two:
            return Scrambler222.solve(state: Scrambler222.stateIndex(of: cube),
                                      distances: Scrambler222.distances).inverted
        }
    }

    /// A uniformly random deal, skipping the handful that are barely scrambled at all.
    /// A cube three turns from solved is a legal draw and a useless scramble.
    static func randomDeal(puzzle: PuzzleKind, using rng: inout some RandomNumberGenerator) -> UInt128 {
        let total = Deal.total(for: puzzle)
        while true {
            let number = UInt128.random(in: 0..<total, using: &rng)
            guard puzzle == .two else { return number }
            if Scrambler222.distances[Int(number)] >= 4 { return number }
        }
    }
}
