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
 * Sự cố bếp: hết nguyên liệu, món hỏng phải làm lại.
 * Ghi nhận sự cố không làm món lùi về hàng chờ — nếu lùi thì người khác có thể
 * nhận lại món đang có người làm dở.
 */
@WebServlet("/kitchen/issue")
public class KitchenIssueServlet extends BaseServlet {

    private final KitchenService kitchenService = new KitchenService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        req.setAttribute("openIssues", kitchenService.openIssues());
        req.setAttribute("recentIssues", kitchenService.recentIssues(30));
        req.setAttribute("orderItemId", WebUtil.getInt(req, "orderItemId", 0));
        forward(req, resp, "kitchen/issue.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        String action = WebUtil.getString(req, "action");

        if ("resolve".equals(action)) {
            int issueId = WebUtil.getInt(req, "issueId", 0);
            handle(req, resp, () -> kitchenService.resolveIssue(issueId, user.getUserId()),
                    "Đã đánh dấu sự cố được xử lý.", "/kitchen/issue");
            return;
        }

        int orderItemId = WebUtil.getInt(req, "orderItemId", 0);
        String issueType = WebUtil.getString(req, "issueType");
        String description = WebUtil.getString(req, "description");
        handle(req, resp, () -> kitchenService.openIssue(orderItemId, user.getUserId(), issueType, description),
                "Đã ghi nhận sự cố.", "/kitchen/issue");
    }
}
