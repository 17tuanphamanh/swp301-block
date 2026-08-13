package com.fastfood.dao;

import com.fastfood.model.entity.KitchenIssue;

import java.sql.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/** Truy vấn bảng KitchenIssue. */
public class KitchenIssueDAO {

    private static final String BASE =
            "SELECT ki.issue_id, ki.order_item_id, ki.created_by, ki.issue_type, ki.description, " +
            "       ki.status, ki.created_at, ki.resolved_at, " +
            "       u.full_name AS created_by_name, oi.product_name_snapshot, oi.order_id " +
            "FROM dbo.KitchenIssue ki " +
            "JOIN dbo.Users u      ON u.user_id = ki.created_by " +
            "JOIN dbo.OrderItem oi ON oi.order_item_id = ki.order_item_id ";

    public int insert(Connection con, KitchenIssue issue) throws SQLException {
        String sql = "INSERT INTO dbo.KitchenIssue (order_item_id, created_by, issue_type, description, " +
                     "status, created_at) VALUES (?, ?, ?, ?, ?, ?)";
        try (PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, issue.getOrderItemId());
            ps.setInt(2, issue.getCreatedBy());
            ps.setString(3, issue.getIssueType());
            JdbcSupport.setString(ps, 4, issue.getDescription());
            ps.setString(5, issue.getStatus());
            JdbcSupport.setDateTime(ps, 6, issue.getCreatedAt());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    issue.setIssueId(keys.getInt(1));
                }
            }
        }
        return issue.getIssueId();
    }

    public int resolve(Connection con, int issueId, LocalDateTime now) throws SQLException {
        String sql = "UPDATE dbo.KitchenIssue SET status = 'RESOLVED', resolved_at = ? " +
                     "WHERE issue_id = ? AND status = 'OPEN'";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            JdbcSupport.setDateTime(ps, 1, now);
            ps.setInt(2, issueId);
            return ps.executeUpdate();
        }
    }

    public List<KitchenIssue> findOpen(Connection con) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(
                BASE + "WHERE ki.status = 'OPEN' ORDER BY ki.created_at DESC")) {
            return collect(ps);
        }
    }

    public List<KitchenIssue> findRecent(Connection con, int limit) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(
                BASE.replaceFirst("SELECT", "SELECT TOP (" + limit + ")") + "ORDER BY ki.created_at DESC")) {
            return collect(ps);
        }
    }

    public List<KitchenIssue> findByOrderItem(Connection con, int orderItemId) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(
                BASE + "WHERE ki.order_item_id = ? ORDER BY ki.created_at DESC")) {
            ps.setInt(1, orderItemId);
            return collect(ps);
        }
    }

    private List<KitchenIssue> collect(PreparedStatement ps) throws SQLException {
        List<KitchenIssue> list = new ArrayList<>();
        try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                KitchenIssue i = new KitchenIssue();
                i.setIssueId(rs.getInt("issue_id"));
                i.setOrderItemId(rs.getInt("order_item_id"));
                i.setCreatedBy(rs.getInt("created_by"));
                i.setIssueType(rs.getString("issue_type"));
                i.setDescription(rs.getNString("description"));
                i.setStatus(rs.getString("status"));
                i.setCreatedAt(JdbcSupport.getDateTime(rs, "created_at"));
                i.setResolvedAt(JdbcSupport.getDateTime(rs, "resolved_at"));
                i.setCreatedByName(rs.getNString("created_by_name"));
                i.setProductName(rs.getNString("product_name_snapshot"));
                i.setOrderId(rs.getInt("order_id"));
                list.add(i);
            }
        }
        return list;
    }
}
