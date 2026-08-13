package com.fastfood.controller.customer;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.PaymentService;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Bắt đầu thanh toán: tạo bản ghi giao dịch rồi chuyển khách sang cổng thanh toán.
 * <p>
 * Bản chạy thử chuyển sang trang giả lập ngay trong ứng dụng. Khi tích hợp cổng thật,
 * chỉ địa chỉ chuyển hướng thay đổi, phần còn lại giữ nguyên.
 */
@WebServlet("/payment/start")
public class PaymentStartServlet extends BaseServlet {

    private final PaymentService paymentService = new PaymentService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        int orderId = WebUtil.getInt(req, "orderId", 0);
        try {
            String returnUrl = WebUtil.baseUrl(req) + "/payment/gateway";
            String redirectUrl = paymentService.startOnlinePayment(orderId, user.getUserId(), returnUrl);
            resp.sendRedirect(redirectUrl + "&orderId=" + orderId);
        } catch (AppException e) {
            WebUtil.flashError(req, e.getMessage());
            redirect(req, resp, "/order/track?orderId=" + orderId);
        }
    }
}
