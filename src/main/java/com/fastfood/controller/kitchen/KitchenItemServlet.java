package com.fastfood.controller.kitchen;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.service.KitchenService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Chi tiết một món cần chế biến, kèm lịch sử sự cố của món đó. */
@WebServlet("/kitchen/item")
public class KitchenItemServlet extends BaseServlet {

    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        int itemId = WebUtil.getInt(req, "id", 0);
        try {
            req.setAttribute("item", kitchenService.findItem(itemId));
            req.setAttribute("issues", kitchenService.issuesOfItem(itemId));
            forward(req, resp, "kitchen/item-detail.jsp");
        } catch (AppException e) {
            req.setAttribute("errorMessage", e.getMessage());
            resp.setStatus(HttpServletResponse.SC_NOT_FOUND);
            forward(req, resp, "error/404.jsp");
        }
    }
}
