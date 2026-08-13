package com.fastfood.service;

import com.fastfood.common.constant.NotificationEvent;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.MoneyUtil;
import com.fastfood.dao.NotificationDAO;
import com.fastfood.integration.notification.MockNotificationSender;
import com.fastfood.integration.notification.NotificationSender;
import com.fastfood.model.entity.Notification;
import com.fastfood.model.entity.Order;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;

/**
 * Gửi tin cho khách và lưu lại nhật ký đã gửi.
 * <p>
 * Tin báo món sẵn sàng bắt buộc phải kèm giờ hẹn và mã nhận hàng — thiếu mã thì khách
 * tới quầy không nhận được món, và nhân viên phải tra tay từng đơn.
 */
public class NotificationService {

    private final NotificationDAO notificationDAO = new NotificationDAO();
    private final NotificationSender sender = new MockNotificationSender();

    public void notifyOrderConfirmed(Connection con, Order order) throws SQLException {
        if (!order.isOnline()) {
            return;   // Khách mua tại quầy đứng ngay đó, không cần nhắn tin
        }
        String subject = "Đơn hàng #" + order.getOrderId() + " đã được xác nhận";
        String content = String.format(
                "Đơn #%d đã thanh toán thành công %s. Giờ nhận hàng: %s. Mã nhận hàng: %s.",
                order.getOrderId(),
                MoneyUtil.format(order.getTotalAmount()),
                DateTimeUtil.format(order.getPickupTime()),
                order.getPickupCode());
        record(con, order, NotificationEvent.ORDER_CONFIRMED, subject, content);
    }

    public void notifyOrderReady(Connection con, Order order) throws SQLException {
        if (!order.isOnline()) {
            return;
        }
        String subject = "Đơn hàng #" + order.getOrderId() + " đã sẵn sàng";
        String content = String.format(
                "Món của bạn đã sẵn sàng. Vui lòng đến quầy trước %s và đưa mã %s để nhận hàng.",
                DateTimeUtil.format(order.getPickupTime()),
                order.getPickupCode());
        record(con, order, NotificationEvent.ORDER_READY, subject, content);
    }

    public List<Notification> findByOrder(int orderId) {
        return Tx.read(con -> notificationDAO.findByOrder(con, orderId));
    }

    public List<Notification> findRecentByUser(int userId, int limit) {
        return Tx.read(con -> notificationDAO.findRecentByUser(con, userId, limit));
    }

    private void record(Connection con, Order order, NotificationEvent event,
                        String subject, String content) throws SQLException {
        boolean sent = sender.send(order.getCustomerEmail(), subject, content);

        Notification n = new Notification();
        n.setUserId(order.getCustomerId());
        n.setOrderId(order.getOrderId());
        n.setChannel(sender.getChannel());
        n.setEventType(event.name());
        n.setContent(content);
        n.setStatus(sent ? "SENT" : "FAILED");
        n.setSentAt(sent ? DateTimeUtil.now() : null);
        notificationDAO.insert(con, n);
    }
}
