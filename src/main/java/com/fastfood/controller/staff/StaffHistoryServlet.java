package com.fastfood.controller.staff;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.service.AuditService;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Tra cứu đơn cũ và nhật ký thao tác tại quầy. */
@WebServlet("/staff/history")
public class StaffHistoryServlet extends BaseServlet {

    private final OrderService orderService = new OrderService();
    private final AuditService auditService = new AuditService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String source = WebUtil.getString(req, "source");
        String status = WebUtil.getString(req, "status");

        req.setAttribute("orders", orderService.search(source, status,
                WebUtil.getDateTime(req, "from"), WebUtil.getDateTime(req, "to")));
        req.setAttribute("auditLogs", auditService.search("ORDER", null, null, null, 50));
        req.setAttribute("source", source);
        req.setAttribute("status", status);
        forward(req, resp, "staff/history.jsp");
    }
}
