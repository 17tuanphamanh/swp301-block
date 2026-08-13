package com.fastfood.controller.kitchen;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.KitchenService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Hàng chờ của bếp.
 * <p>
 * Chỉ hiện món của những đơn đã được đưa xuống bếp. Đơn đặt trước đã thanh toán nhưng
 * chưa tới giờ không xuất hiện ở đây — đó là cách hệ thống giữ cho món không bị làm sớm.
 */
@WebServlet("/kitchen/queue")
public class KdsQueueServlet extends BaseServlet {

    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        req.setAttribute("queue", kitchenService.waitingQueue());
        req.setAttribute("myTasks", kitchenService.myTasks(user.getUserId()));
        forward(req, resp, "kitchen/kds-queue.jsp");
    }

    /** Nhận việc. */
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        int itemId = WebUtil.getInt(req, "orderItemId", 0);
        handle(req, resp, () -> kitchenService.claim(itemId, user.getUserId()),
                "Đã nhận món. Bắt đầu chế biến.", "/kitchen/queue");
    }
}
