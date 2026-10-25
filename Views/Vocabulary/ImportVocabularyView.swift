import SwiftUI
import SwiftData

// MARK: - ImportVocabularyView
/// Full-screen, spacious AI vocabulary extractor interface.
/// Eliminates cramped modal sheets in favor of an eye-soothing, minimalist workspace.
struct ImportVocabularyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ImportViewModel()
    @State private var isDocumentPickerPresented: Bool = false
    @State private var isCSVPickerPresented: Bool = false
    @Query(sort: \VocabularyDeck.createdAt, order: .reverse) private var existingDecks: [VocabularyDeck]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background
                AppTheme.background
                    .ignoresSafeArea(.all)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Intro
                        headerIntroSection

                        // Mode Switcher
                        modeSelectorSection

                        // Content Input Area (Text, PDF or CSV)
                        if viewModel.mode == .rawText {
                            rawTextInputSection
                        } else if viewModel.mode == .pdfFile {
                            pdfUploadDropzoneSection
                        } else {
                            csvUploadDropzoneSection
                        }

                        // Smart List Detection Banner
                        if let listCount = viewModel.detectedListCount {
                            smartListBanner(count: listCount)
                        }

                        // Deck / Folder Destination
                        deckSelectionSection

                        // Extract Action Button
                        extractButtonSection

                        // AI Analysis Results
                        if !viewModel.previewItems.isEmpty {
                            previewResultsSection
                        }

                        // Spacer for bottom sticky bar
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                // Sticky Bottom Save Bar (Visible when results are ready)
                if !viewModel.previewItems.isEmpty {
                    stickySaveActionBar
                }
            }
            .navigationTitle("Trích xuất thông minh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticFeedback.light()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Quay lại")
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .fileImporter(
                isPresented: $isDocumentPickerPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let pickedUrl = urls.first {
                        viewModel.handleSelectedPDF(url: pickedUrl)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showErrorAlert = true
                    HapticFeedback.error()
                }
            }
            .fileImporter(
                isPresented: $isCSVPickerPresented,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .utf8PlainText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let pickedUrl = urls.first {
                        viewModel.handleSelectedCSV(url: pickedUrl)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showErrorAlert = true
                    HapticFeedback.error()
                }
            }
            .alert("Thông báo", isPresented: $viewModel.showErrorAlert) {
                if viewModel.canFallbackOffline {
                    Button("Trích xuất dự phòng ngay") {
                        viewModel.startOfflineExtraction()
                    }
                }
                Button("Đóng", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Header Intro
    private var headerIntroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trích xuất từ vựng qua AI")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Tải lên tài liệu PDF hoặc dán văn bản tiếng Anh. App chọn lọc từ vựng đơn trọng tâm hoặc lấy trọn danh sách từ vựng soạn sẵn, kèm phiên âm tiếng Việt tự nhiên.")
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Mode Selector
    private var modeSelectorSection: some View {
        HStack(spacing: 8) {
            ForEach(ImportMode.allCases) { mode in
                let isSelected = viewModel.mode == mode
                Button {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.mode = mode
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mode == .rawText ? "text.alignleft" : (mode == .pdfFile ? "doc.text.fill" : "tablecells"))
                            .font(.system(size: 15, weight: .medium))
                        Text(mode.rawValue)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? AppTheme.primary : AppTheme.cardBackground)
                    .foregroundStyle(isSelected ? Color.white : AppTheme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                            .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Raw Text Input Section
    private var rawTextInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nội dung bài đọc tiếng Anh")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.rawText)
                    .font(.body)
                    .lineSpacing(5)
                    .padding(16)
                    .frame(minHeight: 200)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)

                if viewModel.rawText.isEmpty {
                    Text("Dán bài báo, bài luận, tài liệu hoặc đoạn văn bản tiếng Anh vào đây...")
                        .font(.body)
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(22)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - PDF Upload Dropzone Section
    private var pdfUploadDropzoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tài liệu định dạng PDF")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            Button {
                HapticFeedback.light()
                isDocumentPickerPresented = true
            } label: {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.12))
                            .frame(width: 72, height: 72)

                        Image(systemName: viewModel.selectedPDFName != nil ? "checkmark.circle.fill" : "doc.badge.arrow.up")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    if let pdfName = viewModel.selectedPDFName {
                        VStack(spacing: 6) {
                            Text(pdfName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                Text("Đã sẵn sàng trích xuất (\(viewModel.extractedTextFromPDF.count) ký tự)")
                                    .font(.caption)
                            }
                            .foregroundStyle(AppTheme.success)
                        }
                    } else if viewModel.isExtractingPDF {
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(AppTheme.primary)
                            Text("Đang đọc PDF…")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Tài liệu dài có thể mất vài giây")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else {
                        VStack(spacing: 6) {
                            Text("Chạm để chọn tệp PDF")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Hỗ trợ tài liệu học tập, giáo trình, báo cáo")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.caption)
                        Text(viewModel.selectedPDFName != nil ? "Đổi tệp PDF khác" : "Duyệt tệp trong máy")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
                .locklishCardStyle(cornerRadius: AppTheme.cornerRadiusCard)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - CSV Upload Dropzone Section
    private var csvUploadDropzoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tệp từ vựng CSV / Anki / Quizlet")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            Button {
                HapticFeedback.light()
                isCSVPickerPresented = true
            } label: {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.12))
                            .frame(width: 72, height: 72)

                        Image(systemName: viewModel.selectedCSVName != nil ? "checkmark.circle.fill" : "tablecells")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    if let csvName = viewModel.selectedCSVName {
                        VStack(spacing: 6) {
                            Text(csvName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                Text("Đã đọc \(viewModel.csvEntryLines.count) từ — sẵn sàng nhập")
                                    .font(.caption)
                            }
                            .foregroundStyle(AppTheme.success)
                        }
                    } else {
                        VStack(spacing: 6) {
                            Text("Chạm để chọn tệp CSV")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Hỗ trợ Anki, Quizlet, Excel — ngăn cách bởi dấu ; , hoặc tab")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.caption)
                        Text(viewModel.selectedCSVName != nil ? "Đổi tệp khác" : "Duyệt tệp trong máy")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.accent.opacity(0.08))
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
                .locklishCardStyle(cornerRadius: AppTheme.cornerRadiusCard)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Smart List Banner
    private func smartListBanner(count: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.success)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Phát hiện danh sách đã soạn sẵn (\(count) từ)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Hệ thống sẽ lấy toàn bộ từ tiếng Anh trong nội dung vào từ điển, giữ nguyên nghĩa bạn đã chú thích và tự bổ sung phiên âm tiếng Việt.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .stroke(AppTheme.success.opacity(0.25), lineWidth: 1)
        )
    }



    // MARK: - Deck Selection Section (compact single row)
    private var deckSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lưu vào bộ từ")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.primary)

                if viewModel.isCreatingNewDeck {
                    TextField("Tên tệp mới (vd: IELTS Writing...)", text: $viewModel.newDeckName)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)

                    Button {
                        HapticFeedback.light()
                        viewModel.isCreatingNewDeck = false
                        viewModel.newDeckName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Menu {
                        Button {
                            viewModel.selectedDeck = nil
                            viewModel.isCreatingNewDeck = false
                        } label: {
                            HStack {
                                Text("Chưa gán tệp (Tất cả)")
                                if viewModel.selectedDeck == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        if !existingDecks.isEmpty {
                            Divider()
                            ForEach(existingDecks) { deck in
                                Button {
                                    viewModel.selectedDeck = deck
                                    viewModel.isCreatingNewDeck = false
                                } label: {
                                    HStack {
                                        Text(deck.name)
                                        if viewModel.selectedDeck?.id == deck.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        Button {
                            viewModel.isCreatingNewDeck = true
                            viewModel.selectedDeck = nil
                        } label: {
                            Label("Tạo tệp mới...", systemImage: "plus.circle")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedDeck?.name ?? "Chưa gán tệp")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.primary)
                                .lineLimit(1)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Extract Action Button
    private var extractButtonSection: some View {
        Button {
            Task {
                await viewModel.startExtraction()
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isExtracting {
                    ProgressView()
                        .tint(.white)
                    Text(viewModel.extractionProgressText)
                        .font(.headline)
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "sparkles")
                        .font(.headline)
                    Text("Phân tích & Trích xuất Từ vựng")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .shadow(color: AppTheme.primary.opacity(0.25), radius: 10, x: 0, y: 4)
        }
        .disabled(viewModel.isExtracting)
    }

    // MARK: - Preview Results Section
    private var previewResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kết quả phân tích")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Đã chọn \(viewModel.selectedItemIndices.count) / \(viewModel.previewItems.count) từ để lưu")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button("Chọn tất cả") {
                    HapticFeedback.light()
                    viewModel.selectedItemIndices = Set(0..<viewModel.previewItems.count)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.primary)
            }
            .padding(.top, 12)

            ForEach(Array(viewModel.previewItems.enumerated()), id: \.offset) { index, item in
                let isSelected = viewModel.selectedItemIndices.contains(index)

                HStack(alignment: .top, spacing: 14) {
                    Button {
                        viewModel.toggleSelection(at: index)
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(item.word)
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)

                            AudioSpeakerButton(word: item.word, size: 28, iconSize: 13, tintColor: AppTheme.primary)

                            Spacer()

                            Text(item.ipa)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        // Vietnamese phonetic accent
                        Text("Phát âm: \(item.viPhonetic)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.primary)

                        HStack(spacing: 6) {
                            if !item.partOfSpeech.isEmpty {
                                Text(item.partOfSpeech)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }

                            Text(item.meaning)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        let parsed = VocabularyItem.splitExampleAndNote(
                            rawExample: item.example ?? "",
                            rawTranslation: item.exampleTranslation ?? "",
                            rawNote: item.note ?? ""
                        )

                        if !parsed.example.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ví dụ: \(parsed.example)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                                if !parsed.translation.isEmpty {
                                    Text("(\(parsed.translation))")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            .padding(.top, 2)
                        }

                        if !parsed.note.isEmpty {
                            Text("Ghi chú: \(parsed.note)")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.accent)
                                .padding(.top, 1)
                        }
                    }
                }
                .padding(18)
                .locklishCardStyle(cornerRadius: AppTheme.cornerRadiusMedium)
            }
        }
    }

    // MARK: - Sticky Bottom Save Action Bar
    private var stickySaveActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.primary.opacity(0.06))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.selectedItemIndices.count) từ vựng")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Sẵn sàng thêm vào từ điển")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    let count = viewModel.saveSelectedItems(to: modelContext)
                    if count > 0 {
                        dismiss()
                    }
                } label: {
                    Text("Lưu vào từ điển")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(AppTheme.primaryGradient)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.primary.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .disabled(viewModel.selectedItemIndices.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground)
        }
    }
}
