package com.fastfood.controller.customer;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.CartService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Giỏ hàng: xem, thêm, đổi số lượng, bỏ món.
 * <p>
 * Mọi thao tác ghi đều kết thúc bằng chuyển hướng chứ không hiển thị thẳng, để khách
 * bấm tải lại trang không vô tình thêm món lần nữa.
 */
@WebServlet("/cart")
public class CartServlet extends BaseServlet {

    private final CartService cartService = new CartService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        req.setAttribute("cart", cartService.getCart(user.getUserId()));
        forward(req, resp, "customer/cart.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        String action = WebUtil.getString(req, "action");
        int userId = user.getUserId();

        switch (action == null ? "" : action) {
            case "add": {
                int productId = WebUtil.getInt(req, "productId", 0);
                int quantity = WebUtil.getInt(req, "quantity", 1);
                String back = WebUtil.getString(req, "returnTo");
                handle(req, resp, () -> cartService.addProduct(userId, productId, quantity),
                        "Đã thêm món vào giỏ hàng.", back != null ? back : "/menu");
                return;
            }
            case "update": {
                int cartItemId = WebUtil.getInt(req, "cartItemId", 0);
                int quantity = WebUtil.getInt(req, "quantity", 1);
                handle(req, resp, () -> cartService.updateQuantity(userId, cartItemId, quantity),
                        null, "/cart");
                return;
            }
            case "remove": {
                int cartItemId = WebUtil.getInt(req, "cartItemId", 0);
                handle(req, resp, () -> cartService.removeItem(userId, cartItemId),
                        "Đã bỏ món khỏi giỏ hàng.", "/cart");
                return;
            }
            case "removeUnavailable": {
                handle(req, resp, () -> cartService.removeUnavailable(userId),
                        "Đã bỏ các món không còn phục vụ.", "/cart");
                return;
            }
            default:
                redirect(req, resp, "/cart");
        }
    }
}
