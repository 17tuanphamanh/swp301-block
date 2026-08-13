package com.fastfood.controller.admin;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.AdminService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Quản lý tài khoản.
 * Nhân viên nghỉ việc thì khoá tài khoản chứ không xoá, để lịch sử đơn do người đó
 * xử lý vẫn tra cứu được.
 */
@WebServlet("/admin/users")
public class UserManageServlet extends BaseServlet {

    private final AdminService adminService = new AdminService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String roleName = WebUtil.getString(req, "role");
        String keyword = WebUtil.getString(req, "keyword");

        req.setAttribute("users", adminService.listUsers(roleName, keyword));
        req.setAttribute("roles", adminService.listRoles());
        req.setAttribute("role", roleName);
        req.setAttribute("keyword", keyword);
        forward(req, resp, "admin/user.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User admin = requireUser(req);
        String action = WebUtil.getString(req, "action");
        int userId = WebUtil.getInt(req, "userId", 0);

        switch (action == null ? "" : action) {
            case "create":
                handle(req, resp, () -> adminService.createStaff(admin.getUserId(),
                                WebUtil.getString(req, "fullName"),
                                WebUtil.getString(req, "email"),
                                WebUtil.getString(req, "phone"),
                                req.getParameter("password"),
                                WebUtil.getInt(req, "roleId", 0)),
                        "Đã tạo tài khoản nhân viên.", "/admin/users");
                return;
            case "lock":
                handle(req, resp, () -> adminService.setUserStatus(admin.getUserId(), userId, "LOCKED"),
                        "Đã khoá tài khoản.", "/admin/users");
                return;
            case "unlock":
                handle(req, resp, () -> adminService.setUserStatus(admin.getUserId(), userId, "ACTIVE"),
                        "Đã mở khoá tài khoản.", "/admin/users");
                return;
            case "changeRole":
                handle(req, resp, () -> adminService.setUserRole(admin.getUserId(), userId,
                                WebUtil.getInt(req, "roleId", 0)),
                        "Đã đổi vai trò.", "/admin/users");
                return;
            case "resetPassword":
                handle(req, resp, () -> adminService.resetPassword(admin.getUserId(), userId,
                                req.getParameter("newPassword")),
                        "Đã đặt lại mật khẩu.", "/admin/users");
                return;
            default:
                redirect(req, resp, "/admin/users");
        }
    }
}
