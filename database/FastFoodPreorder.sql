/* =============================================================================================
   FAST FOOD PRE-ORDER PICKUP & POS  —  DATABASE (SQL Server)
   Dự án SWP301 · Requirements Baseline V6 · docs/preview-2 (1).html

   Hai kênh đặt hàng:
     ONLINE_PREORDER — đặt từ xa, hẹn giờ đến lấy, thanh toán online trước
     POS             — khách walk-in đặt tại quầy
   MVP KHÔNG có Delivery/Shipper.

   ---------------------------------------------------------------------------------------------
   YÊU CẦU : SQL Server 2016 trở lên (dùng DROP ... IF EXISTS)
   CÁCH CHẠY: mở file trong SSMS -> Execute (F5). Hoặc:
              sqlcmd -S localhost -U sa -P '<password>' -C -i FastFoodPreorder.sql

   *** CẢNH BÁO: file này XOÁ và TẠO LẠI toàn bộ bảng mỗi lần chạy. ***
   Thiết kế như vậy để luôn cho ra một database sạch, không phụ thuộc trạng thái trước đó.
   Đừng chạy trên môi trường có dữ liệu thật.

   ĐÂY LÀ FILE DATABASE DUY NHẤT của dự án — lược đồ, dữ liệu demo và bộ kiểm tra nằm chung
   một chỗ, chạy một lần là xong. Không có file migration đi kèm: sửa lược đồ thì sửa thẳng
   vào đây rồi chạy lại, vì mỗi lần chạy đều dựng lại từ đầu nên không có bước nâng cấp nào
   để phải viết riêng.
   ---------------------------------------------------------------------------------------------

   NỘI DUNG
     1. Tạo database
     2. Xoá đối tượng cũ
     3. 13 bảng          (nhóm: danh mục · giỏ hàng · đơn hàng · thanh toán · vận hành)
     4. 17 index
     5. 2 view           (suy ra trạng thái release & KPI đúng hẹn)
     6. 6 trigger        (BR-04 + chặn hard-delete BR-20)
     7. Dữ liệu mẫu     (7 user · 13 món · 2 giỏ hàng · 11 đơn phủ đủ 7 trạng thái ·
                          tin báo và nhật ký thao tác suy ra từ chính các mốc thời gian)
     8. Kiểm tra sau khi chạy — 10 bảng đối chiếu, in ra ngay sau khi chạy xong

   BA TÊN BẢNG KHÁC TÀI LIỆU — vì trùng từ khoá SQL Server:
     User -> Users        Order -> Orders        Transaction -> PaymentTransaction
   Java entity vẫn giữ tên theo tài liệu; ánh xạ chỉ nằm trong tầng DAO.

   TÀI KHOẢN MẪU — mật khẩu tất cả: 123456
     customer1@gmail.com  customer2@gmail.com          (CUSTOMER)
     cashier1@fastfood.vn cashier2@fastfood.vn         (CASHIER)
     kitchen1@fastfood.vn kitchen2@fastfood.vn         (KITCHEN)
     admin@fastfood.vn                                 (ADMIN)
   ============================================================================================= */


/* =============================================================================================
   1. TẠO DATABASE
   ============================================================================================= */
USE master;
GO

IF DB_ID('FastFoodPreorder') IS NULL
    /* Collation Vietnamese_CI_AS: sắp xếp và tìm kiếm tên món tiếng Việt đúng,
       không phân biệt hoa thường khi khách search menu. Phải đặt ngay lúc tạo DB. */
    CREATE DATABASE FastFoodPreorder COLLATE Vietnamese_CI_AS;
GO

/* KDS poll dữ liệu mỗi 2 giây (NFR-04). Không bật snapshot thì các câu SELECT liên tục
   của màn hình bếp sẽ chặn thao tác ghi của chính bếp. */
IF EXISTS (SELECT 1 FROM sys.databases WHERE name='FastFoodPreorder' AND is_read_committed_snapshot_on = 0)
    ALTER DATABASE FastFoodPreorder SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

USE FastFoodPreorder;
GO


/* =============================================================================================
   2. XOÁ ĐỐI TƯỢNG CŨ  — theo chiều ngược phụ thuộc khoá ngoại
   (DROP TABLE không bị trigger chặn hard-delete cản, nên file luôn chạy lại được)
   ============================================================================================= */
DROP VIEW  IF EXISTS dbo.vw_OnTimeReady;
DROP VIEW  IF EXISTS dbo.vw_OrderReleaseState;

DROP TABLE IF EXISTS dbo.AuditLog;
DROP TABLE IF EXISTS dbo.KitchenIssue;
DROP TABLE IF EXISTS dbo.Notification;
DROP TABLE IF EXISTS dbo.PaymentTransaction;
DROP TABLE IF EXISTS dbo.Payment;
DROP TABLE IF EXISTS dbo.OrderItem;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.CartItem;
DROP TABLE IF EXISTS dbo.Cart;
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.Category;
DROP TABLE IF EXISTS dbo.Users;
DROP TABLE IF EXISTS dbo.Role;
GO


/* =============================================================================================
   3. BẢNG

   Quy ước chung
     · Khoá chính  : <bảng>_id, INT IDENTITY (riêng AuditLog dùng BIGINT vì ghi nhiều nhất)
     · Tiền        : DECIMAL(12,2) — không dùng FLOAT/MONEY để tránh sai số khi cộng doanh thu
     · Thời gian   : DATETIME2(0) — đủ độ chính xác tới giây
     · Tiếng Việt  : NVARCHAR   ·  Mã / enum / email: VARCHAR
     · Enum        : VARCHAR + CHECK, không tạo bảng lookup, vì các tập giá trị đã được
                     khoá ở mục 18 và khớp 1-1 với enum Java trong com.fastfood.common.constant

   QUAN TRỌNG — thời gian: mọi mốc thời gian nghiệp vụ do TẦNG ỨNG DỤNG sinh và truyền xuống.
   DEFAULT SYSDATETIME() chỉ là lưới an toàn. Nếu Tomcat và SQL Server lệch giờ thì Scheduler
   sẽ đưa món vào bếp sai thời điểm và toàn bộ KPI đúng hẹn sai theo — lỗi rất khó truy.
   ============================================================================================= */

/* ------------------------------- NHÓM 1 — DANH MỤC & NGƯỜI DÙNG --------------------------- */

CREATE TABLE dbo.Role (
    role_id     INT IDENTITY(1,1) NOT NULL,
    name        VARCHAR(20)       NOT NULL,
    description NVARCHAR(200)     NULL,
    CONSTRAINT PK_Role      PRIMARY KEY (role_id),
    CONSTRAINT UQ_Role_name UNIQUE (name),
    CONSTRAINT CK_Role_name CHECK (name IN ('CUSTOMER','CASHIER','KITCHEN','ADMIN'))
);
GO

CREATE TABLE dbo.Users (
    user_id       INT IDENTITY(1,1) NOT NULL,
    full_name     NVARCHAR(100)     NOT NULL,
    email         VARCHAR(150)      NOT NULL,      -- dùng làm username đăng nhập
    phone         VARCHAR(20)       NULL,
    password_hash VARCHAR(255)      NOT NULL,      -- bcrypt; để 255 để sau này đổi thuật toán không phải sửa bảng
    role_id       INT               NOT NULL,      -- MVP: 1 User = 1 Role
    status        VARCHAR(20)       NOT NULL CONSTRAINT DF_Users_status    DEFAULT ('ACTIVE'),
    /* Bật khi quản trị viên đặt lại mật khẩu hộ. Mật khẩu lúc đó ít nhất hai người biết,
       nên tài khoản chỉ vào được trang tài khoản cho tới khi chủ nhân tự đặt lại. */
    must_change_password BIT        NOT NULL CONSTRAINT DF_Users_mustChangePw DEFAULT (0),
    created_at    DATETIME2(0)      NOT NULL CONSTRAINT DF_Users_createdAt DEFAULT (SYSDATETIME()),
    updated_at    DATETIME2(0)      NULL,
    CONSTRAINT PK_Users        PRIMARY KEY (user_id),
    CONSTRAINT UQ_Users_email  UNIQUE (email),
    CONSTRAINT FK_Users_Role   FOREIGN KEY (role_id) REFERENCES dbo.Role(role_id),
    -- Admin khoá tài khoản chứ không xoá, để giữ nguyên lịch sử đơn của người đó
    CONSTRAINT CK_Users_status CHECK (status IN ('ACTIVE','LOCKED'))
);
GO

CREATE TABLE dbo.Category (
    category_id   INT IDENTITY(1,1) NOT NULL,
    name          NVARCHAR(100)     NOT NULL,
    status        VARCHAR(20)       NOT NULL CONSTRAINT DF_Category_status DEFAULT ('ACTIVE'),
    display_order INT               NOT NULL CONSTRAINT DF_Category_order  DEFAULT (0),
    CONSTRAINT PK_Category        PRIMARY KEY (category_id),
    CONSTRAINT CK_Category_status CHECK (status IN ('ACTIVE','INACTIVE'))
);
GO

/* Hai cột trạng thái tách riêng là CỐ Ý:
     status       — còn kinh doanh hay đã ngừng bán  (Admin quyết định, ít thay đổi)
     is_available — tạm hết hàng trong ngày          (nhân viên bật/tắt thường xuyên)
   Món chỉ được đặt khi ĐỦ CẢ BA: product ACTIVE + available + category ACTIVE.
   Ba điều kiện nằm ở hai bảng nên không CHECK được — mọi truy vấn menu bắt buộc join Category. */
CREATE TABLE dbo.Product (
    product_id   INT IDENTITY(1,1) NOT NULL,
    category_id  INT               NOT NULL,
    name         NVARCHAR(150)     NOT NULL,
    description  NVARCHAR(500)     NULL,
    price        DECIMAL(12,2)     NOT NULL,
    image_url    VARCHAR(255)      NULL,
    is_available BIT               NOT NULL CONSTRAINT DF_Product_available DEFAULT (1),
    status       VARCHAR(20)       NOT NULL CONSTRAINT DF_Product_status    DEFAULT ('ACTIVE'),
    created_at   DATETIME2(0)      NOT NULL CONSTRAINT DF_Product_createdAt DEFAULT (SYSDATETIME()),
    updated_at   DATETIME2(0)      NULL,
    CONSTRAINT PK_Product          PRIMARY KEY (product_id),
    CONSTRAINT FK_Product_Category FOREIGN KEY (category_id) REFERENCES dbo.Category(category_id),
    CONSTRAINT CK_Product_price    CHECK (price >= 0),
    CONSTRAINT CK_Product_status   CHECK (status IN ('ACTIVE','INACTIVE'))
);
GO

/* ------------------------------------ NHÓM 2 — GIỎ HÀNG ----------------------------------- */

/* Chỉ khách Online đã đăng nhập mới có giỏ trong DB.
   POS dựng giỏ tạm trong session của Cashier, không ghi xuống đây — nếu ghi thì mỗi khách
   vãng lai lại sinh một dòng rác. */
CREATE TABLE dbo.Cart (
    cart_id    INT IDENTITY(1,1) NOT NULL,
    user_id    INT               NOT NULL,
    updated_at DATETIME2(0)      NOT NULL CONSTRAINT DF_Cart_updatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Cart      PRIMARY KEY (cart_id),
    CONSTRAINT UQ_Cart_user UNIQUE (user_id),                    -- mỗi khách đúng một giỏ
    CONSTRAINT FK_Cart_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id)
);
GO

/* Bảng duy nhất trong toàn hệ thống được phép CASCADE DELETE:
   giỏ hàng là dữ liệu nháp, không phải dữ liệu giao dịch cần lưu vết. */
CREATE TABLE dbo.CartItem (
    cart_item_id INT IDENTITY(1,1) NOT NULL,
    cart_id      INT               NOT NULL,
    product_id   INT               NOT NULL,
    quantity     INT               NOT NULL,
    CONSTRAINT PK_CartItem         PRIMARY KEY (cart_item_id),
    CONSTRAINT FK_CartItem_Cart    FOREIGN KEY (cart_id)    REFERENCES dbo.Cart(cart_id) ON DELETE CASCADE,
    CONSTRAINT FK_CartItem_Product FOREIGN KEY (product_id) REFERENCES dbo.Product(product_id),
    CONSTRAINT CK_CartItem_qty     CHECK (quantity > 0),
    -- thêm lại món đã có trong giỏ thì cộng dồn số lượng, không tạo dòng thứ hai
    CONSTRAINT UQ_CartItem         UNIQUE (cart_id, product_id)
);
GO

/* ------------------------------------ NHÓM 3 — ĐƠN HÀNG ----------------------------------- */

/* Ba mốc thời gian dưới đây là phần cốt lõi phân biệt Online Pre-order với POS:

     pickup_time         CAM KẾT với khách — giờ khách sẽ đến lấy
     kitchen_release_at  KẾ HOẠCH          — tính một lần khi đơn được xác nhận, = pickup_time - 20'
     released_to_kds_at  THỰC TẾ           — Scheduler ghi đúng một lần; NULL nghĩa là bếp chưa thấy đơn

   Nhờ tách kế hoạch và thực tế, hệ thống vừa tránh làm món quá sớm, vừa đo được
   Scheduler chạy đúng giờ hay trễ (chênh lệch giữa hai cột).

   Cố ý KHÔNG tạo cột release_state hay is_overdue: hai giá trị đó suy ra được từ timestamps,
   lưu thêm chỉ tạo nguy cơ dữ liệu mâu thuẫn. Xem view ở mục 5. */
CREATE TABLE dbo.Orders (
    order_id           INT IDENTITY(1,1) NOT NULL,
    customer_id        INT               NULL,          -- NULL với khách vãng lai mua tại quầy
    created_by_user_id INT               NULL,          -- Cashier lập đơn POS
    order_source       VARCHAR(20)       NOT NULL,      -- ONLINE_PREORDER | POS
    total_amount       DECIMAL(12,2)     NOT NULL CONSTRAINT DF_Orders_total DEFAULT (0),
    order_status       VARCHAR(20)       NOT NULL,
    idempotency_key    VARCHAR(64)       NULL,          -- chặn tạo trùng đơn khi khách bấm Đặt hàng 2 lần

    -- Nhóm cột lịch hẹn & nhận hàng: chỉ dùng cho ONLINE_PREORDER
    pickup_time        DATETIME2(0)      NULL,
    kitchen_release_at DATETIME2(0)      NULL,
    released_to_kds_at DATETIME2(0)      NULL,
    pickup_code        VARCHAR(10)       NULL,          -- định dạng yyMMdd + 4 ký tự ngẫu nhiên

    -- Mốc vòng đời
    ready_at           DATETIME2(0)      NULL,          -- thời điểm món cuối cùng xong; là mẫu số của KPI đúng hẹn
    picked_up_at       DATETIME2(0)      NULL,
    handoff_by_user_id INT               NULL,          -- Cashier thực hiện giao món
    created_at         DATETIME2(0)      NOT NULL CONSTRAINT DF_Orders_createdAt DEFAULT (SYSDATETIME()),
    completed_at       DATETIME2(0)      NULL,
    cancelled_at       DATETIME2(0)      NULL,
    expired_at         DATETIME2(0)      NULL,

    CONSTRAINT PK_Orders           PRIMARY KEY (order_id),
    CONSTRAINT FK_Orders_Customer  FOREIGN KEY (customer_id)        REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_Orders_CreatedBy FOREIGN KEY (created_by_user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_Orders_Handoff   FOREIGN KEY (handoff_by_user_id) REFERENCES dbo.Users(user_id),

    -- chặn mọi kênh ngoài phạm vi MVP lọt vào hệ thống
    CONSTRAINT CK_Orders_source CHECK (order_source IN ('ONLINE_PREORDER','POS')),

    CONSTRAINT CK_Orders_status CHECK (order_status IN
        ('PENDING_PAYMENT','CONFIRMED','PREPARING','READY','COMPLETED','CANCELLED','EXPIRED')),

    -- đơn tại quầy thu tiền ngay nên không bao giờ ở trạng thái chờ thanh toán
    CONSTRAINT CK_Orders_pendingOnlineOnly CHECK
        (order_status <> 'PENDING_PAYMENT' OR order_source = 'ONLINE_PREORDER'),

    -- đơn Online bắt buộc có giờ hẹn; đơn POS không được gán giờ hẹn
    CONSTRAINT CK_Orders_pickupTime CHECK
        ((order_source = 'ONLINE_PREORDER' AND pickup_time IS NOT NULL)
      OR (order_source = 'POS'             AND pickup_time IS NULL)),

    /* Đặt trước bắt buộc đăng nhập, nên đơn Online luôn có chủ. Không có ràng buộc này thì
       một đơn Online thiếu customer_id vẫn ghi được, và sau đó không ai tra được lịch sử của
       nó, không gửi được tin báo món sẵn sàng, cũng không kiểm tra được quyền xem đơn.
       Khách vãng lai mua tại quầy thì ngược lại: cố tình để trống, không bắt lập tài khoản. */
    CONSTRAINT CK_Orders_onlineCustomer CHECK
        (order_source <> 'ONLINE_PREORDER' OR customer_id IS NOT NULL),

    -- bắt lỗi tính sai lead time ngay tại DB: kế hoạch vào bếp phải trước giờ hẹn
    CONSTRAINT CK_Orders_releaseBeforePickup CHECK
        (kitchen_release_at IS NULL OR pickup_time IS NULL OR kitchen_release_at < pickup_time),

    -- mã nhận hàng chỉ sinh cho đơn Online; khách tại quầy nhận trực tiếp
    CONSTRAINT CK_Orders_pickupCodeOnline CHECK
        (pickup_code IS NULL OR order_source = 'ONLINE_PREORDER'),

    CONSTRAINT CK_Orders_total CHECK (total_amount >= 0)
);
GO

/* Mỗi dòng là một việc trên màn hình bếp.
   Vừa giữ khoá ngoại product_id vừa lưu bản sao tên và giá là có lý do:
     · thiếu bản sao  -> Admin sửa giá thì hoá đơn cũ đổi giá theo
     · thiếu khoá ngoại -> không gom nhóm được báo cáo món bán chạy
   Một dòng là một việc nguyên khối: không có trạng thái "xong 2/3 phần". */
CREATE TABLE dbo.OrderItem (
    order_item_id         INT IDENTITY(1,1) NOT NULL,
    order_id              INT               NOT NULL,
    product_id            INT               NOT NULL,
    product_name_snapshot NVARCHAR(150)     NOT NULL,
    unit_price            DECIMAL(12,2)     NOT NULL,
    quantity              INT               NOT NULL,
    item_status           VARCHAR(20)       NOT NULL CONSTRAINT DF_OrderItem_status DEFAULT ('WAITING'),
    assigned_to_user_id   INT               NULL,      -- đầu bếp đã nhận việc
    started_at            DATETIME2(0)      NULL,
    ready_at              DATETIME2(0)      NULL,

    /* Bàn giao món từ bếp ra quầy. Hai mốc chứ không phải một: bếp đặt món lên quầy và thu
       ngân cầm lấy là hai hành động của hai người, và khoảng giữa chúng chính là lúc món
       nằm chờ — đó mới là thứ màn hình quầy cần hiện ra.

       Không nhét vào item_status vì đây là trục song song: món vẫn ở trạng thái READY suốt
       cả hai bước. Thêm bậc vào chuỗi WAITING→PREPARING→READY sẽ kéo theo mọi chỗ đang đếm
       "món chưa xong" phải sửa lại, trong khi nghĩa của chúng không hề đổi. */
    handed_over_at        DATETIME2(0)      NULL,      -- bếp đưa món ra quầy
    handed_over_by        INT               NULL,
    received_at           DATETIME2(0)      NULL,      -- thu ngân nhận món tại quầy
    received_by           INT               NULL,

    CONSTRAINT PK_OrderItem          PRIMARY KEY (order_item_id),
    CONSTRAINT FK_OrderItem_Orders   FOREIGN KEY (order_id)            REFERENCES dbo.Orders(order_id),
    CONSTRAINT FK_OrderItem_Product  FOREIGN KEY (product_id)          REFERENCES dbo.Product(product_id),
    CONSTRAINT FK_OrderItem_Assignee FOREIGN KEY (assigned_to_user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_OrderItem_HandedBy FOREIGN KEY (handed_over_by)      REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_OrderItem_RecvBy   FOREIGN KEY (received_by)         REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_OrderItem_qty      CHECK (quantity > 0),
    CONSTRAINT CK_OrderItem_price    CHECK (unit_price >= 0),
    CONSTRAINT CK_OrderItem_status   CHECK (item_status IN ('WAITING','PREPARING','READY')),
    /* Không thể nhận món chưa được bàn giao. Ràng buộc này chặn đứng thứ tự ngược ngay ở
       tầng dữ liệu, kể cả khi có ai đó sửa thẳng bằng câu lệnh SQL. */
    CONSTRAINT CK_OrderItem_handover CHECK (received_at IS NULL OR handed_over_at IS NOT NULL)
);
GO

/* ----------------------------------- NHÓM 4 — THANH TOÁN ---------------------------------- */

/* Một đơn có thể có nhiều lần thanh toán: khách thất bại rồi thử lại.
   Không ghi đè dòng cũ — mỗi lần thử là một dòng riêng để đối soát được với cổng thanh toán. */
CREATE TABLE dbo.Payment (
    payment_id     INT IDENTITY(1,1) NOT NULL,
    order_id       INT               NOT NULL,
    method         VARCHAR(20)       NOT NULL,     -- ONLINE_GATEWAY | CASH
    amount         DECIMAL(12,2)     NOT NULL,
    payment_status VARCHAR(20)       NOT NULL,     -- UNPAID | PENDING | PAID | FAILED | REFUNDED
    attempt_no     INT               NOT NULL CONSTRAINT DF_Payment_attempt   DEFAULT (1),
    created_at     DATETIME2(0)      NOT NULL CONSTRAINT DF_Payment_createdAt DEFAULT (SYSDATETIME()),
    paid_at        DATETIME2(0)      NULL,         -- mốc dùng để tính doanh thu
    refunded_at    DATETIME2(0)      NULL,
    CONSTRAINT PK_Payment           PRIMARY KEY (payment_id),
    CONSTRAINT FK_Payment_Orders    FOREIGN KEY (order_id) REFERENCES dbo.Orders(order_id),
    CONSTRAINT CK_Payment_method    CHECK (method IN ('ONLINE_GATEWAY','CASH')),
    CONSTRAINT CK_Payment_status    CHECK (payment_status IN ('UNPAID','PENDING','PAID','FAILED','REFUNDED')),
    CONSTRAINT CK_Payment_amount    CHECK (amount >= 0),
    CONSTRAINT CK_Payment_attemptNo CHECK (attempt_no >= 1),
    /* Lưu ý khi lập trình: tính attempt_no bằng MAX(attempt_no)+1 sẽ bị trùng nếu khách
       bấm thanh toán ở hai tab cùng lúc. Bắt lỗi trùng khoá rồi thử lại tối đa 3 lần. */
    CONSTRAINT UQ_Payment_attempt   UNIQUE (order_id, attempt_no)
);
GO

/* Nhật ký giao dịch với cổng thanh toán.
   external_transaction_id UNIQUE là chốt chặn quan trọng nhất về mặt tiền bạc: cổng thanh toán
   có thể gọi callback nhiều lần cho cùng một giao dịch, lần thứ hai sẽ bị lỗi trùng khoá và
   bị bỏ qua. Không kiểm tra bằng SELECT rồi mới INSERT — hai callback vào cùng lúc vẫn lọt. */
CREATE TABLE dbo.PaymentTransaction (
    transaction_id          INT IDENTITY(1,1) NOT NULL,
    payment_id              INT               NOT NULL,
    gateway                 VARCHAR(50)       NOT NULL,
    external_transaction_id VARCHAR(100)      NOT NULL,
    status                  VARCHAR(20)       NOT NULL,
    raw_reference           NVARCHAR(MAX)     NULL,     -- payload gốc, giữ để đối soát khi có tranh chấp
    created_at              DATETIME2(0)      NOT NULL CONSTRAINT DF_Txn_createdAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Transaction         PRIMARY KEY (transaction_id),
    CONSTRAINT UQ_Transaction_extId   UNIQUE (external_transaction_id),
    CONSTRAINT FK_Transaction_Payment FOREIGN KEY (payment_id) REFERENCES dbo.Payment(payment_id)
);
GO

/* --------------------------------- NHÓM 5 — VẬN HÀNH & AUDIT ------------------------------ */

CREATE TABLE dbo.Notification (
    notification_id INT IDENTITY(1,1) NOT NULL,
    user_id         INT               NULL,       -- NULL với khách vãng lai không có tài khoản
    order_id        INT               NOT NULL,
    channel         VARCHAR(20)       NOT NULL CONSTRAINT DF_Notification_channel DEFAULT ('MOCK'),
    event_type      VARCHAR(30)       NOT NULL,   -- xem com.fastfood.common.constant.NotificationEvent
    content         NVARCHAR(MAX)     NULL,       -- tin báo sẵn sàng phải kèm giờ hẹn và mã nhận hàng
    status          VARCHAR(20)       NOT NULL CONSTRAINT DF_Notification_status  DEFAULT ('PENDING'),
    sent_at         DATETIME2(0)      NULL,
    CONSTRAINT PK_Notification         PRIMARY KEY (notification_id),
    CONSTRAINT FK_Notification_Users   FOREIGN KEY (user_id)  REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_Notification_Orders  FOREIGN KEY (order_id) REFERENCES dbo.Orders(order_id),
    /* Bốn sự kiện sau đều là chuyện khách cần biết ngay mà không phải tự mở trang ra xem.
       Hai cái đầu là tin vui, hai cái sau là tin xấu — thiếu chúng thì đơn hết hiệu lực hay
       tiền được hoàn lại đều diễn ra im lặng, khách chỉ phát hiện qua sao kê ngân hàng. */
    CONSTRAINT CK_Notification_event   CHECK (event_type IN
        ('ORDER_CONFIRMED','ORDER_READY','ORDER_CANCELLED','ORDER_EXPIRED')),
    CONSTRAINT CK_Notification_status  CHECK (status  IN ('PENDING','SENT','FAILED')),
    CONSTRAINT CK_Notification_channel CHECK (channel IN ('EMAIL','MOCK'))
);
GO

/* Sự cố bếp chạy song song với trạng thái món, không kéo trạng thái lùi lại.
   Món hỏng phải làm lại vẫn nằm ở PREPARING cho tới khi xong, kèm một sự cố đang mở. */
CREATE TABLE dbo.KitchenIssue (
    issue_id      INT IDENTITY(1,1) NOT NULL,
    order_item_id INT               NOT NULL,
    created_by    INT               NOT NULL,
    issue_type    VARCHAR(30)       NOT NULL,   -- OUT_OF_STOCK | QUALITY | REMAKE | OTHER
    description   NVARCHAR(500)     NULL,
    status        VARCHAR(20)       NOT NULL CONSTRAINT DF_Issue_status    DEFAULT ('OPEN'),
    created_at    DATETIME2(0)      NOT NULL CONSTRAINT DF_Issue_createdAt DEFAULT (SYSDATETIME()),
    resolved_at   DATETIME2(0)      NULL,
    CONSTRAINT PK_KitchenIssue    PRIMARY KEY (issue_id),
    CONSTRAINT FK_Issue_OrderItem FOREIGN KEY (order_item_id) REFERENCES dbo.OrderItem(order_item_id),
    CONSTRAINT FK_Issue_Users     FOREIGN KEY (created_by)    REFERENCES dbo.Users(user_id),
    -- CANCELLED: sự cố báo nhầm, do chính người báo thu hồi khi còn đang mở. Giữ lại dòng
    -- thay vì xoá hẳn để nhật ký thao tác vẫn dẫn được về đúng bản ghi mà nó nhắc tới.
    CONSTRAINT CK_Issue_status    CHECK (status     IN ('OPEN','RESOLVED','CANCELLED')),
    CONSTRAINT CK_Issue_type      CHECK (issue_type IN ('OUT_OF_STOCK','QUALITY','REMAKE','OTHER'))
);
GO

/* Nhật ký thao tác, thiết kế dạng chung để ghi được mọi loại đối tượng mà không cần
   thêm bảng mỗi khi có nghiệp vụ mới. actor_id để trống nghĩa là do hệ thống tự thực hiện.
   Bắt buộc ghi lại: thanh toán thành công, tự động xác nhận, đưa đơn xuống bếp, bắt đầu và
   hoàn thành món, xác minh mã nhận hàng, giao món, huỷ và hoàn tiền, thao tác quản trị. */
CREATE TABLE dbo.AuditLog (
    audit_id    BIGINT IDENTITY(1,1) NOT NULL,
    actor_id    INT           NULL,
    entity_type VARCHAR(50)   NOT NULL,     -- ORDER | ORDER_ITEM | PAYMENT | PRODUCT | USER ...
    entity_id   VARCHAR(50)   NOT NULL,
    action      VARCHAR(50)   NOT NULL,     -- xem com.fastfood.common.constant.AuditAction
    old_value   NVARCHAR(MAX) NULL,
    new_value   NVARCHAR(MAX) NULL,
    created_at  DATETIME2(0)  NOT NULL CONSTRAINT DF_Audit_createdAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_AuditLog    PRIMARY KEY (audit_id),
    CONSTRAINT FK_Audit_Users FOREIGN KEY (actor_id) REFERENCES dbo.Users(user_id)
);
GO


/* =============================================================================================
   4. INDEX

   Mỗi index dưới đây phục vụ một truy vấn có thật trong ứng dụng. Không tạo thêm "cho chắc":
   Orders và OrderItem là hai bảng bị ghi nhiều nhất, index thừa làm chậm chính luồng bếp.
   ============================================================================================= */

CREATE INDEX IX_Users_role ON dbo.Users(role_id);

-- màn hình menu: chạy mỗi lần khách mở trang
CREATE INDEX IX_Product_category ON dbo.Product(category_id, status, is_available) INCLUDE (name, price);
GO

-- chặn tạo trùng đơn khi khách bấm Đặt hàng nhiều lần; lọc NULL để index luôn nhỏ
CREATE UNIQUE INDEX UX_Orders_idempotency ON dbo.Orders(idempotency_key) WHERE idempotency_key IS NOT NULL;
GO

-- Cashier tra mã khi khách đến nhận: vừa đảm bảo mã không trùng, vừa tra tức thì
CREATE UNIQUE INDEX UX_Orders_pickupCode ON dbo.Orders(pickup_code) WHERE pickup_code IS NOT NULL;
GO

/* Index quan trọng nhất của hệ thống.
   Scheduler quét mỗi 30 giây để tìm đơn tới giờ đưa xuống bếp. Nhờ lọc "chưa release",
   index chỉ chứa các đơn đang chờ nên kích thước gần như không đổi dù bảng Orders lớn dần
   theo năm tháng — đây là điều kiện để đưa đơn xuống bếp không trễ quá 60 giây. */
CREATE INDEX IX_Orders_release ON dbo.Orders(order_status, kitchen_release_at) WHERE released_to_kds_at IS NULL;
GO

-- màn hình đơn hàng của Cashier: 4 tab đơn tại quầy / đơn hẹn giờ / sẵn sàng giao / quá hạn
CREATE INDEX IX_Orders_status_source ON dbo.Orders(order_status, order_source, pickup_time);

-- lịch sử đơn của khách, luôn kèm điều kiện lọc theo chính chủ
CREATE INDEX IX_Orders_customer ON dbo.Orders(customer_id, created_at DESC);
GO

-- xem chi tiết đơn và tổng hợp trạng thái: chạy mỗi lần bếp đổi trạng thái một món
CREATE INDEX IX_OrderItem_order ON dbo.OrderItem(order_id) INCLUDE (item_status);

-- hàng chờ và việc đang làm trên màn hình bếp: truy vấn lại mỗi 2 giây
CREATE INDEX IX_OrderItem_kds ON dbo.OrderItem(item_status, assigned_to_user_id) INCLUDE (order_id);

/* Món bếp đã đưa ra quầy mà thu ngân chưa cầm. Cùng nguyên tắc lọc như IX_Orders_release:
   điều kiện WHERE giữ index chỉ chứa những món đang thật sự nằm chờ trên quầy — thường vài
   dòng — nên nó không lớn lên theo số món đã bán từ đầu tới giờ.
   Đáng có index riêng vì con số này còn hiện thành huy hiệu trên thanh điều hướng của thu
   ngân, tức là chạy ở MỌI trang thu ngân mở ra, không riêng màn hình quầy giao nhận. */
CREATE INDEX IX_OrderItem_counter ON dbo.OrderItem(handed_over_at, order_item_id)
    INCLUDE (order_id) WHERE received_at IS NULL;
GO

-- kiểm tra đã thanh toán chưa trước khi giao món
CREATE INDEX IX_Payment_order ON dbo.Payment(order_id, payment_status);

/* Báo cáo doanh thu quét theo khoảng ngày, và quét bằng HAI mốc chứ không một:
   tiền thu vào tính theo paid_at, tiền hoàn ra tính theo refunded_at. Một khoản thu
   tháng này mà hoàn tháng sau phải rơi vào đúng hai kỳ khác nhau, nên mỗi mốc cần
   một index riêng. */
CREATE INDEX IX_Payment_paidAt     ON dbo.Payment(paid_at)     INCLUDE (amount, method, payment_status);
CREATE INDEX IX_Payment_refundedAt ON dbo.Payment(refunded_at) INCLUDE (amount, method) WHERE refunded_at IS NOT NULL;

CREATE INDEX IX_Transaction_payment ON dbo.PaymentTransaction(payment_id);
GO

CREATE INDEX IX_Notification_order ON dbo.Notification(order_id, event_type);
CREATE INDEX IX_Issue_item         ON dbo.KitchenIssue(order_item_id, status);
CREATE INDEX IX_Audit_entity       ON dbo.AuditLog(entity_type, entity_id, created_at DESC);
GO


/* =============================================================================================
   5. VIEW

   Chỉ tạo view cho những giá trị suy ra mà công thức KHÔNG hiển nhiên, để mọi màn hình dùng
   chung một cách tính. Các báo cáo còn lại (doanh thu, món bán chạy, thống kê thanh toán)
   chỉ là GROUP BY thuần nên viết thẳng trong ReportDAO, không giấu vào DB.
   ============================================================================================= */

/* Trạng thái đưa xuống bếp và cờ quá hạn nhận hàng.
   Cả hai KHÔNG phải trạng thái đơn — chúng được suy ra từ các mốc thời gian.
   Khách đến muộn chỉ bị đánh dấu để nhân viên chú ý, tuyệt đối không tự huỷ hay tự hoàn tiền
   vì đơn đã được trả tiền trước.

   Cột is_overdue dùng đồng hồ của SQL Server nên chỉ dành cho hiển thị; khi tầng Service cần
   mốc thời gian chính xác thì tự tính lại bằng thời gian của ứng dụng. */
CREATE VIEW dbo.vw_OrderReleaseState
AS
SELECT  o.order_id,
        o.order_source,
        o.order_status,
        o.pickup_time,
        o.kitchen_release_at,
        o.released_to_kds_at,

        CASE WHEN o.released_to_kds_at IS NOT NULL THEN 'RELEASED_TO_KDS'
             WHEN o.order_status = 'CONFIRMED'     THEN 'SCHEDULED'
             ELSE 'NOT_RELEASED'
        END AS release_state,

        CASE WHEN o.order_status = 'READY'
              AND o.order_source = 'ONLINE_PREORDER'
              AND SYSDATETIME() > DATEADD(MINUTE, 30, o.pickup_time)
             THEN 1 ELSE 0
        END AS is_overdue,

        -- Scheduler chạy trễ bao nhiêu giây so với kế hoạch (yêu cầu: không quá 60)
        DATEDIFF(SECOND, o.kitchen_release_at, o.released_to_kds_at) AS release_delay_seconds
FROM    dbo.Orders o;
GO

/* Tỷ lệ món sẵn sàng đúng hẹn — chỉ số vận hành riêng của kênh đặt trước.
   Đây chính là thứ chứng minh Online Pre-order không chỉ khác ở giao diện: nó có cam kết
   thời gian đo được bằng số. */
CREATE VIEW dbo.vw_OnTimeReady
AS
SELECT  o.order_id,
        o.pickup_time,
        o.ready_at,
        o.released_to_kds_at,
        o.completed_at,
        CASE WHEN o.ready_at <= o.pickup_time THEN 1 ELSE 0 END AS is_on_time,
        DATEDIFF(MINUTE, o.released_to_kds_at, o.ready_at)        AS prep_lead_minutes
FROM    dbo.Orders o
WHERE   o.order_source = 'ONLINE_PREORDER'
  AND   o.ready_at IS NOT NULL;
GO


/* =============================================================================================
   6. TRIGGER

   Chỉ dùng trigger cho hai loại quy tắc: rule liên bảng có rủi ro tiền bạc, và rule chống
   mất dữ liệu giao dịch. Mọi quy tắc còn lại nằm ở tầng Service — nơi có thông tin về
   thời điểm hiện tại, người đang thao tác, và có thể trả thông báo tiếng Việt cho người dùng.
   ============================================================================================= */

/* Đơn đặt trước bắt buộc thanh toán online, không thu tiền mặt tại quầy.
   Không viết được thành CHECK vì phải đọc bảng Orders. Đây là quy tắc liên quan tới tiền
   nên cần một lớp chặn ngay tại DB, không phó thác hoàn toàn cho tầng ứng dụng. */
CREATE TRIGGER dbo.TR_Payment_OnlineGatewayOnly
ON dbo.Payment
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM   inserted i
               JOIN   dbo.Orders o ON o.order_id = i.order_id
               WHERE  o.order_source = 'ONLINE_PREORDER' AND i.method = 'CASH')
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW 50004, 'Don dat truoc chi cho phep thanh toan online, khong thu tien mat tai quay.', 1;
    END
END
GO

/* Không xoá vĩnh viễn dữ liệu giao dịch — cần giữ để đối soát và truy vết.
   Muốn "xoá" thì đổi trạng thái: đơn thành CANCELLED/EXPIRED, thanh toán thành REFUNDED,
   sản phẩm và tài khoản thành INACTIVE/LOCKED.

   OrderItem cũng được chặn: khoá ngoại chỉ ngăn xoá đơn khi còn món, chứ không ngăn xoá
   chính dòng món — mà xoá món sẽ làm tổng tiền của đơn sai lệch mà không ai biết.

   Lưu ý: DROP TABLE và TRUNCATE không bị các trigger này chặn. Ở môi trường thật cần
   không cấp quyền ALTER cho tài khoản mà ứng dụng dùng để kết nối. */
CREATE TRIGGER dbo.TR_Orders_NoHardDelete ON dbo.Orders INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50020, 'Khong duoc xoa Orders. Dung order_status = CANCELLED / EXPIRED.', 1;
END
GO

CREATE TRIGGER dbo.TR_OrderItem_NoHardDelete ON dbo.OrderItem INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50021, 'Khong duoc xoa OrderItem — se lam sai tong tien cua don.', 1;
END
GO

CREATE TRIGGER dbo.TR_Payment_NoHardDelete ON dbo.Payment INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50022, 'Khong duoc xoa Payment. Dung payment_status = REFUNDED.', 1;
END
GO

CREATE TRIGGER dbo.TR_Transaction_NoHardDelete ON dbo.PaymentTransaction INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50023, 'Khong duoc xoa PaymentTransaction — mat dau vet doi soat voi cong thanh toan.', 1;
END
GO

CREATE TRIGGER dbo.TR_AuditLog_NoHardDelete ON dbo.AuditLog INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50024, 'Khong duoc xoa AuditLog.', 1;
END
GO


/* =============================================================================================
   7. DỮ LIỆU MẪU
   ============================================================================================= */
SET NOCOUNT ON;
GO

/* --------------------------------------- Vai trò ------------------------------------------ */
INSERT INTO dbo.Role (name, description) VALUES
 ('CUSTOMER', N'Khách hàng đặt trước qua ứng dụng'),
 ('CASHIER',  N'Nhân viên bán hàng và giao món tại quầy'),
 ('KITCHEN',  N'Nhân viên bếp'),
 ('ADMIN',    N'Quản trị hệ thống');
GO

/* ------------------------------------- Người dùng -----------------------------------------
   Mật khẩu tất cả tài khoản: 123456
   Hash bcrypt cost 10, tiền tố $2a$ — thư viện jBCrypt 0.4 chỉ chấp nhận $2$ và $2a$.
   Nếu tự sinh hash bằng htpasswd (ra $2y$) thì phải đổi tiền tố thành $2a$, phần còn lại giữ nguyên.
   ------------------------------------------------------------------------------------------ */
DECLARE @pw VARCHAR(255) = '$2a$10$Kpqc42/3twhcoaPX6ezdS.HAMJB7suONI3r9eOk6nbhklIHTNqdO6';

INSERT INTO dbo.Users (full_name, email, phone, password_hash, role_id, status)
SELECT v.full_name, v.email, v.phone, @pw, r.role_id, 'ACTIVE'
FROM (VALUES
        (N'Nguyễn Văn An',  'customer1@gmail.com',  '0901000001', 'CUSTOMER'),
        (N'Trần Thị Bình',  'customer2@gmail.com',  '0901000002', 'CUSTOMER'),
        (N'Lê Thu Ngân',    'cashier1@fastfood.vn', '0902000001', 'CASHIER'),
        (N'Vũ Minh Quang',  'cashier2@fastfood.vn', '0902000002', 'CASHIER'),
        (N'Phạm Hữu Phước', 'kitchen1@fastfood.vn', '0903000001', 'KITCHEN'),
        (N'Đỗ Thanh Hà',    'kitchen2@fastfood.vn', '0903000002', 'KITCHEN'),
        (N'Quản Trị Viên',  'admin@fastfood.vn',    '0904000001', 'ADMIN')
     ) AS v(full_name, email, phone, role_name)
JOIN dbo.Role r ON r.name = v.role_name;
GO

/* -------------------------------------- Danh mục ------------------------------------------ */
INSERT INTO dbo.Category (name, status, display_order) VALUES
 (N'Burger',       'ACTIVE',   1),
 (N'Gà rán',       'ACTIVE',   2),
 (N'Khoai tây',    'ACTIVE',   3),
 (N'Đồ uống',      'ACTIVE',   4),
 (N'Combo',        'ACTIVE',   5),
 (N'Món theo mùa', 'INACTIVE', 9);   -- danh mục đã tắt: món bên trong không được lên menu
GO

/* -------------------------------------- Sản phẩm ------------------------------------------
   Ba món cuối cố ý không đủ điều kiện lên menu, để kiểm chứng quy tắc lọc món ba tầng:
   tạm hết hàng · đã ngừng bán · thuộc danh mục đã tắt.
   ------------------------------------------------------------------------------------------ */
INSERT INTO dbo.Product (category_id, name, description, price, image_url, is_available, status)
SELECT c.category_id, v.name, v.description, v.price, v.image_url, v.is_available, v.status
FROM (VALUES
    (N'Burger',       N'Burger Bò Phô Mai',   N'Bò nướng, phô mai cheddar, rau tươi',   55000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Burger+Bo+Pho+Mai',  1, 'ACTIVE'),
    (N'Burger',       N'Burger Gà Giòn',      N'Gà chiên giòn, sốt mayonnaise',         49000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Burger+Ga+Gion',  1, 'ACTIVE'),
    (N'Gà rán',       N'Gà Rán 1 Miếng',      N'Gà rán truyền thống',                   35000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Ga+Ran+1+Mieng',   1, 'ACTIVE'),
    (N'Gà rán',       N'Gà Rán 3 Miếng',      N'Phần ba miếng gà rán',                  95000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Ga+Ran+3+Mieng',   1, 'ACTIVE'),
    (N'Khoai tây',    N'Khoai Tây Chiên (M)', N'Khoai tây chiên cỡ vừa',                25000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Khoai+Tay+Chien+M',    1, 'ACTIVE'),
    (N'Khoai tây',    N'Khoai Tây Chiên (L)', N'Khoai tây chiên cỡ lớn',                35000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Khoai+Tay+Chien+L',    1, 'ACTIVE'),
    (N'Đồ uống',      N'Pepsi (M)',           N'Nước ngọt có ga',                       15000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Pepsi+M',      1, 'ACTIVE'),
    (N'Đồ uống',      N'Trà Đào Cam Sả',      N'Trà đào cam sả',                        29000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Tra+Dao+Cam+Sa',    1, 'ACTIVE'),
    (N'Combo',        N'Combo Burger Solo',   N'Burger bò, khoai tây cỡ vừa và Pepsi',  85000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Combo+Burger+Solo', 1, 'ACTIVE'),
    (N'Combo',        N'Combo Gia Đình',      N'Ba gà rán, hai khoai lớn và bốn nước', 259000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Combo+Gia+Dinh',   1, 'ACTIVE'),
    (N'Gà rán',       N'Gà Rán Cay Hàn Quốc', N'Sốt cay kiểu Hàn — tạm hết hàng',       45000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Ga+Ran+Cay+Han+Quoc',     0, 'ACTIVE'),
    (N'Đồ uống',      N'Nước Cam Ép',         N'Đã ngừng kinh doanh',                   30000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Nuoc+Cam+Ep',     1, 'INACTIVE'),
    (N'Món theo mùa', N'Bánh Trung Thu',      N'Món theo mùa, ngoài menu thường',       60000., 'https://placehold.co/400x300/fff1f0/d92d20?text=Banh+Trung+Thu',  1, 'ACTIVE')
   ) AS v(category_name, name, description, price, image_url, is_available, status)
JOIN dbo.Category c ON c.name = v.category_name;
GO

/* ------------------------------------- Giỏ hàng mẫu ---------------------------------------
   Hai giỏ, mỗi giỏ dựng sẵn một tình huống khác nhau của màn hình /cart:

     customer1 — giỏ sạch, bấm Đặt hàng là đi thẳng sang trang thanh toán.
     customer2 — trong giỏ có món vừa hết hàng. Đây mới là cái đáng dựng sẵn: giỏ hàng đọc
                 kèm is_available và trạng thái danh mục để chặn thanh toán và hiện dải cảnh
                 báo "bỏ món hết hàng ra". Nếu không có giỏ nào ở tình trạng đó thì nhánh
                 xử lý ấy chỉ chạy được sau khi tự tay đi tắt một món trong trang quản trị.

   Chỉ khách Online mới có giỏ trong DB; giỏ của thu ngân nằm trong session nên không ghi
   xuống đây. Giỏ là dữ liệu nháp — không có audit log, không có ràng buộc nào ràng nó với
   đơn hàng, và OrderService dọn sạch giỏ ngay sau khi đặt hàng thành công.
   ------------------------------------------------------------------------------------------ */
INSERT INTO dbo.Cart (user_id, updated_at)
SELECT u.user_id, DATEADD(MINUTE, -20, SYSDATETIME())
FROM   dbo.Users u
WHERE  u.email IN ('customer1@gmail.com', 'customer2@gmail.com');
GO

INSERT INTO dbo.CartItem (cart_id, product_id, quantity)
SELECT c.cart_id, p.product_id, v.quantity
FROM (VALUES
        ('customer1@gmail.com', N'Burger Bò Phô Mai',    1),
        ('customer1@gmail.com', N'Khoai Tây Chiên (M)',  2),
        ('customer2@gmail.com', N'Pepsi (M)',            2),
        -- món tạm hết hàng: chính là thứ làm nút thanh toán của customer2 bị khoá
        ('customer2@gmail.com', N'Gà Rán Cay Hàn Quốc',  1)
     ) AS v(email, product_name, quantity)
JOIN dbo.Users   u ON u.email   = v.email
JOIN dbo.Cart    c ON c.user_id = u.user_id
JOIN dbo.Product p ON p.name    = v.product_name;
GO

/* ------------------------------------- Đơn hàng mẫu ---------------------------------------
   11 đơn phủ đủ bảy trạng thái và các tình huống ngoại lệ quan trọng.
   Mọi mốc thời gian tính tương đối so với lúc chạy file, nên dữ liệu luôn hợp lý:
   đơn hẹn giờ luôn nằm ở tương lai, đơn quá hạn luôn nằm ở quá khứ.

   D1  Online  PENDING_PAYMENT  đang chờ khách thanh toán
   D2  Online  EXPIRED          thanh toán thất bại rồi quá hạn 15 phút
   D3  Online  CONFIRMED        đã trả tiền, đang chờ tới giờ mới đưa xuống bếp
   D4  Online  PREPARING        bếp đang làm dở
   D5  Online  READY            sẵn sàng, đúng hẹn — dùng để demo xác minh mã nhận hàng
   D6  Online  READY            quá giờ hẹn 40 phút mà khách chưa tới
   D7  Online  COMPLETED        đã giao đúng hẹn
   D8  Online  CANCELLED        huỷ trước khi vào bếp, đã hoàn tiền đầy đủ
   D9  POS     COMPLETED        khách tại quầy trả tiền mặt
   D10 POS     PREPARING        khách tại quầy quét mã trả tiền, đang có sự cố bếp
   D11 Online  COMPLETED        món xong TRỄ so với giờ hẹn — để tỷ lệ đúng hẹn ra 75%
                                thay vì 100%, mới kiểm chứng được công thức
   ------------------------------------------------------------------------------------------ */
DECLARE @now DATETIME2(0) = SYSDATETIME();
/* CONVERT kiểu 12 cho ra đúng yyMMdd, giống PickupCodeGenerator sinh mã lúc chạy thật.
   KHÔNG dùng FORMAT: đó là hàm CLR, mà Azure SQL Edge (bản chạy được trên máy Mac dùng chip
   ARM) không bật CLR. Khi đó FORMAT trả về NULL, @day thành NULL, và vì NULL nối chuỗi vẫn ra
   NULL nên TOÀN BỘ mã nhận hàng của dữ liệu mẫu biến mất — lặng lẽ, không có lỗi nào báo lên.
   Hậu quả: không đơn đặt trước nào giao được, vì giao món phải đối chiếu mã. */
DECLARE @day VARCHAR(6)   = CONVERT(VARCHAR(6), @now, 12);

DECLARE @cus1  INT = (SELECT user_id FROM dbo.Users WHERE email = 'customer1@gmail.com');
DECLARE @cus2  INT = (SELECT user_id FROM dbo.Users WHERE email = 'customer2@gmail.com');
DECLARE @cash1 INT = (SELECT user_id FROM dbo.Users WHERE email = 'cashier1@fastfood.vn');
DECLARE @kit1  INT = (SELECT user_id FROM dbo.Users WHERE email = 'kitchen1@fastfood.vn');
DECLARE @kit2  INT = (SELECT user_id FROM dbo.Users WHERE email = 'kitchen2@fastfood.vn');

DECLARE @pBurgerBo INT = (SELECT product_id FROM dbo.Product WHERE name = N'Burger Bò Phô Mai');
DECLARE @pBurgerGa INT = (SELECT product_id FROM dbo.Product WHERE name = N'Burger Gà Giòn');
DECLARE @pGa1      INT = (SELECT product_id FROM dbo.Product WHERE name = N'Gà Rán 1 Miếng');
DECLARE @pGa3      INT = (SELECT product_id FROM dbo.Product WHERE name = N'Gà Rán 3 Miếng');
DECLARE @pKhoaiM   INT = (SELECT product_id FROM dbo.Product WHERE name = N'Khoai Tây Chiên (M)');
DECLARE @pKhoaiL   INT = (SELECT product_id FROM dbo.Product WHERE name = N'Khoai Tây Chiên (L)');
DECLARE @pPepsi    INT = (SELECT product_id FROM dbo.Product WHERE name = N'Pepsi (M)');
DECLARE @pTraDao   INT = (SELECT product_id FROM dbo.Product WHERE name = N'Trà Đào Cam Sả');
DECLARE @pSolo     INT = (SELECT product_id FROM dbo.Product WHERE name = N'Combo Burger Solo');
DECLARE @pGiaDinh  INT = (SELECT product_id FROM dbo.Product WHERE name = N'Combo Gia Đình');

DECLARE @o INT, @pay INT, @item INT;

/* -- D1 · Online · chờ thanh toán · 70.000 ------------------------------------------------- */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key, pickup_time, created_at)
VALUES (@cus1, 'ONLINE_PREORDER', 70000, 'PENDING_PAYMENT', 'demo-0001', DATEADD(MINUTE,45,@now), DATEADD(MINUTE,-5,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status) VALUES
 (@o, @pBurgerBo, N'Burger Bò Phô Mai', 55000, 1, 'WAITING'),
 (@o, @pPepsi,    N'Pepsi (M)',         15000, 1, 'WAITING');
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at)
VALUES (@o, 'ONLINE_GATEWAY', 70000, 'PENDING', DATEADD(MINUTE,-5,@now));

/* -- D2 · Online · quá hạn thanh toán · 70.000 --------------------------------------------- */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key, pickup_time, created_at, expired_at)
VALUES (@cus2, 'ONLINE_PREORDER', 70000, 'EXPIRED', 'demo-0002', DATEADD(MINUTE,40,@now), DATEADD(MINUTE,-30,@now), DATEADD(MINUTE,-15,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status)
VALUES (@o, @pGa1, N'Gà Rán 1 Miếng', 35000, 2, 'WAITING');
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at)
VALUES (@o, 'ONLINE_GATEWAY', 70000, 'FAILED', DATEADD(MINUTE,-29,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, raw_reference, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0002-FAIL', 'FAILED', N'{"code":"51","message":"Insufficient funds"}', DATEADD(MINUTE,-29,@now));
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, new_value, created_at)
VALUES (NULL, 'ORDER', CAST(@o AS VARCHAR(50)), 'ORDER_EXPIRED', 'EXPIRED', DATEADD(MINUTE,-15,@now));

/* -- D3 · Online · đã xác nhận, chờ tới giờ vào bếp · 114.000 ------------------------------
   Trạng thái đặc trưng nhất của dự án: tiền đã thu, đơn đã nhận, nhưng bếp CHƯA thấy đơn
   để món không bị làm quá sớm. Giờ hẹn +60 phút nên kế hoạch vào bếp là +40 phút. */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, pickup_code, created_at)
VALUES (@cus1, 'ONLINE_PREORDER', 114000, 'CONFIRMED', 'demo-0003',
        DATEADD(MINUTE,60,@now), DATEADD(MINUTE,40,@now), @day+'A1C7', DATEADD(MINUTE,-10,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status) VALUES
 (@o, @pSolo,   N'Combo Burger Solo', 85000, 1, 'WAITING'),
 (@o, @pTraDao, N'Trà Đào Cam Sả',    29000, 1, 'WAITING');
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 114000, 'PAID', DATEADD(MINUTE,-10,@now), DATEADD(MINUTE,-9,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, raw_reference, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0003', 'SUCCESS', N'{"code":"00","message":"Success"}', DATEADD(MINUTE,-9,@now));
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, new_value, created_at) VALUES
 (NULL, 'PAYMENT', CAST(@pay AS VARCHAR(50)), 'PAYMENT_PAID', 'PAID',      DATEADD(MINUTE,-9,@now)),
 (NULL, 'ORDER',   CAST(@o   AS VARCHAR(50)), 'AUTO_CONFIRM', 'CONFIRMED', DATEADD(MINUTE,-9,@now));

/* -- D4 · Online · bếp làm xong một món, còn một món · 130.000 ------------------------------
   Đơn hai món với đúng một món đã xong là trạng thái mở khoá nút "bàn giao ra quầy" của bếp —
   khối quan trọng nhất trên màn hình bếp, vì trước khi có nó món nấu xong không còn nằm trong
   danh sách nào. Thiếu đơn này thì khối đó rỗng ngay sau khi cài, không có gì để thử.

   Cả hai món đều của kitchen1, một xong một đang làm. Nhờ vậy màn hình bếp có đủ việc ở cả ba
   khối cùng lúc — thiếu một khối là mất một nút không thử được.

   Đơn vẫn ở PREPARING vì món kia chưa xong (BR-11), và đó chính là điều đáng thấy: món xong
   trước được mang ra quầy ngay thay vì nằm lại chờ món cuối rồi nguội. */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, released_to_kds_at, pickup_code, created_at)
VALUES (@cus2, 'ONLINE_PREORDER', 130000, 'PREPARING', 'demo-0004',
        DATEADD(MINUTE,15,@now), DATEADD(MINUTE,-5,@now), DATEADD(MINUTE,-5,@now), @day+'B2D8', DATEADD(MINUTE,-30,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at, ready_at) VALUES
 (@o, @pGa3,    N'Gà Rán 3 Miếng',      95000, 1, 'READY',     @kit1, DATEADD(MINUTE,-4,@now), DATEADD(MINUTE,-1,@now)),
 (@o, @pKhoaiL, N'Khoai Tây Chiên (L)', 35000, 1, 'PREPARING', @kit1, DATEADD(MINUTE,-3,@now), NULL);
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 130000, 'PAID', DATEADD(MINUTE,-30,@now), DATEADD(MINUTE,-29,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0004', 'SUCCESS', DATEADD(MINUTE,-29,@now));
/* Chỉ ghi tay sự kiện mức đơn. Sự kiện mức món do khối suy ra ở cuối tệp sinh — viết tay ở
   đây phải tự nhập entity_id, mà mã món chỉ biết được sau khi INSERT nên rất dễ ghi nhầm
   thành mã đơn. Bản trước đã nhầm đúng như vậy: entity_type ghi ORDER_ITEM nhưng entity_id
   lại là mã đơn, bấm vào trong màn hình nhật ký thì ra nhầm bản ghi. */
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, new_value, created_at) VALUES
 (NULL,  'ORDER',      CAST(@o AS VARCHAR(50)), 'KDS_RELEASE', 'RELEASED',  DATEADD(MINUTE,-5,@now));

/* -- D5 · Online · sẵn sàng, đúng hẹn · 98.000 --------------------------------------------- */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, released_to_kds_at, pickup_code, ready_at, created_at)
VALUES (@cus1, 'ONLINE_PREORDER', 98000, 'READY', 'demo-0005',
        DATEADD(MINUTE,10,@now), DATEADD(MINUTE,-10,@now), DATEADD(MINUTE,-10,@now), @day+'C3E9',
        DATEADD(MINUTE,-2,@now), DATEADD(MINUTE,-40,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at, ready_at)
VALUES (@o, @pBurgerGa, N'Burger Gà Giòn', 49000, 2, 'READY', @kit1, DATEADD(MINUTE,-9,@now), DATEADD(MINUTE,-2,@now));
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 98000, 'PAID', DATEADD(MINUTE,-40,@now), DATEADD(MINUTE,-39,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0005', 'SUCCESS', DATEADD(MINUTE,-39,@now));

/* -- D6 · Online · sẵn sàng nhưng khách chưa tới, đã quá hẹn 40 phút · 259.000 -------------
   Chỉ được đánh dấu để nhân viên chú ý; không tự huỷ, không tự hoàn tiền. */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, released_to_kds_at, pickup_code, ready_at, created_at)
VALUES (@cus2, 'ONLINE_PREORDER', 259000, 'READY', 'demo-0006',
        DATEADD(MINUTE,-40,@now), DATEADD(MINUTE,-60,@now), DATEADD(MINUTE,-60,@now), @day+'D4F1',
        DATEADD(MINUTE,-45,@now), DATEADD(MINUTE,-90,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at, ready_at)
VALUES (@o, @pGiaDinh, N'Combo Gia Đình', 259000, 1, 'READY', @kit2, DATEADD(MINUTE,-58,@now), DATEADD(MINUTE,-45,@now));
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 259000, 'PAID', DATEADD(MINUTE,-90,@now), DATEADD(MINUTE,-89,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0006', 'SUCCESS', DATEADD(MINUTE,-89,@now));

/* -- D7 · Online · đã giao xong, đúng hẹn · 95.000 ----------------------------------------- */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, released_to_kds_at, pickup_code,
                        ready_at, picked_up_at, handoff_by_user_id, created_at, completed_at)
VALUES (@cus1, 'ONLINE_PREORDER', 95000, 'COMPLETED', 'demo-0007',
        DATEADD(MINUTE,-120,@now), DATEADD(MINUTE,-140,@now), DATEADD(MINUTE,-140,@now), @day+'E5G2',
        DATEADD(MINUTE,-125,@now), DATEADD(MINUTE,-118,@now), @cash1, DATEADD(MINUTE,-155,@now), DATEADD(MINUTE,-118,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at, ready_at) VALUES
 (@o, @pBurgerBo, N'Burger Bò Phô Mai',   55000, 1, 'READY', @kit1, DATEADD(MINUTE,-138,@now), DATEADD(MINUTE,-127,@now)),
 (@o, @pKhoaiM,   N'Khoai Tây Chiên (M)', 25000, 1, 'READY', @kit1, DATEADD(MINUTE,-135,@now), DATEADD(MINUTE,-125,@now)),
 (@o, @pPepsi,    N'Pepsi (M)',           15000, 1, 'READY', @kit2, DATEADD(MINUTE,-134,@now), DATEADD(MINUTE,-130,@now));
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 95000, 'PAID', DATEADD(MINUTE,-155,@now), DATEADD(MINUTE,-154,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0007', 'SUCCESS', DATEADD(MINUTE,-154,@now));
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, new_value, created_at) VALUES
 (@cash1, 'ORDER', CAST(@o AS VARCHAR(50)), 'PICKUP_VERIFY_OK', @day+'E5G2', DATEADD(MINUTE,-119,@now)),
 (@cash1, 'ORDER', CAST(@o AS VARCHAR(50)), 'HANDOFF',          'COMPLETED', DATEADD(MINUTE,-118,@now));

/* -- D8 · Online · huỷ trước khi vào bếp, đã hoàn tiền · 85.000 ---------------------------
   Huỷ hợp lệ vì thời điểm huỷ còn trước kế hoạch vào bếp, nên bếp chưa từng nhận việc này. */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, pickup_code, created_at, cancelled_at)
VALUES (@cus2, 'ONLINE_PREORDER', 85000, 'CANCELLED', 'demo-0008',
        DATEADD(MINUTE,-90,@now), DATEADD(MINUTE,-110,@now), @day+'F6H3', DATEADD(MINUTE,-180,@now), DATEADD(MINUTE,-150,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status)
VALUES (@o, @pSolo, N'Combo Burger Solo', 85000, 1, 'WAITING');
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at, refunded_at)
VALUES (@o, 'ONLINE_GATEWAY', 85000, 'REFUNDED', DATEADD(MINUTE,-180,@now), DATEADD(MINUTE,-179,@now), DATEADD(MINUTE,-149,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at) VALUES
 (@pay, 'MOCK', 'MOCK-TXN-0008',        'SUCCESS',  DATEADD(MINUTE,-179,@now)),
 (@pay, 'MOCK', 'MOCK-TXN-0008-REFUND', 'REFUNDED', DATEADD(MINUTE,-149,@now));
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, old_value, new_value, created_at) VALUES
 (@cus2, 'ORDER',   CAST(@o   AS VARCHAR(50)), 'ORDER_CANCELLED',  'CONFIRMED', 'CANCELLED', DATEADD(MINUTE,-150,@now)),
 (NULL,  'PAYMENT', CAST(@pay AS VARCHAR(50)), 'PAYMENT_REFUNDED', 'PAID',      'REFUNDED',  DATEADD(MINUTE,-149,@now));

/* -- D9 · Quầy · đã giao xong, trả tiền mặt · 85.000 --------------------------------------- */
INSERT INTO dbo.Orders (customer_id, created_by_user_id, order_source, total_amount, order_status,
                        released_to_kds_at, ready_at, picked_up_at, handoff_by_user_id, created_at, completed_at)
VALUES (NULL, @cash1, 'POS', 85000, 'COMPLETED',
        DATEADD(MINUTE,-60,@now), DATEADD(MINUTE,-52,@now), DATEADD(MINUTE,-50,@now), @cash1,
        DATEADD(MINUTE,-61,@now), DATEADD(MINUTE,-50,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at, ready_at) VALUES
 (@o, @pGa1,   N'Gà Rán 1 Miếng', 35000, 2, 'READY', @kit2, DATEADD(MINUTE,-59,@now), DATEADD(MINUTE,-52,@now)),
 (@o, @pPepsi, N'Pepsi (M)',      15000, 1, 'READY', @kit2, DATEADD(MINUTE,-59,@now), DATEADD(MINUTE,-58,@now));
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'CASH', 85000, 'PAID', DATEADD(MINUTE,-61,@now), DATEADD(MINUTE,-60,@now));
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, new_value, created_at) VALUES
 (@cash1, 'ORDER', CAST(@o AS VARCHAR(50)), 'POS_CONFIRM', 'CONFIRMED', DATEADD(MINUTE,-60,@now)),
 (@cash1, 'ORDER', CAST(@o AS VARCHAR(50)), 'HANDOFF',     'COMPLETED', DATEADD(MINUTE,-50,@now));

/* -- D10 · Quầy · đang làm, khách quét mã trả tiền, có sự cố bếp · 80.000 ------------------ */
INSERT INTO dbo.Orders (customer_id, created_by_user_id, order_source, total_amount, order_status, released_to_kds_at, created_at)
VALUES (NULL, @cash1, 'POS', 80000, 'PREPARING', DATEADD(MINUTE,-6,@now), DATEADD(MINUTE,-7,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at)
VALUES (@o, @pBurgerBo, N'Burger Bò Phô Mai', 55000, 1, 'PREPARING', @kit2, DATEADD(MINUTE,-5,@now));
SET @item = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status)
VALUES (@o, @pKhoaiM, N'Khoai Tây Chiên (M)', 25000, 1, 'WAITING');
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 80000, 'PAID', DATEADD(MINUTE,-7,@now), DATEADD(MINUTE,-6,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0010-QR', 'SUCCESS', DATEADD(MINUTE,-6,@now));
INSERT INTO dbo.KitchenIssue (order_item_id, created_by, issue_type, description, status, created_at)
VALUES (@item, @kit2, 'QUALITY', N'Bánh bị cháy cạnh, cần làm lại', 'OPEN', DATEADD(MINUTE,-3,@now));

/* -- D11 · Online · đã giao xong nhưng món ra TRỄ so với giờ hẹn · 124.000 ----------------- */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, released_to_kds_at, pickup_code,
                        ready_at, picked_up_at, handoff_by_user_id, created_at, completed_at)
VALUES (@cus2, 'ONLINE_PREORDER', 124000, 'COMPLETED', 'demo-0011',
        DATEADD(MINUTE,-165,@now), DATEADD(MINUTE,-185,@now), DATEADD(MINUTE,-185,@now), @day+'G7J4',
        DATEADD(MINUTE,-158,@now), DATEADD(MINUTE,-155,@now), @cash1, DATEADD(MINUTE,-200,@now), DATEADD(MINUTE,-155,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at, ready_at) VALUES
 (@o, @pGa3,    N'Gà Rán 3 Miếng', 95000, 1, 'READY', @kit1, DATEADD(MINUTE,-183,@now), DATEADD(MINUTE,-158,@now)),
 (@o, @pTraDao, N'Trà Đào Cam Sả', 29000, 1, 'READY', @kit2, DATEADD(MINUTE,-182,@now), DATEADD(MINUTE,-176,@now));
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 124000, 'PAID', DATEADD(MINUTE,-200,@now), DATEADD(MINUTE,-199,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0011', 'SUCCESS', DATEADD(MINUTE,-199,@now));

/* -- Bàn giao món giữa bếp và quầy cho dữ liệu mẫu -----------------------------------------
   Đặt ở cuối, sau khi mọi đơn đã có đủ món, để viết theo trạng thái đơn thay vì phải nhớ
   từng mã đơn. Bốn mức khác nhau là cố ý — mỗi mức mở ra một thao tác để thử.

   Mức "đã xong mà còn trong bếp" KHÔNG nằm ở đây mà nằm ngay tại D4: nó là món đầu tiên của
   một đơn hai món, nên không viết được bằng điều kiện theo trạng thái đơn. Xem lại mục 8.6
   sau khi sửa dữ liệu mẫu — mức nào rơi về 0 là một màn hình mất chỗ để thử. */

/* Đơn đã giao cho khách thì hiển nhiên đã đi qua cả hai bước. */
UPDATE oi
SET    handed_over_at = oi.ready_at, handed_over_by = oi.assigned_to_user_id,
       received_at    = oi.ready_at, received_by    = @cash1
FROM   dbo.OrderItem oi
JOIN   dbo.Orders    o ON o.order_id = oi.order_id
WHERE  o.order_status = 'COMPLETED';

/* Đơn đang chờ khách tới lấy: bếp đã đưa món ra quầy, quầy chưa xác nhận nhận.
   Đây là dữ liệu để thử thao tác "nhận món" ở màn hình quầy. */
UPDATE oi
SET    handed_over_at = oi.ready_at, handed_over_by = oi.assigned_to_user_id
FROM   dbo.OrderItem oi
JOIN   dbo.Orders    o ON o.order_id = oi.order_id
WHERE  o.order_status = 'READY';

/* Riêng D5 thì quầy đã nhận đủ món, nên thao tác giao cho khách thử được ngay mà không phải
   bấm nhận trước. Thiếu đơn này thì màn hình giao món không có gì để thử. */
UPDATE oi
SET    received_at = oi.ready_at, received_by = @cash1
FROM   dbo.OrderItem oi
JOIN   dbo.Orders    o ON o.order_id = oi.order_id
WHERE  o.idempotency_key = 'demo-0005';
GO


/* -- Tin đã gửi cho khách ------------------------------------------------------------------
   Suy ra từ các mốc thời gian của đơn, cùng lý do như khối nhật ký ngay bên dưới: viết tay
   ở từng đơn thì luôn sót. Bản trước chỉ có hai dòng cho mười một đơn — trong khi hai loại
   tin xấu (đơn bị huỷ, đơn hết hiệu lực) không có lấy một dòng nào, dù đó chính là hai loại
   tin mà thiếu chúng khách sẽ mất tiền hoặc mất đơn trong im lặng.

   Bốn điều kiện dưới đây khớp đúng với NotificationService: chỉ đơn ONLINE_PREORDER và chỉ
   khi đơn có chủ. Khách mua tại quầy đứng ngay đó nên không có tin nào, và đó là lý do
   Notification.user_id để NULL được dù bảng vẫn bắt buộc có order_id.

   Nội dung dựng đúng theo mẫu câu của NotificationService — kèm số tiền, giờ hẹn và mã nhận
   hàng. MVP chưa có màn hình nào hiển thị các tin này (kênh gửi là MOCK, nội dung chỉ ra
   log), nên chúng phục vụ việc đối soát: tra thẳng bằng SQL để kiểm chứng rằng mỗi bước
   trong vòng đời đơn đều đã báo cho khách, và báo bằng đúng câu chữ mà mã nguồn sinh ra.
   ------------------------------------------------------------------------------------------ */
;WITH don AS (
    SELECT  o.order_id, o.customer_id, o.pickup_time, o.ready_at, o.cancelled_at, o.expired_at,
            ma_nhan = ISNULL(o.pickup_code, '---'),
            /* 259000.00 -> "259.000 đ", giống MoneyUtil.format.
               Không dùng FORMAT vì Azure SQL Edge không bật CLR — xem ghi chú ở phần đơn hàng.
               CONVERT kiểu 1 cho ra "259,000.00": cắt ba ký tự cuối rồi đổi dấu phân nhóm. */
            tien = REPLACE(LEFT(CONVERT(VARCHAR(30), CAST(o.total_amount AS MONEY), 1),
                                LEN(CONVERT(VARCHAR(30), CAST(o.total_amount AS MONEY), 1)) - 3),
                           ',', '.') + N' đ',
            -- "dd/MM/yyyy HH:mm", giống DateTimeUtil.format
            gio_hen = CONVERT(VARCHAR(10), o.pickup_time, 103) + ' ' + CONVERT(VARCHAR(5), o.pickup_time, 108),
            da_tra  = (SELECT MIN(p.paid_at) FROM dbo.Payment p
                       WHERE p.order_id = o.order_id AND p.paid_at IS NOT NULL),
            da_hoan = CASE WHEN EXISTS (SELECT 1 FROM dbo.Payment p
                                        WHERE p.order_id = o.order_id AND p.refunded_at IS NOT NULL)
                           THEN 1 ELSE 0 END
    FROM    dbo.Orders o
    WHERE   o.order_source = 'ONLINE_PREORDER' AND o.customer_id IS NOT NULL
), tin AS (
    /* Tiền vào là đơn được xác nhận (BR-07) — tin này mang mã nhận hàng tới cho khách */
    SELECT d.customer_id, d.order_id, 'ORDER_CONFIRMED' AS event_type, d.da_tra AS sent_at,
           N'Đơn #' + CAST(d.order_id AS NVARCHAR(20)) + N' đã thanh toán thành công ' + d.tien
         + N'. Giờ nhận hàng: ' + d.gio_hen + N'. Mã nhận hàng: ' + d.ma_nhan + N'.' AS content
    FROM   don d WHERE d.da_tra IS NOT NULL
    UNION ALL
    /* Món xong — nhắc lại giờ hẹn và mã, vì đây là tin khách mở ra lúc đang trên đường tới */
    SELECT d.customer_id, d.order_id, 'ORDER_READY', d.ready_at,
           N'Món của bạn đã sẵn sàng. Vui lòng đến quầy trước ' + d.gio_hen
         + N' và đưa mã ' + d.ma_nhan + N' để nhận hàng.'
    FROM   don d WHERE d.ready_at IS NOT NULL
    UNION ALL
    /* Huỷ — nói thẳng tiền có được hoàn hay không, đây là câu khách hỏi đầu tiên */
    SELECT d.customer_id, d.order_id, 'ORDER_CANCELLED', d.cancelled_at,
           N'Đơn #' + CAST(d.order_id AS NVARCHAR(20)) + N' đã bị huỷ.'
         + CASE WHEN d.da_hoan = 1
                THEN N' Toàn bộ ' + d.tien + N' đã được hoàn lại về phương thức thanh toán ban đầu.'
                ELSE N'' END
    FROM   don d WHERE d.cancelled_at IS NOT NULL
    UNION ALL
    /* Hết hiệu lực vì quá hạn thanh toán — chưa từng thu tiền nên không có chuyện hoàn */
    SELECT d.customer_id, d.order_id, 'ORDER_EXPIRED', d.expired_at,
           N'Đơn #' + CAST(d.order_id AS NVARCHAR(20))
         + N' không được thanh toán trong thời gian giữ chỗ nên đã hết hiệu lực. '
         + N'Bạn không bị trừ tiền. Vui lòng đặt lại nếu vẫn muốn dùng bữa.'
    FROM   don d WHERE d.expired_at IS NOT NULL
)
INSERT INTO dbo.Notification (user_id, order_id, channel, event_type, content, status, sent_at)
SELECT t.customer_id, t.order_id, 'MOCK', t.event_type, t.content, 'SENT', t.sent_at
FROM   tin t
WHERE  t.sent_at IS NOT NULL;
GO


/* -- Nhật ký thao tác cho dữ liệu mẫu ------------------------------------------------------
   NFR-08 liệt kê các sự kiện bắt buộc phải có vết. Viết tay từng dòng ở mỗi đơn thì luôn sót:
   ở bản trước, 11 đơn đi hết vòng đời chỉ để lại 12 dòng — năm đơn đã giao khách mà chỉ hai
   dòng HANDOFF, và không dòng nào cho việc bàn giao bếp→quầy.

   Nên phần này SUY RA từ chính các mốc thời gian đã ghi trong đơn. Cách viết đó có hai cái
   được: không sót đơn nào, và nhật ký không bao giờ mâu thuẫn với dữ liệu nó mô tả.

   Chỉ chèn cho sự kiện CHƯA có dòng, để những dòng viết tay ở trên (mang thông tin riêng như
   lý do huỷ) được giữ nguyên. */

DECLARE @cash1 INT = (SELECT user_id FROM dbo.Users WHERE email = 'cashier1@fastfood.vn');

;WITH moi AS (
    /* Thanh toán thành công */
    SELECT NULL AS actor, 'PAYMENT' AS et, p.payment_id AS eid, 'PAYMENT_PAID' AS act,
           NULL AS ov, 'PAID' AS nv, p.paid_at AS t
    FROM dbo.Payment p WHERE p.paid_at IS NOT NULL
    UNION ALL
    /* Hoàn tiền */
    SELECT @cash1, 'PAYMENT', p.payment_id, 'PAYMENT_REFUNDED', 'PAID', 'REFUNDED', p.refunded_at
    FROM dbo.Payment p WHERE p.refunded_at IS NOT NULL
    UNION ALL
    /* Hệ thống tự xác nhận đơn đặt trước sau khi tiền vào (BR-07) — actor để trống */
    SELECT NULL, 'ORDER', o.order_id, 'AUTO_CONFIRM', 'PENDING_PAYMENT', 'CONFIRMED', o.created_at
    FROM dbo.Orders o
    WHERE o.order_source = 'ONLINE_PREORDER'
      AND o.order_status NOT IN ('PENDING_PAYMENT','EXPIRED')
    UNION ALL
    /* Thu ngân xác nhận đơn tại quầy (BR-10) */
    SELECT o.created_by_user_id, 'ORDER', o.order_id, 'POS_CONFIRM', NULL, 'CONFIRMED', o.created_at
    FROM dbo.Orders o WHERE o.order_source = 'POS'
    UNION ALL
    /* Bộ hẹn giờ đưa đơn xuống bếp — actor để trống là dấu hiệu việc do hệ thống làm */
    SELECT NULL, 'ORDER', o.order_id, 'KDS_RELEASE', NULL, 'RELEASED', o.released_to_kds_at
    FROM dbo.Orders o WHERE o.released_to_kds_at IS NOT NULL
    UNION ALL
    /* Bếp nhận việc và báo xong từng món */
    SELECT oi.assigned_to_user_id, 'ORDER_ITEM', oi.order_item_id, 'ITEM_START', 'WAITING', 'PREPARING', oi.started_at
    FROM dbo.OrderItem oi WHERE oi.started_at IS NOT NULL
    UNION ALL
    SELECT oi.assigned_to_user_id, 'ORDER_ITEM', oi.order_item_id, 'ITEM_READY', 'PREPARING', 'READY', oi.ready_at
    FROM dbo.OrderItem oi WHERE oi.ready_at IS NOT NULL
    UNION ALL
    /* Hai lần bàn giao của hai người khác nhau (BR-25) */
    SELECT oi.handed_over_by, 'ORDER_ITEM', oi.order_item_id, 'ITEM_HANDED_OVER', 'READY', 'AT_COUNTER', oi.handed_over_at
    FROM dbo.OrderItem oi WHERE oi.handed_over_at IS NOT NULL
    UNION ALL
    SELECT oi.received_by, 'ORDER_ITEM', oi.order_item_id, 'ITEM_RECEIVED', 'AT_COUNTER', 'RECEIVED', oi.received_at
    FROM dbo.OrderItem oi WHERE oi.received_at IS NOT NULL
    UNION ALL
    /* Cả đơn sẵn sàng — do backend tổng hợp từ các món (BR-11) */
    SELECT NULL, 'ORDER', o.order_id, 'ORDER_READY', 'PREPARING', 'READY', o.ready_at
    FROM dbo.Orders o WHERE o.ready_at IS NOT NULL
    UNION ALL
    /* Đối chiếu mã và giao món cho khách */
    SELECT o.handoff_by_user_id, 'ORDER', o.order_id, 'PICKUP_VERIFY_OK', NULL, o.pickup_code, o.picked_up_at
    FROM dbo.Orders o WHERE o.picked_up_at IS NOT NULL AND o.pickup_code IS NOT NULL
    UNION ALL
    SELECT o.handoff_by_user_id, 'ORDER', o.order_id, 'HANDOFF', 'READY', 'COMPLETED', o.picked_up_at
    FROM dbo.Orders o WHERE o.picked_up_at IS NOT NULL
    UNION ALL
    /* Kết thúc bất thường */
    SELECT NULL, 'ORDER', o.order_id, 'ORDER_EXPIRED', 'PENDING_PAYMENT', 'EXPIRED', o.expired_at
    FROM dbo.Orders o WHERE o.expired_at IS NOT NULL
    UNION ALL
    SELECT NULL, 'ORDER', o.order_id, 'ORDER_CANCELLED', NULL, 'CANCELLED', o.cancelled_at
    FROM dbo.Orders o WHERE o.cancelled_at IS NOT NULL
    UNION ALL
    /* Sự cố bếp */
    SELECT ki.created_by, 'ORDER_ITEM', ki.order_item_id, 'ISSUE_OPENED', NULL, ki.issue_type, ki.created_at
    FROM dbo.KitchenIssue ki
    UNION ALL
    SELECT ki.created_by, 'ORDER_ITEM', ki.order_item_id, 'ISSUE_RESOLVED', 'OPEN', 'RESOLVED', ki.resolved_at
    FROM dbo.KitchenIssue ki WHERE ki.resolved_at IS NOT NULL
)
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, old_value, new_value, created_at)
SELECT m.actor, m.et, CAST(m.eid AS VARCHAR(50)), m.act, m.ov, m.nv, m.t
FROM   moi m
WHERE  m.t IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM dbo.AuditLog a
                   WHERE a.entity_type = m.et
                     AND a.entity_id   = CAST(m.eid AS VARCHAR(50))
                     AND a.action      = m.act);
GO


/* =============================================================================================
   8. KIỂM TRA SAU KHI CHẠY
   Chạy xong file, đối chiếu các bảng kết quả bên dưới. Nếu khớp là database đã sẵn sàng.
   ============================================================================================= */

/* 8.1 · Số lượng bản ghi từng bảng — kỳ vọng cả 13 bảng đều khác 0.
        Bảng nào bằng 0 nghĩa là có một màn hình chưa có dữ liệu để thử. */
SELECT 'Role' AS bang, COUNT(*) AS so_dong FROM dbo.Role
UNION ALL SELECT 'Users',              COUNT(*) FROM dbo.Users
UNION ALL SELECT 'Category',           COUNT(*) FROM dbo.Category
UNION ALL SELECT 'Product',            COUNT(*) FROM dbo.Product
UNION ALL SELECT 'Cart',               COUNT(*) FROM dbo.Cart
UNION ALL SELECT 'CartItem',           COUNT(*) FROM dbo.CartItem
UNION ALL SELECT 'Orders',             COUNT(*) FROM dbo.Orders
UNION ALL SELECT 'OrderItem',          COUNT(*) FROM dbo.OrderItem
UNION ALL SELECT 'Payment',            COUNT(*) FROM dbo.Payment
UNION ALL SELECT 'PaymentTransaction', COUNT(*) FROM dbo.PaymentTransaction
UNION ALL SELECT 'Notification',       COUNT(*) FROM dbo.Notification
UNION ALL SELECT 'KitchenIssue',       COUNT(*) FROM dbo.KitchenIssue
UNION ALL SELECT 'AuditLog',           COUNT(*) FROM dbo.AuditLog;

/* 8.2 · Menu hiển thị cho khách — đây chính là truy vấn mà màn hình menu phải dùng.
        Kỳ vọng 10 món: ba món còn lại bị loại vì tạm hết hàng, đã ngừng bán,
        hoặc thuộc danh mục đã tắt. */
SELECT  c.name AS danh_muc, p.name AS mon, p.price AS gia
FROM    dbo.Product  p
JOIN    dbo.Category c ON c.category_id = p.category_id
WHERE   p.status = 'ACTIVE' AND p.is_available = 1 AND c.status = 'ACTIVE'
ORDER BY c.display_order, p.name;

/* 8.3 · Toàn bộ đơn kèm trạng thái đưa xuống bếp — kỳ vọng đủ 11 đơn, 7 trạng thái */
SELECT  o.order_id, o.order_source, o.order_status, rs.release_state, rs.is_overdue,
        o.total_amount, o.pickup_time, o.kitchen_release_at, o.released_to_kds_at, o.pickup_code
FROM    dbo.Orders o
JOIN    dbo.vw_OrderReleaseState rs ON rs.order_id = o.order_id
ORDER BY o.order_id;

/* 8.4 · Tỷ lệ món sẵn sàng đúng hẹn — kỳ vọng 4 đơn, đúng hẹn 3, tỷ lệ 75% */
SELECT  COUNT(*)        AS so_don_da_xong_mon,
        SUM(is_on_time) AS dung_hen,
        CAST(100.0 * SUM(is_on_time) / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS ty_le_dung_hen,
        CAST(AVG(CAST(prep_lead_minutes AS FLOAT)) AS DECIMAL(6,2))        AS thoi_gian_lam_trung_binh
FROM    dbo.vw_OnTimeReady;

/* 8.5 · Đối soát tổng tiền: tổng của đơn phải bằng tổng các dòng món.
        Kỳ vọng KHÔNG có dòng nào trả về. */
SELECT  o.order_id, o.total_amount AS tong_luu, SUM(oi.unit_price * oi.quantity) AS tong_tinh_lai
FROM    dbo.Orders o
JOIN    dbo.OrderItem oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.total_amount
HAVING  o.total_amount <> SUM(oi.unit_price * oi.quantity);

/* 8.6 · Đường đi của món từ bếp ra quầy (BR-25). Dữ liệu mẫu cố ý dựng đủ BỐN mức, mỗi mức
        mở khoá một nút ở một màn hình khác nhau:
          "1 chua nau xong"        → bếp bấm nhận việc / báo xong ở /kitchen/queue
          "2 xong, con trong bep"  → bếp bấm BÀN GIAO ra quầy ở /kitchen/queue
          "3 dang cho o quay"      → thu ngân bấm NHẬN món ở /staff/counter
          "4 quay da nhan"         → giao cho khách ở /staff/order/detail
        Kỳ vọng cả bốn mức đều KHÁC 0. Mức nào bằng 0 thì màn hình tương ứng mở ra trống trơn.

        Tách mức 1 khỏi mức 2 là có lý do: gộp chung thì con số luôn khác 0 nhờ các món còn
        đang chờ nấu, và việc thiếu hẳn món "đã xong mà chưa ai mang ra" bị che mất — đúng
        cái lỗ mà bản kiểm tra đầu tiên đã để lọt. */
SELECT  CASE WHEN oi.received_at     IS NOT NULL   THEN N'4 quay da nhan'
             WHEN oi.handed_over_at  IS NOT NULL   THEN N'3 dang cho o quay'
             WHEN oi.item_status      = 'READY'    THEN N'2 xong, con trong bep'
             ELSE                                       N'1 chua nau xong' END AS vi_tri_mon,
        COUNT(*) AS so_mon
FROM    dbo.OrderItem oi
GROUP BY CASE WHEN oi.received_at     IS NOT NULL   THEN N'4 quay da nhan'
              WHEN oi.handed_over_at  IS NOT NULL   THEN N'3 dang cho o quay'
              WHEN oi.item_status      = 'READY'    THEN N'2 xong, con trong bep'
              ELSE                                       N'1 chua nau xong' END
ORDER BY vi_tri_mon;

/* 8.7 · Không món nào được nhận mà chưa qua bàn giao. CK_OrderItem_handover đã chặn ở tầng
        dữ liệu, câu này chỉ để nhìn thấy điều đó bằng mắt.
        Kỳ vọng KHÔNG có dòng nào trả về. */
SELECT  oi.order_item_id, oi.order_id, oi.handed_over_at, oi.received_at
FROM    dbo.OrderItem oi
WHERE   oi.received_at IS NOT NULL AND oi.handed_over_at IS NULL;

/* 8.8 · Tin đã gửi cho khách, đếm theo loại sự kiện.
        Kỳ vọng đủ CẢ BỐN loại. Thiếu ORDER_CANCELLED hoặc ORDER_EXPIRED là dấu hiệu dữ liệu
        mẫu chỉ dựng đường đi thuận lợi — hai nhánh khách mất đơn hoặc mất tiền không có gì
        để xem. Tin chỉ sinh cho đơn đặt trước; đơn tại quầy không có tin nào là đúng. */
SELECT  n.event_type AS loai_tin, COUNT(*) AS so_tin, MAX(n.sent_at) AS gui_gan_nhat
FROM    dbo.Notification n
GROUP BY n.event_type
ORDER BY loai_tin;

/* 8.9 · Hai giỏ hàng mẫu — cột dat_hang_duoc phải có cả 1 và 0.
        Giỏ bị chặn (customer2) là giỏ có món vừa hết hàng: nó dựng sẵn dải cảnh báo và nút
        "bỏ món hết hàng ra" ở /cart, thứ không tự xuất hiện nếu mọi món đều còn bán. */
SELECT  u.email,
        COUNT(ci.cart_item_id) AS so_dong,
        SUM(ci.quantity)       AS tong_so_luong,
        SUM(ci.quantity * p.price) AS tam_tinh,
        CASE WHEN SUM(CASE WHEN p.is_available = 1 AND p.status = 'ACTIVE' AND c.status = 'ACTIVE'
                           THEN 0 ELSE 1 END) = 0
             THEN 1 ELSE 0 END AS dat_hang_duoc
FROM    dbo.Cart     ca
JOIN    dbo.Users    u  ON u.user_id     = ca.user_id
JOIN    dbo.CartItem ci ON ci.cart_id    = ca.cart_id
JOIN    dbo.Product  p  ON p.product_id  = ci.product_id
JOIN    dbo.Category c  ON c.category_id = p.category_id
GROUP BY u.email
ORDER BY u.email;

/* 8.10 · Giờ của SQL Server — phải khớp giờ máy chạy Tomcat, lệch dưới 5 giây.
         Lệch giờ sẽ khiến đơn được đưa xuống bếp sai thời điểm. */
SELECT SYSDATETIME() AS gio_sql_server, DB_NAME() AS database_hien_tai;
GO
