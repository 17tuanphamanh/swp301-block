package com.fastfood.service;

import com.fastfood.common.constant.AuditAction;
import com.fastfood.common.exception.BusinessException;
import com.fastfood.common.exception.NotFoundException;
import com.fastfood.common.exception.ValidationException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.dao.KitchenIssueDAO;
import com.fastfood.dao.OrderItemDAO;
import com.fastfood.model.dto.KdsItemView;
import com.fastfood.model.entity.KitchenIssue;
import com.fastfood.model.entity.OrderItem;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Nghiệp vụ bếp.
 * <p>
 * Bếp chỉ nhìn thấy món của những đơn đã được đưa xuống. Đơn đặt trước đã thanh toán nhưng
 * chưa tới giờ nằm ngoài tầm nhìn của bếp — đó chính là cơ chế giữ cho món không bị làm sớm.
 * <p>
 * Bếp cũng không biết gì về tiền: không thấy trạng thái thanh toán, không đổi được giờ hẹn.
 */
public class KitchenService {

    private final OrderItemDAO orderItemDAO = new OrderItemDAO();
    private final KitchenIssueDAO issueDAO = new KitchenIssueDAO();
    private final OrderService orderService = new OrderService();
    private final AuditService auditService = new AuditService();

    /** Hàng chờ: món chưa ai nhận, sắp theo mức độ gấp. */
    public List<KdsItemView> waitingQueue() {
        List<OrderItem> items = Tx.read(orderItemDAO::findWaitingQueue);
        List<KdsItemView> views = new ArrayList<>(items.size());
        for (OrderItem item : items) {
            views.add(new KdsItemView(item));
        }
        return views;
    }

    /** Việc mà đầu bếp đang làm dở. */
    public List<KdsItemView> myTasks(int userId) {
        List<OrderItem> items = Tx.read(con -> orderItemDAO.findMyTasks(con, userId));
        List<KdsItemView> views = new ArrayList<>(items.size());
        for (OrderItem item : items) {
            views.add(new KdsItemView(item));
        }
        return views;
    }

    public List<OrderItem> recentReady(int limit) {
        return Tx.read(con -> orderItemDAO.findRecentReady(con, limit));
    }

    public OrderItem findItem(int orderItemId) {
        OrderItem item = Tx.read(con -> orderItemDAO.findById(con, orderItemId));
        if (item == null) {
            throw new NotFoundException("Không tìm thấy món cần chế biến.");
        }
        return item;
    }

    /**
     * Đầu bếp nhận việc.
     * <p>
     * Điều kiện "món còn ở hàng chờ và chưa ai nhận" nằm ngay trong câu lệnh cập nhật.
     * Hai người cùng bấm nhận một món thì người thứ hai nhận về 0 dòng và được báo món
     * đã có người làm — thay vì ghi đè lên phân công của người trước.
     */
    public void claim(int orderItemId, int userId) {
        LocalDateTime now = DateTimeUtil.now();
        Tx.writeVoid(con -> {
            int changed = orderItemDAO.claim(con, orderItemId, userId, now);
            if (changed == 0) {
                throw new BusinessException("Món này vừa được người khác nhận.");
            }
            OrderItem item = orderItemDAO.findById(con, orderItemId);
            auditService.log(con, userId, "ORDER_ITEM", orderItemId,
                    AuditAction.ITEM_START, null, "PREPARING");
            // Đơn chuyển sang đang chế biến khi món đầu tiên được nhận
            orderService.recalculateStatus(con, item.getOrderId(), now);
        });
    }

    /**
     * Đánh dấu món đã xong.
     * <p>
     * Một dòng món là một việc nguyên khối: đặt 3 phần thì làm xong cả 3 mới đánh dấu,
     * không có trạng thái xong một phần.
     *
     * @return true nếu món này là món cuối cùng và cả đơn vừa chuyển sang sẵn sàng
     */
    public boolean markReady(int orderItemId, int userId) {
        LocalDateTime now = DateTimeUtil.now();
        return Tx.write(con -> {
            OrderItem item = orderItemDAO.findById(con, orderItemId);
            if (item == null) {
                throw new NotFoundException("Không tìm thấy món.");
            }
            int changed = orderItemDAO.markReady(con, orderItemId, userId, now);
            if (changed == 0) {
                throw new BusinessException("Chỉ người đang chế biến món này mới đánh dấu hoàn thành được.");
            }
            auditService.log(con, userId, "ORDER_ITEM", orderItemId,
                    AuditAction.ITEM_READY, "PREPARING", "READY");
            return orderService.recalculateStatus(con, item.getOrderId(), now);
        });
    }

    // ------------------------------------------------------------ sự cố bếp

    /**
     * Ghi nhận sự cố: hết nguyên liệu, món hỏng phải làm lại.
     * Sự cố chạy song song với trạng thái món — món đang làm lại vẫn giữ trạng thái
     * đang chế biến chứ không lùi về hàng chờ, để tránh việc bị người khác nhận lại.
     */
    public void openIssue(int orderItemId, int userId, String issueType, String description) {
        if (issueType == null || issueType.isBlank()) {
            throw new ValidationException("Vui lòng chọn loại sự cố.");
        }
        LocalDateTime now = DateTimeUtil.now();
        Tx.writeVoid(con -> {
            OrderItem item = orderItemDAO.findById(con, orderItemId);
            if (item == null) {
                throw new NotFoundException("Không tìm thấy món.");
            }
            KitchenIssue issue = new KitchenIssue();
            issue.setOrderItemId(orderItemId);
            issue.setCreatedBy(userId);
            issue.setIssueType(issueType);
            issue.setDescription(description);
            issue.setStatus("OPEN");
            issue.setCreatedAt(now);
            issueDAO.insert(con, issue);
            auditService.log(con, userId, "ORDER_ITEM", orderItemId,
                    AuditAction.ISSUE_OPENED, null, issueType);
        });
    }

    public void resolveIssue(int issueId, int userId) {
        LocalDateTime now = DateTimeUtil.now();
        Tx.writeVoid(con -> {
            int changed = issueDAO.resolve(con, issueId, now);
            if (changed == 0) {
                throw new BusinessException("Sự cố này đã được xử lý.");
            }
            auditService.log(con, userId, "KITCHEN_ISSUE", issueId,
                    AuditAction.ISSUE_RESOLVED, "OPEN", "RESOLVED");
        });
    }

    public List<KitchenIssue> openIssues() {
        return Tx.read(issueDAO::findOpen);
    }

    public List<KitchenIssue> recentIssues(int limit) {
        return Tx.read(con -> issueDAO.findRecent(con, limit));
    }

    public List<KitchenIssue> issuesOfItem(int orderItemId) {
        return Tx.read(con -> issueDAO.findByOrderItem(con, orderItemId));
    }
}
