import SwiftUI

/// Ruban horaire d'une journée. Les segments viennent de DayTimeline.segments(...).
/// `summary` est lu par VoiceOver (utilise DayTimeline.summary(segments:)).
struct HourRibbon: View {
    @Environment(\.palette) private var palette
    private let segments: [DaySegment]
    private let range: HourRange
    private let nowHour: Double?
    private let summary: String

    init(segments: [DaySegment], range: HourRange = HourRange(from: 6, to: 24), nowHour: Double? = nil, summary: String) {
        self.segments = segments
        self.range = range
        self.nowHour = nowHour
        self.summary = summary
    }

    /// Étiquettes de l'axe : 7 repères régulièrement espacés (6, 9, 12, 15, 18, 21, 24 pour la plage 6 à 24).
    static func axisLabels(range: HourRange) -> [Int] {
        var labels: [Int] = []
        let span = range.to - range.from
        for i in 0...6 {
            labels.append(Int((range.from + span * Double(i) / 6).rounded()))
        }
        return labels
    }

    private func color(for segment: DaySegment) -> Color {
        return segment.activity.tone.color(palette)
    }

    /// Position et largeur d'un segment dans la piste, nil s'il sort de la plage.
    private func geometry(startHour: Double, endHour: Double, width: CGFloat) -> (x: CGFloat, w: CGFloat)? {
        let span = max(range.to - range.from, 1)
        let s = max(startHour, range.from)
        let e = min(endHour, range.to)
        if e <= s { return nil }
        let x = CGFloat((s - range.from) / span) * width
        let w = max(CGFloat((e - s) / span) * width, 2)
        return (x: x, w: w)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .fill(palette.fill)
                    ForEach(segments) { segment in
                        segmentView(segment, width: proxy.size.width)
                    }
                    nowMarker(width: proxy.size.width)
                }
            }
            .frame(height: 28)
            HStack {
                ForEach(Array(HourRibbon.axisLabels(range: range).enumerated()), id: \.offset) { item in
                    Text("\(item.element)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(palette.textTertiary)
                    if item.offset < 6 { Spacer(minLength: 0) }
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    @ViewBuilder
    private func segmentView(_ segment: DaySegment, width: CGFloat) -> some View {
        if let g = geometry(startHour: segment.startHour, endHour: segment.endHour, width: width) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(segment.isDoubt ? segment.activity.tone.soft(palette) : color(for: segment))
                .overlay {
                    if segment.isDoubt {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(color(for: segment), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    }
                }
                .frame(width: g.w, height: 20)
                .offset(x: g.x)
        }
    }

    @ViewBuilder
    private func nowMarker(width: CGFloat) -> some View {
        if let h = nowHour, let g = geometry(startHour: h, endHour: h + 0.05, width: width) {
            Rectangle()
                .fill(palette.textPrimary)
                .frame(width: 2, height: 28)
                .offset(x: g.x)
        }
    }
}

/// Chiffre clé : libellé avec pastille de couleur, valeur en chiffres mono, note.
struct StatTile: View {
    @Environment(\.palette) private var palette
    private let label: String
    private let value: String
    private let note: String?
    private let tone: PLTTone

    init(label: String, value: String, note: String? = nil, tone: PLTTone = .neutral) {
        self.label = label
        self.value = value
        self.note = note
        self.tone = tone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs + Theme.Spacing.xxs) {
                Circle()
                    .fill(tone.color(palette))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
            }
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.textPrimary)
            if let note = note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
