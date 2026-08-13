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
 * Màn hình bếp — toàn bộ việc của một đầu bếp trên một trang.
 * <p>
 * Ba khối theo đúng thứ tự làm việc: món đang làm dở, món đã xong chờ đưa ra quầy, rồi mới
 * tới hàng chờ chung. Trước đây hai khối đầu nằm ở một trang khác, nên đầu bếp phải nhớ mình
 * đang làm gì trong lúc nhìn danh sách việc mới — và món đã xong thì không có chỗ nào nhắc,
 * nên nó nằm lại trong bếp cho tới khi khách hỏi.
 * <p>
 * Hàng chờ chỉ hiện món của những đơn đã được đưa xuống bếp. Đơn đặt trước đã thanh toán
 * nhưng chưa tới giờ không xuất hiện ở đây — đó là cách hệ thống giữ cho món không bị làm sớm.
 */
@WebServlet("/kitchen/queue")
public class KdsQueueServlet extends BaseServlet {

    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        req.setAttribute("myTasks", kitchenService.myTasks(user.getUserId()));
        req.setAttribute("awaitingHandover", kitchenService.awaitingHandover(user.getUserId()));
        req.setAttribute("queue", kitchenService.waitingQueue());
        forward(req, resp, "kitchen/kds-queue.jsp");
    }

    /**
     * Ba thao tác của một món, cùng đổ về đây vì cùng kết thúc bằng việc vẽ lại trang này.
     * Trang chi tiết món cũng gửi về đây kèm {@code returnTo} để quay lại đúng chỗ nó đứng.
     */
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        int itemId = WebUtil.getInt(req, "orderItemId", 0);
        String action = WebUtil.getString(req, "action");
        String back = WebUtil.safeRedirect(WebUtil.getString(req, "returnTo"), "/kitchen/queue");

        switch (action == null ? "" : action) {
            case "ready":
                // Thông báo đặt bên trong thao tác và truyền null ở tham số sau, nếu không
                // thông báo chung sẽ ghi đè lên thông báo "cả đơn đã sẵn sàng".
                handle(req, resp, () -> {
                    boolean orderReady = kitchenService.markReady(itemId, user.getUserId());
                    WebUtil.flashSuccess(req, orderReady
                            ? "Món đã xong. Cả đơn đã sẵn sàng, khách đã được báo. "
                              + "Nhớ bàn giao món ra quầy."
                            : "Đã đánh dấu món hoàn thành. Nhớ bàn giao món ra quầy.");
                }, null, back);
                return;
            case "handover":
                handle(req, resp, () -> kitchenService.handOverToCounter(itemId, user.getUserId()),
                        "Đã bàn giao món ra quầy.", back);
                return;
            case "claim":
            default:
                handle(req, resp, () -> kitchenService.claim(itemId, user.getUserId()),
                        "Đã nhận món. Bắt đầu chế biến.", back);
        }
    }
}
