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
 * Việc mà đầu bếp đang làm dở, và nút đánh dấu hoàn thành.
 * Món cuối cùng của đơn được đánh dấu xong sẽ tự động chuyển cả đơn sang sẵn sàng
 * và gửi tin báo cho khách.
 */
@WebServlet("/kitchen/my-tasks")
public class MyTasksServlet extends BaseServlet {

    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        req.setAttribute("myTasks", kitchenService.myTasks(user.getUserId()));
        forward(req, resp, "kitchen/my-tasks.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        int itemId = WebUtil.getInt(req, "orderItemId", 0);
        String back = WebUtil.getString(req, "returnTo");
        handle(req, resp, () -> {
            boolean orderReady = kitchenService.markReady(itemId, user.getUserId());
            if (orderReady) {
                WebUtil.flashSuccess(req, "Món đã xong. Cả đơn đã sẵn sàng, khách đã được báo.");
            }
        }, "Đã đánh dấu món hoàn thành.", back != null ? back : "/kitchen/my-tasks");
    }
}
