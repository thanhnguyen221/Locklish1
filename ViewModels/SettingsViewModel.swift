import Foundation
import SwiftUI

// MARK: - SettingsViewModel
@Observable
@MainActor
final class SettingsViewModel {
    var geminiAPIKeyInput: String = ""
    var isKeySaved: Bool = false
    var showKeySavedToast: Bool = false
    var testKeyResult: String? = nil
    var isTestingKey: Bool = false

    init() {
        self.geminiAPIKeyInput = GeminiService.shared.apiKey
    }

    func saveGeminiKey() {
        GeminiService.shared.apiKey = geminiAPIKeyInput
        isKeySaved = true
        showKeySavedToast = true
        testKeyResult = nil
        HapticFeedback.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.showKeySavedToast = false
        }
    }

    func testGeminiKey() async {
        let key = geminiAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            testKeyResult = "⚠️ Vui lòng nhập API Key trước khi kiểm tra."
            return
        }

        isTestingKey = true
        testKeyResult = nil

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)"
        guard let url = URL(string: urlString) else {
            isTestingKey = false
            testKeyResult = "❌ URL không hợp lệ"
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": "Hi"]]]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            isTestingKey = false
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    testKeyResult = "✅ Tuyệt vời! API Key hợp lệ và đã kết nối thành công với Gemini AI."
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? [String: Any],
                       let msg = err["message"] as? String {
                        if msg.contains("denied access") {
                            testKeyResult = "❌ Lỗi 403: Tài khoản Google này bị từ chối truy cập (Denied Access). Bạn hãy dùng tài khoản Gmail khác tạo key tại aistudio.google.com nhé."
                        } else if msg.contains("API key not valid") {
                            testKeyResult = "❌ Lỗi 400: API Key không đúng định dạng. Key chuẩn của Google bắt đầu bằng 'AIzaSy...'."
                        } else {
                            testKeyResult = "❌ Lỗi (\(http.statusCode)): \(msg)"
                        }
                    } else {
                        testKeyResult = "❌ Lỗi máy chủ: HTTP \(http.statusCode)"
                    }
                }
            }
        } catch {
            isTestingKey = false
            testKeyResult = "❌ Lỗi kết nối mạng: \(error.localizedDescription)"
        }
    }

    func reloadGameCatalog() {
        GameCatalogService.shared.reloadCatalogFromSource()
        HapticFeedback.success()
    }
}
