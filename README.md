# ChiaTien

iOS app chia tiền nhóm, viết bằng SwiftUI.

## Tính năng

**Chia nhanh** — nhập tổng hoá đơn, chọn số người, app tính mỗi người trả bao nhiêu. Hỗ trợ thêm phí dịch vụ/tip (0-30%) và làm tròn lên nghìn.

**Chia tiền nhóm** — quản lý thành viên, thêm nhiều khoản chi với một hoặc nhiều người ứng tiền. App tự tính số dư từng người và đề xuất quyết toán tối thiểu giao dịch (greedy matching).

## Yêu cầu

- iOS 17.0+
- Xcode 15+
- Swift 5.0

## Build

```bash
git clone <repo-url>
open ChiaTien.xcodeproj
```

Build và chạy trên simulator hoặc device từ Xcode. Không cần CocoaPods hay SPM — project không có dependency ngoài.

## CI

Project có GitHub Actions workflow tự build và xuất file `.ipa` mỗi khi push lên `main` hoặc tạo tag `v*`. Xem [Actions tab](../../actions) để tải IPA.

## License

MIT
