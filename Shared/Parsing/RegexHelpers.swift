import Foundation

extension String {
    func regexMatches(_ pattern: String, options: NSRegularExpression.Options = [],
                      in range: NSRange? = nil) -> [NSTextCheckingResult] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        return re.matches(in: self, range: range ?? NSRange(startIndex..., in: self))
    }

    func substring(_ nsRange: NSRange) -> String? {
        guard nsRange.location != NSNotFound, let r = Range(nsRange, in: self) else { return nil }
        return String(self[r])
    }

    func replacingRegex(_ pattern: String, with template: String,
                        options: NSRegularExpression.Options = []) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self), withTemplate: template)
    }
}
