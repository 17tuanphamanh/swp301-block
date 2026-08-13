package com.fastfood.controller.customer;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Lịch sử đơn của khách. Chỉ thấy đơn của chính mình — điều kiện lọc nằm ở tầng dịch vụ. */
@WebServlet("/order/history")
public class OrderHistoryServlet extends BaseServlet {

    private final OrderService orderService = new OrderService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        req.setAttribute("pageData",
                orderService.historyOfCustomer(user.getUserId(), WebUtil.getInt(req, "page", 1)));
        req.setAttribute("filterQuery", WebUtil.queryStringWithout(req, "page"));
        // Khung "đang theo dõi" ở trên cùng luôn hiện đủ, không phân trang: đơn đang chạy
        // của một khách chỉ có vài cái, và đó chính là thứ họ mở trang này để xem.
        req.setAttribute("activeOrders", orderService.activeOrdersOfCustomer(user.getUserId()));
        forward(req, resp, "customer/order-history.jsp");
    }
}
