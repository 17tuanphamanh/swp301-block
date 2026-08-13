package com.fastfood.service;

import com.fastfood.common.constant.*;
import com.fastfood.common.exception.BusinessException;
import com.fastfood.common.exception.NotFoundException;
import com.fastfood.common.exception.ValidationException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.common.util.PickupCodeGenerator;
import com.fastfood.config.AppConfig;
import com.fastfood.dao.*;
import com.fastfood.model.dto.Page;
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

    /** Số lần sinh lại mã nhận hàng khi gặp mã đã có. Xem {@link #confirmOnlineAfterPaid}. */
    private static final int PICKUP_CODE_ATTEMPTS = 5;

    /**
     * Tên "cổng thanh toán" ghi vào nhật ký đối soát cho khoản thu bằng thẻ hoặc mã QR tại quầy.
     * Không phải cổng trực tuyến: tiền chạy qua máy thanh toán đặt ở quầy, hệ thống chỉ lưu
     * lại mã giao dịch in trên biên lai để sau này đối chiếu với sao kê.
     */
    private static final String POS_TERMINAL = "POS_TERMINAL";

    /**
     * Lời từ chối khi bếp đã bắt tay vào làm.
     * <p>
     * Dùng chung cho hai đường tới cùng một kết luận: đơn đã chuyển sang đang chế biến, và
     * đơn còn ở trạng thái đã xác nhận nhưng vừa có món được nhận. Người dùng chỉ thấy một
     * tình huống nên chỉ được nghe một câu trả lời, và câu đó phải chỉ ra việc tiếp theo cần
     * làm — báo "không huỷ được" rồi thôi thì khách chỉ còn cách gọi điện hỏi cho ra chuyện.
     */
    private static final String KITCHEN_ALREADY_STARTED =
            "Bếp đã bắt đầu chuẩn bị đơn này nên không thể huỷ. Vui lòng liên hệ nhân viên tại quầy.";

    private final OrderDAO orderDAO = new OrderDAO();
    private final OrderItemDAO orderItemDAO = new OrderItemDAO();
    private final PaymentDAO paymentDAO = new PaymentDAO();
    private final TransactionDAO transactionDAO = new TransactionDAO();
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

        try {
            return doCreateOnlineOrder(customerId, pickupTime, idempotencyKey, now);
        } catch (RuntimeException e) {
            // Hai lần bấm gần như cùng lúc: cả hai cùng đọc thấy "chưa có đơn nào", cùng ghi,
            // và lần thứ hai đụng ràng buộc duy nhất trên khoá chống trùng. Đây chính là lúc
            // chống trùng phát huy tác dụng, nên trả về đơn mà lần thứ nhất vừa tạo
            // thay vì báo lỗi cho khách.
            if (idempotencyKey == null || !JdbcSupport.isUniqueViolation(e)) {
                throw e;
            }
            Order existing = Tx.read(con -> loadFull(con, idempotencyKey));
            if (existing == null) {
                throw e;
            }
            return existing;
        }
    }

    private Order doCreateOnlineOrder(int customerId, LocalDateTime pickupTime,
                                      String idempotencyKey, LocalDateTime now) {
        return Tx.write(con -> {
            // Khách bấm đặt hàng hai lần (bấm đúp, hoặc tải lại trang) chỉ tạo một đơn
            if (idempotencyKey != null) {
                Order existing = orderDAO.findByIdempotencyKey(con, idempotencyKey);
                if (existing != null) {
                    existing.setItems(orderItemDAO.findByOrder(con, existing.getOrderId()));
                    return existing;
                }
            }

            // Giỏ hàng chỉ được dọn khi tiền về, nên khách còn đang dở dang ở cổng thanh toán
            // thì giỏ vẫn nguyên hàng. Thiếu chốt này, khách bấm quay lại rồi đặt tiếp sẽ có
            // hai đơn cho cùng một lần mua.
            Order pending = orderDAO.findPendingByCustomer(con, customerId);
            if (pending != null) {
                // Nói rõ đường thoát. Chặn mà không chỉ chỗ đi tiếp thì khách tưởng mình bị kẹt
                // cho tới khi đơn cũ tự hết hạn — cả hai việc dưới đây đều làm ngay được ở
                // trang theo dõi đơn.
                throw new BusinessException("Bạn đang có đơn #" + pending.getOrderId()
                        + " chờ thanh toán. Mở đơn đó ở mục \"Đơn của tôi\" để thanh toán nốt,"
                        + " hoặc huỷ đi rồi đặt lại — đơn chưa thanh toán huỷ được ngay.");
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
            // Giỏ hàng KHÔNG dọn ở đây mà đợi tới lúc tiền về — xem confirmOnlineAfterPaid.
            // Dọn sớm thì khách thanh toán hỏng hoặc để quá hạn sẽ mất sạch giỏ và phải chọn
            // lại từ đầu, trong khi họ chẳng làm gì sai.

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
     * <p>
     * Hai hình thức thu tiền được xác nhận theo hai cách khác nhau:
     * <ul>
     *   <li><b>Tiền mặt</b> — thu ngân đếm tiền, không có gì để đối chiếu về sau ngoài chính
     *       bản ghi này.</li>
     *   <li><b>Thẻ hoặc mã QR</b> — tiền chạy qua máy thanh toán ở quầy chứ không qua hệ thống,
     *       nên bản ghi "đã thu" ở đây chỉ là lời khai của thu ngân. Vì vậy bắt buộc phải nhập
     *       mã giao dịch in trên biên lai, và mã đó được ghi vào nhật ký đối soát. Ràng buộc
     *       duy nhất trên mã khiến một biên lai không thể dùng cho hai đơn — chặn đúng tình
     *       huống thu ngân lỡ tay lập lại đơn cho một lần quẹt thẻ.</li>
     * </ul>
     *
     * @param terminalReference mã giao dịch trên biên lai máy thanh toán; bỏ trống khi trả tiền mặt
     */
    public Order createPosOrder(int cashierId, List<PosLine> lines, PaymentMethod method,
                                String terminalReference) {
        if (lines == null || lines.isEmpty()) {
            throw new ValidationException("Chưa chọn món nào.");
        }
        if (method == null) {
            throw new ValidationException("Chưa chọn hình thức thanh toán.");
        }
        String reference = terminalReference == null ? "" : terminalReference.trim().toUpperCase();
        if (method == PaymentMethod.ONLINE_GATEWAY && reference.isEmpty()) {
            throw new ValidationException(
                    "Vui lòng nhập mã giao dịch in trên biên lai của máy thanh toán.");
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
                // Phiếu tạm nằm trong phiên của thu ngân nhưng số lượng vẫn do trình duyệt gửi lên,
                // nên vẫn phải kiểm ở đây chứ không tin vào giới hạn của ô nhập.
                if (line.getQuantity() <= 0 || line.getQuantity() > CartService.MAX_QUANTITY_PER_LINE) {
                    throw new ValidationException("Số lượng mỗi món phải từ 1 đến "
                            + CartService.MAX_QUANTITY_PER_LINE + ".");
                }
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

            // Khoản thu qua máy thanh toán phải để lại dấu vết đối soát. Ghi mã biên lai vào
            // cùng bảng với giao dịch của cổng trực tuyến, nên báo cáo đối soát chỉ cần đọc
            // một nơi, và ràng buộc duy nhất bảo vệ cả hai đường thu tiền như nhau.
            if (method == PaymentMethod.ONLINE_GATEWAY) {
                Transaction txn = transactionDAO.newTransaction(payment.getPaymentId(), POS_TERMINAL,
                        reference, "SUCCESS", "Thu tại quầy, mã biên lai do thu ngân nhập.", now);
                if (!transactionDAO.insertIfNew(con, txn)) {
                    throw new BusinessException("Mã giao dịch \"" + reference
                            + "\" đã được ghi nhận cho một đơn khác. Vui lòng kiểm tra lại biên lai — "
                            + "một lần thanh toán chỉ dùng được cho một đơn.");
                }
            }

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
     * <p>
     * Ba điều kiện: cách hiện tại đủ xa để còn kịp thanh toán và chế biến, không quá 7 ngày,
     * và nằm trong giờ mở cửa. Điều kiện cuối không thừa — thiếu nó thì khách hẹn 3 giờ sáng
     * vẫn đặt được và bộ hẹn giờ vẫn đẩy đơn xuống bếp lúc 2 giờ 40 khi không có ai ở cửa hàng.
     * <p>
     * Giờ hẹn còn phải muộn hơn giờ mở cửa ít nhất bằng thời gian chuẩn bị, vì đơn được đưa
     * xuống bếp trước giờ hẹn đúng khoảng đó.
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

        int openHour = AppConfig.storeOpenHour();
        int closeHour = AppConfig.storeCloseHour();
        LocalDateTime earliestThatDay = pickupTime.toLocalDate().atTime(openHour, 0)
                .plusMinutes(AppConfig.kitchenPrepLeadMinutes());
        if (pickupTime.isBefore(earliestThatDay) || pickupTime.getHour() >= closeHour) {
            throw new ValidationException(String.format(
                    "Cửa hàng mở cửa %02d:00–%02d:00. Giờ nhận hàng sớm nhất trong ngày là %s.",
                    openHour, closeHour, DateTimeUtil.formatTime(earliestThatDay)));
        }
    }

    /**
     * Giờ hẹn sớm nhất khách được chọn — dùng đặt giá trị nhỏ nhất cho ô nhập trên giao diện.
     * <p>
     * Nhảy sang khung mở cửa kế tiếp nếu thời điểm tính ra rơi ngoài giờ làm việc, để ô nhập
     * không gợi ý sẵn một giá trị mà bấm gửi lên là bị từ chối.
     */
    public LocalDateTime earliestPickupTime() {
        LocalDateTime candidate = DateTimeUtil.now().plusMinutes(AppConfig.pickupMinLeadMinutes());
        int openHour = AppConfig.storeOpenHour();
        int closeHour = AppConfig.storeCloseHour();
        LocalDateTime openThatDay = candidate.toLocalDate().atTime(openHour, 0)
                .plusMinutes(AppConfig.kitchenPrepLeadMinutes());

        if (candidate.isBefore(openThatDay)) {
            return openThatDay;                     // sáng sớm — đợi tới giờ mở cửa hôm nay
        }
        if (candidate.getHour() >= closeHour) {
            return openThatDay.plusDays(1);         // đã qua giờ đóng cửa — sang hôm sau
        }
        return candidate;
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
        LocalDateTime releaseAt = order.getPickupTime().minusMinutes(AppConfig.kitchenPrepLeadMinutes());

        // Mã nhận hàng sinh ngẫu nhiên và có ràng buộc duy nhất trong cơ sở dữ liệu. Trùng mã
        // là hiếm nhưng không phải không thể, và nếu để lỗi lọt ra thì cả giao dịch thanh toán
        // bị huỷ — khách mất tiền mà đơn không được xác nhận. Sinh lại mã khác vài lần
        // rẻ hơn nhiều so với hậu quả đó.
        String pickupCode = null;
        int changed = 0;
        for (int attempt = 1; attempt <= PICKUP_CODE_ATTEMPTS; attempt++) {
            pickupCode = PickupCodeGenerator.generate();
            try {
                changed = orderDAO.confirmOnlineAfterPaid(con, order.getOrderId(), pickupCode, releaseAt);
                break;
            } catch (SQLException e) {
                if (!JdbcSupport.isUniqueViolation(e) || attempt == PICKUP_CODE_ATTEMPTS) {
                    throw e;
                }
            }
        }
        if (changed == 0) {
            return false;
        }

        order.setOrderStatus(OrderStatus.CONFIRMED.name());
        order.setPickupCode(pickupCode);
        order.setKitchenReleaseAt(releaseAt);

        // Giờ mới dọn giỏ hàng — đơn đã trả tiền xong thì số hàng trong giỏ mới thật sự
        // trở thành đơn. Dọn từ lúc tạo đơn thì khách trả tiền hỏng là mất giỏ oan.
        if (order.getCustomerId() != null) {
            cartDAO.clear(con, cartDAO.getOrCreateCartId(con, order.getCustomerId(), now));
        }

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

    /** Một trang lịch sử đơn của khách, mới nhất trước. */
    public Page<Order> historyOfCustomer(int customerId, int pageNo) {
        int page = Page.safePage(pageNo);
        int offset = Page.offset(page, Page.SIZE);
        return Tx.read(con -> new Page<>(
                orderDAO.findByCustomer(con, customerId, offset, Page.SIZE),
                page, Page.SIZE,
                orderDAO.countByCustomer(con, customerId)));
    }

    public List<Order> activeOrdersOfCustomer(int customerId) {
        return Tx.read(con -> orderDAO.findActiveByCustomer(con, customerId));
    }

    /** Bốn tab trên màn hình đơn hàng của thu ngân. */
    public List<Order> dashboard(String tab) {
        return Tx.read(con -> orderDAO.findForDashboard(con, tab, DateTimeUtil.now(),
                AppConfig.pickupOverdueMinutes()));
    }

    /** Một trang đơn khớp bộ lọc, dùng cho màn hình lịch sử của thu ngân. */
    public Page<Order> search(String source, String status,
                              LocalDateTime from, LocalDateTime to, int pageNo) {
        int page = Page.safePage(pageNo);
        int offset = Page.offset(page, Page.SIZE);
        return Tx.read(con -> new Page<>(
                orderDAO.search(con, source, status, from, to, offset, Page.SIZE),
                page, Page.SIZE,
                orderDAO.countSearch(con, source, status, from, to)));
    }

    // ============================================================ huỷ đơn

    /**
     * Khách tự huỷ đơn. Nhận hai trạng thái, vì hai lý do khác nhau:
     * <ul>
     *   <li><b>Chờ thanh toán</b> — khách đổi ý trước khi trả tiền. Chưa thu đồng nào, bếp chưa
     *       thấy đơn, nên bỏ đi là chuyện hiển nhiên phải cho phép. Không cho thì khách vừa
     *       không trả tiền được vừa không đặt đơn khác được, phải ngồi đợi đơn tự hết hạn.</li>
     *   <li><b>Đã xác nhận</b> — đã trả tiền, và chốt chặn là <b>bếp đã bắt đầu làm hay chưa</b>,
     *       không phải "đơn đã xuống bếp hay chưa". Đơn xuống bếp trước giờ hẹn 20 phút và suốt
     *       khoảng đó có thể chưa ai nhận việc; huỷ lúc ấy chưa tốn nguyên liệu.</li>
     * </ul>
     * Dòng đơn được khoá trước khi đếm. Cơ sở dữ liệu bật chế độ đọc ảnh chụp, nên nếu không
     * khoá thì lệnh đếm ở đây và lệnh nhận việc của bếp có thể cùng nhìn thấy trạng thái cũ
     * của nhau: đơn bị huỷ trong khi bếp vừa bắc chảo lên. {@link KitchenService#claim} khoá
     * cùng dòng đơn này trước khi ghi, nên hai bên luôn xếp hàng chứ không chạy song song.
     * <p>
     * Khách huỷ đơn chờ thanh toán rồi cổng mới báo tiền về vẫn an toàn:
     * {@code confirmOnlineAfterPaid} thấy đơn không còn chờ thanh toán nên trả về false, và
     * {@link PaymentService#handleCallback} hoàn tiền ngay trong cùng giao dịch.
     */
    public boolean cancelByCustomer(int orderId, int customerId) {
        return Tx.write(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null || order.getCustomerId() == null || order.getCustomerId() != customerId) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            String before = order.getOrderStatus();
            boolean unpaid = OrderStatus.PENDING_PAYMENT.name().equals(before);
            if (!unpaid && !OrderStatus.CONFIRMED.name().equals(before)) {
                throw new BusinessException(cannotCancelReason(before));
            }

            orderDAO.lockForUpdate(con, orderId);
            if (orderItemDAO.countInProgress(con, orderId) > 0) {
                throw new BusinessException(KITCHEN_ALREADY_STARTED);
            }

            int changed = orderDAO.markCancelled(con, orderId, DateTimeUtil.now());
            if (changed == 0) {
                throw new BusinessException("Đơn vừa được xử lý bởi người khác. Vui lòng tải lại.");
            }
            auditService.log(con, customerId, "ORDER", orderId, AuditAction.ORDER_CANCELLED,
                    before, OrderStatus.CANCELLED.name());
            boolean refunded = refundIfPaid(con, orderId, customerId);

            // Đơn chưa trả tiền do chính khách bỏ đi thì không gửi tin: họ vừa tự bấm và đang
            // nhìn màn hình, mà cũng không có khoản tiền nào để báo. Gửi chỉ thêm nhiễu.
            if (!unpaid) {
                notificationService.notifyOrderCancelled(con, order, "khách tự huỷ", refunded);
            }
            return refunded;
        });
    }

    /**
     * Vì sao đơn ở trạng thái này không huỷ được — nói theo ngôn ngữ của khách.
     * <p>
     * Trả về một câu chung chung là đẩy khách vào chỗ bí: họ không biết mình đang ở tình huống
     * nào và cũng không biết còn làm được gì. Mỗi trạng thái ở đây tương ứng với một chuyện
     * khác hẳn nhau đã xảy ra, và mỗi chuyện có một hướng xử lý riêng.
     */
    private static String cannotCancelReason(String status) {
        OrderStatus current = OrderStatus.valueOf(status);
        return switch (current) {
            // Bếp đang làm hoặc đã làm xong: tiền và nguyên liệu đều đã bỏ ra
            case PREPARING, READY -> KITCHEN_ALREADY_STARTED;
            case COMPLETED -> "Đơn này đã được giao cho khách nên không huỷ được nữa.";
            case CANCELLED -> "Đơn này đã được huỷ trước đó rồi.";
            case EXPIRED -> "Đơn này đã hết hiệu lực vì quá hạn thanh toán. Vui lòng đặt lại.";
            default -> "Đơn này không còn ở trạng thái huỷ được.";
        };
    }

    /**
     * Thu ngân đóng đơn.
     * <p>
     * Khác đường huỷ của khách ở chỗ đóng được cả đơn đang nấu dở và đơn đã sẵn sàng mà
     * khách không tới lấy. Đây là lối thoát duy nhất cho ba tình huống trước đây không có
     * cách xử lý: khách không đến, bếp báo hết nguyên liệu, và khách gọi điện xin huỷ muộn.
     * <p>
     * Lý do huỷ bắt buộc phải có và được ghi vào nhật ký thao tác — đây là thao tác duy nhất
     * làm mất doanh thu đã ghi nhận, nên phải truy được ai quyết định và vì sao.
     */
    public void cancelByStaff(int orderId, int staffId, String reason) {
        String note = reason == null ? "" : reason.trim();
        if (note.isEmpty()) {
            throw new ValidationException("Vui lòng nhập lý do huỷ đơn.");
        }
        Tx.writeVoid(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            if (order.statusEnum().isFinal()) {
                throw new BusinessException("Đơn đã kết thúc, không huỷ được nữa.");
            }

            int changed = orderDAO.markCancelledByStaff(con, orderId, DateTimeUtil.now());
            if (changed == 0) {
                throw new BusinessException("Đơn vừa được xử lý bởi người khác. Vui lòng tải lại.");
            }
            auditService.log(con, staffId, "ORDER", orderId, AuditAction.ORDER_CANCELLED,
                    order.getOrderStatus(), OrderStatus.CANCELLED.name() + ": " + note);
            boolean refunded = refundIfPaid(con, orderId, staffId);
            notificationService.notifyOrderCancelled(con, order, note, refunded);
        });
    }

    /**
     * Hoàn lại tiền của đơn nếu đã thu. Hệ thống không có hoàn một phần nên mỗi đơn
     * hoặc hoàn hết hoặc không hoàn.
     *
     * @return true nếu thật sự có một khoản vừa được hoàn — dùng để viết đúng nội dung
     *         tin nhắn báo cho khách
     */
    private boolean refundIfPaid(Connection con, int orderId, int actorId) throws SQLException {
        Payment paid = paymentDAO.findPaidByOrder(con, orderId);
        if (paid == null) {
            return false;
        }
        paymentDAO.markRefunded(con, paid.getPaymentId(), DateTimeUtil.now());
        auditService.log(con, actorId, "PAYMENT", paid.getPaymentId(),
                AuditAction.PAYMENT_REFUNDED, PaymentStatus.PAID.name(), PaymentStatus.REFUNDED.name());
        return true;
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

    // ============================================================ quầy nhận món từ bếp

    /** Món bếp đã đưa ra quầy mà chưa ai xác nhận cầm. */
    public List<OrderItem> awaitingCounter() {
        return Tx.read(orderItemDAO::findAwaitingCounter);
    }

    /** Số món đang nằm chờ trên quầy — hiện thành cảnh báo trên màn hình điều phối. */
    public int countAwaitingCounter() {
        return Tx.read(orderItemDAO::countAwaitingCounter);
    }

    /**
     * Đơn chờ khách tới lấy, kèm danh sách món, để màn hình quầy nói được đơn nào còn thiếu món.
     * <p>
     * {@link #dashboard} không nạp món vì bốn tab của nó chỉ hiện dòng tóm tắt. Ở đây thì cần,
     * nên phải có phương thức riêng — mỗi đơn một lượt truy vấn món. Danh sách này bị chặn bởi
     * số đơn thật sự đang nằm chờ ở một quầy, tức là vài đơn, nên chấp nhận được; nếu về sau
     * nó dài ra thì đây là chỗ cần gộp thành một câu truy vấn.
     */
    public List<Order> readyOrdersForCounter() {
        return Tx.read(con -> {
            List<Order> orders = orderDAO.findForDashboard(con, "READY", DateTimeUtil.now(),
                    AppConfig.pickupOverdueMinutes());
            for (Order order : orders) {
                order.setItems(orderItemDAO.findByOrder(con, order.getOrderId()));
            }
            return orders;
        });
    }

    /**
     * Thu ngân xác nhận đã cầm món tại quầy.
     * <p>
     * Không đổi trạng thái đơn: đây là bàn giao nội bộ giữa hai vị trí trong cửa hàng, khách
     * chưa nhận được gì. Trạng thái đơn chỉ đổi khi món thật sự ra khỏi cửa hàng — xem
     * {@link #handoff}.
     */
    public void receiveAtCounter(int orderItemId, int cashierId) {
        LocalDateTime now = DateTimeUtil.now();
        Tx.writeVoid(con -> {
            OrderItem item = orderItemDAO.findById(con, orderItemId);
            if (item == null) {
                throw new NotFoundException("Không tìm thấy món.");
            }
            int changed = orderItemDAO.receiveAtCounter(con, orderItemId, cashierId, now);
            if (changed == 0) {
                // Đọc lại để nói đúng lý do thay vì một câu chung chung khiến thu ngân
                // bấm đi bấm lại một nút không bao giờ ăn.
                if (item.isReceived()) {
                    throw new BusinessException("Món này đã được nhận rồi.");
                }
                throw new BusinessException("Bếp chưa bàn giao món này ra quầy.");
            }
            auditService.log(con, cashierId, "ORDER_ITEM", orderItemId,
                    AuditAction.ITEM_RECEIVED, "AT_COUNTER", "RECEIVED");
        });
    }

    /**
     * Giao món cho khách.
     * <p>
     * Bốn điều kiện phải cùng đúng: món đã sẵn sàng, quầy đã nhận đủ món từ bếp, tiền đã thu,
     * và với đơn đặt trước thì mã khách đưa phải khớp. Kiểm tra ở phía máy chủ chứ không dựa
     * vào giao diện, vì đây là bước quyết định món ra khỏi cửa hàng.
     * <p>
     * Lần đưa sai mã được ghi lại ở <b>giao dịch riêng</b>. Ghi chung với giao dịch chính thì
     * bản ghi bị huỷ cùng lúc với thao tác bị từ chối, và chuyện đáng theo dõi nhất — ai đó
     * đứng ở quầy thử hết mã này tới mã khác — lại là chuyện duy nhất không để lại dấu vết.
     */
    public Order handoff(int orderId, int cashierId, String presentedCode) {
        LocalDateTime now = DateTimeUtil.now();
        try {
            return doHandoff(orderId, cashierId, presentedCode, now);
        } catch (PickupCodeMismatch e) {
            auditService.logRejected(cashierId, "ORDER", orderId,
                    AuditAction.PICKUP_VERIFY_FAILED, e.expected, e.given);
            throw new BusinessException("Mã nhận hàng không khớp với đơn này.");
        }
    }

    /** Mã khách đưa không khớp. Chỉ dùng trong nội bộ lớp này để thoát khỏi giao dịch. */
    private static final class PickupCodeMismatch extends RuntimeException {
        private final transient String expected;
        private final transient String given;

        PickupCodeMismatch(String expected, String given) {
            super(null, null, false, false);   // không cần vết ngăn xếp, đây là luồng nghiệp vụ
            this.expected = expected;
            this.given = given;
        }
    }

    private Order doHandoff(int orderId, int cashierId, String presentedCode, LocalDateTime now) {
        return Tx.write(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            if (!OrderStatus.READY.name().equals(order.getOrderStatus())) {
                throw new BusinessException("Đơn chưa sẵn sàng để giao.");
            }
            // Đơn sẵn sàng chỉ nghĩa là bếp đã nấu xong. Món có thể vẫn còn trong bếp, và giao
            // cho khách trước khi quầy cầm được món là cách chắc chắn nhất để phát thiếu món.
            int notReceived = orderItemDAO.countNotReceived(con, orderId);
            if (notReceived > 0) {
                throw new BusinessException("Còn " + notReceived + " món chưa được nhận tại quầy. "
                        + "Vào màn hình Quầy giao nhận để nhận món từ bếp trước khi giao cho khách.");
            }
            Payment paid = paymentDAO.findPaidByOrder(con, orderId);
            if (paid == null) {
                // Phân biệt hai chuyện khác hẳn nhau: chưa từng thu được tiền, và đã thu rồi
                // hoàn lại. Gộp làm một thì nhân viên tưởng cứ thu tiền là giao được, trong khi
                // đơn đã hoàn tiền phải lập lại từ đầu.
                Payment latest = paymentDAO.findLatestByOrder(con, orderId);
                if (latest != null && PaymentStatus.REFUNDED.name().equals(latest.getPaymentStatus())) {
                    throw new BusinessException("Đơn này đã được hoàn tiền nên không giao được. "
                            + "Nếu khách vẫn muốn nhận, vui lòng lập đơn mới tại quầy.");
                }
                throw new BusinessException("Đơn chưa được thanh toán.");
            }
            if (order.isOnline()) {
                String expected = order.getPickupCode();
                String given = presentedCode == null ? "" : presentedCode.trim().toUpperCase();
                if (expected == null || !expected.equals(given)) {
                    // KHÔNG ghi nhật ký ở đây: câu lệnh tiếp theo huỷ cả giao dịch, và bản ghi
                    // nhật ký sẽ bị huỷ theo. Ném ra ngoài rồi ghi ở giao dịch riêng — xem
                    // khối catch bên dưới.
                    throw new PickupCodeMismatch(expected, given);
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
     * Khoá dòng đơn trong giao dịch hiện tại.
     * <p>
     * Mọi thao tác vừa đọc trạng thái các món vừa quyết định số phận của cả đơn đều phải gọi
     * cái này trước: nhận việc trong bếp, khách huỷ đơn, tổng hợp lại trạng thái. Cùng lấy một
     * khoá nghĩa là chúng xếp hàng chứ không chạy chồng lên nhau — cần thiết vì cơ sở dữ liệu
     * bật chế độ đọc ảnh chụp, các lệnh đọc không tự chặn nhau.
     */
    public void lockOrder(Connection con, int orderId) throws SQLException {
        orderDAO.lockForUpdate(con, orderId);
    }

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
        return fill(con, orderDAO.findById(con, orderId));
    }

    /** Như trên nhưng tra theo khoá chống trùng — dùng khi khách bấm đặt hàng hai lần. */
    private Order loadFull(Connection con, String idempotencyKey) throws SQLException {
        return fill(con, orderDAO.findByIdempotencyKey(con, idempotencyKey));
    }

    private Order fill(Connection con, Order order) throws SQLException {
        if (order == null) {
            return null;
        }
        order.setItems(orderItemDAO.findByOrder(con, order.getOrderId()));
        order.setLatestPayment(paymentDAO.findLatestByOrder(con, order.getOrderId()));
        return order;
    }
}
