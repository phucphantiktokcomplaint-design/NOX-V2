# Ghi chú cập nhật NOX (V2)

- Splash NOX hiển thị 5 giây trước khi chuyển tới luồng xác thực KEY.
- Đã đổi tên hiển thị/product/bundle identifier sang NOX / `com.phucphan.nox`; scheme chia sẻ là `NOX`.
- Tự chạy kernel exploit đã bị vô hiệu hóa; hàm gọi cũ chỉ ghi log, không thực thi.
- Màn HOME không hiển thị KEY thô; chỉ hiển thị trạng thái license.
- Thông báo bảo trì đổi thành đúng câu: `The NOX APP is under maintenance. Please wait!`.
- Đã chỉnh một số token nền sang palette sáng.
- Không có GitHub PAT phát hiện trong source khi quét chuỗi mẫu; tài liệu placeholder đã thêm.

**Chưa build/test bằng Xcode:** môi trường chỉnh sửa không có macOS/iOS SDK.
**Các màn PATCH/game-targeting và exploit-related code không được triển khai/chỉnh để kích hoạt.**
