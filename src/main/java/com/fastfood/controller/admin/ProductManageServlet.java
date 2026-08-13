package com.fastfood.controller.admin;

import com.fastfood.common.util.WebUtil;
import com.fastfood.controller.BaseServlet;
import com.fastfood.model.entity.Product;
import com.fastfood.model.entity.User;
import com.fastfood.service.AdminService;

import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.math.BigDecimal;

/**
 * Quản lý món ăn.
 * <p>
 * Không có nút xoá: món ngừng bán thì chuyển sang trạng thái ngừng kinh doanh. Xoá thật
 * sẽ làm hỏng các đơn cũ đang tham chiếu tới món đó.
 */
@WebServlet("/admin/products")
public class ProductManageServlet extends BaseServlet {

    private final AdminService adminService = new AdminService();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        Integer categoryId = WebUtil.getInteger(req, "categoryId");
        String keyword = WebUtil.getString(req, "keyword");
        int editId = WebUtil.getInt(req, "edit", 0);

        req.setAttribute("products", adminService.listProducts(categoryId, keyword));
        req.setAttribute("categories", adminService.activeCategories());
        req.setAttribute("selectedCategory", categoryId);
        req.setAttribute("keyword", keyword);
        if (editId > 0) {
            req.setAttribute("editing", adminService.findProduct(editId));
        }
        forward(req, resp, "admin/product.jsp");
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        User admin = requireUser(req);
        String action = WebUtil.getString(req, "action");

        if ("toggle".equals(action)) {
            int productId = WebUtil.getInt(req, "productId", 0);
            boolean available = WebUtil.getBoolean(req, "available");
            handle(req, resp, () -> adminService.toggleProductAvailability(admin.getUserId(), productId, available),
                    available ? "Đã đánh dấu món còn hàng." : "Đã đánh dấu món tạm hết hàng.",
                    "/admin/products");
            return;
        }

        Product form = new Product();
        form.setProductId(WebUtil.getInt(req, "productId", 0));
        form.setCategoryId(WebUtil.getInt(req, "categoryId", 0));
        form.setName(WebUtil.getString(req, "name"));
        form.setDescription(WebUtil.getString(req, "description"));
        form.setImageUrl(WebUtil.getString(req, "imageUrl"));
        form.setAvailable(WebUtil.getBoolean(req, "available"));
        form.setStatus(WebUtil.getBoolean(req, "active") ? "ACTIVE" : "INACTIVE");
        try {
            form.setPrice(new BigDecimal(WebUtil.getString(req, "price")));
        } catch (RuntimeException e) {
            form.setPrice(BigDecimal.valueOf(-1));   // để tầng dịch vụ báo lỗi giá không hợp lệ
        }

        handle(req, resp, () -> adminService.saveProduct(admin.getUserId(), form),
                form.getProductId() > 0 ? "Đã cập nhật món ăn." : "Đã thêm món mới.",
                "/admin/products");
    }
}
