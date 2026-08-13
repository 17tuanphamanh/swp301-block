package com.fastfood.integration.payment;

import java.math.BigDecimal;

/**
 * Cổng thanh toán trực tuyến.
 * <p>
 * Tách thành giao diện vì đây là chỗ thật sự cần thay thế được: bản chạy thử dùng
 * {@link MockPaymentGateway}, khi tích hợp cổng thật chỉ cần viết lớp mới mà không
 * đụng tới tầng Service.
 */
public interface PaymentGateway {

    /** Tên cổng, ghi vào nhật ký đối soát. */
    String getName();

    /**
     * Khởi tạo một lần thanh toán.
     * @return địa chỉ để chuyển hướng khách sang trang thanh toán
     */
    PaymentInitResult initiate(int paymentId, int orderId, BigDecimal amount, String returnUrl);

    /**
     * Kiểm tra chữ ký của dữ liệu cổng thanh toán gửi về.
     * Trả về false thì tuyệt đối không được ghi nhận tiền.
     */
    boolean verifySignature(GatewayCallback callback);
}
