package com.fastfood.controller.staff;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Màn hình điều phối của thu ngân, chia bốn tab:
 * đơn tại quầy đang xử lý, đơn đặt trước đang chờ tới giờ, đơn chờ khách tới lấy,
 * và đơn khách đã quá hẹn.
 */
@WebServlet("/staff/orders")
public class OrderDashboardServlet extends BaseServlet {

    private final OrderService orderService = new OrderService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String tab = WebUtil.getString(req, "tab");
        if (tab == null || tab.isBlank()) {
            tab = "POS";
        }
        req.setAttribute("tab", tab);
        req.setAttribute("orders", orderService.dashboard(tab));

        // Số lượng trên nhãn từng tab để nhân viên thấy ngay chỗ nào cần xử lý
        req.setAttribute("countPos", orderService.dashboard("POS").size());
        req.setAttribute("countScheduled", orderService.dashboard("SCHEDULED").size());
        req.setAttribute("countReady", orderService.dashboard("READY").size());
        req.setAttribute("countOverdue", orderService.dashboard("OVERDUE").size());
        forward(req, resp, "staff/order-dashboard.jsp");
    }
}
