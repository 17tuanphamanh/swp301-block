package com.fastfood.controller.customer;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.CartService;
import com.fastfood.service.MenuService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Thực đơn — trang công khai, không cần đăng nhập để xem. */
@WebServlet("/menu")
public class MenuServlet extends BaseServlet {

    private final MenuService menuService = new MenuService();
    private final CartService cartService = new CartService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        Integer categoryId = WebUtil.getInteger(req, "categoryId");
        String keyword = WebUtil.getString(req, "keyword");

        req.setAttribute("products", menuService.browse(categoryId, keyword));
        req.setAttribute("categories", menuService.activeCategories());
        req.setAttribute("selectedCategory", categoryId);
        req.setAttribute("keyword", keyword);

        User user = WebUtil.currentUser(req);
        if (user != null && "CUSTOMER".equals(user.getRoleName())) {
            req.setAttribute("cartCount", cartService.countItems(user.getUserId()));
        }
        forward(req, resp, "customer/menu.jsp");
    }
}
