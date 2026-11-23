import Foundation

/// One dated week of personal shifts copied from a message.
enum PlanningMessageParser {
    struct Entry: Identifiable {
        let id: Int
        let day: Date
        let ranges: [ShiftTimeRange]
    }

    struct Result {
        var entries: [Entry] = []
        var skippedLines: [String] = []
    }

    private static let labelledDay = #"^(\p{L}{2,9})\.?\s*:?\s+(.+)$"#
    private static let datedDay = #"^(\d{1,2})[/.](\d{1,2})\s*:?\s+(.+)$"#
    private static let clock = #"[0-9]{1,2}(?:[:hH][0-9]{2}|[hH])?"#
    private static let range = "(?:de\\s+)?(\(clock))\\s*(?:[-–—/]|à|a)\\s*(\(clock))"
    private static let rangesOnly = "^(?:\(range))(?:\\s*[/,;]\\s*(?:\(range)))*$"

    private static func captures(_ input: String, pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: input, range: NSRange(input.startIndex..., in: input)).map { match in
            (1..<match.numberOfRanges).compactMap { index in
                Range(match.range(at: index), in: input).map { String(input[$0]) }
            }
        }
    }

    private static func readRanges(_ hours: String) -> [ShiftTimeRange]? {
        guard hours.range(of: rangesOnly, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        let parts = captures(hours, pattern: range)
        var ranges: [ShiftTimeRange] = []
        for part in parts {
            guard part.count == 2, let from = ScheduleTextParser.parseClockInput(part[0]) else { return nil }
            let to = ["24", "24h", "24h00", "24:00"].contains(part[1].lowercased())
                ? 1440 : ScheduleTextParser.parseClockInput(part[1])
            guard let to, from != to else { return nil }
            ranges.append(ShiftTimeRange(startMinutes: from, endMinutes: to < from ? to + 1440 : to,
                                         crossesMidnight: to < from))
        }
        return ranges.isEmpty ? nil : ranges
    }

    static func read(_ text: String, week: Date, calendar: Calendar) -> Result {
        let start = PlanningRules.weekStart(for: week, calendar: calendar)
        let days = PlanningRules.days(ofWeekStarting: start, calendar: calendar)
        var result = Result()
        for (index, line) in text.split(whereSeparator: \.isNewline).enumerated() {
            let raw = line.trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { continue }
            let day: Date?
            let hours: String
            if let match = captures(raw, pattern: datedDay).first, match.count == 3,
               let number = Int(match[0]), let month = Int(match[1]) {
                day = days.first { calendar.component(.day, from: $0) == number
                    && calendar.component(.month, from: $0) == month }
                hours = match[2]
            } else if let match = captures(raw, pattern: labelledDay).first, match.count == 2,
                      let header = ScheduleTextParser.parseDayHeader(match[0]),
                      header.weekdays.count == 1, let offset = header.weekdays.first,
                      days.indices.contains(offset) {
                day = days[offset]
                hours = match[1]
            } else {
                result.skippedLines.append(raw)
                continue
            }
            guard let day else {
                result.skippedLines.append(raw)
                continue
            }
            if case .rest = ScheduleTextParser.parseCell(hours) { continue }
            if let ranges = readRanges(hours) {
                result.entries.append(Entry(id: index, day: day, ranges: ranges))
            } else {
                result.skippedLines.append(raw)
            }
        }
        return result
    }
}
