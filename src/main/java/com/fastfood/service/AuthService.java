package com.fastfood.service;

import com.fastfood.common.constant.AuditAction;
import com.fastfood.common.constant.RoleName;
import com.fastfood.common.exception.BusinessException;
import com.fastfood.common.exception.ValidationException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.PasswordUtil;
import com.fastfood.common.util.ValidationUtil;
import com.fastfood.dao.RoleDAO;
import com.fastfood.dao.UserDAO;
import com.fastfood.model.entity.Role;
import com.fastfood.model.entity.User;

/** Đăng nhập, đăng ký và đổi thông tin tài khoản. */
public class AuthService {

    private final UserDAO userDAO = new UserDAO();
    private final RoleDAO roleDAO = new RoleDAO();
    private final AuditService auditService = new AuditService();

    /**
     * Kiểm tra thông tin đăng nhập.
     * <p>
     * Sai email và sai mật khẩu trả về cùng một thông báo, để người ngoài không dò được
     * email nào đã có trong hệ thống.
     */
    public User login(String email, String rawPassword) {
        String normalizedEmail = ValidationUtil.requireEmail(email);
        ValidationUtil.requireText(rawPassword, "mật khẩu");

        User user = Tx.read(con -> userDAO.findByEmail(con, normalizedEmail));
        if (user == null || !PasswordUtil.matches(rawPassword, user.getPasswordHash())) {
            throw new ValidationException("Email hoặc mật khẩu không đúng.");
        }
        if (!user.isActive()) {
            throw new BusinessException("Tài khoản đã bị khoá. Vui lòng liên hệ quản trị viên.");
        }
        return user;
    }

    /** Đăng ký tài khoản khách hàng. Nhân viên do quản trị viên tạo, không tự đăng ký. */
    public User register(String fullName, String email, String phone, String password, String confirmPassword) {
        String name = ValidationUtil.requireText(fullName, "họ tên");
        String normalizedEmail = ValidationUtil.requireEmail(email);
        String normalizedPhone = ValidationUtil.optionalPhone(phone);
        ValidationUtil.requirePasswordStrength(password);
        if (!password.equals(confirmPassword)) {
            throw new ValidationException("Mật khẩu nhập lại không khớp.");
        }

        return Tx.write(con -> {
            if (userDAO.emailExists(con, normalizedEmail)) {
                throw new ValidationException("Email này đã được đăng ký.");
            }
            Role role = roleDAO.findByName(con, RoleName.CUSTOMER.name());
            User u = new User();
            u.setFullName(name);
            u.setEmail(normalizedEmail);
            u.setPhone(normalizedPhone);
            u.setPasswordHash(PasswordUtil.hash(password));
            u.setRoleId(role.getRoleId());
            u.setStatus("ACTIVE");
            u.setCreatedAt(DateTimeUtil.now());
            userDAO.insert(con, u);
            u.setRoleName(role.getName());
            auditService.log(con, u.getUserId(), "USER", u.getUserId(),
                    AuditAction.USER_CHANGED, null, "REGISTERED");
            return u;
        });
    }

    public User findById(int userId) {
        return Tx.read(con -> userDAO.findById(con, userId));
    }

    public void updateProfile(int userId, String fullName, String phone) {
        String name = ValidationUtil.requireText(fullName, "họ tên");
        String normalizedPhone = ValidationUtil.optionalPhone(phone);
        Tx.writeVoid(con -> {
            User u = userDAO.findById(con, userId);
            if (u == null) {
                throw new ValidationException("Không tìm thấy tài khoản.");
            }
            u.setFullName(name);
            u.setPhone(normalizedPhone);
            u.setUpdatedAt(DateTimeUtil.now());
            userDAO.updateProfile(con, u);
        });
    }

    public void changePassword(int userId, String currentPassword, String newPassword, String confirmPassword) {
        ValidationUtil.requirePasswordStrength(newPassword);
        if (!newPassword.equals(confirmPassword)) {
            throw new ValidationException("Mật khẩu nhập lại không khớp.");
        }
        Tx.writeVoid(con -> {
            User u = userDAO.findById(con, userId);
            if (u == null || !PasswordUtil.matches(currentPassword, u.getPasswordHash())) {
                throw new ValidationException("Mật khẩu hiện tại không đúng.");
            }
            // Tự đổi thì gỡ luôn cờ bắt buộc đổi — đây chính là việc mà cờ đó đang chờ.
            userDAO.updatePassword(con, userId, PasswordUtil.hash(newPassword), false);
            auditService.log(con, userId, "USER", userId, AuditAction.USER_CHANGED, null, "PASSWORD_CHANGED");
        });
    }
}
