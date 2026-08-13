# Cấu trúc dự án — Fast Food Pre-order Pickup & POS

Java Servlet + JSTL + SQL Server, kiến trúc MVC ba tầng.
Nguồn nghiệp vụ: [preview-2 (1).html](preview-2%20(1).html) · Thiết kế dữ liệu: [DATABASE-PLAN.md](DATABASE-PLAN.md)

---

## 1. Kiến trúc

```
Trình duyệt · Máy bán hàng tại quầy · Màn hình bếp
        │  HTTP
        ▼
┌──────────────────────────────────────────────────┐
│ BỘ LỌC   Bảng mã → Đăng nhập → Phân quyền        │  com.fastfood.filter
├──────────────────────────────────────────────────┤
│ CONTROLLER  Servlet: đọc tham số, gọi Service,   │  com.fastfood.controller
│             chọn trang hiển thị                  │
├──────────────────────────────────────────────────┤
│ SERVICE     Toàn bộ quy tắc nghiệp vụ và         │  com.fastfood.service
│             ranh giới giao dịch                  │
├──────────────────────────────────────────────────┤
│ DAO         Chỉ câu lệnh SQL, nhận sẵn Connection│  com.fastfood.dao
├──────────────────────────────────────────────────┤
│ SQL Server — FastFoodPreorder                    │
└──────────────────────────────────────────────────┘
        ▲                          ▲
   BỘ HẸN GIỜ                 TÍCH HỢP NGOÀI
   com.fastfood.scheduler     com.fastfood.integration

HIỂN THỊ: JSP + JSTL trong /WEB-INF/views — không mở trực tiếp từ trình duyệt được
```

**Ba nguyên tắc xuyên suốt**

1. **Controller không viết SQL, DAO không chứa quy tắc nghiệp vụ.** Service là nơi duy nhất
   biết cả hai, và cũng là nơi mở/đóng giao dịch.
2. **Mọi trang JSP nằm trong `WEB-INF`.** Không có đường vào nào bỏ qua được chuỗi bộ lọc.
3. **Quy tắc chống trùng lặp nằm trong chính câu lệnh SQL**, không phải ở kiểm tra trước khi ghi.

### Vì sao dùng lớp cụ thể thay vì giao diện + lớp cài đặt

DAO và Service viết thẳng thành lớp cụ thể. Mỗi lớp chỉ có một cách cài đặt, nên thêm một
giao diện chỉ làm tăng số tệp phải mở khi lần theo một luồng nghiệp vụ.

Chỗ **có** dùng giao diện là nơi thật sự cần thay thế được: `PaymentGateway` và
`NotificationSender`. Bản chạy thử dùng lớp giả lập; đổi sang cổng thanh toán thật hay
gửi email thật chỉ cần viết lớp mới, không đụng tới tầng Service.

---

## 2. Cây thư mục

```
swp301-block/
├── pom.xml                          Maven, đóng gói WAR
├── database/FastFoodPreorder.sql    Một tệp duy nhất: bảng, chỉ mục, view, dữ liệu mẫu
├── docs/                            Tài liệu phân tích và thiết kế
└── src/main/
    ├── java/com/fastfood/
    │   ├── common/constant/   10  Hằng số và kiểu liệt kê nghiệp vụ
    │   ├── common/exception/   7  Ngoại lệ mang sẵn thông báo cho người dùng
    │   ├── common/util/        9  Tiện ích, đáng chú ý là DateTimeUtil và ViewFunctions
    │   ├── config/             3  Kết nối cơ sở dữ liệu và tham số vận hành
    │   ├── model/entity/      14  13 lớp ánh xạ 13 bảng
    │   ├── model/dto/          6  Dữ liệu đã gộp sẵn cho tầng hiển thị
    │   ├── dao/               15  14 lớp truy vấn + JdbcSupport
    │   ├── service/           13  11 lớp nghiệp vụ + Tx (quản lý giao dịch)
    │   ├── integration/        8  Cổng thanh toán, kênh gửi tin
    │   ├── filter/             4  Ba bộ lọc chạy theo thứ tự
    │   ├── listener/           3  Vòng đời ứng dụng
    │   ├── scheduler/          3  Hai công việc chạy nền
    │   └── controller/        37  28 servlet chia theo vai trò
    ├── resources/                  db.properties · app.properties
    └── webapp/
        ├── assets/css/main.css
        └── WEB-INF/
            ├── web.xml · fastfood.tld
            └── views/               24 trang + 4 tệp bố cục dùng chung
```

---

## 3. Ba luồng nghiệp vụ đáng đọc trước

### 3.1 Đặt trước — giữ đơn tới sát giờ mới đưa xuống bếp

```
Khách chọn giờ → CheckoutServlet
     → OrderService.createOnlineOrder      đọc lại giá và tình trạng từng món
                                           tạo đơn ở trạng thái chờ thanh toán
     → PaymentService.startOnlinePayment   tạo bản ghi thanh toán, chuyển sang cổng
     ← PaymentCallbackServlet              cổng gửi kết quả về
     → PaymentService.handleCallback       kiểm chữ ký → ghi mã giao dịch (chống trùng)
                                           → ghi nhận tiền → xác nhận đơn
     → OrderService.confirmOnlineAfterPaid sinh mã nhận hàng, chốt giờ vào bếp
                                           = giờ hẹn trừ 20 phút

     ... đơn NẰM CHỜ, bếp chưa nhìn thấy ...

     → KitchenReleaseScheduler (mỗi 30 giây)
     → ScheduleService.releaseDueOrders    đưa xuống bếp đúng một lần
     → KitchenService.claim / markReady    bếp làm món
     → OrderService.recalculateStatus      món cuối xong → cả đơn sẵn sàng → báo khách
     → OrderService.handoff                thu ngân đối chiếu mã rồi giao món
```

### 3.2 Bán tại quầy — gọn trong một giao dịch

`PosServlet` giữ phiếu tạm trong phiên của thu ngân, không ghi xuống cơ sở dữ liệu.
Bấm thu tiền thì `OrderService.createPosOrder` làm liền một mạch: lập đơn → ghi nhận
tiền → xác nhận → đưa xuống bếp. Không có giờ hẹn, không có mã nhận hàng.

### 3.3 Ba chỗ chống trùng lặp

| Tình huống | Cách xử lý | Nằm ở |
|---|---|---|
| Bộ hẹn giờ chạy lại, đưa đơn xuống bếp hai lần | `UPDATE ... WHERE released_to_kds_at IS NULL` rồi kiểm số dòng | `OrderDAO.markReleasedToKds` |
| Cổng thanh toán gửi kết quả về hai lần | Ghi mã giao dịch có ràng buộc duy nhất; lần hai bị từ chối | `TransactionDAO.insertIfNew` |
| Khách bấm đặt hàng hai lần | Khoá chống trùng sinh khi mở trang đặt hàng | `OrderService.createOnlineOrder` |
| Hai đầu bếp nhận cùng một món | `UPDATE ... WHERE item_status = 'WAITING'` rồi kiểm số dòng | `OrderItemDAO.claim` |
| Hai món cuối xong cùng lúc, đơn kẹt mãi | Khoá dòng đơn trước khi đếm món chưa xong | `OrderService.recalculateStatus` |

---

## 4. Bảng địa chỉ

Servlet khai báo bằng `@WebServlet`. Trang JSP nằm trong `/WEB-INF/views/`.

### Không cần đăng nhập
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/menu` | MenuServlet | customer/menu.jsp |
| `/product/detail` | ProductDetailServlet | customer/product-detail.jsp |
| `/login` `/logout` `/register` | LoginServlet · LogoutServlet · RegisterServlet | auth/ |
| `/payment/callback` | PaymentCallbackServlet | (cổng thanh toán gọi vào) |

### Khách hàng
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/cart` | CartServlet | customer/cart.jsp |
| `/checkout` | CheckoutServlet | customer/checkout.jsp |
| `/payment/start` | PaymentStartServlet | → cổng thanh toán |
| `/payment/gateway` | PaymentGatewayServlet | customer/payment-gateway.jsp |
| `/order/track` | OrderTrackingServlet | customer/order-tracking.jsp |
| `/order/history` | OrderHistoryServlet | customer/order-history.jsp |
| `/profile` | ProfileServlet | customer/profile.jsp |

### Thu ngân — `/staff/*`
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/staff/pos` | PosServlet | staff/pos.jsp |
| `/staff/orders` | OrderDashboardServlet | staff/order-dashboard.jsp |
| `/staff/order/detail` | OrderDetailServlet | staff/order-detail.jsp |
| `/staff/pickup/verify` | PickupVerifyServlet | staff/pickup-verify.jsp |
| `/staff/history` | StaffHistoryServlet | staff/history.jsp |

### Bếp — `/kitchen/*`
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/kitchen/queue` | KdsQueueServlet | kitchen/kds-queue.jsp |
| `/kitchen/my-tasks` | MyTasksServlet | kitchen/my-tasks.jsp |
| `/kitchen/item` | KitchenItemServlet | kitchen/item-detail.jsp |
| `/kitchen/issue` | KitchenIssueServlet | kitchen/issue.jsp |
| `/kitchen/history` | KitchenHistoryServlet | kitchen/history.jsp |

### Quản trị — `/admin/*`
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/admin/dashboard` | AdminDashboardServlet | admin/dashboard.jsp |
| `/admin/products` | ProductManageServlet | admin/product.jsp |
| `/admin/categories` | CategoryManageServlet | admin/category.jsp |
| `/admin/users` | UserManageServlet | admin/user.jsp |
| `/admin/audit` | AuditServlet | admin/audit.jsp |

### Dữ liệu JSON cho trang tự cập nhật
| Địa chỉ | Servlet | Dùng ở |
|---|---|---|
| `/api/kds/queue` | KdsApiServlet | Màn hình bếp, hỏi lại mỗi 5 giây |
| `/api/order/status` | OrderStatusApiServlet | Trang theo dõi đơn, hỏi lại mỗi 10 giây |

---

## 5. Bảo mật

| Lớp | Thực hiện | Chặn được gì |
|---|---|---|
| `AuthenticationFilter` | Liệt kê trang công khai, còn lại bắt đăng nhập | Thêm màn hình mới mà quên khai báo thì bị bắt đăng nhập thừa, không lộ dữ liệu |
| `RoleAuthorizationFilter` | Phân quyền theo tiền tố địa chỉ | Gõ thẳng `/admin/...` vào trình duyệt |
| Kiểm tra chủ sở hữu | Điều kiện `customer_id` ngay trong câu truy vấn | Khách xem đơn của người khác. Trả về "không tìm thấy" để không lộ mã đơn nào có thật |
| Mật khẩu | bcrypt cost 10 | Lộ cơ sở dữ liệu vẫn không đọc được mật khẩu |
| Câu lệnh SQL | `PreparedStatement` toàn bộ | Chèn mã SQL qua ô tìm kiếm |
| Phiên đăng nhập | Cấp phiên mới sau khi đăng nhập | Chiếm phiên đã biết trước |
| Chữ ký cổng thanh toán | Kiểm tra trước khi ghi nhận tiền | Gọi thẳng địa chỉ nhận kết quả để tự xác nhận đơn |

---

## 6. Cách chạy

```bash
# 1. Cơ sở dữ liệu
sqlcmd -S localhost -U sa -P '<mật khẩu>' -C -i database/FastFoodPreorder.sql

# 2. Sửa src/main/resources/db.properties cho khớp máy chủ SQL Server

# 3. Đóng gói và triển khai
mvn clean package
cp target/fastfood.war $TOMCAT_HOME/webapps/
```

Mở `http://localhost:8080/fastfood/` — mật khẩu mọi tài khoản mẫu là `123456`.

Cấu hình hiện tại dùng **Tomcat 9** (`javax.servlet`). Chạy Tomcat 10 trở lên phải đổi
phụ thuộc sang `jakarta.*` và đổi toàn bộ lệnh `import javax.servlet.*`.

---

## 7. Ngoài phạm vi — không có trong mã nguồn

Không giao hàng tận nơi, không nhiều chi nhánh, không quản lý kho và nhà cung cấp,
không mã giảm giá, không tích điểm, không đánh giá món, không hoàn tiền một phần,
không đặt trước mà không đăng nhập, không trả tiền mặt cho đơn đặt trước.
