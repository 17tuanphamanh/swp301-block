package com.fastfood.flow;

import com.fastfood.common.constant.PaymentMethod;
import com.fastfood.common.exception.BusinessException;
import com.fastfood.common.exception.ValidationException;
import com.fastfood.model.dto.PosLine;
import com.fastfood.model.entity.Order;
import com.fastfood.service.OrderService;
import com.fastfood.testsupport.IntegrationTestBase;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Bán hàng tại quầy — trọng tâm là <b>sự thật về tiền</b> (BR-22).
 * <p>
 * Tiền của lần quẹt thẻ chạy qua máy thanh toán đặt ở quầy chứ không qua hệ thống, nên dòng
 * "đã thu" trong cơ sở dữ liệu chỉ là lời khai của thu ngân. Buộc nhập mã giao dịch trên biên
 * lai là cách biến lời khai đó thành thứ đối soát được với sao kê — và ràng buộc duy nhất trên
 * mã chặn luôn tình huống một lần quẹt thẻ bị lập thành hai đơn.
 */
@DisplayName("Đơn tại quầy và sự thật về tiền")
class PosOrderIT extends IntegrationTestBase {

    private final OrderService orderService = new OrderService();

    private List<PosLine> oneItem() {
        return List.of(new PosLine(anyOrderableProductId(), 2));
    }

    // ------------------------------------------------------------------ tiền mặt

    @Test
    @DisplayName("Thu tiền mặt: lập đơn, thu tiền và đưa xuống bếp trong một nhịp")
    void cashOrderIsConfirmedAndReleasedImmediately() {
        Order order = orderService.createPosOrder(userId(CASHIER_1), oneItem(), PaymentMethod.CASH, null);

        assertEquals("CONFIRMED", order.getOrderStatus());
        assertEquals("POS", order.getOrderSource());
        assertNull(order.getCustomerId(), "Khách vãng lai không cần tài khoản");
        assertNull(order.getPickupTime(), "Đơn tại quầy không có giờ hẹn");
        assertNotNull(order.getReleasedToKdsAt(), "Khách đứng đợi nên bếp phải thấy đơn ngay");

        assertEquals(1, count("SELECT COUNT(*) FROM dbo.Payment WHERE order_id = ? AND payment_status = 'PAID'",
                order.getOrderId()));
        assertEquals(0, count("SELECT COUNT(*) FROM dbo.PaymentTransaction t " +
                        "JOIN dbo.Payment p ON p.payment_id = t.payment_id WHERE p.order_id = ?",
                order.getOrderId()),
                "Tiền mặt không có bên thứ ba nào để đối chiếu, nên không sinh giao dịch đối soát");
    }

    @Test
    @DisplayName("Thu tiền mặt không cần mã biên lai")
    void cashOrderNeedsNoReference() {
        Order order = orderService.createPosOrder(userId(CASHIER_1), oneItem(), PaymentMethod.CASH, "   ");
        assertEquals("CONFIRMED", order.getOrderStatus());
    }

    // ------------------------------------------------------------------ thẻ / mã QR

    @Test
    @DisplayName("Quẹt thẻ mà bỏ trống mã biên lai thì bị từ chối")
    void cardPaymentRequiresReference() {
        ValidationException e = assertThrows(ValidationException.class,
                () -> orderService.createPosOrder(userId(CASHIER_1), oneItem(),
                        PaymentMethod.ONLINE_GATEWAY, null));

        assertTrue(e.getMessage().contains("mã giao dịch"),
                "Thông báo phải nói rõ cần nhập gì, nhưng là: " + e.getMessage());
    }

    @Test
    @DisplayName("Quẹt thẻ có mã biên lai thì ghi lại dấu vết đối soát")
    void cardPaymentRecordsTransactionForReconciliation() {
        String reference = "POS-REF-" + System.nanoTime();

        Order order = orderService.createPosOrder(userId(CASHIER_1), oneItem(),
                PaymentMethod.ONLINE_GATEWAY, reference);

        String gateway = text("SELECT t.gateway FROM dbo.PaymentTransaction t " +
                "JOIN dbo.Payment p ON p.payment_id = t.payment_id WHERE p.order_id = ?", order.getOrderId());
        String externalId = text("SELECT t.external_transaction_id FROM dbo.PaymentTransaction t " +
                "JOIN dbo.Payment p ON p.payment_id = t.payment_id WHERE p.order_id = ?", order.getOrderId());

        assertEquals("POS_TERMINAL", gateway,
                "Phải phân biệt được khoản thu ở quầy với khoản thu qua cổng trực tuyến");
        assertEquals(reference.toUpperCase(), externalId,
                "Mã biên lai được chuẩn hoá về chữ hoa để tra cứu không phụ thuộc cách gõ");
    }

    @Test
    @DisplayName("Một biên lai không lập được thành hai đơn")
    void sameReferenceCannotCreateTwoOrders() {
        String reference = "POS-DUP-" + System.nanoTime();
        orderService.createPosOrder(userId(CASHIER_1), oneItem(), PaymentMethod.ONLINE_GATEWAY, reference);

        int before = count("SELECT COUNT(*) FROM dbo.Orders");

        BusinessException e = assertThrows(BusinessException.class,
                () -> orderService.createPosOrder(userId(CASHIER_1), oneItem(),
                        PaymentMethod.ONLINE_GATEWAY, reference));

        assertTrue(e.getMessage().contains("đã được ghi nhận"),
                "Thông báo phải giải thích được cho thu ngân đang đứng trước khách: " + e.getMessage());
        assertEquals(before, count("SELECT COUNT(*) FROM dbo.Orders"),
                "Lần lập đơn hỏng phải được huỷ sạch, không để lại đơn mồ côi không có tiền");
    }

    @Test
    @DisplayName("Mã biên lai không phân biệt hoa thường khi kiểm tra trùng")
    void referenceComparisonIgnoresCase() {
        String reference = "pos-case-" + System.nanoTime();
        orderService.createPosOrder(userId(CASHIER_1), oneItem(), PaymentMethod.ONLINE_GATEWAY, reference);

        assertThrows(BusinessException.class,
                () -> orderService.createPosOrder(userId(CASHIER_1), oneItem(),
                        PaymentMethod.ONLINE_GATEWAY, reference.toUpperCase()),
                "Gõ lại cùng mã bằng chữ hoa vẫn là cùng một biên lai");
    }

    // ------------------------------------------------------------------ kiểm tra đầu vào

    @Test
    @DisplayName("Phiếu trống thì không lập đơn")
    void emptyCartIsRejected() {
        assertThrows(ValidationException.class,
                () -> orderService.createPosOrder(userId(CASHIER_1), List.of(), PaymentMethod.CASH, null));
    }

    @Test
    @DisplayName("Số lượng vô lý bị chặn ở máy chủ, không tin ô nhập trên trình duyệt")
    void quantityIsValidatedServerSide() {
        List<PosLine> bad = List.of(new PosLine(anyOrderableProductId(), 0));
        assertThrows(ValidationException.class,
                () -> orderService.createPosOrder(userId(CASHIER_1), bad, PaymentMethod.CASH, null));
    }

    @Test
    @DisplayName("Món đã ngừng bán thì không lập đơn được")
    void unavailableProductIsRejected() {
        Integer offMenu = scalar(Integer.class,
                "SELECT TOP 1 product_id FROM dbo.Product WHERE is_available = 0 OR status = 'INACTIVE'");
        org.junit.jupiter.api.Assumptions.assumeTrue(offMenu != null, "Du lieu mau khong co mon ngoai menu");

        assertThrows(BusinessException.class,
                () -> orderService.createPosOrder(userId(CASHIER_1),
                        List.of(new PosLine(offMenu, 1)), PaymentMethod.CASH, null));
    }

    @Test
    @DisplayName("Đơn lưu bản sao tên và giá tại thời điểm bán (BR-02)")
    void orderItemKeepsSnapshotOfNameAndPrice() {
        Order order = orderService.createPosOrder(userId(CASHIER_1), oneItem(), PaymentMethod.CASH, null);

        assertEquals(1, count("SELECT COUNT(*) FROM dbo.OrderItem " +
                        "WHERE order_id = ? AND product_name_snapshot IS NOT NULL AND unit_price > 0",
                order.getOrderId()),
                "Thiếu bản sao thì quản trị viên đổi giá sẽ làm đổi luôn hoá đơn cũ");
    }
}
