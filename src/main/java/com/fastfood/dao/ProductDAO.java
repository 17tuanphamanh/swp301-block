package com.fastfood.dao;

import com.fastfood.model.entity.Product;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/** Truy vấn bảng Product. */
public class ProductDAO {

    private static final String COLS =
            "p.product_id, p.category_id, p.name, p.description, p.price, p.image_url, " +
            "p.is_available, p.status, p.created_at, p.updated_at, c.name AS category_name ";

    /**
     * Thực đơn hiển thị cho khách.
     * <p>
     * Ba điều kiện lọc nằm ở hai bảng nên bắt buộc phải join: món còn kinh doanh, còn hàng,
     * và thuộc nhóm đang mở. Thiếu điều kiện cuối thì tắt cả nhóm món vẫn thấy món trên thực đơn.
     */
    public List<Product> findMenu(Connection con, Integer categoryId, String keyword) throws SQLException {
        StringBuilder sql = new StringBuilder(
                "SELECT " + COLS +
                "FROM dbo.Product p JOIN dbo.Category c ON c.category_id = p.category_id " +
                "WHERE p.status = 'ACTIVE' AND p.is_available = 1 AND c.status = 'ACTIVE' ");
        List<Object> params = new ArrayList<>();
        if (categoryId != null && categoryId > 0) {
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
        }
        if (keyword != null && !keyword.isBlank()) {
            sql.append("AND p.name LIKE ? ");
            params.add("%" + keyword.trim() + "%");
        }
        sql.append("ORDER BY c.display_order, p.name");
        return query(con, sql.toString(), params);
    }

    /** Danh sách đầy đủ cho màn hình quản trị, gồm cả món đã ngừng bán. */
    public List<Product> findAllForAdmin(Connection con, Integer categoryId, String keyword) throws SQLException {
        StringBuilder sql = new StringBuilder(
                "SELECT " + COLS +
                "FROM dbo.Product p JOIN dbo.Category c ON c.category_id = p.category_id WHERE 1 = 1 ");
        List<Object> params = new ArrayList<>();
        if (categoryId != null && categoryId > 0) {
            sql.append("AND p.category_id = ? ");
            params.add(categoryId);
        }
        if (keyword != null && !keyword.isBlank()) {
            sql.append("AND p.name LIKE ? ");
            params.add("%" + keyword.trim() + "%");
        }
        sql.append("ORDER BY c.display_order, p.name");
        return query(con, sql.toString(), params);
    }

    public Product findById(Connection con, int productId) throws SQLException {
        String sql = "SELECT " + COLS +
                     "FROM dbo.Product p JOIN dbo.Category c ON c.category_id = p.category_id " +
                     "WHERE p.product_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, productId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    /**
     * Đọc lại món ngay trước khi tạo đơn, kèm trạng thái của nhóm món.
     * Cần thiết vì giữa lúc khách bỏ vào giỏ và lúc bấm thanh toán, quản trị viên
     * có thể đã đổi giá hoặc đánh dấu hết hàng.
     */
    public Product findForCheckout(Connection con, int productId) throws SQLException {
        String sql = "SELECT " + COLS + ", c.status AS category_status " +
                     "FROM dbo.Product p JOIN dbo.Category c ON c.category_id = p.category_id " +
                     "WHERE p.product_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, productId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                Product p = map(rs);
                // Nhóm món đã tắt thì coi như món không đặt được nữa
                if (!"ACTIVE".equals(rs.getString("category_status"))) {
                    p.setStatus("INACTIVE");
                }
                return p;
            }
        }
    }

    public int insert(Connection con, Product p) throws SQLException {
        String sql = "INSERT INTO dbo.Product (category_id, name, description, price, image_url, " +
                     "is_available, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement ps = con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, p.getCategoryId());
            ps.setNString(2, p.getName());
            JdbcSupport.setString(ps, 3, p.getDescription());
            ps.setBigDecimal(4, p.getPrice());
            JdbcSupport.setString(ps, 5, p.getImageUrl());
            ps.setBoolean(6, p.isAvailable());
            ps.setString(7, p.getStatus());
            JdbcSupport.setDateTime(ps, 8, p.getCreatedAt());
            ps.executeUpdate();
            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    p.setProductId(keys.getInt(1));
                }
            }
        }
        return p.getProductId();
    }

    public void update(Connection con, Product p) throws SQLException {
        String sql = "UPDATE dbo.Product SET category_id = ?, name = ?, description = ?, price = ?, " +
                     "image_url = ?, is_available = ?, status = ?, updated_at = ? WHERE product_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setInt(1, p.getCategoryId());
            ps.setNString(2, p.getName());
            JdbcSupport.setString(ps, 3, p.getDescription());
            ps.setBigDecimal(4, p.getPrice());
            JdbcSupport.setString(ps, 5, p.getImageUrl());
            ps.setBoolean(6, p.isAvailable());
            ps.setString(7, p.getStatus());
            JdbcSupport.setDateTime(ps, 8, p.getUpdatedAt());
            ps.setInt(9, p.getProductId());
            ps.executeUpdate();
        }
    }

    /** Bật/tắt nhanh trạng thái còn hàng ngay trên danh sách. */
    public void toggleAvailability(Connection con, int productId, boolean available) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(
                "UPDATE dbo.Product SET is_available = ? WHERE product_id = ?")) {
            ps.setBoolean(1, available);
            ps.setInt(2, productId);
            ps.executeUpdate();
        }
    }

    private List<Product> query(Connection con, String sql, List<Object> params) throws SQLException {
        List<Product> list = new ArrayList<>();
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(map(rs));
                }
            }
        }
        return list;
    }

    private Product map(ResultSet rs) throws SQLException {
        Product p = new Product();
        p.setProductId(rs.getInt("product_id"));
        p.setCategoryId(rs.getInt("category_id"));
        p.setName(rs.getNString("name"));
        p.setDescription(rs.getNString("description"));
        p.setPrice(JdbcSupport.getMoney(rs, "price"));
        p.setImageUrl(rs.getString("image_url"));
        p.setAvailable(rs.getBoolean("is_available"));
        p.setStatus(rs.getString("status"));
        p.setCreatedAt(JdbcSupport.getDateTime(rs, "created_at"));
        p.setUpdatedAt(JdbcSupport.getDateTime(rs, "updated_at"));
        p.setCategoryName(rs.getNString("category_name"));
        return p;
    }
}
