package com.fastfood.controller.customer;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.integration.payment.GatewayCallback;
import com.fastfood.service.PaymentService;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Nhận kết quả từ cổng thanh toán.
 * <p>
 * Địa chỉ này không yêu cầu đăng nhập vì cổng thanh toán gọi vào từ máy chủ của họ,
 * không mang theo phiên của khách. Bù lại, mọi dữ liệu đều phải qua kiểm tra chữ ký,
 * và mã giao dịch được chống trùng ở tầng cơ sở dữ liệu — chi tiết trong
 * {@link PaymentService#handleCallback}.
 */
@WebServlet("/payment/callback")
public class PaymentCallbackServlet extends BaseServlet {

    private final PaymentService paymentService = new PaymentService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        process(req, resp);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        process(req, resp);
    }

    private void process(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        GatewayCallback callback = new GatewayCallback();
        callback.setPaymentId(WebUtil.getInt(req, "paymentId", 0));
        callback.setExternalTransactionId(WebUtil.getString(req, "txnId"));
        callback.setSuccess(WebUtil.getBoolean(req, "success"));
        callback.setSignature(WebUtil.getString(req, "sig"));
        callback.setRawPayload(req.getQueryString());

        int orderId = WebUtil.getInt(req, "orderId", 0);

        try {
            boolean paid = paymentService.handleCallback(callback);
            if (orderId <= 0) {
                orderId = paymentService.orderIdOfPayment(callback.getPaymentId());
            }
            if (paid) {
                WebUtil.flashSuccess(req, "Thanh toán thành công. Đơn hàng đã được xác nhận.");
            } else if (!callback.isSuccess()) {
                WebUtil.flashError(req, "Thanh toán không thành công. Bạn có thể thử lại.");
            }
        } catch (AppException e) {
            WebUtil.flashError(req, e.getMessage());
        }
        redirect(req, resp, "/order/track?orderId=" + orderId);
    }
}
