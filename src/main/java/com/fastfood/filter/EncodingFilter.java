package com.fastfood.filter;

import javax.servlet.*;
import javax.servlet.annotation.WebFilter;
import java.io.IOException;

/**
 * Đặt bảng mã UTF-8 cho mọi request và response.
 * Không có bộ lọc này thì tên món và họ tên tiếng Việt gửi lên từ biểu mẫu sẽ thành ký tự lỗi.
 * Phải chạy trước mọi bộ lọc khác vì việc đọc tham số sẽ chốt bảng mã.
 */
@WebFilter(filterName = "01-EncodingFilter", urlPatterns = "/*")
public class EncodingFilter implements Filter {

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        request.setCharacterEncoding("UTF-8");
        response.setCharacterEncoding("UTF-8");
        chain.doFilter(request, response);
    }
}
