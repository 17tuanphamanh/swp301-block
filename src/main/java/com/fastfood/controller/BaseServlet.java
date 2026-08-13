package com.fastfood.controller;

import com.fastfood.common.exception.AppException;
import com.fastfood.common.util.WebUtil;
import com.fastfood.model.entity.User;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Lớp cha cho mọi servlet.
 * <p>
 * Gom hai việc lặp lại ở khắp nơi: chuyển tiếp sang trang JSP, và biến ngoại lệ thành
 * thông báo cho người dùng. Lỗi nghiệp vụ hiện thành thông báo tiếng Việt ngay trên trang;
 * lỗi ngoài dự kiến được ghi log đầy đủ nhưng chỉ hiện thông báo chung, để không lộ
 * cấu trúc hệ thống ra ngoài.
 */
public abstract class BaseServlet extends HttpServlet {

    private static final Logger LOG = Logger.getLogger(BaseServlet.class.getName());

    protected void forward(HttpServletRequest req, HttpServletResponse resp, String view)
            throws ServletException, IOException {
        WebUtil.consumeFlash(req);
        req.getRequestDispatcher("/WEB-INF/views/" + view).forward(req, resp);
    }

    protected void redirect(HttpServletRequest req, HttpServletResponse resp, String path)
            throws IOException {
        resp.sendRedirect(req.getContextPath() + path);
    }

    protected User requireUser(HttpServletRequest req) {
        User user = WebUtil.currentUser(req);
        if (user == null) {
            throw new AppException("Vui lòng đăng nhập.", 401);
        }
        return user;
    }

    /**
     * Chạy một thao tác ghi dữ liệu rồi chuyển hướng.
     * Thất bại thì giữ nguyên thông báo lỗi và quay lại đúng trang cũ, để người dùng
     * sửa và làm lại mà không mất ngữ cảnh.
     */
    protected void handle(HttpServletRequest req, HttpServletResponse resp,
                          Action action, String successMessage, String redirectPath) throws IOException {
        try {
            action.run();
            if (successMessage != null) {
                WebUtil.flashSuccess(req, successMessage);
            }
        } catch (AppException e) {
            WebUtil.flashError(req, e.getMessage());
        } catch (RuntimeException e) {
            LOG.log(Level.SEVERE, "Loi khong mong doi tai " + req.getRequestURI(), e);
            WebUtil.flashError(req, "Có lỗi xảy ra, vui lòng thử lại.");
        }
        redirect(req, resp, redirectPath);
    }

    @FunctionalInterface
    protected interface Action {
        void run();
    }
}
