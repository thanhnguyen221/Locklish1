# Locklish — Nhật ký phát triển tổng hợp

> Tài liệu tổng kết toàn bộ những gì đã làm trong dự án (cập nhật lần cuối: 24/10/2026).
> Trạng thái: **P0 ✅ 100% · P1 ✅ 12/12 · P2 ✅ 5/5 màn · P3 code-side ✅** — xem kế hoạch còn lại trong `ROADMAP.md` và bước phát hành trong `RELEASE.md`.

---

## 1. Import từ vựng (PDF · Dán văn bản · CSV)

### Parser & độ sạch dữ liệu
- **Bộ chuẩn hoá ký tự dùng chung** (`ImportTextNormalizer`): khoảng trắng không ngắt (NBSP), soft hyphen, ký tự zero-width, ligature (ﬁ→fi), dấu nháy cong — áp dụng **cho cả văn bản dán lẫn PDF** nên 2 luồng nhận diện như nhau.
- **Sửa headword sạch tuyệt đối** (`sanitizeHeadword`): không số, không tiếng Việt, chỉ chữ cái Anh, tối đa 3 từ, tự bỏ ngoặc/ký tự rác — "Trai"/"tinh yeu"/"Unit 1" không còn lọt vào trường từ.
- **Chống âm Việt viết không dấu**: blocklist ~100 từ Việt ASCII + `NLLanguageRecognizer` + lexicon iOS (`UITextChecker`) — từ Anh thật như "den", "con" không bị oan.
- **Nghĩa sạch**: strip tiền tố phiên âm `(ke-phồ-li)` khỏi nghĩa (cả trước và sau dấu phân cách), giữ nguyên chú thích giữa câu; bỏ nhét `(pos)` vào trường nghĩa (POS có chip riêng).
- **Sửa 2 lỗi parser thật**: dấu gạch-khít không còn cắt nát `(ke-phồ-li)` hay từ ghép `well-known`; dòng tiêu đề (`Vocabulary list:`) không bị tính thành từ, không đánh cắp nghĩa của dòng kế tiếp.
- **POS chuẩn hoá**: `(adj)/(n)...` map đúng thành "adjective"…; nội dung trong ngoặc chỉ nhận khi đúng là nhãn từ loại (không nuốt `(humble)`).

### AI & danh sách soạn sẵn
- **Prompt Gemini viết lại hoàn toàn** (OUTPUT CONTRACT tuyệt đối): word = đúng 1 token tiếng Anh, cấm phrase/idiom/collocation, cấm tiếng Việt có/không dấu, cấm tên riêng, cấm câu cắt cụt; bước SELF-CHECK bắt buộc.
- **`responseSchema`** ép cấu trúc JSON + `partOfSpeech` khoá enum 8 giá trị thật — model không thể tự gắn nhãn "phrasal verb".
- **Hậu kiểm cứng** (`validateAndCleanItems`): mọi kết quả AI (Gemini + local) đều lọc lại — bỏ cụm từ, bỏ từ Việt ASCII, khử trùng hoa/thường, dọn rác.
- **Gửi Gemini bản danh sách đã làm sạch** (`serializePrecompiledList`): dán list soạn sẵn → parser lấy đúng 100% → serialize `word /ipa/ (pos): nghĩa` → Gemini chỉ làm giàu, không tự chế.
- **Chế độ còn lại**: dán văn bản & PDF dùng chung 1 pipeline; banner "Phát hiện danh sách đã soạn sẵn (N từ)".

### CSV 2 chiều
- **Xuất**: nút share trên folder → CSV 7 cột (`Word;IPA;POS;Meaning;Phiên âm Việt;Example;Dịch`), escape chuẩn, **BOM UTF-8** cho Excel — import được vào Anki/Quizlet/Excel.
- **Nhập**: tab "Tệp CSV" thứ 3 — **tự nhận delimiter** (`;` `,` tab), **map header theo tên cột** (Word/IPA/… hoặc Term/Definition), quote-escape RFC-4180, strip BOM; round-trip với chính file app xuất giữ nguyên toàn bộ trường; từ CSV đi qua đúng pipeline sạch + tự bổ sung phần thiếu. **9/9 test PASS**.

---

## 2. YouTube study — độ chính xác & trải nghiệm

### Video player sạch
- **Sửa caption bật ngược**: script cũ `toggleSubtitles()` có thể BẬT caption đang tắt → thay bằng tắt chủ động + gọi lại mỗi lần phát lại.
- **Ẩn toàn bộ chrome YouTube**: thanh điều khiển, CC, settings, fullscreen, gradient, caption window — chỉ còn hình sạch; chạm giữa video vẫn play/pause.
- **Hết méo khung**: `<video>` ép `object-fit: contain`, tỉ lệ khung lấy từ `videoWidth/videoHeight` thật (metadata) — không bao giờ bị kéo giãn.

### Phụ đề chính xác
- **Ưu tiên track người thật làm** (manual > auto ASR) cho cả tiếng Anh lẫn tiếng Việt — parse trường `kind`.
- **Không lẫn tiếng Anh vào cột tiếng Việt** khi ghép cặp câu.
- **Dịch đủ 100% câu thiếu** (trước chỉ 20 câu đầu) — batch 8 câu xen kẽ.
- **Báo lỗi trung thực**: video không có track tiếng Anh → liệt kê ngôn ngữ có sẵn thay vì trả sub ngôn ngữ sai.
- **InnerTube 2 client** (ANDROID → IOS) trước khi xuống HTML scrape.
- **Cache phụ đề ra đĩa** (`Documents/SubtitleCache/`) — mất mạng vẫn học lại video đã mở.

### Karaoke & hiệu năng
- **Karaoke theo từ bằng timing THẬT của YouTube** (word-level từ timedtext JSON3/XML) — fallback chia tỉ lệ chỉ khi track không có.
- **Perf toàn diện**: bridge JS giảm 30 → ~6 tin/giây (nội suy thời gian lo phần giữa — clamp 0.5s); **cache display model** (tokenize + sanitize + saved-flag + boundary tính 1 lần, không 30 lần/giây); binary search câu active; cache danh sách lọc theo query.

---

## 3. SRS — Spaced Repetition (SM-2)

- Thêm `reviewCount` (số lần ôn thật) vào model + đếm trong `processReview`.
- **Màn Thống kê từng folder** (icon biểu đồ trên toolbar):
  - Số lớn "X từ cần ôn hôm nay" + "N từ đã trễ hẹn"; 3 chip Đã thuộc / Đang học / Chưa học.
  - **Nút "Ôn ngay N từ"** gradient → thẳng Flashcard queue due.
  - **Biểu đồ núi 14 ngày** (Swift Charts: Area + Line Catmull-Rom + Point, trục Y số nguyên) + dòng tổng kết "Nhiều nhất: N từ · Thứ Bảy 25/10", "Trung bình X từ/ngày".
  - **"Từng từ một"**: nhóm theo cách người học nghĩ (chờ ôn / Ngày mai / Thứ N · dd/MM / sau 7 ngày / chưa học), mỗi từ có **thanh sức nhớ** (đỏ→cam→xanh theo interval, 21+ ngày = dài hạn) + chip thời điểm + "Đã ôn N lần".
  - Toàn bộ số liệu tính **1 pass** qua items (từ 15 pass xuống 1).

---

## 4. Tính năng P1

- **Widget màn hình chính "X từ cần ôn"** (Small + Medium): target `LocklishWidget` riêng, gradient sage, vòng % đã thuộc; dữ liệu SRS thật qua **App Group** `group.com.locklish.shared` (file JSON — ổn định hơn UserDefaults suite), reload khi mở app / app active. *Xuyên qua 2 cạm bẫy: xcodegen xoá rỗng entitlements nếu khai báo thiếu `properties`; cần `ENTITLEMENTS_REQUIRED: YES`.*
- **Luyện nói Speak & Check**: `SpeechRecognitionService` (SFSpeechRecognizer en-US, live transcript + mic level RMS); màn luyện với 2 chế độ Từ/Câu ví dụ, nút mic phập phồng theo âm lượng, **chấm similarity Levenshtein** (chế độ từ lấy token khớp nhất) → vòng % + 4 mức nhận xét → **nộp SM-2**; quyền Micro + Speech trong Info.plist.
- **Streak chuỗi ngày học**: `StreakService` hook duy nhất tại `SRSEngine.processReview` → mọi loại luyện đều tính; banner 🔥 trên màn chủ (chuỗi hiện tại + kỷ lục + trạng thái hôm nay).
- **iCloud Sync (SwiftData + CloudKit)**: schema chuẩn CK (bỏ `.unique`, mọi attr có default, inverse `deck`), entitlements iCloud + aps + background remote-notification; **backup store 1 lần trước migration** (verify 99 từ nguyên vẹn); card trạng thái trong Cài đặt.
- **Fix crash launch**: container khởi tạo **4 nấc** (bình thường → tắt CK mirror → cách ly store hỏng `Recovery-<timestamp>` + tạo mới → in-memory) — không bao giờ crash-loop; log rõ từng nấc.
- **Karaoke TTS cho Truyện AI**: TTSService phát **queue từng đoạn** + callback thật `willSpeakRangeOfSpeechString` (tokenizer tính range UTF-16 từng từ) — từ đang đọc gạch chân accent, từ đã đọc màu primary, **màn tự cuộn theo giọng đọc**. (YouTube dùng audio thật video — không TTS.)
- **iPad + landscape**: Universal (device family 1,2), đủ 4 hướng iPad + landscape iPhone; **YouTube study 2 cột** trên màn rộng (player trái max 560pt + phụ đề phải); Thống kê 2 cột. Verify trên iPad Pro 11" landscape + iPhone không hồi quy.

---

## 5. P0 & P2 — nền móng + giao diện

- **Onboarding 3 màn** (lần đầu): chọn mục tiêu (4 lựa chọn) → giới thiệu import (mở thử ngay được) → giải thích vòng SM-2; người đã có folder tự bỏ qua; mọi bước skippable. Đã chụp verify UI.
- **Thông báo nhắc ôn hằng ngày**: `ReviewReminderService` + toggle trong Cài đặt, chọn giờ (07:00–22:00, mặc định 20:00), nội dung ghi đúng số từ due lúc lên lịch, tự làm mới khi mở app.
- **P2 redesign từng cụm**:
  - *Màn chủ*: card folder mới (avatar màu, chip "Cần ôn N", vòng %) + **sửa bug ô tìm kiếm không hoạt động** + trạng thái "Không tìm thấy".
  - *DeckDetail*: hàng nổi bật **"Ôn ngay N từ đến hạn"** (chỉ hiện khi có due).
  - *Import*: chọn folder gọn thành 1 hàng pill (menu + textfield tạo mới inline).
  - *Settings*: nhóm 3 mục có header — HỌC TẬP / AI & DỊCH DỤNG / GIỚI THIỆU.
  - *Game Hub*: stat bar emoji → SF Symbols trong vòng màu đồng bộ theme, bỏ shadow chồng.

---

## 6. P3 — chuẩn bị phát hành (code-side)

- **App Icon** (project trước đó KHÔNG có): tạo `Assets.xcassets` single-size 1024 — gradient sage + silhouette sách + chữ L trắng; xử lý alpha & kích thước; build sinh đủ mọi size vào bundle.
- **PrivacyInfo.xcprivacy**: không tracking, không thu thập dữ liệu; khai báo UserDefaults (CA92.1) + FileTimestamp (C617.1).
- **PDF import off-main-thread** + spinner "Đang đọc PDF…" — UI không còn đơ với PDF dài.
- `MARKETING_VERSION 1.0.0` (build 1); **RELEASE.md**: checklist Apple Developer/TestFlight (public link cho mọi người test không cần cài từng máy), kế hoạch IAP, kịch bản 6 ảnh App Store, audit trước submit.

---

## 7. Hiệu năng & chất lượng (nguyên tắc duy trì)

- Không thao tác chuỗi nào lặp trong `TimelineView` 30fps — mọi thứ tiền tính thành display model.
- Thống kê tính 1 pass (home card 5→1 pass, DeckStats 15→1 pass).
- Bridge JS ~6Hz + nội suy; binary search phụ đề.
- Parser/CSV kiểm thử bằng **harness swiftc macOS** (34+ test PASS tổng), migration verify trên dữ liệu thật, mọi màn chính đã chụp màn hình verify trên simulator iPhone + iPad landscape.

## 8. Tài liệu trong repo

| File | Nội dung |
|---|---|
| `ROADMAP.md` | Kế hoạch P0–P3, đánh dấu ✅ từng mục + ghi chú kỹ thuật |
| `RELEASE.md` | Checklist phát hành: Apple Developer, TestFlight, IAP, ảnh chụp, audit |
| `CHANGELOG.md` | File này — tổng kết toàn bộ |
