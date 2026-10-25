import Foundation
import SwiftData
import SwiftUI

// MARK: - ImportMode
enum ImportMode: String, CaseIterable, Identifiable {
    case rawText = "Dán văn bản"
    case pdfFile = "Tệp PDF"
    case csvFile = "Tệp CSV"

    var id: String { rawValue }
}

// MARK: - ImportViewModel
@Observable
@MainActor
final class ImportViewModel {
    var mode: ImportMode = .rawText
    var rawText: String = ""
    var selectedPDFName: String? = nil
    var extractedTextFromPDF: String = ""

    // CSV import state
    var selectedCSVName: String? = nil
    var csvEntryLines: [String] = []
    var csvRowCount: Int = 0

    var isExtracting: Bool = false
    var extractionProgressText: String = ""
    var errorMessage: String? = nil
    var showErrorAlert: Bool = false

    var previewItems: [VocabularyItemDTO] = []
    var selectedItemIndices: Set<Int> = []

    // Custom AI Prompt & Target Options
    var customPrompt: String = ""
    var targetWordCount: Int = 20
    var isCustomPromptExpanded: Bool = true

    // Deck / Folder Selection & Creation
    var selectedDeck: VocabularyDeck? = nil
    var newDeckName: String = ""
    var isCreatingNewDeck: Bool = false

    /// Automatically detects if the user entered/uploaded a pre-compiled word list
    var detectedListCount: Int? {
        if mode == .csvFile {
            return csvEntryLines.isEmpty ? nil : csvEntryLines.count
        }
        guard let list = LocalVocabularyExtractorService.shared.parsePrecompiledList(from: normalizedInputText), !list.isEmpty else {
            return nil
        }
        return list.count
    }

    /// The exact text used for detection and extraction — pasted text goes through the
    /// same normalization as PDF extraction (spaces, soft hyphens, ligatures, quotes).
    var normalizedInputText: String {
        ImportTextNormalizer.normalize(mode == .rawText ? rawText : extractedTextFromPDF)
    }

    // MARK: - PDF File Handling
    /// True while a PDF is being parsed off the main thread.
    var isExtractingPDF: Bool = false

    func handleSelectedPDF(url: URL) {
        guard !isExtractingPDF else { return }
        isExtractingPDF = true

        // PDFKit text extraction of a large document can take seconds — run it
        // off the main actor so the dropzone spinner animates smoothly.
        Task.detached(priority: .userInitiated) { [weak self] in
            let result: Result<String, Error> = await {
                // Security-scoped access must wrap the whole read
                let accessGranted = url.startAccessingSecurityScopedResource()
                defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
                do {
                    let text = try PDFExtractorService.extractText(from: url)
                    return .success(text)
                } catch {
                    return .failure(error)
                }
            }()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isExtractingPDF = false
                switch result {
                case .success(let extracted):
                    self.extractedTextFromPDF = extracted
                    self.selectedPDFName = url.lastPathComponent
                    HapticFeedback.light()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                    HapticFeedback.error()
                }
            }
        }
    }

    var canFallbackOffline: Bool = false

    // MARK: - CSV File Handling
    func handleSelectedCSV(url: URL) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let parsed = CSVImportService.parseToEntryLines(content)
            guard parsed.rowCount > 0, !parsed.lines.isEmpty else {
                errorMessage = "Không đọc được từ vựng nào từ tệp CSV. Kiểm tra tệp có định dạng 'từ;nghĩa' (mỗi dòng một từ) nhé."
                showErrorAlert = true
                HapticFeedback.error()
                return
            }
            csvEntryLines = parsed.lines
            csvRowCount = parsed.rowCount
            selectedCSVName = url.lastPathComponent
            HapticFeedback.light()
        } catch {
            errorMessage = "Không thể đọc tệp CSV: \(error.localizedDescription)"
            showErrorAlert = true
            HapticFeedback.error()
        }
    }

    // MARK: - AI Extraction Trigger (With Automatic Seamless Fallback)
    func startExtraction() async {
        // CSV mode: deterministic import of the parsed file — no AI involved.
        if mode == .csvFile {
            guard !csvEntryLines.isEmpty else {
                errorMessage = "Hãy chọn tệp CSV (Anki, Quizlet, Excel) trước khi nhập."
                showErrorAlert = true
                return
            }

            isExtracting = true
            extractionProgressText = "Đang nhập \(csvEntryLines.count) từ từ tệp CSV..."
            let dtos = await LocalVocabularyExtractorService.shared.extractPrecompiledList(fromNormalizedLines: csvEntryLines)
            finishExtraction(with: dtos)
            return
        }

        let inputText = normalizedInputText
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Vui lòng nhập văn bản hoặc chọn tệp PDF trước khi phân tích."
            showErrorAlert = true
            return
        }

        isExtracting = true

        // Detect a pre-compiled list ONCE on the normalized text. When found, Gemini
        // receives the re-serialized clean list (word /ipa/ (pos): meaning lines) so it
        // enriches exactly the user's composed entries instead of re-parsing raw noise.
        let detectedEntries = LocalVocabularyExtractorService.shared.parsePrecompiledList(from: inputText)
        let isPrecompiledList = detectedEntries != nil && detectedEntries!.count >= 2
        let geminiInput: String
        if isPrecompiledList, let entries = detectedEntries {
            extractionProgressText = "Đang lấy trọn vẹn \(entries.count) từ theo danh sách của bạn..."
            geminiInput = LocalVocabularyExtractorService.shared.serializePrecompiledList(entries)
        } else {
            extractionProgressText = "AI đang chọn lọc từ vựng trọng tâm trong bài..."
            geminiInput = inputText
        }

        // Hard post-validation: clean English headwords only. List mode keeps the user's
        // own short entries; passage mode is strictly single words.
        func sanitized(_ dtos: [VocabularyItemDTO]) -> [VocabularyItemDTO] {
            LocalVocabularyExtractorService.shared.validateAndCleanItems(dtos, allowMultiWord: isPrecompiledList)
        }

        // No valid Gemini key: resolve on-device. Detected lists go through the
        // deterministic pre-compiled parser (100% coverage, user meanings kept).
        guard GeminiService.shared.hasValidKey else {
            let dtos: [VocabularyItemDTO]
            if isPrecompiledList {
                dtos = await LocalVocabularyExtractorService.shared.extractPrecompiledList(from: inputText)
            } else {
                dtos = await LocalVocabularyExtractorService.shared.extractVocabulary(
                    from: inputText,
                    maxCount: 80
                )
            }
            finishExtraction(with: sanitized(dtos))
            return
        }

        // Try Gemini Cloud AI; if unavailable, seamlessly fall back to Local AI
        do {
            let dtos = try await GeminiService.shared.extractVocabulary(
                from: geminiInput,
                customInstruction: nil,
                targetCount: nil
            )
            finishExtraction(with: sanitized(dtos))
        } catch {
            print("Gemini API unavailable (\(error.localizedDescription)). Seamlessly falling back to Smart Local AI...")
            let dtos: [VocabularyItemDTO]
            if isPrecompiledList {
                dtos = await LocalVocabularyExtractorService.shared.extractPrecompiledList(from: inputText)
            } else {
                dtos = await LocalVocabularyExtractorService.shared.extractVocabulary(
                    from: inputText,
                    maxCount: 80
                )
            }
            finishExtraction(with: sanitized(dtos))
        }
    }

    private func finishExtraction(with dtos: [VocabularyItemDTO]) {
        previewItems = dtos
        selectedItemIndices = Set(0..<dtos.count)
        isExtracting = false
        if dtos.isEmpty {
            errorMessage = "Không trích xuất được từ vựng nào từ nội dung này."
            showErrorAlert = true
            HapticFeedback.error()
        } else {
            HapticFeedback.success()
        }
    }

    // MARK: - Offline Fallback Extraction
    func startOfflineExtraction() {
        let inputText = normalizedInputText
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isExtracting = true
        if detectedListCount != nil {
            extractionProgressText = "Đang lấy toàn bộ từ trong danh sách của bạn..."
        } else {
            extractionProgressText = "Đang trích xuất từ vựng, tra nghĩa & tạo phiên âm Việt..."
        }
        HapticFeedback.selection()

        Task {
            let dtos = await LocalVocabularyExtractorService.shared.extractVocabulary(from: inputText)
            previewItems = dtos
            selectedItemIndices = Set(0..<dtos.count)
            isExtracting = false
            showErrorAlert = false
            HapticFeedback.success()
        }
    }

    // MARK: - Save to SwiftData
    func saveSelectedItems(to modelContext: ModelContext) -> Int {
        var targetDeck: VocabularyDeck? = selectedDeck
        let cleanNewDeckName = newDeckName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isCreatingNewDeck && !cleanNewDeckName.isEmpty {
            let createdDeck = VocabularyDeck(name: cleanNewDeckName)
            modelContext.insert(createdDeck)
            targetDeck = createdDeck
        }

        var savedCount = 0
        for index in selectedItemIndices where index < previewItems.count {
            let dto = previewItems[index]
            let newItem = dto.toModel()
            modelContext.insert(newItem)
            if let targetDeck = targetDeck {
                targetDeck.items.append(newItem)
            }
            savedCount += 1
        }

        try? modelContext.save()
        HapticFeedback.success()
        reset()
        return savedCount
    }

    func toggleSelection(at index: Int) {
        if selectedItemIndices.contains(index) {
            selectedItemIndices.remove(index)
        } else {
            selectedItemIndices.insert(index)
        }
        HapticFeedback.selection()
    }

    func reset() {
        rawText = ""
        selectedPDFName = nil
        extractedTextFromPDF = ""
        selectedCSVName = nil
        csvEntryLines = []
        csvRowCount = 0
        previewItems = []
        selectedItemIndices = []
        errorMessage = nil
        showErrorAlert = false
        selectedDeck = nil
        newDeckName = ""
        isCreatingNewDeck = false
    }
}
