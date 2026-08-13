package com.fastfood.dao;

import com.fastfood.model.entity.Role;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/** Truy vấn bảng Role. */
public class RoleDAO {

    public List<Role> findAll(Connection con) throws SQLException {
        String sql = "SELECT role_id, name, description FROM dbo.Role ORDER BY role_id";
        List<Role> list = new ArrayList<>();
        try (PreparedStatement ps = con.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                list.add(map(rs));
            }
        }
        return list;
    }

    public Role findByName(Connection con, String name) throws SQLException {
        String sql = "SELECT role_id, name, description FROM dbo.Role WHERE name = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, name);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    private Role map(ResultSet rs) throws SQLException {
        Role r = new Role();
        r.setRoleId(rs.getInt("role_id"));
        r.setName(rs.getString("name"));
        r.setDescription(rs.getString("description"));
        return r;
    }
}
