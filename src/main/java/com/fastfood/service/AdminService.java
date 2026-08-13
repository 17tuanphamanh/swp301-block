package com.fastfood.service;

import com.fastfood.common.constant.AuditAction;
import com.fastfood.common.exception.NotFoundException;
import com.fastfood.common.exception.ValidationException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.PasswordUtil;
import com.fastfood.common.util.ValidationUtil;
import com.fastfood.dao.CategoryDAO;
import com.fastfood.dao.ProductDAO;
import com.fastfood.dao.RoleDAO;
import com.fastfood.dao.UserDAO;
import com.fastfood.model.entity.Category;
import com.fastfood.model.entity.Product;
import com.fastfood.model.entity.Role;
import com.fastfood.model.entity.User;

import java.math.BigDecimal;
import java.util.List;

/**
 * Quản trị danh mục món và tài khoản.
 * <p>
 * Không có thao tác xoá ở tầng này. Món ngừng bán thì chuyển sang trạng thái ngừng kinh doanh,
 * tài khoản nghỉ việc thì khoá lại. Xoá thật sẽ làm hỏng các đơn cũ đang tham chiếu tới.
 */
public class AdminService {

    private final ProductDAO productDAO = new ProductDAO();
    private final CategoryDAO categoryDAO = new CategoryDAO();
    private final UserDAO userDAO = new UserDAO();
    private final RoleDAO roleDAO = new RoleDAO();
    private final AuditService auditService = new AuditService();

    // ------------------------------------------------------------ món ăn

    public List<Product> listProducts(Integer categoryId, String keyword) {
        return Tx.read(con -> productDAO.findAllForAdmin(con, categoryId, keyword));
    }

    public Product findProduct(int productId) {
        Product p = Tx.read(con -> productDAO.findById(con, productId));
        if (p == null) {
            throw new NotFoundException("Không tìm thấy món ăn.");
        }
        return p;
    }

    public void saveProduct(int actorId, Product form) {
        ValidationUtil.requireText(form.getName(), "tên món");
        if (form.getPrice() == null || form.getPrice().compareTo(BigDecimal.ZERO) < 0) {
            throw new ValidationException("Giá bán không hợp lệ.");
        }
        if (form.getCategoryId() <= 0) {
            throw new ValidationException("Vui lòng chọn nhóm món.");
        }

        Tx.writeVoid(con -> {
            if (form.getProductId() > 0) {
                Product current = productDAO.findById(con, form.getProductId());
                if (current == null) {
                    throw new NotFoundException("Không tìm thấy món ăn.");
                }
                form.setUpdatedAt(DateTimeUtil.now());
                productDAO.update(con, form);
                auditService.log(con, actorId, "PRODUCT", form.getProductId(),
                        AuditAction.PRODUCT_CHANGED, current.getPrice().toPlainString(),
                        form.getPrice().toPlainString());
            } else {
                form.setCreatedAt(DateTimeUtil.now());
                productDAO.insert(con, form);
                auditService.log(con, actorId, "PRODUCT", form.getProductId(),
                        AuditAction.PRODUCT_CHANGED, null, "CREATED");
            }
        });
    }

    /** Bật/tắt nhanh tình trạng còn hàng ngay trên danh sách. */
    public void toggleProductAvailability(int actorId, int productId, boolean available) {
        Tx.writeVoid(con -> {
            productDAO.toggleAvailability(con, productId, available);
            auditService.log(con, actorId, "PRODUCT", productId, AuditAction.PRODUCT_CHANGED,
                    null, available ? "AVAILABLE" : "OUT_OF_STOCK");
        });
    }

    // ------------------------------------------------------------ nhóm món

    public List<Category> listCategories() {
        return Tx.read(categoryDAO::findAllWithCount);
    }

    public List<Category> activeCategories() {
        return Tx.read(categoryDAO::findActive);
    }

    public Category findCategory(int categoryId) {
        Category c = Tx.read(con -> categoryDAO.findById(con, categoryId));
        if (c == null) {
            throw new NotFoundException("Không tìm thấy nhóm món.");
        }
        return c;
    }

    public void saveCategory(int actorId, Category form) {
        ValidationUtil.requireText(form.getName(), "tên nhóm món");
        Tx.writeVoid(con -> {
            if (form.getCategoryId() > 0) {
                categoryDAO.update(con, form);
            } else {
                categoryDAO.insert(con, form);
            }
            auditService.log(con, actorId, "CATEGORY", form.getCategoryId(),
                    AuditAction.CATEGORY_CHANGED, null, form.getStatus());
        });
    }

    // ------------------------------------------------------------ tài khoản

    public List<User> listUsers(String roleName, String keyword) {
        return Tx.read(con -> userDAO.search(con, roleName, keyword));
    }

    public List<Role> listRoles() {
        return Tx.read(roleDAO::findAll);
    }

    public User findUser(int userId) {
        User u = Tx.read(con -> userDAO.findById(con, userId));
        if (u == null) {
            throw new NotFoundException("Không tìm thấy tài khoản.");
        }
        return u;
    }

    /** Tạo tài khoản nhân viên. Khách hàng tự đăng ký, nhân viên do quản trị viên tạo. */
    public void createStaff(int actorId, String fullName, String email, String phone,
                            String password, int roleId) {
        String name = ValidationUtil.requireText(fullName, "họ tên");
        String normalizedEmail = ValidationUtil.requireEmail(email);
        String normalizedPhone = ValidationUtil.optionalPhone(phone);
        ValidationUtil.requirePasswordStrength(password);

        Tx.writeVoid(con -> {
            if (userDAO.emailExists(con, normalizedEmail)) {
                throw new ValidationException("Email này đã được sử dụng.");
            }
            User u = new User();
            u.setFullName(name);
            u.setEmail(normalizedEmail);
            u.setPhone(normalizedPhone);
            u.setPasswordHash(PasswordUtil.hash(password));
            u.setRoleId(roleId);
            u.setStatus("ACTIVE");
            u.setCreatedAt(DateTimeUtil.now());
            userDAO.insert(con, u);
            auditService.log(con, actorId, "USER", u.getUserId(),
                    AuditAction.USER_CHANGED, null, "CREATED");
        });
    }

    public void setUserStatus(int actorId, int userId, String status) {
        if (actorId == userId) {
            throw new ValidationException("Không thể tự khoá tài khoản của chính mình.");
        }
        Tx.writeVoid(con -> {
            User u = userDAO.findById(con, userId);
            if (u == null) {
                throw new NotFoundException("Không tìm thấy tài khoản.");
            }
            userDAO.updateStatus(con, userId, status);
            auditService.log(con, actorId, "USER", userId,
                    AuditAction.USER_CHANGED, u.getStatus(), status);
        });
    }

    /**
     * Đổi vai trò của một tài khoản.
     * <p>
     * Chặn quản trị viên tự đổi vai trò của chính mình, cùng lý do với việc chặn tự khoá:
     * hạ quyền của mình là thao tác không tự quay lại được — đăng xuất xong là không còn
     * đường vào khu vực quản trị để sửa lại.
     */
    public void setUserRole(int actorId, int userId, int roleId) {
        if (actorId == userId) {
            throw new ValidationException("Không thể tự đổi vai trò của chính mình.");
        }
        Tx.writeVoid(con -> {
            User u = userDAO.findById(con, userId);
            if (u == null) {
                throw new NotFoundException("Không tìm thấy tài khoản.");
            }
            userDAO.updateRole(con, userId, roleId);
            auditService.log(con, actorId, "USER", userId,
                    AuditAction.USER_CHANGED, u.getRoleName(), "ROLE_" + roleId);
        });
    }

    /**
     * Quản trị viên đặt lại mật khẩu hộ một tài khoản.
     * <p>
     * Mật khẩu đặt ra ở đây là <b>mật khẩu tạm</b>: quản trị viên biết nó, và thường còn phải
     * đọc nó qua điện thoại hoặc nhắn cho người kia. Vì vậy tài khoản bị đánh dấu buộc phải
     * đổi mật khẩu, và {@code AuthenticationFilter} giữ người dùng ở trang tài khoản cho tới
     * khi họ tự đặt mật khẩu mới. Thiếu bước này thì mọi tài khoản từng được đặt lại đều chạy
     * tiếp bằng một mật khẩu mà ít nhất hai người biết.
     */
    public void resetPassword(int actorId, int userId, String newPassword) {
        ValidationUtil.requirePasswordStrength(newPassword);
        if (actorId == userId) {
            // Tự đặt lại cho mình rồi tự bị chặn ở trang tài khoản là vòng luẩn quẩn vô nghĩa;
            // quản trị viên đổi mật khẩu của chính mình ở trang tài khoản.
            throw new ValidationException("Đổi mật khẩu của chính mình ở trang tài khoản.");
        }
        Tx.writeVoid(con -> {
            // Kiểm tra tài khoản có thật trước khi ghi: thiếu bước này thì đặt lại mật khẩu
            // cho một mã không tồn tại vẫn báo "đã đặt lại", trong khi không có gì thay đổi.
            if (userDAO.findById(con, userId) == null) {
                throw new NotFoundException("Không tìm thấy tài khoản.");
            }
            userDAO.updatePassword(con, userId, PasswordUtil.hash(newPassword), true);
            auditService.log(con, actorId, "USER", userId,
                    AuditAction.USER_CHANGED, null, "PASSWORD_RESET");
        });
    }
}
