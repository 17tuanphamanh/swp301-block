package com.fastfood.model.entity;

import java.time.LocalDateTime;

/** Tài khoản người dùng. Ánh xạ tới bảng Users. */
public class User {
    private int userId;
    private String fullName;
    private String email;
    private String phone;
    private String passwordHash;
    private int roleId;
    private String status;
    private boolean mustChangePassword;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /** Tên vai trò lấy kèm khi join bảng Role — JSP dùng để hiện menu theo quyền. */
    private String roleName;

    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }

    public int getRoleId() { return roleId; }
    public void setRoleId(int roleId) { this.roleId = roleId; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public String getRoleName() { return roleName; }
    public void setRoleName(String roleName) { this.roleName = roleName; }

    public boolean isActive() { return "ACTIVE".equals(status); }

    /**
     * Quản trị viên vừa đặt lại mật khẩu cho tài khoản này, nên mật khẩu hiện tại là mật khẩu
     * tạm mà một người khác biết. Còn cờ này thì người dùng chỉ đi được tới trang tài khoản
     * để tự đặt mật khẩu mới.
     */
    public boolean isMustChangePassword() { return mustChangePassword; }
    public void setMustChangePassword(boolean mustChangePassword) { this.mustChangePassword = mustChangePassword; }
}
