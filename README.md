# Fast Food Pre-order Pickup & POS — SWP301

Hệ thống bán & quản lý đồ ăn nhanh theo **Requirements Baseline V6**: hai kênh order
**ONLINE_PREORDER** (đặt trước từ xa + hẹn giờ đến lấy tại cửa hàng) và **POS** (walk-in tại quầy).
**MVP không có Delivery/Shipper.**

| Tài liệu | Nội dung |
|---|---|
| [docs/preview-2 (1).html](docs/preview-2%20(1).html) | Phân tích hệ thống V6 — nguồn sự thật |
| [docs/STRUCTURE.md](docs/STRUCTURE.md) | Cấu trúc dự án, mapping class & URL |
| [docs/DATABASE-PLAN.md](docs/DATABASE-PLAN.md) | Plan thi công database chi tiết |

## Công nghệ

| Thành phần | Lựa chọn |
|---|---|
| Backend | Java Servlet (MVC 3 lớp: Controller → Service → DAO) |
| View | JSP + JSTL |
| Database | SQL Server (JDBC + PreparedStatement) |
| Server | Apache Tomcat 9.x |
| Build | Maven (WAR) |
| Pool | HikariCP |

## Luồng nghiệp vụ chính

```
ONLINE_PREORDER
  Login → Cart → Chọn pickup_time (≥ now+30') → Thanh toán online (PAID)
       → System auto CONFIRMED + sinh Pickup Code
       → Chờ tới kitchen_release_at (= pickup_time − 20')
       → Scheduler release sang KDS (idempotent)
       → Kitchen: WAITING → PREPARING → READY
       → Notification ORDER_READY (kèm pickup_time + code/QR)
       → Cashier verify code/QR → Handoff → COMPLETED

POS
  Walk-in → Cashier tạo Order → Thu Cash/Online tại quầy
       → CONFIRMED + release KDS ngay → READY → Handoff → COMPLETED
```

## Cài đặt

1. **Database** — chạy một file duy nhất trong SSMS (F5) hoặc:
   ```bash
   sqlcmd -S localhost -U sa -P '<password>' -C -i database/FastFoodPreorder.sql
   ```
   File tự tạo lại toàn bộ bảng + dữ liệu mẫu. Chi tiết: [database/README.md](database/README.md)
2. **Cấu hình kết nối** — sửa `src/main/resources/db.properties` (url, username, password).
3. **Build & deploy**
   ```bash
   mvn clean package
   # copy target/fastfood.war vào <TOMCAT_HOME>/webapps/
   ```
4. Truy cập `http://localhost:8080/fastfood/`

## Tài khoản demo (password: `123456`)

| Role | Email |
|---|---|
| Customer | customer1@gmail.com |
| Cashier | cashier1@fastfood.vn |
| Kitchen | kitchen1@fastfood.vn |
| Admin | admin@fastfood.vn |

## Trạng thái hiện tại

Đã dựng **khung dự án**: cấu trúc thư mục, `pom.xml`, `web.xml`, database schema + seed,
enum nghiệp vụ đã khóa (mục 18), skeleton JSP cho 20 màn hình theo mã CUS/STF/KIT/ADM.

Chưa implement: Entity, DAO, Service, Servlet, Filter, Scheduler, Integration —
danh sách class và URL mapping dự kiến đã liệt kê đầy đủ trong [docs/STRUCTURE.md](docs/STRUCTURE.md).
