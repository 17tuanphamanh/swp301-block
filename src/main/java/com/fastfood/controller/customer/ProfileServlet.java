package com.fastfood.controller.customer;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.AuthService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Thông tin tài khoản và đổi mật khẩu. */
@WebServlet("/profile")
public class ProfileServlet extends BaseServlet {

    private final AuthService authService = new AuthService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        User user = requireUser(req);
        req.setAttribute("profile", authService.findById(user.getUserId()));
        forward(req, resp, "customer/profile.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User user = requireUser(req);
        String action = WebUtil.getString(req, "action");

        if ("changePassword".equals(action)) {
            handle(req, resp, () -> authService.changePassword(user.getUserId(),
                            req.getParameter("currentPassword"),
                            req.getParameter("newPassword"),
                            req.getParameter("confirmPassword")),
                    "Đã đổi mật khẩu.", "/profile");
            return;
        }

        String fullName = WebUtil.getString(req, "fullName");
        String phone = WebUtil.getString(req, "phone");
        handle(req, resp, () -> {
            authService.updateProfile(user.getUserId(), fullName, phone);
            // Cập nhật lại tên hiển thị trên thanh điều hướng ngay, không đợi đăng nhập lại
            user.setFullName(fullName);
            user.setPhone(phone);
        }, "Đã cập nhật thông tin tài khoản.", "/profile");
    }
}
