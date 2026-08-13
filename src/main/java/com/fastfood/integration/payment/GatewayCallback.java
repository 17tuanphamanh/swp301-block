package com.fastfood.integration.payment;

/**
 * Dữ liệu cổng thanh toán gửi về sau khi khách thanh toán xong.
 * <p>
 * {@code externalTransactionId} là mã định danh giao dịch phía cổng. Cùng một giao dịch
 * có thể được gửi về nhiều lần, nên mã này được lưu với ràng buộc duy nhất để lần thứ hai
 * bị từ chối và tiền không bị ghi nhận trùng.
 */
public class GatewayCallback {

    private int paymentId;
    private String externalTransactionId;
    private boolean success;
    private String signature;
    private String rawPayload;

    public int getPaymentId() { return paymentId; }
    public void setPaymentId(int paymentId) { this.paymentId = paymentId; }

    public String getExternalTransactionId() { return externalTransactionId; }
    public void setExternalTransactionId(String externalTransactionId) { this.externalTransactionId = externalTransactionId; }

    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }

    public String getSignature() { return signature; }
    public void setSignature(String signature) { this.signature = signature; }

    public String getRawPayload() { return rawPayload; }
    public void setRawPayload(String rawPayload) { this.rawPayload = rawPayload; }
}
