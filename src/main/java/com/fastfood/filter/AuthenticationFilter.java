package com.fastfood.filter;

import com.fastfood.common.util.WebUtil;
import com.fastfood.model.entity.User;

import javax.servlet.*;
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
 * <p>
 * Khai báo và thứ tự nằm trong {@code WEB-INF/web.xml} — xem ghi chú ở đó.
 */
public class AuthenticationFilter implements Filter {

    /** Trang ai cũng xem được: thực đơn, đăng nhập, đăng ký, tài nguyên tĩnh. */
    private static final Set<String> PUBLIC_PATHS = Set.of(
            "/", "/index.jsp", "/menu", "/product/detail", "/login", "/logout", "/register",
            "/payment/callback"      // cổng thanh toán gọi vào, không có phiên đăng nhập
    );

    private static final Set<String> PUBLIC_PREFIXES = Set.of("/assets/");

    /**
     * Nơi duy nhất một tài khoản đang bị buộc đổi mật khẩu còn đi tới được.
     * Phải có {@code /logout}, nếu không thì người dùng bị kẹt hẳn: không đổi được mật khẩu
     * mà cũng không thoát ra để đăng nhập bằng tài khoản khác.
     */
    private static final Set<String> PASSWORD_CHANGE_PATHS = Set.of("/profile", "/logout");

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

        // Mật khẩu do quản trị viên đặt hộ là mật khẩu ít nhất hai người biết. Giữ tài khoản
        // ở trang tài khoản cho tới khi chủ tài khoản tự đặt lại — chặn ở đây chứ không ở
        // từng màn hình, vì chỉ cần sót một màn hình là rào chắn mất tác dụng.
        if (user.isMustChangePassword() && !PASSWORD_CHANGE_PATHS.contains(path)) {
            WebUtil.flashError(req, "Mật khẩu của bạn vừa được quản trị viên đặt lại. "
                    + "Vui lòng đặt mật khẩu mới trước khi tiếp tục.");
            resp.sendRedirect(req.getContextPath() + "/profile");
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
