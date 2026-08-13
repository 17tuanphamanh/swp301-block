package com.fastfood.model.entity;

import com.fastfood.common.constant.OrderItemStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Một dòng món trong đơn, đồng thời là một việc trên màn hình bếp.
 * <p>
 * Tên và giá được sao chép lại tại thời điểm đặt hàng. Nhờ vậy khi quản trị viên
 * sửa giá món thì hoá đơn cũ vẫn giữ nguyên giá lúc khách mua.
 * <p>
 * Mỗi dòng là một việc nguyên khối: đặt 3 phần gà thì bếp làm xong cả 3 mới đánh dấu
 * hoàn thành, không có trạng thái xong một phần.
 */
public class OrderItem {

    private int orderItemId;
    private int orderId;
    private int productId;
    private String productNameSnapshot;
    private BigDecimal unitPrice;
    private int quantity;
    private String itemStatus;
    private Integer assignedToUserId;
    private LocalDateTime startedAt;
    private LocalDateTime readyAt;

    // Dữ liệu lấy kèm để màn hình bếp biết đơn này gấp tới đâu
    private String assignedToName;
    private String orderSource;
    private LocalDateTime pickupTime;
    private int openIssueCount;

    public int getOrderItemId() { return orderItemId; }
    public void setOrderItemId(int orderItemId) { this.orderItemId = orderItemId; }

    public int getOrderId() { return orderId; }
    public void setOrderId(int orderId) { this.orderId = orderId; }

    public int getProductId() { return productId; }
    public void setProductId(int productId) { this.productId = productId; }

    public String getProductNameSnapshot() { return productNameSnapshot; }
    public void setProductNameSnapshot(String productNameSnapshot) { this.productNameSnapshot = productNameSnapshot; }

    public BigDecimal getUnitPrice() { return unitPrice; }
    public void setUnitPrice(BigDecimal unitPrice) { this.unitPrice = unitPrice; }

    public int getQuantity() { return quantity; }
    public void setQuantity(int quantity) { this.quantity = quantity; }

    public String getItemStatus() { return itemStatus; }
    public void setItemStatus(String itemStatus) { this.itemStatus = itemStatus; }

    public Integer getAssignedToUserId() { return assignedToUserId; }
    public void setAssignedToUserId(Integer assignedToUserId) { this.assignedToUserId = assignedToUserId; }

    public LocalDateTime getStartedAt() { return startedAt; }
    public void setStartedAt(LocalDateTime startedAt) { this.startedAt = startedAt; }

    public LocalDateTime getReadyAt() { return readyAt; }
    public void setReadyAt(LocalDateTime readyAt) { this.readyAt = readyAt; }

    public String getAssignedToName() { return assignedToName; }
    public void setAssignedToName(String assignedToName) { this.assignedToName = assignedToName; }

    public String getOrderSource() { return orderSource; }
    public void setOrderSource(String orderSource) { this.orderSource = orderSource; }

    public LocalDateTime getPickupTime() { return pickupTime; }
    public void setPickupTime(LocalDateTime pickupTime) { this.pickupTime = pickupTime; }

    public int getOpenIssueCount() { return openIssueCount; }
    public void setOpenIssueCount(int openIssueCount) { this.openIssueCount = openIssueCount; }

    public BigDecimal getLineTotal() {
        return unitPrice == null ? BigDecimal.ZERO : unitPrice.multiply(BigDecimal.valueOf(quantity));
    }

    public OrderItemStatus statusEnum() { return OrderItemStatus.valueOf(itemStatus); }

    public boolean isWaiting()   { return OrderItemStatus.WAITING.name().equals(itemStatus); }
    public boolean isPreparing() { return OrderItemStatus.PREPARING.name().equals(itemStatus); }
    public boolean isReady()     { return OrderItemStatus.READY.name().equals(itemStatus); }

    public boolean isClaimed() { return assignedToUserId != null; }
}
