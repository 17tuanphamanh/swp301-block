package com.fastfood.controller.customer;

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
        req.setAttribute("orders", orderService.historyOfCustomer(user.getUserId()));
        req.setAttribute("activeOrders", orderService.activeOrdersOfCustomer(user.getUserId()));
        forward(req, resp, "customer/order-history.jsp");
    }
}
