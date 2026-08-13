package com.fastfood.controller.auth;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.User;
import com.fastfood.service.AuthService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/** Đăng ký tài khoản khách hàng. Tài khoản nhân viên do quản trị viên tạo. */
@WebServlet("/register")
public class RegisterServlet extends BaseServlet {

    private final AuthService authService = new AuthService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        forward(req, resp, "auth/register.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        try {
            User user = authService.register(
                    WebUtil.getString(req, "fullName"),
                    WebUtil.getString(req, "email"),
                    WebUtil.getString(req, "phone"),
                    req.getParameter("password"),
                    req.getParameter("confirmPassword"));
            req.getSession(true).setAttribute(WebUtil.SESSION_USER, user);
            WebUtil.flashSuccess(req, "Đăng ký thành công. Chào mừng " + user.getFullName() + "!");
            redirect(req, resp, "/menu");
        } catch (AppException e) {
            req.setAttribute("errorMessage", e.getMessage());
            req.setAttribute("fullName", WebUtil.getString(req, "fullName"));
            req.setAttribute("email", WebUtil.getString(req, "email"));
            req.setAttribute("phone", WebUtil.getString(req, "phone"));
            forward(req, resp, "auth/register.jsp");
        }
    }
}
