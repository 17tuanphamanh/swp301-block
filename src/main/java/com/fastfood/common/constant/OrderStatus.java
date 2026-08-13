package com.fastfood.common.constant;

/**
 * Order Status - Baseline V6 mục 7.1.
 * <p>
 * ONLINE_PREORDER: PENDING_PAYMENT -> CONFIRMED -> PREPARING -> READY -> COMPLETED
 * POS:             CONFIRMED -> PREPARING -> READY -> COMPLETED
 * <p>
 * PREPARING và READY do backend aggregate từ OrderItem (BR-11).
 */
public enum OrderStatus {

    /** Chỉ dùng cho ONLINE_PREORDER: Order đã tạo nhưng chưa có Payment PAID. */
    PENDING_PAYMENT,

    /** Đã thanh toán/đủ điều kiện. Online có thể đang chờ kitchen_release_at. */
    CONFIRMED,

    /** Ít nhất một released OrderItem đang PREPARING (aggregate). */
    PREPARING,

    /** Tất cả OrderItem READY; lưu ready_at (aggregate). */
    READY,

    /** Handoff thực tế hoàn tất. */
    COMPLETED,

    /** Hủy theo rule. Online normal cancel chỉ trước kitchen_release_at (BR-12). */
    CANCELLED,

    /** Online checkout không PAID trong payment window 15 phút (BR-13). */
    EXPIRED;

    /** BR-12: chỉ CONFIRMED mới được xét normal cancel. */
    public boolean isCancellable() {
        return this == CONFIRMED;
    }

    /** BR-15/BR-16: chỉ READY mới được handoff. */
    public boolean isHandoffable() {
        return this == READY;
    }

    /** Trạng thái kết thúc, không transition tiếp. */
    public boolean isFinal() {
        return this == COMPLETED || this == CANCELLED || this == EXPIRED;
    }
}
