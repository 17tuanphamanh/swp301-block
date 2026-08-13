package com.fastfood.controller.api;

import com.fastfood.common.util.WebUtil;
import com.fastfood.model.dto.KdsItemView;
import com.fastfood.model.entity.User;
import com.fastfood.service.KitchenService;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;

import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Dữ liệu cho màn hình bếp tự cập nhật.
 * <p>
 * Trang bếp gọi địa chỉ này vài giây một lần thay vì tải lại cả trang, để món mới xuống bếp
 * xuất hiện gần như tức thì mà đầu bếp không phải bấm gì.
 */
@WebServlet("/api/kds/queue")
public class KdsApiServlet extends HttpServlet {

    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = WebUtil.currentUser(req);
        if (user == null) {
            resp.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        JsonObject root = new JsonObject();
        JsonArray queue = new JsonArray();
        for (KdsItemView view : kitchenService.waitingQueue()) {
            JsonObject o = new JsonObject();
            o.addProperty("orderItemId", view.getItem().getOrderItemId());
            o.addProperty("orderId", view.getItem().getOrderId());
            o.addProperty("productName", view.getItem().getProductNameSnapshot());
            o.addProperty("quantity", view.getItem().getQuantity());
            o.addProperty("online", view.isOnline());
            o.addProperty("urgent", view.isUrgent());
            o.addProperty("late", view.isLate());
            o.addProperty("pickupLabel", view.getPickupLabel());
            queue.add(o);
        }
        root.add("queue", queue);
        root.addProperty("queueCount", queue.size());
        root.addProperty("myTaskCount", kitchenService.myTasks(user.getUserId()).size());

        resp.setContentType("application/json;charset=UTF-8");
        resp.getWriter().write(root.toString());
    }
}
