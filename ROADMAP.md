# Locklish — Roadmap "App thật đỉnh"

> Cập nhật: 24/10/2026. Trạng thái hiện tại: lõi học tập đã chắc (import sạch, SRS SM-2, thống kê, YouTube song ngữ). Tài liệu này liệt kê **thứ tự việc cần làm** để đưa app lên đỉnh.

## Tôi đã có gì (đã xong, giữ vững)

- **Import từ PDF / dán văn bản**: chuẩn hoá Unicode chung, parser danh sách soạn sạch (strip phiên âm, lọc tiêu đề rác, chống từ tiếng Việt ASCII), gửi Gemini bản danh sách đã làm sạch, hậu kiểm cứng kết quả AI.
- **SRS SM-2 (SuperMemo)**: step / easeFactor / intervalDays / nextReviewDate / reviewCount — chạy trong Flashcard + Chép chính tả.
- **Thống kê từng folder**: số từ cần ôn hôm nay, biểu đồ núi 14 ngày, lịch từng ngày, sức nhớ + số lần ôn thật của từng từ.
- **YouTube song ngữ**: player in-app sạch (không chrome/CC), karaoke theo timing từng từ thật của YouTube, phụ đề ưu tiên track người thật làm, dịch đủ 100% câu.
- Design system nền: AppTheme (sage/linen, dark mode), thẻ bo góc liên tục, gradient dịu.

## P0 — Chất lượng lõi (làm trước, 1–2 tuần)

1. **Kiểm thử tự động cho luồng dễ vỡ nhất**: XCUITest cho import (dán list → lưu), parser test đã có harness swiftc — đưa vào CI/thư mục Tests chính thức; unit test cho SRSEngine (kịch bản again/good/easy, mốc 1→6→15 ngày).
2. ~~**Độ bền phụ đề YouTube**~~ ✅ *Đã xong toàn bộ (24/10): client InnerTube IOS dự phòng, cache phụ đề ra đĩa (xem lại offline), lỗi rõ ràng khi video chỉ có phụ đề ngôn ngữ khác (liệt kê ngôn ngữ có sẵn).*
3. ~~**Onboarding 3 màn**~~ ✅ *Đã xong (24/10): chọn mục tiêu → giới thiệu import (mở được ngay) → giải thích vòng SM-2; hiện lần đầu cho người dùng mới, người đã có folder tự bỏ qua.*
4. ~~**Nhắc ôn hàng ngày**~~ ✅ *Đã xong: ReviewReminderService + toggle trong Cài đặt, nội dung lấy số từ due thật, tự làm mới khi mở app.*
5. ~~**Nút "Ôn ngay" từ Thống kê**~~ ✅ *Đã xong: nút gradient trong thẻ Hôm nay đẩy thẳng vào Flashcard theo queue due.*

> Hiệu năng (24/10): đã tối ưu YouTube study (bridge JS 30→6 Hz + nội suy, cache display model khỏi 30 fps tick, binary search câu active), deck card màn chủ 5→1 pass items, DeckStats 15→1 pass. Nguyên tắc duy trì: **không string-op nào lặp lại trong TimelineView/onChange mỗi frame**.

## P1 — Tính năng tạo đỉnh (2–6 tuần)

6. ~~**Widget màn hình chính + Lock Screen**~~ ✅ *Đã xong (24/10): target LocklishWidget (Small + Medium) hiển thị số từ cần ôn + vòng % đã thuộc; dữ liệu SRS thật truyền qua App Group `group.com.locklish.shared` (file JSON — ổn định hơn UserDefaults suite), reload timeline khi mở app và khi app active lại; refresh sau mỗi buổi luyện.*
   - *Lưu ý kỹ thuật: khai báo App Group bằng `properties` trong project.yml cho CẢ 2 target — xcodegen xoá rỗng file entitlements nếu chỉ khai `path:`. Đã verify end-to-end trên simulator: app ghi file JSON thật vào shared container.*
   - *Còn: Lock Screen widget (accessory family) — mở rộng sau.*
7. ~~**Luyện nói (Speak & Check)**~~ ✅ *Đã xong (24/10): SpeechRecognitionService (SFSpeechRecognizer en-US) + SpeakPracticeView (mode Từ/Câu ví dụ, mic đập theo âm lượng RMS, chấm similarity Levenshtein → % + vòng điểm, nộp SM-2). Vào từ DeckDetail → hàng "Luyện nói".*
8. ~~**Đọc to + karaoke (Truyện AI)**~~ ✅ *Đã xong (24/10), đúng phạm vi: YouTube đã dùng **âm thanh thật của video** (không TTS); karaoke TTS thuộc về màn Truyện AI — TTSService phát queue từng đoạn (title + paragraphs) và highlight đúng từ đang đọc qua callback thật `willSpeakRangeOfSpeechString` (không ước lượng thời gian): từ hiện tại gạch chân accent đậm, từ đã đọc màu primary, đoạn tự cuộn theo giọng đọc.*
9. ~~**iCloud Sync (SwiftData + CloudKit)**~~ ✅ *Code-side xong (24/10): schema chuẩn CloudKit (bỏ `.unique`, mọi attr có default, relationship có inverse `deck`), entitlements iCloud + aps-environment + background remote-notification, backup store 1 lần trước migration (đã verify migration không mất dữ liệu: 99 từ nguyên vẹn), card trạng thái đồng bộ trong Cài đặt (CloudSyncService).*
   - *Cần làm khi lên máy thật: tạo container `iCloud.com.locklish.app` trong CloudKit Dashboard với Apple Developer team + capability signing. Simulator chưa đăng nhập iCloud → hiển thị đúng trạng thái "Chưa đăng nhập".*
10. ~~**Chuỗi ngày (streak) + mục tiêu ngày**~~ ✅ *Streak đã xong (24/10): StreakService hook tại SRSEngine.processReview nên mọi loại luyện đều tính; banner 🔥 trên màn chủ (chuỗi hiện tại + kỷ lục). Còn: mục tiêu số từ/ngày tuỳ chọn.*
11. ~~**Xuất/nhập Anki + CSV**~~ ✅ *Hoàn chỉnh cả 2 chiều (24/10): Xuất CSV 7 cột (ShareLink, BOM UTF-8). Nhập: chế độ "Tệp CSV" thứ 3 trong Trích xuất — tự nhận delimiter (`;` `,` tab), header map theo tên cột (Word/IPA/POS/Meaning/Example… hoặc Term/Definition kiểu Quizlet), quote-escape chuẩn RFC-4180, BOM Excel; round-trip với chính file app xuất giữ nguyên IPA/POS/ví dụ/dịch — 9/9 test PASS. Từ CSV đi qua đúng pipeline sạch (sanitize headword, tự dịch phần thiếu).*
12. ~~**Chế độ iPad + landscape**~~ ✅ *Đã xong (24/10): TARGETED_DEVICE_FAMILY 1,2 + mở orientation (iPhone portrait+landscape, iPad đủ 4 hướng). YouTube study chuyển **2 cột trên màn rộng** (video trái max 560pt + phụ đề phải) qua horizontalSizeClass regular; Thống kê đặt thẻ Hôm nay & biểu đồ núi cạnh nhau trên wide. Đã verify render trên iPad Pro 11" landscape + iPhone portrait không hồi quy.*

## P2 — Giao diện "đơn giản nhưng đẹp hiệu quả" (kế hoạch redesign theo cụm)

Nguyên tắc: 1 màu chủ đạo (sage) + 1 accent (terracotta), tối đa 2 cỡ chữ tiêu đề, mọi card ≤ 3 vùng thông tin, mọi con số phải có nhãn giải thích cạnh nó. AppTheme đã đủ token — việc còn lại là áp dụng nhất quán:

| Màn | Việc làm |
|---|---|
| Màn chủ | ✅ Đã làm (avatar màu, chip "Cần ôn N", vòng %, search hoạt động thật) |
| DeckDetail | ✅ (24/10) Hàng "Ôn ngay N từ đến hạn" màu warning khi có due → thẳng Flashcard; speak row + quick actions đồng bộ card style |
| GamifiedGameHub | ✅ (24/10) Stat bar đổi emoji → SF Symbols trong vòng màu đồng bộ theme, bỏ shadow chồng, badge BẮT ĐẦU gọn |
| Import | ✅ (24/10) Chọn folder gọn thành 1 hàng pill (menu + inline textfield tạo mới) |
| Settings | ✅ (24/10) Nhóm 3 mục có header: HỌC TẬP (phương pháp, nhắc ôn, iCloud, dữ liệu) / AI & DỊCH DỤNG (Gemini) / GIỚI THIỆU |

## P3 — Phát hành (trước khi lên App Store)

> Chi tiết từng bước nằm trong **RELEASE.md**.

13. **TestFlight beta** 20–30 người thật, thu phản hồi 2 tuần. *(Cần: Apple Developer account của bạn — các bước đã ghi sẵn trong RELEASE.md.)*
14. **IAP**: bản Premium — sync iCloud, widget, theme. (Import + SRS để free.) — *làm SAU khi có người dùng thật.*
15. ~~**App Store assets**~~ ✅ *Đã xong (25/10): App icon + **6 ảnh chụp 6.7" thật** (XCUITest điều hướng qua app thật, kèm dịch song ngữ đang chạy) trong thư mục `AppStoreScreenshots/`: home · grammar roadmap · IPA · news feed · article song ngữ · game hub. Cần thêm bộ iPad khi submit.*
16. ~~**Riêng tư & hiệu năng**~~ ✅ Phần code (24/10): PrivacyInfo.xcprivacy (không tracking, không thu thập — khai báo API UserDefaults/FileTimestamp), PDF import off-main-thread với spinner "Đang đọc PDF…", launch path đã gọn (lazy container). Còn: đo thời gian mở app trên máy thật trong đợt TestFlight.
17. **Bản địa hoá EN** cho toàn bộ chuỗi — nếu nhắm thị trường ngoài Việt Nam.

## P4 — Module mở rộng theo yêu cầu (đã xong, 25/10)

- ✅ **Module Ngữ pháp** (Lộ trình CEFR A1-B2 · Bảng IPA 3 tab + giọng Anh-Anh/Mỹ · 28 bài học + bài tập chấm đa đáp án · lưu tiến độ) — UI nâng cấp bento-gradient theo màu cấp độ.
- ✅ **Module Tin tức** (24 nguồn đã verify + 5 chờ mạng · đọc toàn văn + ảnh inline đúng thứ tự · viewer zoom fullscreen · **dịch song ngữ theo đoạn bằng Gemini batch + cache** · tra từ Cambridge + Lưu từ · độ khó ước lượng · chips gợi ý ngữ pháp · Reddit cấu hình sẵn chờ verify).
- ✅ **Redesign bento-gradient toàn app** (màn chủ · Học từ · Ngữ pháp · Tin tức) theo trend 2025-26.

## Việc KHÔNG nên làm (tránh sa lầy)

- Tự host server proxy Gemini lúc này (chi phí + pháp lý) — giữ BYO-key.
- Thêm ngôn ngữ thứ 2 (Nhật/Hàn) trước khi tiếng Anh hoàn thiện.
- Tự train model AI riêng — dùng API là đủ.
