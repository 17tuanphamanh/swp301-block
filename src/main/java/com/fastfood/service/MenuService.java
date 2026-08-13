package com.fastfood.service;

import com.fastfood.common.exception.NotFoundException;
import com.fastfood.dao.CategoryDAO;
import com.fastfood.dao.ProductDAO;
import com.fastfood.model.entity.Category;
import com.fastfood.model.entity.Product;

import java.util.List;

/** Thực đơn hiển thị cho khách và cho thu ngân. */
public class MenuService {

    private final ProductDAO productDAO = new ProductDAO();
    private final CategoryDAO categoryDAO = new CategoryDAO();

    public List<Product> browse(Integer categoryId, String keyword) {
        return Tx.read(con -> productDAO.findMenu(con, categoryId, keyword));
    }

    public List<Category> activeCategories() {
        return Tx.read(categoryDAO::findActive);
    }

    /** Xem chi tiết món. Món đã ngừng bán vẫn xem được nhưng không cho thêm vào giỏ. */
    public Product detail(int productId) {
        Product p = Tx.read(con -> productDAO.findById(con, productId));
        if (p == null) {
            throw new NotFoundException("Không tìm thấy món ăn.");
        }
        return p;
    }
}
