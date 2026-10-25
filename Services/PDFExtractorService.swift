import Foundation
import PDFKit

// MARK: - PDFExtractorService
/// High-performance, robust PDF text extraction engine leveraging PDFKit.
/// Handles security-scoped resource access, byte buffering, and page-by-page text assembly.
struct PDFExtractorService {
    enum ExtractionError: LocalizedError {
        case fileAccessDenied
        case unableToOpenFile
        case emptyDocument
        case scannedOrProtectedPDF

        var errorDescription: String? {
            switch self {
            case .fileAccessDenied:
                return "Không có quyền truy cập tệp PDF đã chọn. Vui lòng thử lại."
            case .unableToOpenFile:
                return "Không thể mở tệp PDF. Tệp có thể bị hỏng hoặc có mật khẩu bảo vệ."
            case .emptyDocument:
                return "Tệp PDF không có trang nào."
            case .scannedOrProtectedPDF:
                return "Tệp PDF này là dạng hình ảnh scan (chưa có lớp chữ số) hoặc không chứa nội dung văn bản có thể trích xuất. Bạn có thể sao chép văn bản trực tiếp vào tab Dán văn bản."
            }
        }
    }

    /// Extracts clean text from a local or iCloud PDF URL with security-scoped resource protection.
    /// - Parameter url: The security-scoped URL provided by .fileImporter.
    /// - Returns: Complete, normalized text content across all pages.
    static func extractText(from url: URL) throws -> String {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Attempt 1: Load PDF directly via URL
        var document = PDFDocument(url: url)

        // Attempt 2: Buffer binary data directly into memory if URL-based init was restricted
        if document == nil {
            if let data = try? Data(contentsOf: url) {
                document = PDFDocument(data: data)
            }
        }

        guard let pdfDocument = document else {
            throw ExtractionError.unableToOpenFile
        }

        let totalPages = pdfDocument.pageCount
        guard totalPages > 0 else {
            throw ExtractionError.emptyDocument
        }

        var fullText = ""

        for pageIndex in 0..<totalPages {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                // Same normalization as the paste-text side (spaces, hyphens, ligatures)
                fullText.append(ImportTextNormalizer.normalize(pageText))
                fullText.append("\n\n")
            }
        }

        let cleaned = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw ExtractionError.scannedOrProtectedPDF
        }

        return cleaned
    }
}
