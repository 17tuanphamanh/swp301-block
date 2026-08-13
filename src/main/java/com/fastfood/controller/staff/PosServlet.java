package com.fastfood.controller.staff;

import com.fastfood.common.constant.PaymentMethod;
import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.dto.PosLine;
import com.fastfood.model.entity.Order;
import com.fastfood.model.entity.Product;
import com.fastfood.model.entity.User;
import com.fastfood.service.MenuService;
import com.fastfood.service.OrderService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.io.IOException;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Màn hình bán hàng tại quầy.
 * <p>
 * Giỏ tạm giữ trong phiên làm việc của thu ngân chứ không ghi xuống cơ sở dữ liệu:
 * khách vãng lai không có tài khoản, và nếu ghi thì mỗi lần bấm nhầm lại để lại một dòng rác.
 * <p>
 * Khi bấm thu tiền, toàn bộ lập đơn - thu tiền - đưa xuống bếp diễn ra trong một giao dịch,
 * đúng như thao tác thật ở quầy.
 */
@WebServlet("/staff/pos")
public class PosServlet extends BaseServlet {

    private static final String CART_KEY = "posCart";

    private final MenuService menuService = new MenuService();
    private final OrderService orderService = new OrderService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        Integer categoryId = WebUtil.getInteger(req, "categoryId");
        String keyword = WebUtil.getString(req, "keyword");

        List<Product> products = menuService.browse(categoryId, keyword);
        Map<Integer, Integer> cart = cart(req);

        // Ghép số lượng đã chọn với thông tin món để hiển thị phiếu tạm
        List<Product> all = menuService.browse(null, null);
        List<Object[]> lines = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Map.Entry<Integer, Integer> entry : cart.entrySet()) {
            for (Product p : all) {
                if (p.getProductId() == entry.getKey()) {
                    BigDecimal lineTotal = p.getPrice().multiply(BigDecimal.valueOf(entry.getValue()));
                    lines.add(new Object[]{p, entry.getValue(), lineTotal});
                    total = total.add(lineTotal);
                    break;
                }
            }
        }

        req.setAttribute("products", products);
        req.setAttribute("categories", menuService.activeCategories());
        req.setAttribute("selectedCategory", categoryId);
        req.setAttribute("keyword", keyword);
        req.setAttribute("posLines", lines);
        req.setAttribute("posTotal", total);
        forward(req, resp, "staff/pos.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User cashier = requireUser(req);
        String action = WebUtil.getString(req, "action");
        Map<Integer, Integer> cart = cart(req);

        switch (action == null ? "" : action) {
            case "add": {
                int productId = WebUtil.getInt(req, "productId", 0);
                cart.merge(productId, 1, Integer::sum);
                redirect(req, resp, "/staff/pos");
                return;
            }
            case "setQty": {
                int productId = WebUtil.getInt(req, "productId", 0);
                int quantity = WebUtil.getInt(req, "quantity", 0);
                if (quantity <= 0) {
                    cart.remove(productId);
                } else {
                    cart.put(productId, quantity);
                }
                redirect(req, resp, "/staff/pos");
                return;
            }
            case "remove": {
                cart.remove(WebUtil.getInt(req, "productId", 0));
                redirect(req, resp, "/staff/pos");
                return;
            }
            case "clear": {
                cart.clear();
                redirect(req, resp, "/staff/pos");
                return;
            }
            case "pay": {
                if (cart.isEmpty()) {
                    WebUtil.flashError(req, "Chưa chọn món nào.");
                    redirect(req, resp, "/staff/pos");
                    return;
                }
                PaymentMethod method = "CASH".equals(WebUtil.getString(req, "method"))
                        ? PaymentMethod.CASH : PaymentMethod.ONLINE_GATEWAY;
                List<PosLine> lines = new ArrayList<>();
                cart.forEach((productId, quantity) -> lines.add(new PosLine(productId, quantity)));

                try {
                    Order order = orderService.createPosOrder(cashier.getUserId(), lines, method);
                    cart.clear();
                    WebUtil.flashSuccess(req, "Đã lập đơn #" + order.getOrderId()
                            + " và chuyển xuống bếp.");
                    redirect(req, resp, "/staff/order/detail?orderId=" + order.getOrderId());
                } catch (AppException e) {
                    WebUtil.flashError(req, e.getMessage());
                    redirect(req, resp, "/staff/pos");
                }
                return;
            }
            default:
                redirect(req, resp, "/staff/pos");
        }
    }

    @SuppressWarnings("unchecked")
    private Map<Integer, Integer> cart(HttpServletRequest req) {
        HttpSession session = req.getSession();
        Map<Integer, Integer> cart = (Map<Integer, Integer>) session.getAttribute(CART_KEY);
        if (cart == null) {
            cart = new LinkedHashMap<>();
            session.setAttribute(CART_KEY, cart);
        }
        return cart;
    }
}
