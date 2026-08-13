package com.fastfood.controller.customer;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.WebUtil;
import com.fastfood.config.AppConfig;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.dto.CartView;
import com.fastfood.model.entity.Order;
import com.fastfood.model.entity.User;
import com.fastfood.service.CartService;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Đặt trước và chọn giờ đến lấy.
 * <p>
 * Không có ô địa chỉ giao hàng và không có lựa chọn trả tiền tại quầy: đơn đặt trước
 * bắt buộc thanh toán online. Khách muốn trả tiền mặt thì mua trực tiếp tại cửa hàng.
 */
@WebServlet("/checkout")
public class CheckoutServlet extends BaseServlet {

    private final CartService cartService = new CartService();
    private final OrderService orderService = new OrderService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        CartView cart = cartService.getCart(user.getUserId());

        if (cart.isEmpty()) {
            WebUtil.flashError(req, "Giỏ hàng đang trống.");
            redirect(req, resp, "/cart");
            return;
        }
        if (cart.isHasUnavailable()) {
            WebUtil.flashError(req, "Giỏ hàng có món không còn phục vụ. Vui lòng cập nhật lại.");
            redirect(req, resp, "/cart");
            return;
        }

        LocalDateTime earliest = orderService.earliestPickupTime();
        req.setAttribute("cart", cart);
        req.setAttribute("minPickupTime", DateTimeUtil.toHtmlInput(earliest));
        req.setAttribute("suggestedPickupTime", DateTimeUtil.toHtmlInput(earliest.plusMinutes(15)));
        req.setAttribute("minLeadMinutes", AppConfig.pickupMinLeadMinutes());
        req.setAttribute("paymentExpiryMinutes", AppConfig.paymentExpiryMinutes());
        // Khoá chống trùng: khách bấm đúp hoặc tải lại trang cũng chỉ tạo một đơn
        req.setAttribute("idempotencyKey", UUID.randomUUID().toString());
        forward(req, resp, "customer/checkout.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        LocalDateTime pickupTime = WebUtil.getDateTime(req, "pickupTime");
        String idempotencyKey = WebUtil.getString(req, "idempotencyKey");

        try {
            Order order = orderService.createOnlineOrder(user.getUserId(), pickupTime, idempotencyKey);
            redirect(req, resp, "/payment/start?orderId=" + order.getOrderId());
        } catch (AppException e) {
            WebUtil.flashError(req, e.getMessage());
            redirect(req, resp, "/checkout");
        }
    }
}
