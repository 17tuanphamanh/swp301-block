package com.fastfood.controller.kitchen;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.service.KitchenService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Các món bếp đã hoàn thành gần đây. */
@WebServlet("/kitchen/history")
public class KitchenHistoryServlet extends BaseServlet {

    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setAttribute("pageData", kitchenService.recentReady(WebUtil.getInt(req, "page", 1)));
        req.setAttribute("filterQuery", WebUtil.queryStringWithout(req, "page"));
        forward(req, resp, "kitchen/history.jsp");
    }
}
