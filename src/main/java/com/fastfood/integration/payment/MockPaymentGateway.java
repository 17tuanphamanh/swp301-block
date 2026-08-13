package com.fastfood.integration.payment;

import com.fastfood.config.AppConfig;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.UUID;

/**
 * Cổng thanh toán giả lập dùng khi phát triển và trình bày.
 * <p>
 * Thay vì gọi ra ngoài mạng, nó chuyển khách sang một trang trong chính ứng dụng để
 * bấm chọn thành công hoặc thất bại. Nhờ vậy vẫn diễn được đủ các tình huống thật:
 * thanh toán hỏng rồi thử lại, đơn hết hạn, và cổng gửi kết quả về nhiều lần.
 * <p>
 * Chữ ký vẫn được ký và kiểm tra thật để tầng Service không phải sửa gì khi thay bằng cổng thật.
 */
public class MockPaymentGateway implements PaymentGateway {

    private static final String SECRET = AppConfig.get("payment.gateway.secretKey", "SANDBOX_SECRET");

    @Override
    public String getName() {
        return "MOCK";
    }

    @Override
    public PaymentInitResult initiate(int paymentId, int orderId, BigDecimal amount, String returnUrl) {
        String externalId = "MOCK-" + UUID.randomUUID().toString().substring(0, 18).toUpperCase();
        String signature = sign(paymentId, externalId, true);
        String url = returnUrl
                + "?paymentId=" + paymentId
                + "&txnId=" + externalId
                + "&amount=" + amount.toPlainString()
                + "&sig=" + signature;
        return new PaymentInitResult(url, externalId);
    }

    @Override
    public boolean verifySignature(GatewayCallback callback) {
        String expected = sign(callback.getPaymentId(), callback.getExternalTransactionId(), callback.isSuccess());
        return expected.equals(callback.getSignature());
    }

    /** Chữ ký cho trường hợp khách chọn thanh toán thất bại. */
    public String signFailure(int paymentId, String externalId) {
        return sign(paymentId, externalId, false);
    }

    private String sign(int paymentId, String externalId, boolean success) {
        try {
            String raw = paymentId + "|" + externalId + "|" + success + "|" + SECRET;
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.substring(0, 32);
        } catch (Exception e) {
            throw new IllegalStateException("Khong tao duoc chu ky", e);
        }
    }
}
