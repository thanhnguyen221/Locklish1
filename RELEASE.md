# Locklish — Checklist phát hành (P3)

> Trạng thái code: P0/P1/P2 ✅ 100%. Tài liệu này là việc còn lại ĐỂ SHIP.

## Đã chuẩn bị sẵn trong code (24/10)

- ✅ App icon 1024 (Assets.xcassets, single-size universal) — nền gradient sage + chữ L.
- ✅ PrivacyInfo.xcprivacy: **không theo dõi, không thu thập dữ liệu** (điểm bán hàng lớn); khai báo API UserDefaults (CA92.1) + FileTimestamp (C617.1).
- ✅ Universal app (iPhone + iPad), đủ 4 hướng trên iPad.
- ✅ Version 1.0.0 (build 1) trong build settings.
- ✅ PDF import chạy off-main-thread (UI không đơ với tài liệu dài).
- ✅ Backup store 1 lần trước migration + fallback 4 nấc không crash-loop.

## Việc cần LÀM TRÊN APPLE DEVELOPER (bạn)

1. **App ID + capability**: developer.apple.com → Identifiers → com.locklish.app → bật iCloud (container `iCloud.com.locklish.app`) + Push Notifications.
2. **CloudKit Dashboard**: tạo container `iCloud.com.locklish.app`, Production environment sau khi test.
3. **App Store Connect**: tạo app mới "Locklish" — primary language Vietnamese; danh mục Education.
4. **TestFlight**: archive bằng Xcode (Any iOS Device) → Product → Archive → Distribute App → TestFlight & App Store. Group beta 20–30 người, phiếu phản hồi 2 tuần.
5. **Máy thật test sync**: 2 iPhone cùng Apple ID sau khi bật iCloud — kiểm tra folder + tiến trình SRS đồng bộ.

## IAP Premium (làm SAU khi có người dùng thật)

- Gói: Premium (mở khoá) — đề xuất chốt: **sync iCloud + widget + theme**; giữ free: import, SRS, luyện tập cốt lõi.
- StoreKit 2, product id `locklish.premium.lifetime`. Cần App Store Connect tạo product trước khi code paywall.
- Lưu ý pháp lý VN: giá VND, chính sách hoàn tiền hiển thị trong paywall.

## Ảnh chụp App Store (6.7" bắt buộc + iPad 13")

Kể chuyện "từ tài liệu → folder ôn tập trong 5 phút":
1. Màn chủ (folder + chip "Cần ôn N" + streak 🔥)
2. Import PDF → preview kết quả sạch
3. Thống kê folder (biểu đồ núi + "Ôn ngay N từ")
4. YouTube study 2 cột trên iPad (phụ đề song ngữ karaoke)
5. Luyện nói (mic + kết quả chấm điểm %)
6. Widget màn hình chính + màn Cài đặt (điểm nhấn "Không thu thập dữ liệu")

Chụp bằng simulator: `xcrun simctl io booted screenshot` — nhớ tắt debug chrome, bật dark mode cho 3 ảnh.

## Audit trước khi submit

- [ ] Chạy 1 lượt full flow trên máy thật: import → luyện 4 kiểu → widget → notification → streak.
- [ ] Kill app giữa buổi luyện → mở lại: session restore đúng (Flashcard/Dictation có SessionProgressManager).
- [ ] Airplane mode: import offline, YouTube đã cache vẫn mở được, thông báo lỗi hiển thị tử tế.
- [ ] VoiceOver nhanh qua màn chủ + Flashcard (label đầy đủ).
- [ ] Thời gian lạnh mở app < 1s trên iPhone thường.
- [ ] Đọc lại Privacy Policy URL (cần 1 trang web đơn giản — GitHub Pages đủ).

## Không làm (đã quyết định trong ROADMAP)

- Không server riêng / proxy Gemini (BYO-key).
- Không thêm ngôn ngữ học thứ 2 trước khi tiếng Anh hoàn thiện.
