package com.fastfood.dao;

import com.fastfood.model.entity.Notification;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/** Truy vấn bảng Notification. */
public class NotificationDAO {

    public int insert(Connection con, Notification n) throws SQLException {
        String sql = "INSERT INTO dbo.Notification (user_id, order_id, channel, event_type, content, " +
                     "status, sent_at) VALUES (?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            JdbcSupport.setInteger(ps, 1, n.getUserId());
            ps.setInt(2, n.getOrderId());
            ps.setString(3, n.getChannel());
            ps.setString(4, n.getEventType());
            JdbcSupport.setString(ps, 5, n.getContent());
            ps.setString(6, n.getStatus());
            JdbcSupport.setDateTime(ps, 7, n.getSentAt());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    n.setNotificationId(keys.getInt(1));
                }
            }
        }
        return n.getNotificationId();
    }

    public List<Notification> findByOrder(Connection con, int orderId) throws SQLException {
        String sql = "SELECT notification_id, user_id, order_id, channel, event_type, content, status, sent_at " +
                     "FROM dbo.Notification WHERE order_id = ? ORDER BY notification_id";
        List<Notification> list = new ArrayList<>();
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Notification n = new Notification();
                    n.setNotificationId(rs.getInt("notification_id"));
                    n.setUserId(JdbcSupport.getInteger(rs, "user_id"));
                    n.setOrderId(rs.getInt("order_id"));
                    n.setChannel(rs.getString("channel"));
                    n.setEventType(rs.getString("event_type"));
                    n.setContent(rs.getNString("content"));
                    n.setStatus(rs.getString("status"));
                    n.setSentAt(JdbcSupport.getDateTime(rs, "sent_at"));
                    list.add(n);
                }
            }
        }
        return list;
    }

    /** Tin nhắn chưa đọc của khách — hiện lên khi khách vào trang theo dõi đơn. */
    public List<Notification> findRecentByUser(Connection con, int userId, int limit) throws SQLException {
        String sql = "SELECT TOP (?) notification_id, user_id, order_id, channel, event_type, content, " +
                     "status, sent_at FROM dbo.Notification WHERE user_id = ? ORDER BY notification_id DESC";
        List<Notification> list = new ArrayList<>();
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, limit);
            ps.setInt(2, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Notification n = new Notification();
                    n.setNotificationId(rs.getInt("notification_id"));
                    n.setUserId(JdbcSupport.getInteger(rs, "user_id"));
                    n.setOrderId(rs.getInt("order_id"));
                    n.setChannel(rs.getString("channel"));
                    n.setEventType(rs.getString("event_type"));
                    n.setContent(rs.getNString("content"));
                    n.setStatus(rs.getString("status"));
                    n.setSentAt(JdbcSupport.getDateTime(rs, "sent_at"));
                    list.add(n);
                }
            }
        }
        return list;
    }
}
