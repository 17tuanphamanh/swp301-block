package com.fastfood.dao;

import com.fastfood.model.entity.OrderItem;

import java.sql.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Truy vấn bảng OrderItem — vừa là dòng món của đơn, vừa là việc trên màn hình bếp.
 * <p>
 * Màn hình bếp chỉ thấy món của đơn đã được đưa xuống bếp. Đơn đặt trước đã thanh toán
 * nhưng chưa tới giờ vẫn nằm ngoài tầm nhìn của bếp — đó là điểm mấu chốt để món không bị
 * làm quá sớm.
 */
public class OrderItemDAO {

    private static final String COLS =
            "oi.order_item_id, oi.order_id, oi.product_id, oi.product_name_snapshot, oi.unit_price, " +
            "oi.quantity, oi.item_status, oi.assigned_to_user_id, oi.started_at, oi.ready_at ";

    public void insert(Connection con, OrderItem item) throws SQLException {
        String sql = "INSERT INTO dbo.OrderItem (order_id, product_id, product_name_snapshot, unit_price, " +
                     "quantity, item_status) VALUES (?, ?, ?, ?, ?, ?)";
        try (PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, item.getOrderId());
            ps.setInt(2, item.getProductId());
            ps.setNString(3, item.getProductNameSnapshot());
            ps.setBigDecimal(4, item.getUnitPrice());
            ps.setInt(5, item.getQuantity());
            ps.setString(6, item.getItemStatus());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    item.setOrderItemId(keys.getInt(1));
                }
            }
        }
    }

    public List<OrderItem> findByOrder(Connection con, int orderId) throws SQLException {
        String sql = "SELECT " + COLS + ", u.full_name AS assigned_to_name, " +
                     "(SELECT COUNT(*) FROM dbo.KitchenIssue ki " +
                     " WHERE ki.order_item_id = oi.order_item_id AND ki.status = 'OPEN') AS open_issue_count " +
                     "FROM dbo.OrderItem oi LEFT JOIN dbo.Users u ON u.user_id = oi.assigned_to_user_id " +
                     "WHERE oi.order_id = ? ORDER BY oi.order_item_id";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, orderId);
            return collect(ps, false);
        }
    }

    public OrderItem findById(Connection con, int orderItemId) throws SQLException {
        String sql = "SELECT " + COLS + ", u.full_name AS assigned_to_name, " +
                     "o.order_source, o.pickup_time, " +
                     "(SELECT COUNT(*) FROM dbo.KitchenIssue ki " +
                     " WHERE ki.order_item_id = oi.order_item_id AND ki.status = 'OPEN') AS open_issue_count " +
                     "FROM dbo.OrderItem oi " +
                     "JOIN dbo.Orders o ON o.order_id = oi.order_id " +
                     "LEFT JOIN dbo.Users u ON u.user_id = oi.assigned_to_user_id " +
                     "WHERE oi.order_item_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, orderItemId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs, true) : null;
            }
        }
    }

    /**
     * Hàng chờ của bếp: món chưa ai nhận, thuộc đơn đã được đưa xuống bếp.
     * Sắp theo giờ hẹn để đơn gấp hơn nằm trên; đơn tại quầy không có giờ hẹn nên
     * xếp theo thứ tự vào trước làm trước.
     */
    public List<OrderItem> findWaitingQueue(Connection con) throws SQLException {
        String sql = "SELECT " + COLS + ", NULL AS assigned_to_name, o.order_source, o.pickup_time, " +
                     "(SELECT COUNT(*) FROM dbo.KitchenIssue ki " +
                     " WHERE ki.order_item_id = oi.order_item_id AND ki.status = 'OPEN') AS open_issue_count " +
                     "FROM dbo.OrderItem oi JOIN dbo.Orders o ON o.order_id = oi.order_id " +
                     "WHERE oi.item_status = 'WAITING' AND o.released_to_kds_at IS NOT NULL " +
                     "  AND o.order_status IN ('CONFIRMED','PREPARING') " +
                     "ORDER BY CASE WHEN o.pickup_time IS NULL THEN o.released_to_kds_at ELSE o.pickup_time END, " +
                     "         oi.order_item_id";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            return collect(ps, true);
        }
    }

    /** Việc mà một đầu bếp đang làm dở. */
    public List<OrderItem> findMyTasks(Connection con, int userId) throws SQLException {
        String sql = "SELECT " + COLS + ", u.full_name AS assigned_to_name, o.order_source, o.pickup_time, " +
                     "(SELECT COUNT(*) FROM dbo.KitchenIssue ki " +
                     " WHERE ki.order_item_id = oi.order_item_id AND ki.status = 'OPEN') AS open_issue_count " +
                     "FROM dbo.OrderItem oi JOIN dbo.Orders o ON o.order_id = oi.order_id " +
                     "LEFT JOIN dbo.Users u ON u.user_id = oi.assigned_to_user_id " +
                     "WHERE oi.assigned_to_user_id = ? AND oi.item_status = 'PREPARING' " +
                     "ORDER BY CASE WHEN o.pickup_time IS NULL THEN oi.started_at ELSE o.pickup_time END";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, userId);
            return collect(ps, true);
        }
    }

    /** Món đã hoàn thành gần đây, dùng cho màn hình lịch sử của bếp. */
    public List<OrderItem> findRecentReady(Connection con, int limit) throws SQLException {
        String sql = "SELECT TOP (?) " + COLS + ", u.full_name AS assigned_to_name, " +
                     "o.order_source, o.pickup_time, 0 AS open_issue_count " +
                     "FROM dbo.OrderItem oi JOIN dbo.Orders o ON o.order_id = oi.order_id " +
                     "LEFT JOIN dbo.Users u ON u.user_id = oi.assigned_to_user_id " +
                     "WHERE oi.item_status = 'READY' ORDER BY oi.ready_at DESC";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, limit);
            return collect(ps, true);
        }
    }

    /**
     * Đầu bếp nhận việc.
     * <p>
     * Hai điều kiện cuối là chốt chặn: hai người cùng bấm nhận một món thì người thứ hai
     * nhận về 0 dòng và được báo món đã có người làm, thay vì ghi đè lên phân công của người trước.
     */
    public int claim(Connection con, int orderItemId, int userId, LocalDateTime now) throws SQLException {
        String sql = "UPDATE dbo.OrderItem SET assigned_to_user_id = ?, item_status = 'PREPARING', started_at = ? " +
                     "WHERE order_item_id = ? AND item_status = 'WAITING' AND assigned_to_user_id IS NULL";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, userId);
            JdbcSupport.setDateTime(ps, 2, now);
            ps.setInt(3, orderItemId);
            return ps.executeUpdate();
        }
    }

    /** Đánh dấu món xong. Chỉ người đang làm mới đánh dấu được. */
    public int markReady(Connection con, int orderItemId, int userId, LocalDateTime now) throws SQLException {
        String sql = "UPDATE dbo.OrderItem SET item_status = 'READY', ready_at = ? " +
                     "WHERE order_item_id = ? AND item_status = 'PREPARING' AND assigned_to_user_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            JdbcSupport.setDateTime(ps, 1, now);
            ps.setInt(2, orderItemId);
            ps.setInt(3, userId);
            return ps.executeUpdate();
        }
    }

    /** Số món của đơn chưa hoàn thành. Bằng 0 nghĩa là cả đơn đã sẵn sàng. */
    public int countUnready(Connection con, int orderId) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(
                "SELECT COUNT(*) FROM dbo.OrderItem WHERE order_id = ? AND item_status <> 'READY'")) {
            ps.setInt(1, orderId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    public int countByStatus(Connection con, String status) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(
                "SELECT COUNT(*) FROM dbo.OrderItem WHERE item_status = ?")) {
            ps.setString(1, status);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    private List<OrderItem> collect(PreparedStatement ps, boolean withOrderInfo) throws SQLException {
        List<OrderItem> list = new ArrayList<>();
        try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(map(rs, withOrderInfo));
            }
        }
        return list;
    }

    private OrderItem map(ResultSet rs, boolean withOrderInfo) throws SQLException {
        OrderItem i = new OrderItem();
        i.setOrderItemId(rs.getInt("order_item_id"));
        i.setOrderId(rs.getInt("order_id"));
        i.setProductId(rs.getInt("product_id"));
        i.setProductNameSnapshot(rs.getNString("product_name_snapshot"));
        i.setUnitPrice(JdbcSupport.getMoney(rs, "unit_price"));
        i.setQuantity(rs.getInt("quantity"));
        i.setItemStatus(rs.getString("item_status"));
        i.setAssignedToUserId(JdbcSupport.getInteger(rs, "assigned_to_user_id"));
        i.setStartedAt(JdbcSupport.getDateTime(rs, "started_at"));
        i.setReadyAt(JdbcSupport.getDateTime(rs, "ready_at"));
        i.setAssignedToName(rs.getNString("assigned_to_name"));
        i.setOpenIssueCount(rs.getInt("open_issue_count"));
        if (withOrderInfo) {
            i.setOrderSource(rs.getString("order_source"));
            i.setPickupTime(JdbcSupport.getDateTime(rs, "pickup_time"));
        }
        return i;
    }
}
