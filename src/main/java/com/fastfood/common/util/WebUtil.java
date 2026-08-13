package com.fastfood.common.util;

import com.fastfood.model.entity.User;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import java.time.LocalDateTime;

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
