package com.fastfood.model.entity;

import com.fastfood.common.constant.KdsReleaseState;
import com.fastfood.common.constant.OrderSource;
import com.fastfood.common.constant.OrderStatus;
import com.fastfood.config.AppConfig;
import com.fastfood.common.util.DateTimeUtil;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Đơn hàng. Ánh xạ tới bảng Orders.
 * <p>
 * Ba mốc thời gian dưới đây là phần cốt lõi phân biệt đơn đặt trước với đơn tại quầy:
 * <ul>
 *   <li>{@code pickupTime} — giờ đã cam kết với khách</li>
 *   <li>{@code kitchenReleaseAt} — kế hoạch đưa xuống bếp, tính một lần khi đơn được xác nhận</li>
 *   <li>{@code releasedToKdsAt} — thời điểm thực tế bếp nhận được đơn; còn null nghĩa là bếp chưa thấy</li>
 * </ul>
 * Trạng thái đưa xuống bếp và cờ khách đến muộn được suy ra từ ba mốc này, không lưu thành cột.
 */
public class Order {

    private int orderId;
    private Integer customerId;
    private Integer createdByUserId;
    private String orderSource;
    private BigDecimal totalAmount = BigDecimal.ZERO;
    private String orderStatus;
    private String idempotencyKey;

    private LocalDateTime pickupTime;
    private LocalDateTime kitchenReleaseAt;
    private LocalDateTime releasedToKdsAt;
    private String pickupCode;

    private LocalDateTime readyAt;
    private LocalDateTime pickedUpAt;
    private Integer handoffByUserId;
    private LocalDateTime createdAt;
    private LocalDateTime completedAt;
    private LocalDateTime cancelledAt;
    private LocalDateTime expiredAt;

    // Dữ liệu lấy kèm khi join, phục vụ hiển thị
    private String customerName;
    private String customerEmail;
    private String handoffByName;
    private List<OrderItem> items = new ArrayList<>();
    private Payment latestPayment;

    // ----- getter / setter -----

    public int getOrderId() { return orderId; }
    public void setOrderId(int orderId) { this.orderId = orderId; }

    public Integer getCustomerId() { return customerId; }
    public void setCustomerId(Integer customerId) { this.customerId = customerId; }

    public Integer getCreatedByUserId() { return createdByUserId; }
    public void setCreatedByUserId(Integer createdByUserId) { this.createdByUserId = createdByUserId; }

    public String getOrderSource() { return orderSource; }
    public void setOrderSource(String orderSource) { this.orderSource = orderSource; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public String getOrderStatus() { return orderStatus; }
    public void setOrderStatus(String orderStatus) { this.orderStatus = orderStatus; }

    public String getIdempotencyKey() { return idempotencyKey; }
    public void setIdempotencyKey(String idempotencyKey) { this.idempotencyKey = idempotencyKey; }

    public LocalDateTime getPickupTime() { return pickupTime; }
    public void setPickupTime(LocalDateTime pickupTime) { this.pickupTime = pickupTime; }

    public LocalDateTime getKitchenReleaseAt() { return kitchenReleaseAt; }
    public void setKitchenReleaseAt(LocalDateTime kitchenReleaseAt) { this.kitchenReleaseAt = kitchenReleaseAt; }

    public LocalDateTime getReleasedToKdsAt() { return releasedToKdsAt; }
    public void setReleasedToKdsAt(LocalDateTime releasedToKdsAt) { this.releasedToKdsAt = releasedToKdsAt; }

    public String getPickupCode() { return pickupCode; }
    public void setPickupCode(String pickupCode) { this.pickupCode = pickupCode; }

    public LocalDateTime getReadyAt() { return readyAt; }
    public void setReadyAt(LocalDateTime readyAt) { this.readyAt = readyAt; }

    public LocalDateTime getPickedUpAt() { return pickedUpAt; }
    public void setPickedUpAt(LocalDateTime pickedUpAt) { this.pickedUpAt = pickedUpAt; }

    public Integer getHandoffByUserId() { return handoffByUserId; }
    public void setHandoffByUserId(Integer handoffByUserId) { this.handoffByUserId = handoffByUserId; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }

    public LocalDateTime getCancelledAt() { return cancelledAt; }
    public void setCancelledAt(LocalDateTime cancelledAt) { this.cancelledAt = cancelledAt; }

    public LocalDateTime getExpiredAt() { return expiredAt; }
    public void setExpiredAt(LocalDateTime expiredAt) { this.expiredAt = expiredAt; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }

    public String getHandoffByName() { return handoffByName; }
    public void setHandoffByName(String handoffByName) { this.handoffByName = handoffByName; }

    public List<OrderItem> getItems() { return items; }
    public void setItems(List<OrderItem> items) { this.items = items; }

    public Payment getLatestPayment() { return latestPayment; }
    public void setLatestPayment(Payment latestPayment) { this.latestPayment = latestPayment; }

    // ----- thuộc tính suy ra, JSP gọi trực tiếp qua EL -----

    public boolean isOnline() { return OrderSource.ONLINE_PREORDER.name().equals(orderSource); }

    public boolean isPos() { return OrderSource.POS.name().equals(orderSource); }

    public OrderStatus statusEnum() { return OrderStatus.valueOf(orderStatus); }

    /** Trạng thái đưa xuống bếp — suy ra từ mốc thời gian, không phải trạng thái đơn. */
    public KdsReleaseState getReleaseState() {
        if (releasedToKdsAt != null) {
            return KdsReleaseState.RELEASED_TO_KDS;
        }
        if (OrderStatus.CONFIRMED.name().equals(orderStatus)) {
            return KdsReleaseState.SCHEDULED;
        }
        return KdsReleaseState.NOT_RELEASED;
    }

    /**
     * Khách đã quá hẹn nhận hàng chưa. Chỉ để nhân viên chú ý;
     * hệ thống không tự huỷ hay tự hoàn tiền vì đơn đã được trả tiền trước.
     */
    public boolean isOverdue() {
        if (!isOnline() || pickupTime == null || !OrderStatus.READY.name().equals(orderStatus)) {
            return false;
        }
        return DateTimeUtil.now().isAfter(pickupTime.plusMinutes(AppConfig.pickupOverdueMinutes()));
    }

    /** Món xong trễ hơn giờ đã hẹn — dùng cho chỉ số đúng hẹn. */
    public boolean isLateReady() {
        return isOnline() && readyAt != null && pickupTime != null && readyAt.isAfter(pickupTime);
    }

    /**
     * Khách còn huỷ được không: chỉ đơn đặt trước đã xác nhận và chưa tới giờ vào bếp.
     * Khi bếp đã bắt đầu thì nguyên liệu đã dùng, không cho huỷ nữa.
     */
    public boolean isCancellable() {
        if (!OrderStatus.CONFIRMED.name().equals(orderStatus)) {
            return false;
        }
        if (isPos()) {
            return releasedToKdsAt == null;
        }
        return kitchenReleaseAt != null && DateTimeUtil.now().isBefore(kitchenReleaseAt);
    }

    public int getTotalQuantity() {
        return items.stream().mapToInt(OrderItem::getQuantity).sum();
    }
}
