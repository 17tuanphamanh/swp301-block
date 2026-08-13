package com.fastfood.filter;

import com.fastfood.common.constant.RoleName;
import com.fastfood.common.util.WebUtil;
import com.fastfood.model.entity.User;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Phân quyền theo vai trò dựa trên tiền tố địa chỉ.
 * <p>
 * Kiểm tra ở phía máy chủ chứ không chỉ ẩn nút trên giao diện: người dùng có thể gõ thẳng
 * địa chỉ vào trình duyệt. Ẩn nút là để giao diện gọn, không phải là biện pháp bảo vệ.
 * <p>
 * Quyền theo dữ liệu — như khách chỉ xem được đơn của chính mình — không kiểm tra được ở đây
 * vì phải đọc cơ sở dữ liệu, nên nằm trong tầng Service.
 */
@WebFilter(filterName = "03-RoleAuthorizationFilter",
           urlPatterns = {"/staff/*", "/kitchen/*", "/admin/*"})
public class RoleAuthorizationFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse resp = (HttpServletResponse) response;

        User user = WebUtil.currentUser(req);
        if (user == null) {
            resp.sendRedirect(req.getContextPath() + "/login");
            return;
        }

        String path = req.getRequestURI().substring(req.getContextPath().length());
        RoleName required = requiredRole(path);
        RoleName actual = RoleName.from(user.getRoleName());

        // Quản trị viên xem được mọi màn hình vận hành để hỗ trợ và kiểm tra
        boolean allowed = actual == required || actual == RoleName.ADMIN;
        if (!allowed) {
            req.setAttribute("errorMessage",
                    "Tài khoản của bạn không có quyền truy cập khu vực này.");
            resp.setStatus(HttpServletResponse.SC_FORBIDDEN);
            req.getRequestDispatcher("/WEB-INF/views/error/403.jsp").forward(req, resp);
            return;
        }
        chain.doFilter(request, response);
    }

    private RoleName requiredRole(String path) {
        if (path.startsWith("/staff/")) {
            return RoleName.CASHIER;
        }
        if (path.startsWith("/kitchen/")) {
            return RoleName.KITCHEN;
        }
        return RoleName.ADMIN;
    }
}
