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
├── database/FastFoodPreorder.sql    Tệp DB duy nhất: bảng, chỉ mục, view, dữ liệu mẫu, tự kiểm tra
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
Khách chọn giờ → CartServlet (action=placeOrder)
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
     → KitchenService.handOverToCounter    bếp đưa món ra quầy
     → OrderService.receiveAtCounter       thu ngân xác nhận đã cầm món
     → OrderService.handoff                thu ngân đối chiếu mã rồi giao món
```

**Vì sao có hai bước bàn giao ở cuối.** "Đơn sẵn sàng" chỉ nghĩa là bếp đã nấu xong — món vẫn
có thể còn nằm trong bếp. Trước đây khoảng đó không ai nhìn thấy: bếp nấu xong là món biến mất
khỏi mọi danh sách, và nó chỉ lộ ra khi khách hỏi. Nay bếp phải bấm bàn giao, quầy phải bấm
nhận, và `handoff` từ chối giao cho khách chừng nào còn món chưa được quầy nhận.

Hai mốc chứ không phải một, vì đó là hành động của hai người khác nhau; khoảng giữa chúng
chính là lúc món nằm chờ trên quầy — và đó mới là thứ màn hình quầy cần hiện ra. Cả hai mốc
nằm ở cột riêng của `OrderItem`, không thêm bậc vào `item_status`: món vẫn ở trạng thái `READY`
suốt cả hai bước, nên mọi chỗ đang đếm "món chưa xong" giữ nguyên ý nghĩa.

### 3.2 Bán tại quầy — gọn trong một giao dịch

`PosServlet` giữ phiếu tạm trong phiên của thu ngân, không ghi xuống cơ sở dữ liệu.
Bấm thu tiền thì `OrderService.createPosOrder` làm liền một mạch: lập đơn → ghi nhận
tiền → xác nhận → đưa xuống bếp. Không có giờ hẹn, không có mã nhận hàng.

Hai hình thức thu tiền được xác nhận theo hai cách khác nhau, và đây là chỗ dễ bỏ sót nhất:

| | Cách xác nhận | Dấu vết đối soát |
|---|---|---|
| Tiền mặt | Thu ngân đếm tiền | Chỉ có chính bản ghi thanh toán |
| Thẻ hoặc mã QR | Máy thanh toán ở quầy báo thành công | **Bắt buộc** nhập mã giao dịch trên biên lai |

Tiền của lần quẹt thẻ không chạy qua hệ thống mà chạy qua máy đặt ở quầy, nên dòng "đã thu"
ghi ở đây chỉ là lời khai của thu ngân. Vì vậy mã biên lai được lưu vào cùng bảng nhật ký với
giao dịch của cổng trực tuyến: báo cáo đối soát chỉ phải đọc một nơi, và ràng buộc duy nhất
trên mã bảo vệ cả hai đường thu tiền như nhau — một biên lai không lập được thành hai đơn.

### 3.3 Ba chỗ chống trùng lặp

| Tình huống | Cách xử lý | Nằm ở |
|---|---|---|
| Bộ hẹn giờ chạy lại, đưa đơn xuống bếp hai lần | `UPDATE ... WHERE released_to_kds_at IS NULL` rồi kiểm số dòng | `OrderDAO.markReleasedToKds` |
| Cổng thanh toán gửi kết quả về hai lần | Ghi mã giao dịch có ràng buộc duy nhất; lần hai bị từ chối | `TransactionDAO.insertIfNew` |
| Khách bấm đặt hàng hai lần | Khoá chống trùng; hai lần bấm sát nhau thì lần sau bắt lỗi trùng khoá rồi trả về đơn đã tạo | `OrderService.createOnlineOrder` |
| Hai đầu bếp nhận cùng một món | `UPDATE ... WHERE item_status = 'WAITING'` rồi kiểm số dòng | `OrderItemDAO.claim` |
| Bếp nhận món của đơn chưa tới lượt vào bếp | Cùng câu lệnh còn kiểm `released_to_kds_at IS NOT NULL` — trùng khít điều kiện của truy vấn hàng chờ | `OrderItemDAO.claim` |
| Hai món cuối xong cùng lúc, đơn kẹt mãi | Khoá dòng đơn trước khi đếm món chưa xong | `OrderService.recalculateStatus` |
| Khách bấm thanh toán ở hai tab | `(order_id, attempt_no)` duy nhất; đọc lại số thứ tự rồi thử tiếp | `PaymentService.startOnlinePayment` |
| Hai người cùng lúc làm phát sinh giỏ hàng | `user_id` duy nhất; trùng thì đọc lại giỏ vừa tạo | `CartDAO.getOrCreateCartId` |
| Mã nhận hàng sinh trùng mã đã có | Sinh lại mã khác, tối đa 5 lần, ngay trong giao dịch thanh toán | `OrderService.confirmOnlineAfterPaid` |
| Một lần quẹt thẻ ở quầy bị lập thành hai đơn | Mã biên lai có ràng buộc duy nhất; lần hai bị từ chối kèm thông báo rõ | `OrderService.createPosOrder` |

### 3.4 Tiền về sau khi đơn đã hết hiệu lực

Khách để trang thanh toán mở quá 15 phút, bộ hẹn giờ cho đơn hết hiệu lực, rồi khách mới bấm
trả tiền. Tiền lúc đó đã thật sự vào, nhưng đơn không còn để xác nhận.

`PaymentService.handleCallback` nhận ra `confirmOnlineAfterPaid` trả về false, hoàn tiền ngay
trong cùng giao dịch với lúc ghi nhận, và trả về `REFUNDED_ORDER_GONE` để khách được báo đúng
chuyện gì đã xảy ra. Không có khoảnh khắc nào khoản tiền nằm lại mà không có đơn tương ứng.

---

## 4. Bảng địa chỉ

Servlet khai báo bằng `@WebServlet`. Trang JSP nằm trong `/WEB-INF/views/`.

Danh sách chia theo **loại**, không gộp tất cả vào "màn hình": trang có giao diện, endpoint
chỉ để hành động rồi chuyển hướng, và endpoint cho máy gọi vào là ba thứ khác nhau — khác cả
về cách kiểm tra quyền lẫn cách viết ca kiểm thử.

### Trang công khai
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/menu` | MenuServlet | customer/menu.jsp |
| `/product/detail` | ProductDetailServlet | customer/product-detail.jsp |
| `/login` `/logout` `/register` | LoginServlet · LogoutServlet · RegisterServlet | auth/ |

### Khách hàng — 5 trang
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/cart` | CartServlet | customer/cart.jsp — giỏ hàng **và** chọn giờ đến lấy |
| `/payment/gateway` | PaymentGatewayServlet | customer/payment-gateway.jsp — **giả lập, chỉ dùng để chạy thử** |
| `/order/track` | OrderTrackingServlet | customer/order-tracking.jsp |
| `/order/history` | OrderHistoryServlet | customer/order-history.jsp |
| `/profile` | ProfileServlet | customer/profile.jsp |

Cộng hai trang công khai `/menu` và `/product/detail` là **6 màn hình** khách hàng đi qua.
Trang cổng thanh toán không tính vào đó: nó đóng vai trang của bên thứ ba.

### Thu ngân — 5 trang, `/staff/*`
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/staff/pos` | PosServlet | staff/pos.jsp |
| `/staff/orders` | OrderDashboardServlet | staff/order-dashboard.jsp — kèm ô **tra mã nhận hàng** |
| `/staff/order/detail` | OrderDetailServlet | staff/order-detail.jsp — kèm **hoá đơn in** |
| `/staff/counter` | CounterServlet | staff/counter.jsp — nhận món bếp đưa ra, và xem sự cố bếp |
| `/staff/history` | StaffHistoryServlet | staff/history.jsp |

### Bếp — 4 trang, `/kitchen/*`
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/kitchen/queue` | KdsQueueServlet | kitchen/kds-queue.jsp — hàng chờ và việc đang làm dở nằm chung |
| `/kitchen/item` | KitchenItemServlet | kitchen/item-detail.jsp |
| `/kitchen/issue` | KitchenIssueServlet | kitchen/issue.jsp |
| `/kitchen/history` | KitchenHistoryServlet | kitchen/history.jsp |

### Quản trị — 5 trang, `/admin/*`
| Địa chỉ | Servlet | Trang |
|---|---|---|
| `/admin/dashboard` | AdminDashboardServlet | admin/dashboard.jsp |
| `/admin/products` | ProductManageServlet | admin/product.jsp |
| `/admin/categories` | CategoryManageServlet | admin/category.jsp |
| `/admin/users` | UserManageServlet | admin/user.jsp |
| `/admin/audit` | AuditServlet | admin/audit.jsp |

### Không phải trang — endpoint hành động và tích hợp
| Địa chỉ | Servlet | Bản chất |
|---|---|---|
| `/payment/start` | PaymentStartServlet | Lập một lần thanh toán rồi chuyển hướng sang cổng. Không hiển thị gì. Chỉ chủ đơn gọi được |
| `/payment/callback` | PaymentCallbackServlet | Cổng thanh toán gọi vào, không có phiên đăng nhập. Kiểm chữ ký, chống gọi trùng bằng ràng buộc duy nhất trên mã giao dịch |
| `/api/kds/queue` | KdsApiServlet | JSON cho màn hình bếp, hỏi lại mỗi 5 giây — chỉ vai trò Bếp và Quản trị. Chỉ trả dữ liệu bếp cần, không kèm thông tin khách hay thanh toán |
| `/api/order/status` | OrderStatusApiServlet | JSON cho trang theo dõi đơn, hỏi lại mỗi 10 giây |

Hỏi lại theo chu kỳ là lựa chọn có ý thức: chạy được trên Servlet thuần, không cần thêm hạ
tầng. Đánh đổi là độ trễ tối đa đúng bằng chu kỳ hỏi. WebSocket hay SSE nằm ngoài phạm vi.

### Không phải trang — công việc chạy nền
| Lớp | Chu kỳ | Việc |
|---|---|---|
| `KitchenReleaseScheduler` | 30 giây | Đưa đơn tới giờ xuống bếp, đúng một lần cho mỗi đơn |
| `PaymentExpiryScheduler` | 30 giây | Cho hết hiệu lực đơn quá hạn thanh toán 15 phút |

Cả hai ghi nhật ký với người thực hiện để trống — đó là dấu hiệu nhận biết việc do hệ thống
tự làm, không phải do ai bấm.

### Năm màn hình đã gộp

Mỗi vai trò giữ trong khoảng bốn tới sáu màn hình. Năm trang dưới đây từng đứng riêng nhưng
không tự mình làm xong việc gì — người dùng luôn phải đi tiếp sang trang khác — nên chúng
được đưa về đúng chỗ đang cần chúng:

| Trang cũ | Nay nằm ở | Vì sao |
|---|---|---|
| `/checkout` | `/cart`, phần dưới giỏ hàng | Trang chọn giờ vẫn phải liệt kê lại toàn bộ giỏ; sửa số lượng thì phải quay ngược về trang trước |
| `/staff/pickup/verify` | `/staff/orders`, ô tra ở đầu trang | Tra xong vẫn phải mở đơn mới giao được món — hai lần chuyển trang cho một việc lúc khách đứng ở quầy |
| `/staff/receipt` | `/staff/order/detail`, khối `print-only` | Cả trang chỉ để chứa một nút in; nay khối hoá đơn ẩn trên màn hình và hiện ra khi in |
| `/kitchen/my-tasks` | `/kitchen/queue`, khối trên cùng | Đầu bếp phải nhìn việc của mình và hàng chờ cùng lúc mới quyết định được nhận món tiếp theo, và món đã xong thì không có chỗ nào nhắc |
| `/staff/issues` | `/staff/counter` | Sự cố bếp và việc nhận món từ bếp trả lời chung một câu hỏi: món của đơn này đang ở đâu |

Riêng dòng cuối là **đổi vai chứ không bị xoá**: `/staff/issues` trước đây chỉ đọc, chỉ hiện sự
cố bếp. Nay thành `/staff/counter` — **Quầy giao nhận**, nơi thu ngân nhận món bếp vừa đưa ra và
thấy đơn nào đã đủ món để gọi khách. Sự cố bếp vẫn ở đó, thành một trong ba khối.

---

## 5. Bảo mật

| Lớp | Thực hiện | Chặn được gì |
|---|---|---|
| `AuthenticationFilter` | Liệt kê trang công khai, còn lại bắt đăng nhập | Thêm màn hình mới mà quên khai báo thì bị bắt đăng nhập thừa, không lộ dữ liệu |
| `RoleAuthorizationFilter` | Phân quyền theo tiền tố địa chỉ, gồm cả `/api/kds/*` | Gõ thẳng `/admin/...`, hoặc gọi địa chỉ JSON của bếp bằng tài khoản khách |
| Kiểm tra chủ sở hữu | Điều kiện `customer_id` ngay trong câu truy vấn | Khách xem đơn của người khác. Trả về "không tìm thấy" để không lộ mã đơn nào có thật |
| Mật khẩu | bcrypt cost 10 | Lộ cơ sở dữ liệu vẫn không đọc được mật khẩu |
| Câu lệnh SQL | `PreparedStatement` toàn bộ | Chèn mã SQL qua ô tìm kiếm |
| Hiển thị | `<c:out>` cho mọi dữ liệu do người dùng nhập | Chèn mã kịch bản qua tên tài khoản hay tên món — nguy nhất là khi trang quản trị mở lên và chạy mã của khách |
| Địa chỉ quay về | `WebUtil.safeRedirect` chỉ nhận đường dẫn nội bộ | Liên kết đăng nhập của chính cửa hàng nhưng đẩy sang trang giả mạo sau khi đăng nhập |
| Phiên đăng nhập | Cấp phiên mới sau khi đăng nhập | Chiếm phiên đã biết trước |
| Mật khẩu đặt hộ | Quản trị viên đặt lại mật khẩu thì tài khoản bị giữ ở trang tài khoản tới khi tự đổi | Tài khoản chạy tiếp bằng mật khẩu mà ít nhất hai người biết |
| Chữ ký cổng thanh toán | Kiểm tra trước khi ghi nhận tiền | Gọi thẳng địa chỉ nhận kết quả để tự xác nhận đơn |
| Tự hạ quyền | Chặn quản trị viên tự khoá và tự đổi vai trò của chính mình | Mất đường vào khu vực quản trị mà không tự sửa lại được |

Thứ tự ba bộ lọc khai báo trong `web.xml` chứ không bằng `@WebFilter`: đặc tả Servlet không
bảo đảm thứ tự của bộ lọc khai báo bằng annotation, mà `EncodingFilter` thì bắt buộc phải
chạy trước — bảng mã bị chốt ngay khi có ai đó đọc tham số đầu tiên.

**Chưa có trong phạm vi:** chống giả mạo yêu cầu từ trang khác (CSRF token). Mọi thao tác ghi
đều dùng POST và cookie phiên đặt `HttpOnly`, nhưng chưa có mã dùng-một-lần trên biểu mẫu.

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

## 7. Bộ kiểm thử

```bash
mvn test          # 138 bài
```

Chia hai nhóm bằng đuôi tên lớp:

| Nhóm | Đuôi | Chạy ở đâu | Số bài |
|---|---|---|---|
| Logic thuần | `*Test` | Mọi máy, không cần gì thêm | 39 |
| Chạy thật xuống cơ sở dữ liệu | `*IT` | Cần SQL Server ở `localhost:1433` | 99 |

Nhóm `*IT` **tự bỏ qua** khi không có máy chủ, không báo đỏ: màu đỏ phải có nghĩa là mã nguồn
sai, không phải là máy chạy test thiếu thứ gì đó.

**Database test là một database riêng.** `src/test/resources/db.properties` trỏ vào
`FastFoodPreorder_Test`, và `TestDatabase` xoá rồi dựng lại toàn bộ bảng một lần trước cả
lượt chạy — trỏ vào database đang phát triển là mất sạch dữ liệu đang thử tay. Schema dùng
đúng file `database/FastFoodPreorder.sql` chứ không chép ra bản riêng cho test: chép ra thì
hai bản lệch nhau lúc nào không ai biết, và bộ test sẽ xanh trên một schema không tồn tại ở
đâu cả.

| Lớp | Kiểm chứng điều gì |
|---|---|
| `RevenueReportIT` | Doanh thu thuần khi có hoàn tiền — xem ghi chú bên dưới |
| `SchemaConstraintIT` | 21 ràng buộc và trigger, ghi thẳng bằng SQL để **cố tình bỏ qua** tầng Service |
| `OnlinePreorderFlowIT` | Cả vòng đời đơn đặt trước, chạy qua tầng Service thật |
| `PosOrderIT` | Bán tại quầy, và mã biên lai bắt buộc khi quẹt thẻ |
| `KitchenFlowIT` | Bếp làm món, trạng thái đơn tự suy ra, bàn giao ra quầy, sự cố bếp |
| `CancelRuleIT` | Mốc chặn huỷ đơn, hoàn tiền tự động và không lặp |
| `OrderDashboardIT` | Bốn tab phủ kín mọi đơn chưa kết thúc |
| `CounterQueueIT` | Hàng chờ của quầy giao nhận — kể cả món của đơn đã huỷ |
| `AdminAccountIT` | Mật khẩu đặt hộ, chống tự hạ quyền |
| `OrderStateTest` · `BusinessMathTest` · `PickupCodeGeneratorTest` | Giá trị suy ra và các phép tính nhỏ |

**Vì sao `RevenueReportIT` đáng đọc trước.** Bảng `Payment` chỉ có một cột trạng thái, và hoàn
tiền ghi đè `PAID` thành `REFUNDED`. Cách viết trông hợp lý nhất — lọc vế thu theo
`payment_status = 'PAID'` — làm một khoản đã thu rồi hoàn biến mất khỏi vế thu nhưng vẫn còn ở
vế hoàn, tức là bị trừ hai lần: đơn 100.000đ cho ra **âm** 100.000đ. Bộ test này được kiểm
ngược bằng cách tạm khôi phục công thức cũ; nó bắt lỗi ở 4 bài. Cách đúng là mỗi vế đếm theo
mốc thời gian của chính nó — thu theo `paid_at`, hoàn theo `refunded_at`.

---

## 8. Ngoài phạm vi — không có trong mã nguồn

Không giao hàng tận nơi, không nhiều chi nhánh, không quản lý kho và nhà cung cấp,
không mã giảm giá, không tích điểm, không đánh giá món, không hoàn tiền một phần,
không đặt trước mà không đăng nhập, không trả tiền mặt cho đơn đặt trước.
