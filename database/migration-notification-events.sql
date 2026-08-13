/* =============================================================================================
   MIGRATION — nới CK_Notification_event cho hai sự kiện mới

   Dành cho database ĐÃ CÓ DỮ LIỆU, không muốn chạy lại FastFoodPreorder.sql (file đó xoá và
   tạo lại toàn bộ bảng). Cài mới thì không cần tệp này — ràng buộc mới đã nằm sẵn trong đó.

   Vì sao cần: khách chỉ được báo tin khi đơn được xác nhận và khi món sẵn sàng. Đơn hết hiệu
   lực do quá hạn thanh toán, đơn bị huỷ, và khoản tiền về sau khi đơn đã chết rồi được hoàn
   lại — cả ba đều diễn ra im lặng. Trường hợp thứ ba nguy nhất: khách vừa mất tiền vừa mất
   đơn, và nếu đã đóng trang thanh toán thì chỉ phát hiện qua sao kê ngân hàng.

   CHẠY: sqlcmd -S localhost -U sa -P '<mật khẩu>' -C -i database/migration-notification-events.sql
   Chạy lại nhiều lần không sao.
   ============================================================================================= */

USE FastFoodPreorder;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Notification_event')
    ALTER TABLE dbo.Notification DROP CONSTRAINT CK_Notification_event;
GO

ALTER TABLE dbo.Notification WITH CHECK
    ADD CONSTRAINT CK_Notification_event CHECK (event_type IN
        ('ORDER_CONFIRMED','ORDER_READY','ORDER_CANCELLED','ORDER_EXPIRED'));
GO

PRINT 'CK_Notification_event: da nhan them ORDER_CANCELLED va ORDER_EXPIRED.';
GO
