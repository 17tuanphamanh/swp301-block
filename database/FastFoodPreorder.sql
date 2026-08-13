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
   ---------------------------------------------------------------------------------------------

   NỘI DUNG
     1. Tạo database
     2. Xoá đối tượng cũ
     3. 13 bảng          (nhóm: danh mục · giỏ hàng · đơn hàng · thanh toán · vận hành)
     4. 14 index
     5. 2 view           (suy ra trạng thái release & KPI đúng hẹn)
     6. 6 trigger        (BR-04 + chặn hard-delete BR-20)
     7. Dữ liệu mẫu     (7 user · 13 món · 11 đơn phủ đủ 7 trạng thái)
     8. Kiểm tra sau khi chạy

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
    CONSTRAINT PK_OrderItem          PRIMARY KEY (order_item_id),
    CONSTRAINT FK_OrderItem_Orders   FOREIGN KEY (order_id)            REFERENCES dbo.Orders(order_id),
    CONSTRAINT FK_OrderItem_Product  FOREIGN KEY (product_id)          REFERENCES dbo.Product(product_id),
    CONSTRAINT FK_OrderItem_Assignee FOREIGN KEY (assigned_to_user_id) REFERENCES dbo.Users(user_id),
    CONSTRAINT CK_OrderItem_qty      CHECK (quantity > 0),
    CONSTRAINT CK_OrderItem_price    CHECK (unit_price >= 0),
    CONSTRAINT CK_OrderItem_status   CHECK (item_status IN ('WAITING','PREPARING','READY'))
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
    event_type      VARCHAR(30)       NOT NULL,   -- ORDER_CONFIRMED | ORDER_READY
    content         NVARCHAR(MAX)     NULL,       -- tin báo sẵn sàng phải kèm giờ hẹn và mã nhận hàng
    status          VARCHAR(20)       NOT NULL CONSTRAINT DF_Notification_status  DEFAULT ('PENDING'),
    sent_at         DATETIME2(0)      NULL,
    CONSTRAINT PK_Notification         PRIMARY KEY (notification_id),
    CONSTRAINT FK_Notification_Users   FOREIGN KEY (user_id)  REFERENCES dbo.Users(user_id),
    CONSTRAINT FK_Notification_Orders  FOREIGN KEY (order_id) REFERENCES dbo.Orders(order_id),
    CONSTRAINT CK_Notification_event   CHECK (event_type IN ('ORDER_CONFIRMED','ORDER_READY')),
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
    CONSTRAINT CK_Issue_status    CHECK (status     IN ('OPEN','RESOLVED')),
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
GO

-- kiểm tra đã thanh toán chưa trước khi giao món
CREATE INDEX IX_Payment_order ON dbo.Payment(order_id, payment_status);

-- báo cáo doanh thu: quét theo khoảng ngày
CREATE INDEX IX_Payment_paidAt ON dbo.Payment(paid_at) INCLUDE (amount, method, payment_status);

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
    (N'Burger',       N'Burger Bò Phô Mai',   N'Bò nướng, phô mai cheddar, rau tươi',   55000., '/assets/images/burger-bo.jpg',  1, 'ACTIVE'),
    (N'Burger',       N'Burger Gà Giòn',      N'Gà chiên giòn, sốt mayonnaise',         49000., '/assets/images/burger-ga.jpg',  1, 'ACTIVE'),
    (N'Gà rán',       N'Gà Rán 1 Miếng',      N'Gà rán truyền thống',                   35000., '/assets/images/ga-ran-1.jpg',   1, 'ACTIVE'),
    (N'Gà rán',       N'Gà Rán 3 Miếng',      N'Phần ba miếng gà rán',                  95000., '/assets/images/ga-ran-3.jpg',   1, 'ACTIVE'),
    (N'Khoai tây',    N'Khoai Tây Chiên (M)', N'Khoai tây chiên cỡ vừa',                25000., '/assets/images/khoai-m.jpg',    1, 'ACTIVE'),
    (N'Khoai tây',    N'Khoai Tây Chiên (L)', N'Khoai tây chiên cỡ lớn',                35000., '/assets/images/khoai-l.jpg',    1, 'ACTIVE'),
    (N'Đồ uống',      N'Pepsi (M)',           N'Nước ngọt có ga',                       15000., '/assets/images/pepsi.jpg',      1, 'ACTIVE'),
    (N'Đồ uống',      N'Trà Đào Cam Sả',      N'Trà đào cam sả',                        29000., '/assets/images/tra-dao.jpg',    1, 'ACTIVE'),
    (N'Combo',        N'Combo Burger Solo',   N'Burger bò, khoai tây cỡ vừa và Pepsi',  85000., '/assets/images/combo-solo.jpg', 1, 'ACTIVE'),
    (N'Combo',        N'Combo Gia Đình',      N'Ba gà rán, hai khoai lớn và bốn nước', 259000., '/assets/images/combo-gd.jpg',   1, 'ACTIVE'),
    (N'Gà rán',       N'Gà Rán Cay Hàn Quốc', N'Sốt cay kiểu Hàn — tạm hết hàng',       45000., '/assets/images/ga-cay.jpg',     0, 'ACTIVE'),
    (N'Đồ uống',      N'Nước Cam Ép',         N'Đã ngừng kinh doanh',                   30000., '/assets/images/cam-ep.jpg',     1, 'INACTIVE'),
    (N'Món theo mùa', N'Bánh Trung Thu',      N'Món theo mùa, ngoài menu thường',       60000., '/assets/images/trung-thu.jpg',  1, 'ACTIVE')
   ) AS v(category_name, name, description, price, image_url, is_available, status)
JOIN dbo.Category c ON c.name = v.category_name;
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
DECLARE @day VARCHAR(6)   = FORMAT(@now, 'yyMMdd');

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
INSERT INTO dbo.Notification (user_id, order_id, channel, event_type, content, status, sent_at)
VALUES (@cus1, @o, 'MOCK', 'ORDER_CONFIRMED', N'Đơn đã được xác nhận. Mã nhận hàng: ' + @day + 'A1C7', 'SENT', DATEADD(MINUTE,-9,@now));
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, new_value, created_at) VALUES
 (NULL, 'PAYMENT', CAST(@pay AS VARCHAR(50)), 'PAYMENT_PAID', 'PAID',      DATEADD(MINUTE,-9,@now)),
 (NULL, 'ORDER',   CAST(@o   AS VARCHAR(50)), 'AUTO_CONFIRM', 'CONFIRMED', DATEADD(MINUTE,-9,@now));

/* -- D4 · Online · bếp đang làm dở · 130.000 ----------------------------------------------- */
INSERT INTO dbo.Orders (customer_id, order_source, total_amount, order_status, idempotency_key,
                        pickup_time, kitchen_release_at, released_to_kds_at, pickup_code, created_at)
VALUES (@cus2, 'ONLINE_PREORDER', 130000, 'PREPARING', 'demo-0004',
        DATEADD(MINUTE,15,@now), DATEADD(MINUTE,-5,@now), DATEADD(MINUTE,-5,@now), @day+'B2D8', DATEADD(MINUTE,-30,@now));
SET @o = SCOPE_IDENTITY();
INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, quantity, item_status, assigned_to_user_id, started_at) VALUES
 (@o, @pGa3,    N'Gà Rán 3 Miếng',      95000, 1, 'PREPARING', @kit1, DATEADD(MINUTE,-4,@now)),
 (@o, @pKhoaiL, N'Khoai Tây Chiên (L)', 35000, 1, 'WAITING',   NULL,  NULL);
INSERT INTO dbo.Payment (order_id, method, amount, payment_status, created_at, paid_at)
VALUES (@o, 'ONLINE_GATEWAY', 130000, 'PAID', DATEADD(MINUTE,-30,@now), DATEADD(MINUTE,-29,@now));
SET @pay = SCOPE_IDENTITY();
INSERT INTO dbo.PaymentTransaction (payment_id, gateway, external_transaction_id, status, created_at)
VALUES (@pay, 'MOCK', 'MOCK-TXN-0004', 'SUCCESS', DATEADD(MINUTE,-29,@now));
INSERT INTO dbo.AuditLog (actor_id, entity_type, entity_id, action, new_value, created_at) VALUES
 (NULL,  'ORDER',      CAST(@o AS VARCHAR(50)), 'KDS_RELEASE', 'RELEASED',  DATEADD(MINUTE,-5,@now)),
 (@kit1, 'ORDER_ITEM', CAST(@o AS VARCHAR(50)), 'ITEM_START',  'PREPARING', DATEADD(MINUTE,-4,@now));

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
INSERT INTO dbo.Notification (user_id, order_id, channel, event_type, content, status, sent_at)
VALUES (@cus1, @o, 'MOCK', 'ORDER_READY', N'Đơn của bạn đã sẵn sàng. Mã nhận hàng: ' + @day + 'C3E9', 'SENT', DATEADD(MINUTE,-2,@now));

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
GO


/* =============================================================================================
   8. KIỂM TRA SAU KHI CHẠY
   Chạy xong file, đối chiếu các bảng kết quả bên dưới. Nếu khớp là database đã sẵn sàng.
   ============================================================================================= */

/* 8.1 · Số lượng bản ghi từng bảng */
SELECT 'Role' AS bang, COUNT(*) AS so_dong FROM dbo.Role
UNION ALL SELECT 'Users',              COUNT(*) FROM dbo.Users
UNION ALL SELECT 'Category',           COUNT(*) FROM dbo.Category
UNION ALL SELECT 'Product',            COUNT(*) FROM dbo.Product
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

/* 8.6 · Giờ của SQL Server — phải khớp giờ máy chạy Tomcat, lệch dưới 5 giây.
        Lệch giờ sẽ khiến đơn được đưa xuống bếp sai thời điểm. */
SELECT SYSDATETIME() AS gio_sql_server, DB_NAME() AS database_hien_tai;
GO
