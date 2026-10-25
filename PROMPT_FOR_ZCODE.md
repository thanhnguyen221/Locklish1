# PROMPT CHO ZCODE

Copy toàn bộ nội dung bên dưới (từ dòng "---" trở xuống) và gửi cho Zcode, kèm file `grammar_data.json`.

---

Bạn là senior developer. Dự án của tôi là ứng dụng học tiếng Anh. Tôi cần bạn thêm **module Ngữ pháp (Grammar)** gồm 3 phần: **Lộ trình học**, **Bảng IPA**, và **Bài học ngữ pháp theo chủ đề**.

## Bước 0: Khảo sát trước khi code
1. Đọc cấu trúc dự án hiện tại (framework, ngôn ngữ, router, state management, UI library, cách đặt tên file, cách lưu dữ liệu).
2. Tóm tắt ngắn cho tôi: stack đang dùng, nơi bạn định đặt module mới, và các file sẽ tạo/sửa. Sau đó triển khai theo đúng convention hiện có, **không tự đổi kiến trúc hay thêm thư viện nặng** nếu không thật sự cần.

## Dữ liệu nguồn
File đính kèm `grammar_data.json` có cấu trúc:
- `roadmap[]`: 4 giai đoạn (A1, A2, B1, B2), mỗi giai đoạn có `goals_vi`, `duration_weeks`, `ipa_focus`, `topic_ids`.
- `ipa`: `vowels_monophthongs`, `vowels_diphthongs`, `consonants` (mỗi mục có `symbol`, `example`, `tip_vi`), `stress_marks`, `special_rules_vi`.
- `topics[]`: mỗi chủ đề có `id`, `level`, `title_en`, `title_vi`, `explanation_vi`, `forms[]`, `examples[]` (en/vi), `common_mistakes[]` (wrong/right/note_vi), `exercises[]` (q/answer).

Hãy đặt file này vào thư mục dữ liệu phù hợp của dự án và import từ đó (không hard-code nội dung vào component). Viết hàm/service đọc dữ liệu có type (TypeScript interface hoặc tương đương) để dễ mở rộng thêm chủ đề sau này.

## Yêu cầu chức năng

### 1. Lộ trình (Roadmap)
- Trang tổng quan hiển thị 4 giai đoạn dạng timeline/thẻ, thể hiện level, mục tiêu, số tuần, và danh sách chủ đề của giai đoạn đó.
- Click vào chủ đề để mở bài học.
- Hiển thị tiến độ: số chủ đề đã hoàn thành / tổng, theo từng giai đoạn và toàn bộ.

### 2. Bảng IPA
- 3 tab: Nguyên âm đơn, Nguyên âm đôi, Phụ âm.
- Mỗi âm là một thẻ: ký hiệu IPA lớn, từ ví dụ, mẹo phát âm tiếng Việt (`tip_vi`).
- Nút nghe phát âm: dùng Web Speech API (`speechSynthesis`, lang `en-GB` hoặc `en-US`) đọc từ ví dụ. Có công tắc chọn giọng Anh/Mỹ.
- Phụ âm có nhãn hữu thanh / vô thanh.
- Khu vực riêng hiển thị `special_rules_vi` (đuôi -s/-es, -ed, lỗi bỏ âm cuối).

### 3. Bài học ngữ pháp
- Danh sách chủ đề có lọc theo level (A1/A2/B1/B2) và tìm kiếm theo tên (cả tiếng Anh và tiếng Việt).
- Trang chi tiết gồm: giải thích, công thức (`forms`), ví dụ song ngữ (có nút nghe), mục "Lỗi thường gặp" (sai -> đúng, tô màu phân biệt), và bài tập.
- Bài tập: người học nhập đáp án, bấm kiểm tra, hiển thị đúng/sai và đáp án. So sánh không phân biệt hoa thường, bỏ khoảng trắng thừa, chấp nhận nhiều đáp án khi `answer` có dấu "/" (ví dụ "can't / cannot").
- Nút "Đánh dấu đã học" và lưu kết quả bài tập.
- Nút Trước/Sau để chuyển giữa các chủ đề.

### 4. Lưu tiến độ
- Lưu tiến độ (chủ đề đã học, điểm bài tập gần nhất) bằng cơ chế lưu trữ mà dự án đang dùng (localStorage / database / state có sẵn). Nếu chưa có, dùng localStorage bọc try/catch.

## Yêu cầu phi chức năng
- UI nhất quán với giao diện hiện có; responsive mobile; hỗ trợ dark mode nếu dự án đã có.
- Giao diện tiếng Việt, nội dung tiếng Anh giữ nguyên.
- Truy cập được (aria-label cho nút nghe, tab điều hướng được bằng bàn phím).
- Code sạch, tách component nhỏ, không lặp code, có xử lý trường hợp dữ liệu thiếu.
- Dữ liệu được validate khi load (chủ đề trong `topic_ids` phải tồn tại trong `topics`).

## Cách làm việc
1. Gửi tôi bản kế hoạch ngắn (stack, danh sách file, cấu trúc component) và chờ tôi gật đầu nếu có điểm bất thường, còn nếu không thì tiến hành luôn.
2. Triển khai theo thứ tự: data layer -> Roadmap -> IPA -> Grammar lesson + exercises -> lưu tiến độ.
3. Sau mỗi phần, chạy build/lint/test (nếu có) và sửa lỗi.
4. Cuối cùng báo cáo: file đã tạo/sửa, cách chạy thử, và những gì chưa làm.

## Không làm
- Không xóa hay viết lại tính năng cũ.
- Không thêm dependency mới nếu có thể dùng thứ đã có.
- Không tự ý sửa nội dung trong `grammar_data.json` (nếu thấy lỗi, liệt kê cho tôi).
