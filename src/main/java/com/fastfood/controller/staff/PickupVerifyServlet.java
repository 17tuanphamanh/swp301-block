package com.fastfood.controller.staff;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.Order;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Tra mã nhận hàng khi khách tới quầy.
 * <p>
 * Chỉ tra và hiển thị đơn; việc giao món vẫn phải bấm xác nhận ở màn hình chi tiết,
 * để nhân viên có cơ hội đối chiếu món trước khi đưa cho khách.
 */
@WebServlet("/staff/pickup/verify")
public class PickupVerifyServlet extends BaseServlet {

    private final OrderService orderService = new OrderService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String code = WebUtil.getString(req, "code");
        if (code != null && !code.isBlank()) {
            try {
                Order order = orderService.findByPickupCode(code);
                req.setAttribute("order", order);
                if (!order.isOnline()) {
                    req.setAttribute("warning", "Đơn này là đơn tại quầy, không dùng mã nhận hàng.");
                } else if (!"READY".equals(order.getOrderStatus())) {
                    req.setAttribute("warning", "Đơn chưa sẵn sàng để giao. Trạng thái hiện tại: "
                            + order.getOrderStatus());
                }
            } catch (AppException e) {
                req.setAttribute("errorMessage", e.getMessage());
            }
        }
        req.setAttribute("code", code);
        forward(req, resp, "staff/pickup-verify.jsp");
    }
}
