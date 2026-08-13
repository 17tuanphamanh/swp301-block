package com.fastfood.common.util;

import com.fastfood.model.entity.User;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/** Thao tác thường dùng với request và session. */
public final class WebUtil {

    public static final String SESSION_USER = "currentUser";
    public static final String FLASH_SUCCESS = "flashSuccess";
    public static final String FLASH_ERROR = "flashError";

    private WebUtil() {
    }

    public static User currentUser(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        return session == null ? null : (User) session.getAttribute(SESSION_USER);
    }

    public static int currentUserId(HttpServletRequest req) {
        User u = currentUser(req);
        return u == null ? 0 : u.getUserId();
    }

    public static int getInt(HttpServletRequest req, String name, int defaultValue) {
        String raw = req.getParameter(name);
        if (raw == null || raw.isBlank()) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public static Integer getInteger(HttpServletRequest req, String name) {
        String raw = req.getParameter(name);
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public static String getString(HttpServletRequest req, String name) {
        String raw = req.getParameter(name);
        return raw == null ? null : raw.trim();
    }

    public static boolean getBoolean(HttpServletRequest req, String name) {
        String raw = req.getParameter(name);
        return "true".equalsIgnoreCase(raw) || "1".equals(raw) || "on".equalsIgnoreCase(raw);
    }

    public static LocalDateTime getDateTime(HttpServletRequest req, String name) {
        return DateTimeUtil.parseHtmlInput(req.getParameter(name));
    }

    /**
     * Thông báo hiển thị một lần rồi mất, đặt vào session để còn sống qua một lần chuyển hướng.
     * Dùng chuyển hướng thay vì forward sau khi ghi dữ liệu, để khách tải lại trang
     * không gửi lại biểu mẫu lần nữa.
     */
    public static void flashSuccess(HttpServletRequest req, String message) {
        req.getSession().setAttribute(FLASH_SUCCESS, message);
    }

    public static void flashError(HttpServletRequest req, String message) {
        req.getSession().setAttribute(FLASH_ERROR, message);
    }

    /** Chuyển thông báo từ session sang request rồi xoá khỏi session. */
    public static void consumeFlash(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        if (session == null) {
            return;
        }
        Object success = session.getAttribute(FLASH_SUCCESS);
        if (success != null) {
            req.setAttribute(FLASH_SUCCESS, success);
            session.removeAttribute(FLASH_SUCCESS);
        }
        Object error = session.getAttribute(FLASH_ERROR);
        if (error != null) {
            req.setAttribute(FLASH_ERROR, error);
            session.removeAttribute(FLASH_ERROR);
        }
    }

    /**
     * Lọc địa chỉ quay về do người dùng gửi lên.
     * <p>
     * Chỉ chấp nhận đường dẫn nội bộ. Chuỗi bắt đầu bằng {@code //} hay có dấu hai chấm là
     * địa chỉ ra ngoài trá hình: kẻ tấn công gửi liên kết đăng nhập của chính cửa hàng, khách
     * đăng nhập xong bị đẩy sang trang giả mạo mà vẫn tin là mình đang ở đúng nơi.
     * Không hợp lệ thì trả về {@code fallback} chứ không đi tiếp.
     */
    public static String safeRedirect(String target, String fallback) {
        if (target == null || target.isBlank()
                || !target.startsWith("/")
                || target.startsWith("//")
                || target.startsWith("/\\")
                || target.contains(":")) {
            return fallback;
        }
        return target;
    }

    /**
     * Chuỗi tham số hiện tại sau khi bỏ đi những tham số được nêu tên, đã mã hoá sẵn.
     * <p>
     * Dùng cho liên kết chuyển trang: bấm sang trang 2 phải giữ nguyên bộ lọc đang áp dụng,
     * nếu không thì mỗi lần chuyển trang lại nhảy về xem toàn bộ dữ liệu. Bỏ tham số
     * {@code page} ra để thanh chuyển trang tự gắn số trang của nó vào.
     * <p>
     * Trả về chuỗi rỗng khi không còn tham số nào, để nơi gọi tự quyết định có cần dấu
     * {@code &} nối tiếp hay không.
     */
    public static String queryStringWithout(HttpServletRequest req, String... omit) {
        List<String> skip = Arrays.asList(omit);
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String[]> e : req.getParameterMap().entrySet()) {
            if (skip.contains(e.getKey())) {
                continue;
            }
            for (String value : e.getValue()) {
                if (value == null || value.isBlank()) {
                    continue;
                }
                if (sb.length() > 0) {
                    sb.append('&');
                }
                sb.append(URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8))
                  .append('=')
                  .append(URLEncoder.encode(value, StandardCharsets.UTF_8));
            }
        }
        return sb.toString();
    }

    /** Địa chỉ đầy đủ của ứng dụng, dùng dựng địa chỉ quay về cho cổng thanh toán. */
    public static String baseUrl(HttpServletRequest req) {
        String scheme = req.getScheme();
        String host = req.getServerName();
        int port = req.getServerPort();
        String portPart = (("http".equals(scheme) && port == 80) || ("https".equals(scheme) && port == 443))
                ? "" : ":" + port;
        return scheme + "://" + host + portPart + req.getContextPath();
    }
}
