package com.fastfood.service.shared;

import com.fastfood.common.constant.*;
import com.fastfood.common.exception.BusinessException;
import com.fastfood.common.exception.NotFoundException;
import com.fastfood.common.exception.ValidationException;
import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.dao.JdbcSupport;
import com.fastfood.dao.shared.OrderDAO;
import com.fastfood.dao.shared.PaymentDAO;
import com.fastfood.dao.shared.TransactionDAO;
import com.fastfood.integration.payment.GatewayCallback;
import com.fastfood.integration.payment.MockPaymentGateway;
import com.fastfood.integration.payment.PaymentGateway;
import com.fastfood.integration.payment.PaymentInitResult;
import com.fastfood.model.entity.Order;
import com.fastfood.model.entity.Payment;
import com.fastfood.model.entity.Transaction;
import com.fastfood.service.Tx;

import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.logging.Logger;

/**
 * Nghiệp vụ thanh toán.
 * <p>
 * Phần khó nhất ở đây không phải là thu tiền mà là <b>không thu tiền hai lần</b>. Cổng thanh
 * toán có thể gửi kết quả về nhiều lần cho cùng một giao dịch: khách tải lại trang, mạng chập
 * chờn, hoặc cổng chủ động gửi lại khi chưa nhận được xác nhận. Cách xử lý xem tại
 * {@link #handleCallback}.
 */
public class PaymentService {

    /**
     * Kết quả xử lý một lần cổng thanh toán gọi về.
     * <p>
     * Không dùng true/false vì bốn tình huống dưới đây cần bốn thông báo khác nhau cho khách:
     * trả lời gộp lại thì khách không biết tiền của mình đang ở đâu.
     */
    public enum CallbackResult {
        /** Tiền đã về và đơn được xác nhận. */
        PAID,
        /** Cổng báo thanh toán không thành công. */
        FAILED,
        /** Cổng gửi lại kết quả cũ; đã xử lý từ lần trước nên bỏ qua. */
        DUPLICATE,
        /** Tiền về nhưng đơn đã hết hạn hoặc bị huỷ trước đó — đã hoàn lại ngay. */
        REFUNDED_ORDER_GONE
    }

    private static final Logger LOG = Logger.getLogger(PaymentService.class.getName());

    /** Số lần thử lại khi hai tab cùng lập một lần thanh toán. Xem {@link #startOnlinePayment}. */
    private static final int ATTEMPT_NO_RETRIES = 3;

    private final OrderDAO orderDAO = new OrderDAO();
    private final PaymentDAO paymentDAO = new PaymentDAO();
    private final TransactionDAO transactionDAO = new TransactionDAO();
    private final OrderCoreService orderCore = new OrderCoreService();
    private final AuditService auditService = new AuditService();
    private final NotificationService notificationService = new NotificationService();
    private final MockPaymentGateway gateway = new MockPaymentGateway();

    /**
     * Bắt đầu một lần thanh toán cho đơn đặt trước.
     * <p>
     * Mỗi lần thử là một bản ghi riêng chứ không ghi đè lần trước, để còn đối soát được
     * khi khách khiếu nại. Trả về địa chỉ chuyển hướng sang trang thanh toán.
     */
    public String startOnlinePayment(int orderId, int customerId, String returnUrl) {
        LocalDateTime now = DateTimeUtil.now();

        return Tx.write(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null || order.getCustomerId() == null || order.getCustomerId() != customerId) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            if (!OrderStatus.PENDING_PAYMENT.name().equals(order.getOrderStatus())) {
                throw new BusinessException("Đơn hàng này không còn ở trạng thái chờ thanh toán.");
            }

            Payment payment = new Payment();
            payment.setOrderId(orderId);
            payment.setMethod(PaymentMethod.ONLINE_GATEWAY.name());
            payment.setAmount(order.getTotalAmount());
            payment.setPaymentStatus(PaymentStatus.PENDING.name());
            payment.setCreatedAt(now);

            // (order_id, attempt_no) là khoá duy nhất, còn số thứ tự thì tính bằng MAX+1.
            // Khách mở hai tab rồi bấm thanh toán gần như cùng lúc sẽ cùng đọc ra một số,
            // và người thứ hai đụng ràng buộc. Đọc lại rồi thử số kế tiếp thay vì báo lỗi.
            for (int attempt = 1; ; attempt++) {
                payment.setAttemptNo(paymentDAO.nextAttemptNo(con, orderId));
                try {
                    paymentDAO.insert(con, payment);
                    break;
                } catch (SQLException e) {
                    if (!JdbcSupport.isUniqueViolation(e) || attempt == ATTEMPT_NO_RETRIES) {
                        throw e;
                    }
                }
            }

            auditService.log(con, customerId, "PAYMENT", payment.getPaymentId(),
                    AuditAction.PAYMENT_INITIATED, null, PaymentStatus.PENDING.name());

            PaymentInitResult init = gateway.initiate(payment.getPaymentId(), orderId,
                    order.getTotalAmount(), returnUrl);
            return init.getRedirectUrl();
        });
    }

    /**
     * Xử lý kết quả cổng thanh toán gửi về.
     * <p>
     * Thứ tự các bước ở đây là có chủ đích:
     * <ol>
     *   <li>Kiểm tra chữ ký trước tiên — dữ liệu không đúng chữ ký thì bỏ qua ngay, vì
     *       địa chỉ này ai cũng gọi được.</li>
     *   <li>Ghi mã giao dịch của cổng vào bảng nhật ký. Cột này có ràng buộc duy nhất, nên
     *       lần gửi thứ hai sẽ bị cơ sở dữ liệu từ chối. Đây mới là chốt chặn thật sự —
     *       kiểm tra bằng câu truy vấn trước rồi mới ghi vẫn để lọt hai lệnh gọi về cùng lúc.</li>
     *   <li>Ghi nhận tiền và xác nhận đơn, tất cả trong cùng một giao dịch.</li>
     * </ol>
     *
     * Bước cuối cùng phải xử lý được cả trường hợp <b>tiền về sau khi đơn đã hết hiệu lực</b>:
     * khách để trang thanh toán mở quá lâu, bộ hẹn giờ huỷ đơn, rồi khách mới bấm trả tiền.
     * Khi đó tiền vẫn thật sự đã vào, nên phải hoàn lại ngay trong cùng giao dịch chứ không
     * được im lặng giữ lấy một khoản tiền không còn đơn nào tương ứng.
     *
     * @return kết quả xử lý, xem {@link CallbackResult}
     */
    public CallbackResult handleCallback(GatewayCallback callback) {
        if (!gateway.verifySignature(callback)) {
            LOG.warning("Bo qua ket qua thanh toan co chu ky khong hop le, paymentId="
                    + callback.getPaymentId());
            throw new BusinessException("Dữ liệu thanh toán không hợp lệ.");
        }

        LocalDateTime now = DateTimeUtil.now();

        return Tx.write(con -> {
            Payment payment = paymentDAO.findById(con, callback.getPaymentId());
            if (payment == null) {
                throw new NotFoundException("Không tìm thấy giao dịch thanh toán.");
            }

            Transaction txn = transactionDAO.newTransaction(
                    payment.getPaymentId(), gateway.getName(), callback.getExternalTransactionId(),
                    callback.isSuccess() ? "SUCCESS" : "FAILED", callback.getRawPayload(), now);

            boolean isNew = transactionDAO.insertIfNew(con, txn);
            if (!isNew) {
                // Cổng thanh toán gửi lại kết quả cũ — ghi nhận là đã bỏ qua rồi dừng
                auditService.logSystem(con, "PAYMENT", payment.getPaymentId(),
                        AuditAction.CALLBACK_IGNORED, callback.getExternalTransactionId());
                LOG.info("Bo qua callback trung lap: " + callback.getExternalTransactionId());
                return CallbackResult.DUPLICATE;
            }

            if (!callback.isSuccess()) {
                paymentDAO.markFailed(con, payment.getPaymentId());
                auditService.logSystem(con, "PAYMENT", payment.getPaymentId(),
                        AuditAction.PAYMENT_FAILED, PaymentStatus.FAILED.name());
                return CallbackResult.FAILED;
            }

            int paidRows = paymentDAO.markPaid(con, payment.getPaymentId(), now);
            if (paidRows == 0) {
                // Bản ghi này đã được ghi nhận trước đó bằng mã giao dịch khác
                return CallbackResult.DUPLICATE;
            }
            auditService.logSystem(con, "PAYMENT", payment.getPaymentId(),
                    AuditAction.PAYMENT_PAID, PaymentStatus.PAID.name());

            Order order = orderDAO.findById(con, payment.getOrderId());
            if (order != null && order.isOnline()
                    && !orderCore.confirmOnlineAfterPaid(con, order, now)) {
                // Đơn không còn ở trạng thái chờ thanh toán: bộ hẹn giờ đã cho hết hiệu lực,
                // hoặc đơn vừa bị huỷ, trong lúc khách còn đứng ở trang thanh toán.
                // Tiền đã thật sự vào nên phải hoàn ngay tại đây — cùng giao dịch với lúc
                // ghi nhận, để không có khoảnh khắc nào tiền nằm lại mà không có đơn.
                paymentDAO.markRefunded(con, payment.getPaymentId(), now);
                auditService.logSystem(con, "PAYMENT", payment.getPaymentId(),
                        AuditAction.PAYMENT_REFUNDED, PaymentStatus.REFUNDED.name());
                // Trả kết quả về màn hình thôi là chưa đủ: khách đóng tab trước khi trang tải
                // xong thì vừa mất tiền vừa mất đơn mà không hay biết, tự phát hiện qua sao kê
                // ngân hàng vài ngày sau. Gửi tin là cách duy nhất chắc chắn tới được khách.
                notificationService.notifyRefundedOrderGone(con, order);
                LOG.warning("Tien ve sau khi don #" + order.getOrderId()
                        + " het hieu luc (" + order.getOrderStatus() + "); da hoan lai ngay.");
                return CallbackResult.REFUNDED_ORDER_GONE;
            }
            return CallbackResult.PAID;
        });
    }

    /**
     * Hoàn tiền toàn phần cho một đơn đã đóng.
     * Hệ thống không có hoàn một phần: mỗi đơn hoặc hoàn hết hoặc không hoàn.
     * <p>
     * <b>Đây không phải thao tác hàng ngày.</b> Đường hoàn tiền thông thường nằm trong
     * {@code StaffOrderService.cancelByStaff} — huỷ đơn và hoàn tiền là một việc, làm trong cùng
     * một giao dịch. Tách rời ra thì sinh đơn dở dang: tiền đã trả lại khách nhưng đơn vẫn
     * nằm ở trạng thái chờ giao, tiếp tục hiện trên màn hình điều phối và làm sai chỉ số.
     * <p>
     * Vì vậy hàm này chỉ nhận đơn đã huỷ hoặc đã hết hiệu lực, và chỉ còn dùng để sửa
     * những trường hợp hoàn tiền sót lại.
     * <p>
     * Lý do bắt buộc phải có, cùng lý lẽ với huỷ đơn: đây là thao tác trả tiền ra khỏi cửa
     * hàng mà không đi kèm sự kiện nào khác giải thích cho nó, nên bản thân nó phải tự mang
     * lời giải thích. Lý do được ghi vào nhật ký thao tác chứ không chỉ hiện trên màn hình.
     */
    public void refund(int orderId, int actorId, String reason) {
        String note = reason == null ? "" : reason.trim();
        if (note.isEmpty()) {
            throw new ValidationException("Vui lòng nhập lý do hoàn tiền.");
        }
        LocalDateTime now = DateTimeUtil.now();
        Tx.writeVoid(con -> {
            Order order = orderDAO.findById(con, orderId);
            if (order == null) {
                throw new NotFoundException("Không tìm thấy đơn hàng.");
            }
            Payment paid = paymentDAO.findPaidByOrder(con, orderId);
            if (paid == null) {
                throw new BusinessException("Đơn này chưa có khoản thanh toán nào để hoàn.");
            }
            String status = order.getOrderStatus();
            if (!OrderStatus.CANCELLED.name().equals(status) && !OrderStatus.EXPIRED.name().equals(status)) {
                throw new BusinessException("Chỉ hoàn tiền cho đơn đã huỷ hoặc đã hết hiệu lực. "
                        + "Đơn còn hiệu lực thì dùng chức năng huỷ đơn — hệ thống hoàn tiền kèm theo.");
            }

            int changed = paymentDAO.markRefunded(con, paid.getPaymentId(), now);
            if (changed == 0) {
                throw new BusinessException("Khoản thanh toán này đã được hoàn trước đó.");
            }
            auditService.log(con, actorId, "PAYMENT", paid.getPaymentId(),
                    AuditAction.PAYMENT_REFUNDED, PaymentStatus.PAID.name(),
                    PaymentStatus.REFUNDED.name() + ": " + note);
        });
    }

    /** Tra mã đơn từ mã thanh toán — dùng khi cổng thanh toán gọi về và cần biết quay lại đơn nào. */
    public int orderIdOfPayment(int paymentId) {
        return Tx.read(con -> {
            Payment p = paymentDAO.findById(con, paymentId);
            return p == null ? 0 : p.getOrderId();
        });
    }

    public List<Payment> findByOrder(int orderId) {
        return Tx.read(con -> paymentDAO.findByOrder(con, orderId));
    }

    public List<Transaction> findTransactions(int paymentId) {
        return Tx.read(con -> transactionDAO.findByPayment(con, paymentId));
    }

    /** Chữ ký cho nút "thanh toán thất bại" trên trang giả lập. */
    public String signFailure(int paymentId, String externalId) {
        return gateway.signFailure(paymentId, externalId);
    }

    public PaymentGateway getGateway() {
        return gateway;
    }
}
