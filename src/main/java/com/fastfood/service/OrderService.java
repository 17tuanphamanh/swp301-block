package com.fastfood.service;

import com.fastfood.common.constant.*;
import com.fastfood.common.exception.BusinessException;
import com.fastfood.common.exception.NotFoundException;
import com.fastfood.common.exception.ValidationException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.PickupCodeGenerator;
import com.fastfood.config.AppConfig;
import com.fastfood.dao.*;
import com.fastfood.model.dto.PosLine;
import com.fastfood.model.entity.*;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Nghiệp vụ đơn hàng — lớp trung tâm của hệ thống.
 * <p>
 * Hai luồng đặt hàng khác nhau ở chỗ nào:
 * <ul>
 *   <li><b>Đặt trước</b> — khách chọn giờ nhận, trả tiền online, đơn nằm chờ tới sát giờ mới
 *       xuống bếp. Khách nhận món bằng mã nhận hàng.</li>
 *   <li><b>Tại quầy</b> — thu ngân lập đơn, thu tiền, đơn xuống bếp ngay và khách đứng đợi.</li>
 * </ul>
 * Trạng thái "đang chế biến" và "sẵn sàng" của đơn không do ai bấm trực tiếp mà được suy ra
 * từ trạng thái các món — xem {@link #recalculateStatus}.
 */
public class OrderService {

    private final OrderDAO orderDAO = new OrderDAO();
    private final OrderItemDAO orderItemDAO = new OrderItemDAO();
    private final PaymentDAO paymentDAO = new PaymentDAO();
    private final ProductDAO productDAO = new ProductDAO();
    private final CartDAO cartDAO = new CartDAO();
    private final AuditService auditService = new AuditService();
    private final NotificationService notificationService = new NotificationService();

    // ============================================================ tạo đơn

    /**
     * Tạo đơn đặt trước từ giỏ hàng của khách.
     * <p>
     * Ngay trước khi tạo đơn, từng món trong giỏ được đọc lại từ bảng món: giữa lúc khách bỏ
     * vào giỏ và lúc bấm đặt, quản trị viên có thể đã đổi giá hoặc đánh dấu hết hàng. Giá được
     * dùng là giá đọc lại này, và nó được sao chép vào đơn để hoá đơn không đổi về sau.
     * <p>
     * Đơn tạo ra ở trạng thái chờ thanh toán; chỉ khi tiền về đơn mới được xác nhận.
     */
    public Order createOnlineOrder(int customerId, LocalDateTime pickupTime, String idempotencyKey) {
        LocalDateTime now = DateTimeUtil.now();
        validatePickupTime(pickupTime, now);

        return Tx.write(con -> {
            // Khách bấm đặt hàng hai lần (bấm đúp, hoặc tải lại trang) chỉ tạo một đơn
            if (idempotencyKey != null) {
                Order existing = orderDAO.findByIdempotencyKey(con, idempotencyKey);
                if (existing != null) {
                    return existing;
                }
            }

            int cartId = cartDAO.getOrCreateCartId(con, customerId, now);
            List<CartItem> cartItems = cartDAO.findItems(con, cartId);
            if (cartItems.isEmpty()) {
                throw new BusinessException("Giỏ hàng đang trống.");
            }

            Order order = new Order();
            order.setCustomerId(customerId);
            order.setCreatedByUserId(customerId);
            order.setOrderSource(OrderSource.ONLINE_PREORDER.name());
            order.setOrderStatus(OrderStatus.PENDING_PAYMENT.name());
            order.setPickupTime(pickupTime);
            order.setIdempotencyKey(idempotencyKey);
            order.setCreatedAt(now);
            order.setTotalAmount(BigDecimal.ZERO);
            orderDAO.insert(con, order);

            BigDecimal total = BigDecimal.ZERO;
            for (CartItem line : cartItems) {
                Product product = productDAO.findForCheckout(con, line.getProductId());
                if (product == null || !product.isOrderable()) {
                    throw new BusinessException("Món \"" + line.getProductName()
                            + "\" vừa hết hàng. Vui lòng cập nhật lại giỏ hàng.");
                }
                OrderItem item = new OrderItem();
                item.setOrderId(order.getOrderId());
                item.setProductId(product.getProductId());
                item.setProductNameSnapshot(product.getName());
                item.setUnitPrice(product.getPrice());
                item.setQuantity(line.getQuantity());
                item.setItemStatus(OrderItemStatus.WAITING.name());
                orderItemDAO.insert(con, item);
                order.getItems().add(item);
                total = total.add(item.getLineTotal());
            }

            order.setTotalAmount(total);
            orderDAO.updateTotal(con, order.getOrderId(), total);
            cartDAO.clear(con, cartId);

            auditService.log(con, customerId, "ORDER", order.getOrderId(),
                    AuditAction.ORDER_CREATED, null, OrderStatus.PENDING_PAYMENT.name());
            return order;
        });
    }

    /**
     * Thu ngân lập đơn cho khách tại quầy.
     * <p>
     * Khác đơn đặt trước ở chỗ tiền được thu ngay tại chỗ, nên toàn bộ đặt hàng - thanh toán -
     * xác nhận - đưa xuống bếp diễn ra trong cùng một giao dịch. Khách đứng đợi nên không có
     * giờ hẹn và không cần mã nhận hàng.
     */
    public Order createPosOrder(int cashierId, List<PosLine> lines, PaymentMethod method) {
        if (lines == null || lines.isEmpty()) {
            throw new ValidationException("Chưa chọn món nào.");
        }
        LocalDateTime now = DateTimeUtil.now();

        return Tx.write(con -> {
            Order order = new Order();
            order.setCustomerId(null);              // khách vãng lai, không cần tài khoản
            order.setCreatedByUserId(cashierId);
            order.setOrderSource(OrderSource.POS.name());
            order.setOrderStatus(OrderStatus.CONFIRMED.name());
            order.setCreatedAt(now);
            order.setReleasedToKdsAt(now);          // bếp thấy đơn ngay lập tức
            order.setTotalAmount(BigDecimal.ZERO);
            orderDAO.insert(con, order);

            BigDecimal total = BigDecimal.ZERO;
            for (PosLine line : lines) {
                Product product = productDAO.findForCheckout(con, line.getProductId());
                if (product == null || !product.isOrderable()) {
                    throw new BusinessException("Món đã chọn hiện không còn phục vụ.");
                }
                OrderItem item = new OrderItem();
                item.setOrderId(order.getOrderId());
                item.setProductId(product.getProductId());
                item.setProductNameSnapshot(product.getName());
                item.setUnitPrice(product.getPrice());
                item.setQuantity(line.getQuantity());
                item.setItemStatus(OrderItemStatus.WAITING.name());
                orderItemDAO.insert(con, item);
                order.getItems().add(item);
                total = total.add(item.getLineTotal());
            }

            order.setTotalAmount(total);
            orderDAO.updateTotal(con, order.getOrderId(), total);

            Payment payment = new Payment();
            payment.setOrderId(order.getOrderId());
            payment.setMethod(method.name());
            payment.setAmount(total);
            payment.setPaymentStatus(PaymentStatus.PAID.name());
            payment.setAttemptNo(1);
            payment.setCreatedAt(now);
            payment.setPaidAt(now);
            paymentDAO.insert(con, payment);
            order.setLatestPayment(payment);

            auditService.log(con, cashierId, "ORDER", order.getOrderId(),
                    AuditAction.ORDER_CREATED, null, OrderStatus.CONFIRMED.name());
            auditService.log(con, cashierId, "PAYMENT", payment.getPaymentId(),
                    AuditAction.PAYMENT_PAID, null, method.name());
            auditService.log(con, cashierId, "ORDER", order.getOrderId(),
                    AuditAction.KDS_RELEASE, null, "RELEASED");
            return order;
        });
    }

    /**
     * Kiểm tra giờ hẹn nhận hàng.
     * Phải cách hiện tại một khoảng tối thiểu để còn đủ thời gian thanh toán và chế biến.
     */
    public void validatePickupTime(LocalDateTime pickupTime, LocalDateTime now) {
        if (pickupTime == null) {
            throw new ValidationException("Vui lòng chọn giờ đến lấy hàng.");
        }
        int minLead = AppConfig.pickupMinLeadMinutes();
        if (pickupTime.isBefore(now.plusMinutes(minLead))) {
            throw new ValidationException("Giờ nhận hàng phải cách hiện tại ít nhất "
                    + minLead + " phút.");
        }
        if (pickupTime.isAfter(now.plusDays(7))) {
            throw new ValidationException("Chỉ nhận đặt trước tối đa 7 ngày.");
        }
    }

    /** Giờ hẹn sớm nhất mà khách được chọn — dùng để đặt giá trị nhỏ nhất cho ô nhập trên giao diện. */
    public LocalDateTime earliestPickupTime() {
        return DateTimeUtil.now().plusMinutes(AppConfig.pickupMinLeadMinutes());
    }

    // ============================================================ xác nhận sau thanh toán

    /**
     * Xác nhận đơn đặt trước sau khi tiền đã về.
     * <p>
     * Gọi từ {@link PaymentService} trong cùng giao dịch với việc ghi nhận thanh toán.
     * Ở bước này mới sinh mã nhận hàng và chốt giờ đưa xuống bếp, vì đơn chưa trả tiền
     * thì không cần cả hai thứ đó.
     * <p>
     * Trả về false nếu đơn đã được xác nhận trước đó — tình huống bình thường khi cổng
     * thanh toán gửi kết quả về nhiều lần.
     */
    public boolean confirmOnlineAfterPaid(Connection con, Order order, LocalDateTime now) throws SQLException {
        String pickupCode = PickupCodeGenerator.generate();
        LocalDateTime releaseAt = order.getPickupTime().minusMinutes(AppConfig.kitchenPrepLeadMinutes());

        int changed = orderDAO.confirmOnlineAfterPaid(con, order.getOrderId(), pickupCode, releaseAt);
        if (changed == 0) {
            return false;
        }

        order.setOrderStatus(OrderStatus.CONFIRMED.name());
        order.setPickupCode(pickupCode);
        order.setKitchenReleaseAt(releaseAt);

        auditService.logSystem(con, "ORDER", order.getOrderId(),
                AuditAction.AUTO_CONFIRM, OrderStatus.CONFIRMED.name());
        notificationService.notifyOrderConfirmed(con, order);
        return true;
    }

    // ============================================================ đọc

    public Order findById(int orderId) {
        Order order = Tx.read(con -> loadFull(con, orderId));
        if (order == null) {
            throw new NotFoundException("Không tìm thấy đơn hàng.");
        }
        return order;
    }

    /**
     * Lấy đơn của chính khách đang đăng nhập.
     * Đơn của người khác trả về "không tìm thấy" chứ không phải "không có quyền", để không
     * tiết lộ rằng mã đơn đó có tồn tại.
     */
    public Order findForCustomer(int orderId, int customerId) {
        Order order = Tx.read(con -> loadFull(con, orderId));
        if (order == null || order.getCustomerId() == null || order.getCustomerId() != customerId) {
            throw new NotFoundException("Không tìm thấy đơn hàng.");
        }
        return order;
    }

    public List<Order> historyOfCustomer(int customerId) {
        return Tx.read(con -> orderDAO.findByCustomer(con, customerId));
    }

    public List<Order> activeOrdersOfCustomer(int customerId) {
        return Tx.read(con -> orderDAO.findActiveByCustomer(con, customerId));
    }

    /** Bốn tab trên màn hình đơn hàng của thu ngân. */
    public List<Order> dashboard(String tab) {
        return Tx.read(con -> orderDAO.findForDashboard(con, tab, DateTimeUtil.now(),
                AppConfig.pickupOverdueMinutes()));
    }

    public List<Order> search(String source, String status, LocalDateTime from, LocalDateTime to) {
        return Tx.read(con -> orderDAO.search(con, source, status, from, to));
    }

    // ============================================================ huỷ đơn

    /**
     * Khách tự huỷ đơn.
     * <p>
     * Chỉ cho phép khi bếp chưa nhận việc. Điều kiện này nằm ngay trong câu lệnh cập nhật,
     * nên nếu bộ hẹn giờ vừa đưa đơn xuống bếp đúng lúc khách bấm huỷ thì việc huỷ sẽ
     * thất bại chứ không huỷ nhầm đơn đang nấu.
     */
    public void cancelByCustomer(int orderId, int customerId) {
        Tx.writeVoid(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null || order.getCustomerId() == null || order.getCustomerId() != customerId) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            doCancel(con, order, customerId);
        });
    }

    /** Thu ngân huỷ đơn giúp khách. */
    public void cancelByStaff(int orderId, int staffId) {
        Tx.writeVoid(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            doCancel(con, order, staffId);
        });
    }

    private void doCancel(Connection con, Order order, int actorId) throws SQLException {
        if (!OrderStatus.CONFIRMED.name().equals(order.getOrderStatus())) {
            throw new BusinessException("Chỉ huỷ được đơn đang ở trạng thái đã xác nhận.");
        }
        int changed = orderDAO.markCancelled(con, order.getOrderId(), DateTimeUtil.now());
        if (changed == 0) {
            throw new BusinessException("Bếp đã bắt đầu chuẩn bị đơn này nên không thể huỷ.");
        }
        auditService.log(con, actorId, "ORDER", order.getOrderId(),
                AuditAction.ORDER_CANCELLED, order.getOrderStatus(), OrderStatus.CANCELLED.name());

        // Đơn đã trả tiền thì hoàn lại toàn bộ; hệ thống không có hoàn một phần
        Payment paid = paymentDAO.findPaidByOrder(con, order.getOrderId());
        if (paid != null) {
            paymentDAO.markRefunded(con, paid.getPaymentId(), DateTimeUtil.now());
            auditService.log(con, actorId, "PAYMENT", paid.getPaymentId(),
                    AuditAction.PAYMENT_REFUNDED, PaymentStatus.PAID.name(), PaymentStatus.REFUNDED.name());
        }
    }

    // ============================================================ giao món

    /** Tra đơn theo mã nhận hàng khi khách tới quầy. */
    public Order findByPickupCode(String code) {
        String normalized = code == null ? "" : code.trim().toUpperCase();
        if (normalized.isEmpty()) {
            throw new ValidationException("Vui lòng nhập mã nhận hàng.");
        }
        Order order = Tx.read(con -> {
            Order o = orderDAO.findByPickupCode(con, normalized);
            if (o != null) {
                o.setItems(orderItemDAO.findByOrder(con, o.getOrderId()));
                o.setLatestPayment(paymentDAO.findLatestByOrder(con, o.getOrderId()));
            }
            return o;
        });
        if (order == null) {
            throw new NotFoundException("Không tìm thấy đơn hàng với mã này.");
        }
        return order;
    }

    /**
     * Giao món cho khách.
     * <p>
     * Ba điều kiện phải cùng đúng: món đã sẵn sàng, tiền đã thu, và với đơn đặt trước thì
     * mã khách đưa phải khớp. Kiểm tra ở phía máy chủ chứ không dựa vào giao diện, vì
     * đây là bước quyết định món ra khỏi cửa hàng.
     */
    public Order handoff(int orderId, int cashierId, String presentedCode) {
        LocalDateTime now = DateTimeUtil.now();
        return Tx.write(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            if (!OrderStatus.READY.name().equals(order.getOrderStatus())) {
                throw new BusinessException("Đơn chưa sẵn sàng để giao.");
            }
            Payment paid = paymentDAO.findPaidByOrder(con, orderId);
            if (paid == null) {
                throw new BusinessException("Đơn chưa được thanh toán.");
            }
            if (order.isOnline()) {
                String expected = order.getPickupCode();
                String given = presentedCode == null ? "" : presentedCode.trim().toUpperCase();
                if (expected == null || !expected.equals(given)) {
                    auditService.log(con, cashierId, "ORDER", orderId,
                            AuditAction.PICKUP_VERIFY_FAILED, expected, given);
                    throw new BusinessException("Mã nhận hàng không khớp với đơn này.");
                }
                auditService.log(con, cashierId, "ORDER", orderId,
                        AuditAction.PICKUP_VERIFY_OK, null, expected);
            }

            int changed = orderDAO.markCompleted(con, orderId, cashierId, now);
            if (changed == 0) {
                throw new BusinessException("Đơn vừa được xử lý bởi người khác. Vui lòng tải lại.");
            }
            auditService.log(con, cashierId, "ORDER", orderId,
                    AuditAction.HANDOFF, OrderStatus.READY.name(), OrderStatus.COMPLETED.name());

            order.setOrderStatus(OrderStatus.COMPLETED.name());
            order.setCompletedAt(now);
            order.setPickedUpAt(now);
            return order;
        });
    }

    // ============================================================ tổng hợp trạng thái

    /**
     * Cập nhật lại trạng thái đơn sau khi một món đổi trạng thái.
     * <p>
     * Trạng thái đơn không do ai bấm mà được suy ra: còn món chưa xong thì đơn đang chế biến,
     * hết món chưa xong thì đơn sẵn sàng.
     * <p>
     * Dòng đơn được khoá trước khi đếm. Không khoá thì hai đầu bếp hoàn thành hai món cuối
     * cùng gần như đồng thời sẽ cùng đếm thấy "vẫn còn món chưa xong", và đơn kẹt vĩnh viễn
     * ở trạng thái đang chế biến dù bếp đã làm xong hết.
     *
     * @return true nếu đơn vừa chuyển sang sẵn sàng
     */
    public boolean recalculateStatus(Connection con, int orderId, LocalDateTime now) throws SQLException {
        orderDAO.lockForUpdate(con, orderId);

        int unready = orderItemDAO.countUnready(con, orderId);
        if (unready > 0) {
            orderDAO.markPreparing(con, orderId);
            return false;
        }

        int changed = orderDAO.markReady(con, orderId, now);
        if (changed == 0) {
            return false;   // đơn đã sẵn sàng từ trước
        }

        Order order = orderDAO.findById(con, orderId);
        auditService.logSystem(con, "ORDER", orderId, AuditAction.ORDER_READY, OrderStatus.READY.name());
        notificationService.notifyOrderReady(con, order);
        return true;
    }

    // ============================================================ dùng chung

    /** Nạp đơn kèm danh sách món và lần thanh toán gần nhất. */
    private Order loadFull(Connection con, int orderId) throws SQLException {
        Order order = orderDAO.findById(con, orderId);
        if (order == null) {
            return null;
        }
        order.setItems(orderItemDAO.findByOrder(con, orderId));
        order.setLatestPayment(paymentDAO.findLatestByOrder(con, orderId));
        return order;
    }
}
