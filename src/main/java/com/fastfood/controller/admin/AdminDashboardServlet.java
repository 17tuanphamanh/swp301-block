package com.fastfood.controller.admin;

import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.service.ReportService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Bảng điều khiển của quản trị viên.
 * <p>
 * Mặc định xem số liệu 30 ngày gần nhất. Ngoài doanh thu và số đơn, màn hình này có hai
 * chỉ số riêng của mô hình đặt trước: tỷ lệ món sẵn sàng đúng hẹn, và số đơn khách đến muộn.
 */
@WebServlet("/admin/dashboard")
public class AdminDashboardServlet extends BaseServlet {

    private final ReportService reportService = new ReportService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        LocalDateTime from = WebUtil.getDateTime(req, "from");
        LocalDateTime to = WebUtil.getDateTime(req, "to");
        if (from == null) {
            from = DateTimeUtil.now().minusDays(30).toLocalDate().atStartOfDay();
        }
        if (to == null) {
            to = DateTimeUtil.now();
        }

        req.setAttribute("kpi", reportService.loadKpi(from, to));
        req.setAttribute("bestSellers", reportService.bestSellers(from, to, 10));
        req.setAttribute("paymentSummary", reportService.paymentSummary(from, to));
        req.setAttribute("revenueByDay", reportService.revenueByDay(from, to));
        req.setAttribute("from", DateTimeUtil.toHtmlInput(from));
        req.setAttribute("to", DateTimeUtil.toHtmlInput(to));
        forward(req, resp, "admin/dashboard.jsp");
    }
}
