# Cấu trúc dự án — Fast Food Pre-order Pickup & POS (Baseline V6)

Stack: **Java Servlet + JSTL + SQL Server (JDBC)**, kiến trúc **MVC 3 lớp**.
Mọi tên module/entity/màn hình/rule dưới đây bám theo `docs/preview-2 (1).html`.

---

## 1. Kiến trúc MVC 3 lớp

```
Browser / POS Terminal / KDS Screen
        │  HTTP
        ▼
┌───────────────────────────────────────────────┐
│ FILTER   Encoding → Auth → Role → Ownership   │  mục 8, BR-21, NFR-01
├───────────────────────────────────────────────┤
│ CONTROLLER (Servlet)                          │  nhận request, validate input,
│   com.fastfood.controller.*                   │  gọi Service, chọn view
├───────────────────────────────────────────────┤
│ SERVICE  ← nơi đặt BR-01..BR-21                │  transaction, state machine,
│   com.fastfood.service.impl.*                 │  aggregate status, audit
├───────────────────────────────────────────────┤
│ DAO (JDBC + PreparedStatement)                │  chỉ CRUD/query, không rule
│   com.fastfood.dao.impl.*                     │
├───────────────────────────────────────────────┤
│ SQL Server — FastFoodPreorder                 │
└───────────────────────────────────────────────┘
        ▲                              ▲
        │                              │
  SCHEDULER (UC-07, BR-13)      INTEGRATION (Gateway, Notification)

VIEW: JSP + JSTL trong /WEB-INF/views/**  (không truy cập trực tiếp được từ URL)
```

**Nguyên tắc bắt buộc**
- Controller **không** viết SQL và **không** chứa business rule.
- Service **sở hữu** Connection và transaction; DAO nhận `Connection` để nhiều thao tác nằm chung 1 transaction (checkout, payment callback, KDS release).
- JSP **chỉ** hiển thị; mọi tính toán trạng thái làm ở Service.
- Mọi trang JSP nằm trong `WEB-INF` → truy cập bắt buộc đi qua Servlet + Filter (case J mục 15).

---

## 2. Cây thư mục

```
swp301-block/
├── pom.xml
├── README.md
├── .gitignore
├── database/
│   ├── 01_schema.sql              # 13 bảng + 2 view báo cáo + constraint theo BR
│   └── 02_seed_data.sql           # Role, Users, Category, Product mẫu
├── docs/
│   ├── preview-2 (1).html         # Tài liệu phân tích V6 (nguồn sự thật)
│   └── STRUCTURE.md               # file này
└── src/
    ├── main/
    │   ├── java/com/fastfood/
    │   │   ├── common/constant/   # enum đã khóa theo mục 18
    │   │   ├── common/exception/
    │   │   ├── common/util/
    │   │   ├── config/            # DBContext, AppConfig
    │   │   ├── model/entity/      # 13 entity ↔ 13 bảng
    │   │   ├── model/dto/
    │   │   ├── dao/ + dao/impl/
    │   │   ├── service/ + service/impl/
    │   │   ├── controller/{auth,customer,staff,kitchen,admin,api}/
    │   │   ├── filter/
    │   │   ├── listener/
    │   │   ├── scheduler/
    │   │   └── integration/{payment,notification}/
    │   ├── resources/
    │   │   ├── db.properties      # kết nối SQL Server
    │   │   └── app.properties     # tham số BR-05/08/13/17, scheduler, gateway
    │   └── webapp/
    │       ├── index.jsp
    │       ├── assets/{css,js,images}/
    │       └── WEB-INF/
    │           ├── web.xml
    │           └── views/{layout,auth,customer,staff,kitchen,admin,error}/
    └── test/java/com/fastfood/
```

---

## 3. Tầng Model — Entity ↔ Bảng (mục 10)

| Entity (`model/entity`) | Bảng SQL Server | Ghi chú |
|---|---|---|
| `Role` | `Role` | 1 Role – N User; MVP 1 User = 1 Role |
| `User` | `Users` | `User` là từ khoá SQL Server |
| `Category` | `Category` | disable thay vì delete |
| `Product` | `Product` | BR-01: chỉ active + available mới order được |
| `Cart` | `Cart` | chỉ Customer Online đã login |
| `CartItem` | `CartItem` | |
| `Order` | `Orders` | `Order` là từ khoá SQL Server |
| `OrderItem` | `OrderItem` | BR-02 snapshot tên + unit_price |
| `Payment` | `Payment` | BR-14: 1 Order – N attempt |
| `Transaction` | `PaymentTransaction` | `Transaction` là từ khoá SQL Server |
| `Notification` | `Notification` | ORDER_CONFIRMED / ORDER_READY |
| `KitchenIssue` | `KitchenIssue` | OPEN / RESOLVED |
| `AuditLog` | `AuditLog` | NFR-08, BR-20 không hard-delete |

**Enum đã tạo** (`common/constant`): `OrderStatus`, `OrderSource`, `OrderItemStatus`, `PaymentMethod`, `PaymentStatus`, `RoleName`, `KdsReleaseState`, `NotificationEvent`, `AuditAction`, `BusinessRule`.

> `KdsReleaseState` (SCHEDULED / RELEASED_TO_KDS) **không** phải Order Status và **không** có bảng riêng — suy ra từ `kitchen_release_at` + `released_to_kds_at` (mục 7.2). Tương tự, OVERDUE chỉ là UI flag (BR-17).

**DTO dự kiến** (`model/dto`): `CartView`, `CheckoutRequest`, `PickupSlot`, `OrderDetailView`, `KdsItemView`, `PickupQueueRow`, `PaymentCallbackData`, `DashboardKpi`, `ReportFilter`, `PageResult<T>`.

---

## 4. Tầng DAO & Service

### DAO (`dao` + `dao/impl`)
`RoleDAO`, `UserDAO`, `CategoryDAO`, `ProductDAO`, `CartDAO`, `CartItemDAO`, `OrderDAO`, `OrderItemDAO`, `PaymentDAO`, `TransactionDAO`, `NotificationDAO`, `KitchenIssueDAO`, `AuditLogDAO`, `ReportDAO`.

Query đáng chú ý:
- `OrderDAO.findDueForRelease(now)` — quét đơn CONFIRMED có `kitchen_release_at <= now` và `released_to_kds_at IS NULL` (UC-07).
- `OrderDAO.markReleased(orderId)` — `UPDATE ... WHERE released_to_kds_at IS NULL` → idempotent ở tầng SQL (BR-09, NFR-05).
- `OrderDAO.findExpiredCandidates()` — PENDING_PAYMENT quá 15 phút (BR-13).
- `TransactionDAO.existsByExternalId(id)` — chặn duplicate callback (BR-14, NFR-06).
- `OrderItemDAO.findReleasedQueue()` — chỉ item thuộc Order đã `released_to_kds_at` (KIT-01).

### Service (`service` + `service/impl`)

| Service | Trách nhiệm | Rules |
|---|---|---|
| `AuthService` | login/logout, hash password, RBAC context | UC-01, NFR-01 |
| `MenuService` | menu, tìm kiếm, revalidate availability/price | BR-01, BR-06 |
| `CartService` | thao tác Cart/CartItem | UC-03 |
| `OrderService` | tạo Online/POS Order, cancel, complete, aggregate status | BR-02..BR-05, BR-11, BR-12, BR-16, NFR-07 |
| `PaymentService` | attempt, callback idempotent, full refund | BR-04, BR-14, UC-23, NFR-06 |
| `ScheduleService` | tính `kitchen_release_at`, release sang KDS, expire | BR-08, BR-09, BR-13 |
| `KitchenService` | claim, WAITING→PREPARING→READY, KitchenIssue | BR-11, BR-18, BR-19 |
| `PickupService` | sinh & verify Pickup Code/QR, handoff | BR-15, BR-16, UC-15/16 |
| `NotificationService` | ORDER_CONFIRMED / ORDER_READY | module 6 |
| `ReportService` | KPI mục 13 | UC-20 |
| `AuditService` | ghi AuditLog cho mọi sự kiện | NFR-08 |
| `AdminService` | Product/Category/User/Role | UC-18, UC-19 |

---

## 5. Tầng Controller — bảng URL mapping

Servlet khai báo bằng `@WebServlet`. `views` = JSP forward tới.

### Auth
| URL | Servlet | Method | View |
|---|---|---|---|
| `/login` | `LoginServlet` | GET, POST | `auth/login.jsp` |
| `/logout` | `LogoutServlet` | GET | → `/menu` |
| `/register` | `RegisterServlet` | GET, POST | `auth/register.jsp` |

### Customer — CUS-01..05
| URL | Servlet | Màn hình | View |
|---|---|---|---|
| `/menu` | `MenuServlet` | CUS-01 | `customer/menu.jsp` |
| `/product/detail` | `ProductDetailServlet` | CUS-01 | `customer/product-detail.jsp` |
| `/cart` | `CartServlet` | CUS-02 | `customer/cart.jsp` |
| `/checkout` | `CheckoutServlet` | CUS-03 | `customer/checkout.jsp` |
| `/payment/start` | `PaymentStartServlet` | CUS-03 | → gateway |
| `/payment/return` | `PaymentReturnServlet` | CUS-03 | `customer/payment-result.jsp` |
| `/order/track` | `OrderTrackingServlet` | CUS-04 | `customer/order-tracking.jsp` |
| `/order/cancel` | `OrderCancelServlet` | CUS-04 | POST, BR-12 |
| `/order/history` | `OrderHistoryServlet` | CUS-05 | `customer/order-history.jsp` |
| `/profile` | `ProfileServlet` | CUS-05 | `customer/profile.jsp` |

### Staff / Cashier — STF-01..05
| URL | Servlet | Màn hình | View |
|---|---|---|---|
| `/staff/pos` | `PosOrderServlet` | STF-01 | `staff/pos.jsp` |
| `/staff/orders` | `OrderDashboardServlet` | STF-02 | `staff/order-dashboard.jsp` |
| `/staff/order/detail` | `StaffOrderDetailServlet` | STF-03 | `staff/order-detail.jsp` |
| `/staff/pickup/verify` | `PickupVerifyServlet` | STF-03 | `staff/pickup-verify.jsp` |
| `/staff/order/complete` | `HandoffServlet` | STF-03 | POST, BR-15/16 |
| `/staff/payment` | `StaffPaymentServlet` | STF-04 | `staff/payment.jsp` |
| `/staff/payment/refund` | `RefundServlet` | STF-04 | POST, UC-23 |
| `/staff/receipt` | `ReceiptServlet` | STF-04 | UC-17 |
| `/staff/history` | `StaffHistoryServlet` | STF-05 | `staff/history.jsp` |

### Kitchen — KIT-01..05
| URL | Servlet | Màn hình | View |
|---|---|---|---|
| `/kitchen/queue` | `KdsQueueServlet` | KIT-01 | `kitchen/kds-queue.jsp` |
| `/kitchen/item/claim` | `ClaimItemServlet` | KIT-01 | POST, UC-11 |
| `/kitchen/my-tasks` | `MyTasksServlet` | KIT-02 | `kitchen/my-tasks.jsp` |
| `/kitchen/item/ready` | `MarkReadyServlet` | KIT-02 | POST, UC-12 |
| `/kitchen/item/detail` | `KitchenItemDetailServlet` | KIT-03 | `kitchen/item-detail.jsp` |
| `/kitchen/issue` | `KitchenIssueServlet` | KIT-04 | `kitchen/issue.jsp` |
| `/kitchen/history` | `KitchenHistoryServlet` | KIT-05 | `kitchen/history.jsp` |

### Admin — ADM-01..05
| URL | Servlet | Màn hình | View |
|---|---|---|---|
| `/admin/dashboard` | `AdminDashboardServlet` | ADM-01 | `admin/dashboard.jsp` |
| `/admin/products` | `ProductManageServlet` | ADM-02 | `admin/product.jsp` |
| `/admin/categories` | `CategoryManageServlet` | ADM-03 | `admin/category.jsp` |
| `/admin/users` | `UserManageServlet` | ADM-04 | `admin/user.jsp` |
| `/admin/audit` | `AuditServlet` | ADM-05 | `admin/audit.jsp` |
| `/admin/report/export` | `ReportExportServlet` | ADM-05 | file |

### API (JSON, cho AJAX / hệ thống ngoài)
| URL | Servlet | Mục đích |
|---|---|---|
| `/api/kds/queue` | `KdsApiServlet` | KDS polling — NFR-04 (2 giây) |
| `/api/order/status` | `OrderStatusApiServlet` | CUS-04 cập nhật trạng thái |
| `/payment/callback` | `PaymentCallbackServlet` | Gateway webhook — **idempotent**, NFR-06 |

---

## 6. Filter / Listener / Scheduler / Integration

### Filter (`filter`) — thứ tự chuỗi
1. `EncodingFilter` (`/*`) — UTF-8 cho tiếng Việt.
2. `AuthenticationFilter` — chặn khu vực cần login; Online Pre-order bắt buộc login (BR-04).
3. `RoleAuthorizationFilter` — enforce ma trận mục 8 theo prefix URL (`/staff/*` → CASHIER, `/kitchen/*` → KITCHEN, `/admin/*` → ADMIN).
4. `OwnershipFilter` — BR-21: Customer chỉ truy cập Order/Payment của mình; sai → 403/404 (case J).

### Listener (`listener`)
- `AppContextListener` — khởi tạo `DBContext` pool, nạp `AppConfig`, start scheduler; shutdown sạch khi undeploy (NFR-10).
- `SessionListener` — theo dõi phiên đăng nhập.

### Scheduler (`scheduler`) — `ScheduledExecutorService`
- `KitchenReleaseScheduler` — chạy mỗi 30s: tìm Order CONFIRMED tới hạn → release sang KDS, ghi `released_to_kds_at` **một lần** (BR-09, NFR-03/05).
- `PaymentExpiryScheduler` — chạy mỗi 60s: PENDING_PAYMENT quá 15 phút → EXPIRED (BR-13).

### Integration (`integration`)
- `payment/PaymentGateway` (interface) + `MockPaymentGateway` — sandbox; callback khớp `external_transaction_id` UNIQUE.
- `notification/NotificationSender` (interface) + `MockNotificationSender`, `EmailNotificationSender`.

---

## 7. Các điểm dễ sai — cần bám đúng khi code

| Rủi ro | Ràng buộc bắt buộc |
|---|---|
| Đưa đơn Online vào bếp quá sớm | Chỉ release khi `now >= kitchen_release_at` (BR-08) |
| Duplicate kitchen task khi scheduler chạy lại | `UPDATE ... WHERE released_to_kds_at IS NULL` (BR-09) |
| Duplicate doanh thu khi gateway gọi callback nhiều lần | `external_transaction_id` UNIQUE + kiểm tra trước khi transition (BR-14) |
| Cashier tự set PREPARING/READY | Chỉ Kitchen đổi OrderItem; Order status là **aggregate** (BR-11) |
| Giao nhầm đơn | Handoff chỉ khi READY + PAID + code hợp lệ, verify **server-side** (BR-15, NFR-01) |
| Khách đến muộn | Chỉ gắn flag OVERDUE, **không** auto cancel/refund/complete (BR-17) |
| Xoá dữ liệu giao dịch | Không hard-delete Order/Payment/Transaction/AuditLog (BR-20) |
| Giá đổi sau khi khách bỏ vào giỏ | Revalidate ngay trước payment + snapshot khi tạo OrderItem (BR-06, BR-02) |

---

## 8. Ngoài phạm vi (mục 17) — **không** tạo trong dự án

Không có `DeliveryAddress` / `Shipment` / `Shipper`, không delivery fee, không `OUT_FOR_DELIVERY`/`DELIVERED`, không multi-branch, không Inventory/Supplier, không Voucher/Loyalty/Review, không partial refund, không guest checkout Online, không Pay at Counter cho ONLINE_PREORDER.

---

## 9. Ghi chú môi trường

- Cấu hình hiện tại dùng **Tomcat 9.x** (`javax.servlet`). Nếu chạy **Tomcat 10+**, đổi dependency sang `jakarta.servlet-api` + `jakarta.servlet.jsp.jstl`, và đổi toàn bộ `import javax.servlet.*` → `jakarta.servlet.*`.
- Chạy DB: thực thi `database/01_schema.sql` rồi `database/02_seed_data.sql`.
- Sửa `src/main/resources/db.properties` cho đúng instance SQL Server trước khi chạy.
