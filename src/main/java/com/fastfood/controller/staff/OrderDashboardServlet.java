package com.fastfood.controller.staff;

import com.fastfood.common.constant.OrderStatus;
import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.Order;
import com.fastfood.service.KitchenService;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Màn hình điều phối của thu ngân, chia bốn tab: đơn tại quầy đang xử lý, đơn đặt trước
 * (đang chờ tới giờ hoặc đang làm), đơn chờ khách tới lấy, và đơn khách đã quá hẹn.
 * <p>
 * Bốn tab cộng lại phủ kín mọi đơn chưa kết thúc — xem
 * {@link com.fastfood.dao.OrderDAO#findForDashboard}.
 * <p>
 * Màn hình này cũng là chỗ tra mã nhận hàng khi khách tới quầy. Tra xong vẫn phải mở đơn ra
 * mới giao được món, để nhân viên có cơ hội đối chiếu món trước khi đưa cho khách.
 */
@WebServlet("/staff/orders")
public class OrderDashboardServlet extends BaseServlet {

    private static final List<String> TABS = List.of("POS", "SCHEDULED", "READY", "OVERDUE");

    private final OrderService orderService = new OrderService();
    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String tab = WebUtil.getString(req, "tab");
        if (tab == null || tab.isBlank()) {
            tab = "POS";
        }

        // Bốn tab đều cần số lượng để nhân viên thấy ngay chỗ nào cần xử lý; tab đang mở
        // thì dùng lại chính danh sách đó thay vì hỏi cơ sở dữ liệu thêm một lần nữa.
        Map<String, List<Order>> byTab = new LinkedHashMap<>();
        for (String name : TABS) {
            byTab.put(name, orderService.dashboard(name));
        }
        List<Order> current = byTab.getOrDefault(tab, byTab.get("POS"));

        req.setAttribute("tab", tab);
        req.setAttribute("orders", current);
        req.setAttribute("countPos", byTab.get("POS").size());
        req.setAttribute("countScheduled", byTab.get("SCHEDULED").size());
        req.setAttribute("countReady", byTab.get("READY").size());
        req.setAttribute("countOverdue", byTab.get("OVERDUE").size());
        // Sự cố bếp không nằm trong tab nào vì nó cắt ngang cả bốn: đơn nào cũng có thể
        // vướng. Để nhân viên tự đi tìm thì không ai tìm, nên đẩy thành cảnh báo trên đầu.
        req.setAttribute("openIssueCount", kitchenService.countOpenIssues());
        req.setAttribute("awaitingCounterCount", orderService.countAwaitingCounter());

        lookupPickupCode(req);
        forward(req, resp, "staff/order-dashboard.jsp");
    }

    /**
     * Tra mã nhận hàng ngay trên màn hình điều phối.
     * <p>
     * Trước đây là một màn hình riêng, nhưng thu ngân luôn phải đi qua đây rồi mới mở được
     * đơn để giao món — hai lần chuyển trang cho một việc. Gộp vào đầu màn hình này thì lúc
     * khách đứng ở quầy chỉ còn một chỗ để nhìn.
     */
    private void lookupPickupCode(HttpServletRequest req) {
        String code = WebUtil.getString(req, "code");
        req.setAttribute("code", code);
        if (code == null || code.isBlank()) {
            return;
        }
        try {
            // Chỉ đơn đặt trước mới có mã nhận hàng — ràng buộc CK_Orders_pickupCodeOnline
            // đảm bảo điều đó — nên tra theo mã thì không bao giờ ra đơn tại quầy.
            Order found = orderService.findByPickupCode(code);
            req.setAttribute("found", found);

            // Giao món cần đủ ba điều kiện: mã khớp, món đã xong, tiền đã thu. Mã khớp thì vừa
            // tra xong; hai điều kiện còn lại phải nói thành lời ở đây. Chỉ hiện huy hiệu trạng
            // thái là chưa đủ — nhân viên đang vội sẽ đọc lướt qua, rồi bấm giao món và nhận một
            // thông báo lỗi mà lúc đó khách đã đứng chờ sẵn ở quầy.
            //
            // Đây chỉ là cảnh báo sớm cho người dùng. Chốt chặn thật nằm ở OrderService.handoff,
            // nơi cả ba điều kiện được kiểm lại một lần nữa.
            if (!OrderStatus.READY.name().equals(found.getOrderStatus())) {
                req.setAttribute("lookupWarning", "Đơn chưa sẵn sàng để giao. Trạng thái hiện tại: "
                        + found.getOrderStatus());
            } else if (!found.isPaid()) {
                req.setAttribute("lookupWarning", "Đơn này chưa có khoản thanh toán thành công nên "
                        + "không giao được. Kiểm tra lại tình trạng thanh toán trước khi đưa món.");
            }
        } catch (AppException e) {
            req.setAttribute("lookupError", e.getMessage());
        }
    }
}
