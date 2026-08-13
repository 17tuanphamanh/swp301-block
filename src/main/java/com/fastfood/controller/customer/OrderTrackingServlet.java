package com.fastfood.controller.customer;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.QrCodeUtil;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.Order;
import com.fastfood.model.entity.User;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Theo dõi đơn và xem mã nhận hàng.
 * <p>
 * Mã QR được sinh tại chỗ và nhúng thẳng vào trang, không lưu file ảnh — mã chỉ dùng
 * trong vài chục phút nên không đáng để quản lý vòng đời tệp trên đĩa.
 */
@WebServlet("/order/track")
public class OrderTrackingServlet extends BaseServlet {

    private final OrderService orderService = new OrderService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        int orderId = WebUtil.getInt(req, "orderId", 0);

        try {
            Order order = orderService.findForCustomer(orderId, user.getUserId());
            req.setAttribute("order", order);
            if (order.getPickupCode() != null) {
                req.setAttribute("qrDataUri", QrCodeUtil.toDataUri(order.getPickupCode(), 220));
            }
            forward(req, resp, "customer/order-tracking.jsp");
        } catch (AppException e) {
            req.setAttribute("errorMessage", e.getMessage());
            resp.setStatus(HttpServletResponse.SC_NOT_FOUND);
            forward(req, resp, "error/404.jsp");
        }
    }

    /** Khách tự huỷ đơn khi bếp chưa bắt đầu chuẩn bị. */
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        int orderId = WebUtil.getInt(req, "orderId", 0);
        handle(req, resp, () -> orderService.cancelByCustomer(orderId, user.getUserId()),
                "Đã huỷ đơn hàng. Tiền sẽ được hoàn lại nếu bạn đã thanh toán.",
                "/order/track?orderId=" + orderId);
    }
}
