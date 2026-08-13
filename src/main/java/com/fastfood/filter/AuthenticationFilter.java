package com.fastfood.filter;

import com.fastfood.common.util.WebUtil;
import com.fastfood.model.entity.User;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Set;

/**
 * Chặn các trang cần đăng nhập.
 * <p>
 * Danh sách trang công khai được liệt kê tường minh, còn lại mặc định là phải đăng nhập.
 * Cách này an toàn hơn liệt kê trang cần bảo vệ: thêm màn hình mới mà quên khai báo thì
 * hậu quả là bắt đăng nhập thừa, chứ không phải để lộ dữ liệu.
 */
@WebFilter(filterName = "02-AuthenticationFilter", urlPatterns = "/*")
public class AuthenticationFilter implements Filter {

    /** Trang ai cũng xem được: thực đơn, đăng nhập, đăng ký, tài nguyên tĩnh. */
    private static final Set<String> PUBLIC_PATHS = Set.of(
            "/", "/index.jsp", "/menu", "/product/detail", "/login", "/logout", "/register",
            "/payment/callback"      // cổng thanh toán gọi vào, không có phiên đăng nhập
    );

    private static final Set<String> PUBLIC_PREFIXES = Set.of("/assets/");

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse resp = (HttpServletResponse) response;

        String path = req.getRequestURI().substring(req.getContextPath().length());

        if (isPublic(path)) {
            chain.doFilter(request, response);
            return;
        }

        User user = WebUtil.currentUser(req);
        if (user == null) {
            // Nhớ trang khách định vào để đăng nhập xong quay lại đúng chỗ đó
            String target = req.getQueryString() == null ? path : path + "?" + req.getQueryString();
            req.getSession().setAttribute("redirectAfterLogin", target);
            resp.sendRedirect(req.getContextPath() + "/login");
            return;
        }
        chain.doFilter(request, response);
    }

    private boolean isPublic(String path) {
        if (PUBLIC_PATHS.contains(path)) {
            return true;
        }
        for (String prefix : PUBLIC_PREFIXES) {
            if (path.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }
}
