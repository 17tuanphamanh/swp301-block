# Database

Toàn bộ database nằm trong **một file duy nhất**: [`FastFoodPreorder.sql`](FastFoodPreorder.sql)

```bash
sqlcmd -S localhost -U sa -P '<password>' -C -i FastFoodPreorder.sql
```

Hoặc mở file trong SSMS rồi nhấn F5. Yêu cầu SQL Server 2016 trở lên.

> **File xoá và tạo lại toàn bộ bảng mỗi lần chạy.** Thiết kế như vậy để luôn cho ra
> một database sạch, không phụ thuộc trạng thái trước đó. Đừng chạy trên dữ liệu thật.

Chạy xong, file tự in ra 6 bảng kiểm tra ở cuối — đối chiếu để biết database đã sẵn sàng:

| Mục | Kỳ vọng |
|---|---|
| 8.1 Số bản ghi | 13 bảng có dữ liệu |
| 8.2 Menu | đúng 10 món (3 món bị loại vì hết hàng / ngừng bán / danh mục tắt) |
| 8.3 Đơn hàng | 11 đơn, đủ 7 trạng thái, có 1 đơn quá hạn nhận |
| 8.4 Tỷ lệ đúng hẹn | 4 đơn, đúng hẹn 3 → 75% |
| 8.5 Đối soát tiền | **không có dòng nào** |
| 8.6 Giờ SQL Server | khớp giờ máy chạy Tomcat, lệch dưới 5 giây |

## Nội dung file

13 bảng · 15 index · 2 view · 6 trigger · dữ liệu mẫu (7 user, 13 món, 11 đơn).

Ba tên bảng khác tài liệu phân tích vì trùng từ khoá SQL Server:

| Tài liệu | Bảng thực tế |
|---|---|
| `User` | `Users` |
| `Order` | `Orders` |
| `Transaction` | `PaymentTransaction` |

Java entity vẫn giữ tên theo tài liệu; ánh xạ chỉ nằm trong tầng DAO.

## Tài khoản mẫu

Mật khẩu tất cả: **`123456`**

| Vai trò | Email |
|---|---|
| CUSTOMER | customer1@gmail.com · customer2@gmail.com |
| CASHIER | cashier1@fastfood.vn · cashier2@fastfood.vn |
| KITCHEN | kitchen1@fastfood.vn · kitchen2@fastfood.vn |
| ADMIN | admin@fastfood.vn |

Hash bcrypt dùng tiền tố `$2a$` vì jBCrypt 0.4 chỉ chấp nhận `$2$` và `$2a$` —
hash sinh bằng `htpasswd` ra `$2y$` thì phải đổi tiền tố, phần còn lại giữ nguyên.

## Thiết kế

Lý do đằng sau từng quyết định: [../docs/DATABASE-PLAN.md](../docs/DATABASE-PLAN.md)
