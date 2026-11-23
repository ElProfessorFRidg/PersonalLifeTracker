import SwiftUI
import SwiftData
import Observation
import UIKit

/// Un créneau lu sur la photo, en cours de relecture. Rien n'est enregistré tant que l'utilisateur n'a pas validé.
struct PlanningShiftDraft: Identifiable, Equatable {
    let id: UUID
    var day: Date
    /// Nil si la case n'a pas pu être lue : l'utilisateur saisit les heures ou retire le créneau.
    var startMinutes: Int?
    /// Peut dépasser 1440 (fin le lendemain).
    var endMinutes: Int?
    var confidence: Double
    var reason: String?
    /// "C'est bon" tapé (créneau moyen) ou créneau corrigé à la main.
    var isResolved: Bool
    var wasEdited: Bool

    var level: ScheduleConfidenceLevel {
        if wasEdited { return .high }
        return ScheduleConfidence.level(confidence)
    }

    var hasTimes: Bool { return startMinutes != nil && endMinutes != nil }

    /// Reste à régler avant de pouvoir garder : heures manquantes, ou créneau pas fiable et pas encore validé.
    var needsAttention: Bool {
        if !hasTimes { return true }
        if isResolved { return false }
        return level != .high
    }

    /// Un créneau incertain ("Incertain") ne se valide pas d'un tap : il se corrige ou se retire.
    var canConfirmAsIs: Bool {
        return hasTimes && !isResolved && level == .mid
    }

    var durationMinutes: Int? {
        guard let s = startMinutes, let e = endMinutes else { return nil }
        return max(0, e - s)
    }
}

enum PlanningImportPhase: Equatable {
    case idle
    case loading
    case result
    case failed(title: String, message: String)
    case saved(count: Int, skipped: Int)
}

@MainActor
@Observable
final class PlanningImportModel {
    var phase: PlanningImportPhase = .idle
    var progress: Double = 0
    var image: UIImage? = nil
    private(set) var messageWeek: Date?
    private(set) var skippedMessageLines: [String] = []
    var notice: String? = nil
    var errorMessage: String? = nil
    var drafts: [PlanningShiftDraft] = []
    private(set) var parse: ScheduleParseResult? = nil
    private(set) var forcedRow: Int? = nil
    private(set) var lineConfirmed: Bool = false
    private(set) var weekOffset: Int = 0

    private var lines: [OCRTextLine] = []
    private var names: [String] = []
    private var readTask: Task<Void, Never>? = nil

    // MARK: - Profil

    /// "Léo, Léo Martin, LM" donne trois variantes.
    static func parseNames(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n")
        return text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Lecture

    func start(image: UIImage, names: [String], notice: String? = nil, triesOtherOrientations: Bool = true) {
        readTask?.cancel()
        messageWeek = nil
        skippedMessageLines = []
        self.image = image
        self.names = names
        self.notice = notice
        self.errorMessage = nil
        parse = nil
        drafts = []
        forcedRow = nil
        weekOffset = 0
        lineConfirmed = false
        progress = 0
        phase = .loading
        readTask = Task { [weak self] in
            guard let cgImage = ScheduleOCR.normalizedImage(image) else {
                self?.failReading()
                return
            }
            do {
                let found = try await ScheduleOCR.recognizeLines(in: cgImage) { value in
                    Task { @MainActor in
                        self?.progress = value
                    }
                }
                if Task.isCancelled { return }
                guard let self else { return }
                let initial = ScheduleTextParser.parse(lines: found, options: self.orientationOptions)
                if triesOtherOrientations && (initial.rowNames.isEmpty || (cgImage.height > cgImage.width && initial.shifts.isEmpty)) {
                    let orientations: [UIImage.Orientation] = [.left, .right]
                    var bestLines = found
                    var bestImage = image
                    var best = initial
                    for orientation in orientations {
                        if Task.isCancelled { return }
                        let rotated = UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
                        guard let upright = ScheduleOCR.normalizedImage(rotated),
                              let candidateLines = try? await ScheduleOCR.recognizeLines(in: upright) else { continue }
                        let candidate = ScheduleTextParser.parse(lines: candidateLines, options: self.orientationOptions)
                        if self.orientationRank(candidate) > self.orientationRank(best) {
                            best = candidate
                            bestLines = candidateLines
                            bestImage = UIImage(cgImage: upright)
                        }
                        if best.shifts.count >= 2, best.unreadable.isEmpty { break }
                    }
                    if Task.isCancelled { return }
                    self.image = bestImage
                    self.finishReading(bestLines)
                } else {
                    self.finishReading(found)
                }
            } catch {
                if Task.isCancelled { return }
                self?.failReading()
            }
        }
    }

    private var orientationOptions: ScheduleParseOptions {
        ScheduleParseOptions(names: names, referenceDate: Date(), calendar: PlanningSupport.calendar)
    }

    private func orientationRank(_ result: ScheduleParseResult) -> Int {
        guard !result.rowNames.isEmpty else { return 0 }
        let matchingRow = result.chosenRowIndex == nil ? 0 : 1000
        return matchingRow + min(40, result.rowNames.count) + result.shifts.count * 100
    }

    func rotatePhoto() {
        guard let image, let normalized = ScheduleOCR.normalizedImage(image) else { return }
        let rotated = UIImage(cgImage: normalized, scale: 1, orientation: .right)
        start(image: rotated, names: names, notice: notice, triesOtherOrientations: false)
    }

    func readMessage(_ text: String, week: Date) {
        reset()
        let calendar = PlanningSupport.calendar
        let result = PlanningMessageParser.read(text, week: week, calendar: calendar)
        messageWeek = PlanningRules.weekStart(for: week, calendar: calendar)
        skippedMessageLines = result.skippedLines
        drafts = result.entries.flatMap { entry in
            entry.ranges.map { range in
                PlanningShiftDraft(id: UUID(), day: entry.day,
                                   startMinutes: range.startMinutes, endMinutes: range.endMinutes,
                                   confidence: range.crossesMidnight ? 0.5 : 1,
                                   reason: range.crossesMidnight ? "Cette plage finit le lendemain. Vérifie les deux heures." : nil,
                                   isResolved: false, wasEdited: false)
            }
        }.sorted { ($0.day, $0.startMinutes ?? 0) < ($1.day, $1.startMinutes ?? 0) }
        lineConfirmed = true
        phase = .result
    }

    func cancelReading() {
        readTask?.cancel()
        readTask = nil
        reset()
    }

    func reset() {
        readTask?.cancel()
        readTask = nil
        image = nil
        messageWeek = nil
        skippedMessageLines = []
        notice = nil
        errorMessage = nil
        parse = nil
        drafts = []
        lines = []
        forcedRow = nil
        weekOffset = 0
        lineConfirmed = false
        progress = 0
        phase = .idle
    }

    private func failReading() {
        phase = .failed(title: "J'arrive pas à lire cette photo",
                        message: "La lecture a planté. Rien n'a été enregistré. Essaie avec une autre photo.")
    }

    private func finishReading(_ found: [OCRTextLine]) {
        lines = found
        rebuild()
    }

    private func rebuild() {
        let options = ScheduleParseOptions(names: names,
                                           referenceDate: Date(),
                                           calendar: Calendar.current,
                                           forcedRowIndex: forcedRow,
                                           guessedWeekOffset: weekOffset)
        let result = ScheduleTextParser.parse(lines: lines, options: options)
        parse = result
        switch result.failure {
        case .some(.noText):
            phase = .failed(title: "J'arrive pas à lire cette photo",
                            message: "Je ne vois aucun texte dessus. Rien n'a été enregistré. Tu peux en reprendre une.")
            return
        case .some(.noHeader):
            phase = .failed(title: "Je ne retrouve pas le tableau",
                            message: "Je ne vois pas les jours de la semaine en haut des colonnes. Rien n'a été enregistré. Cadre tout le tableau et reprends une photo.")
            return
        case .some(.nameNotFound), .none:
            break
        }

        var list: [PlanningShiftDraft] = []
        for shift in result.shifts {
            list.append(PlanningShiftDraft(id: UUID(),
                                           day: shift.day,
                                           startMinutes: shift.startMinutes,
                                           endMinutes: shift.endMinutes,
                                           confidence: shift.confidence,
                                           reason: shift.reason,
                                           isResolved: false,
                                           wasEdited: false))
        }
        for cell in result.unreadable {
            list.append(PlanningShiftDraft(id: UUID(),
                                           day: cell.day,
                                           startMinutes: nil,
                                           endMinutes: nil,
                                           confidence: 0,
                                           reason: "Je n'ai pas réussi à lire « \(cell.rawText) ». Saisis les heures ou retire ce jour.",
                                           isResolved: false,
                                           wasEdited: false))
        }
        list.sort { a, b in
            if a.day != b.day { return a.day < b.day }
            return (a.startMinutes ?? -1) < (b.startMinutes ?? -1)
        }
        drafts = list
        lineConfirmed = !result.needsLineChoice || forcedRow != nil
        phase = .result
    }

    // MARK: - Ligne et semaine

    /// Choisir sa ligne relance l'analyse : les corrections déjà faites sur l'ancienne ligne sont perdues.
    func chooseRow(_ index: Int) {
        forcedRow = index
        rebuild()
    }

    /// "C'est bien ma ligne" : garde la ligne retenue sans relancer l'analyse.
    func confirmLine() {
        lineConfirmed = true
    }

    /// Fichier illisible ou lecture impossible : l'écran d'échec explique quoi faire.
    func failWith(title: String, message: String) {
        phase = .failed(title: title, message: message)
    }

    func shiftWeek(by delta: Int) {
        weekOffset += delta
        rebuild()
    }

    var chosenRowName: String? {
        guard let result = parse, let index = result.chosenRowIndex, index < result.rowNames.count else { return nil }
        return result.rowNames[index]
    }

    // MARK: - Relecture

    var pendingCount: Int {
        return drafts.filter { $0.needsAttention }.count
    }

    var needsLineSelection: Bool {
        guard let result = parse else { return false }
        return result.chosenRowIndex == nil
    }

    var canKeep: Bool {
        if drafts.isEmpty { return false }
        if needsLineSelection || !lineConfirmed { return false }
        return pendingCount == 0
    }

    var totalMinutes: Int {
        return drafts.reduce(0) { $0 + ($1.durationMinutes ?? 0) }
    }

    func markOK(_ id: UUID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        if drafts[index].canConfirmAsIs {
            drafts[index].isResolved = true
        }
    }

    func remove(_ id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    /// Applique une correction d'heures. Renvoie un message d'erreur si le texte n'est pas une heure.
    func applyEdit(id: UUID, startText: String, endText: String) -> String? {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return nil }
        guard let start = ScheduleTextParser.parseClockInput(startText) else {
            return "Le début doit être une heure, par exemple 09:00."
        }
        guard let end = ScheduleTextParser.parseClockInput(endText) else {
            return "La fin doit être une heure, par exemple 16:00."
        }
        if start == end {
            return "Le début et la fin sont identiques."
        }
        drafts[index].startMinutes = start
        drafts[index].endMinutes = end > start ? end : end + 1440
        drafts[index].confidence = 1.0
        drafts[index].reason = nil
        drafts[index].isResolved = true
        drafts[index].wasEdited = true
        return nil
    }

    // MARK: - Enregistrement

    /// Crée les créneaux prévus (source "photo"). Les créneaux identiques déjà présents ne sont pas doublés.
    func keep(in context: ModelContext) {
        if !canKeep { return }
        let calendar = PlanningSupport.calendar
        var inserted: [PlannedShift] = []
        do {
            var existing = try context.fetch(FetchDescriptor<PlannedShift>())
            var additions: [PlannedShift] = []
            var skipped = 0
            for draft in drafts {
                guard let s = draft.startMinutes, let e = draft.endMinutes else { continue }
                let start = ScheduleTextParser.date(day: draft.day, minutes: s, calendar: calendar)
                let end = ScheduleTextParser.date(day: draft.day, minutes: e, calendar: calendar)
                if existing.contains(where: { $0.start == start && $0.end == end && $0.activity == .work }) {
                    skipped += 1
                    continue
                }
                if end <= start || existing.contains(where: { $0.activity == .work && $0.start < end && $0.end > start }) {
                    errorMessage = "Deux créneaux de travail se chevauchent. Vérifie les horaires avant d’enregistrer."
                    return
                }
                let shift = PlannedShift(start: start, end: end, activity: .work,
                                         source: messageWeek == nil ? "photo" : "text")
                additions.append(shift)
                existing.append(shift)
            }
            for shift in additions {
                context.insert(shift)
                inserted.append(shift)
            }
            try context.save()
            errorMessage = nil
            phase = .saved(count: inserted.count, skipped: skipped)
        } catch {
            for shift in inserted { context.delete(shift) }
            errorMessage = "Je n'ai pas pu enregistrer les créneaux. Réessaie dans un instant."
        }
    }
}
