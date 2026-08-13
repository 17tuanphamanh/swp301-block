package com.fastfood.service;

import com.fastfood.common.exception.BusinessException;
import com.fastfood.common.exception.NotFoundException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.ValidationUtil;
import com.fastfood.dao.CartDAO;
import com.fastfood.dao.ProductDAO;
import com.fastfood.model.dto.CartView;
import com.fastfood.model.entity.CartItem;
import com.fastfood.model.entity.Product;

import java.util.List;

/**
 * Giỏ hàng của khách đặt trước.
 * <p>
 * Giỏ chỉ là bản nháp: giá trong giỏ luôn đọc mới từ bảng món chứ không lưu lại,
 * nên khách nhìn thấy giá hiện hành ngay cả khi để giỏ qua đêm. Giá thật chỉ được
 * chốt và sao chép lại vào lúc đặt hàng.
 */
public class CartService {

    private final CartDAO cartDAO = new CartDAO();
    private final ProductDAO productDAO = new ProductDAO();

    public CartView getCart(int userId) {
        return Tx.read(con -> {
            int cartId = cartDAO.getOrCreateCartId(con, userId, DateTimeUtil.now());
            List<CartItem> items = cartDAO.findItems(con, cartId);
            CartView view = new CartView();
            view.setCartId(cartId);
            view.setItems(items);
            return view;
        });
    }

    /** Số món trên biểu tượng giỏ hàng ở thanh điều hướng. */
    public int countItems(int userId) {
        return Tx.read(con -> cartDAO.countItems(con, userId));
    }

    /**
     * Số lượng tối đa một dòng trong giỏ.
     * <p>
     * Ô nhập trên giao diện đã giới hạn, nhưng đó chỉ là gợi ý cho người dùng — gửi thẳng
     * một con số khổng lồ lên vẫn được nhận. Chặn ở đây để thành tiền không vượt quá sức
     * chứa của cột tiền trong cơ sở dữ liệu và làm hỏng cả lượt đặt hàng.
     */
    public static final int MAX_QUANTITY_PER_LINE = 50;

    public void addProduct(int userId, int productId, int quantity) {
        ValidationUtil.requirePositive(quantity, "Số lượng");
        requireSaneQuantity(quantity);
        Tx.writeVoid(con -> {
            Product p = productDAO.findForCheckout(con, productId);
            if (p == null) {
                throw new NotFoundException("Không tìm thấy món ăn.");
            }
            if (!p.isOrderable()) {
                throw new BusinessException("Món \"" + p.getName() + "\" hiện không còn phục vụ.");
            }
            int cartId = cartDAO.getOrCreateCartId(con, userId, DateTimeUtil.now());
            cartDAO.addItem(con, cartId, productId, quantity);
            cartDAO.touch(con, cartId, DateTimeUtil.now());
        });
    }

    private void requireSaneQuantity(int quantity) {
        if (quantity > MAX_QUANTITY_PER_LINE) {
            throw new BusinessException("Mỗi món chỉ đặt được tối đa "
                    + MAX_QUANTITY_PER_LINE + " phần. Cần nhiều hơn, vui lòng liên hệ cửa hàng.");
        }
    }

    /** Đặt lại số lượng; về 0 thì bỏ món khỏi giỏ. */
    public void updateQuantity(int userId, int cartItemId, int quantity) {
        requireSaneQuantity(quantity);
        Tx.writeVoid(con -> {
            int cartId = cartDAO.getOrCreateCartId(con, userId, DateTimeUtil.now());
            if (quantity <= 0) {
                cartDAO.removeItem(con, cartId, cartItemId);
            } else {
                cartDAO.updateQuantity(con, cartId, cartItemId, quantity);
            }
            cartDAO.touch(con, cartId, DateTimeUtil.now());
        });
    }

    public void removeItem(int userId, int cartItemId) {
        Tx.writeVoid(con -> {
            int cartId = cartDAO.getOrCreateCartId(con, userId, DateTimeUtil.now());
            cartDAO.removeItem(con, cartId, cartItemId);
            cartDAO.touch(con, cartId, DateTimeUtil.now());
        });
    }

    /** Bỏ khỏi giỏ những món vừa hết hàng, để khách đi tiếp được mà không phải xoá từng dòng. */
    public int removeUnavailable(int userId) {
        return Tx.write(con -> {
            int cartId = cartDAO.getOrCreateCartId(con, userId, DateTimeUtil.now());
            int removed = 0;
            for (CartItem item : cartDAO.findItems(con, cartId)) {
                if (!item.isOrderable()) {
                    cartDAO.removeItem(con, cartId, item.getCartItemId());
                    removed++;
                }
            }
            cartDAO.touch(con, cartId, DateTimeUtil.now());
            return removed;
        });
    }
}
