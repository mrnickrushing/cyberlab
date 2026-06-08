import Foundation

extension String {
    func strippingANSI() -> String {
        // Matches ESC[ ... m and other CSI sequences
        let pattern = "\u{1B}\\[[0-9;]*[a-zA-Z]|\u{1B}[^\\[][^a-zA-Z]*[a-zA-Z]|\u{1B}\\].*?\u{07}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
    }
}
