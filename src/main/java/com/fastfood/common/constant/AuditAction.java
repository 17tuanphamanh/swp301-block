package com.fastfood.common.constant;

/**
 * Audit action - NFR-08: payment success, auto-confirm, KDS release, item start/ready,
 * pickup verification, handoff, cancel/refund và admin action đều phải có audit event.
 */
public final class AuditAction {

    // Payment
    public static final String PAYMENT_INITIATED = "PAYMENT_INITIATED";
    public static final String PAYMENT_PAID      = "PAYMENT_PAID";
    public static final String PAYMENT_FAILED    = "PAYMENT_FAILED";
    public static final String PAYMENT_REFUNDED  = "PAYMENT_REFUNDED";
    public static final String CALLBACK_IGNORED  = "CALLBACK_IGNORED";   // duplicate external_transaction_id

    // Order lifecycle
    public static final String ORDER_CREATED     = "ORDER_CREATED";
    public static final String AUTO_CONFIRM      = "AUTO_CONFIRM";       // BR-07
    public static final String POS_CONFIRM       = "POS_CONFIRM";        // BR-10
    public static final String ORDER_EXPIRED     = "ORDER_EXPIRED";      // BR-13
    public static final String ORDER_CANCELLED   = "ORDER_CANCELLED";    // BR-12
    public static final String ORDER_COMPLETED   = "ORDER_COMPLETED";    // BR-16

    // Kitchen / KDS
    public static final String KDS_RELEASE       = "KDS_RELEASE";        // BR-09, ghi 1 lần
    public static final String ITEM_CLAIM        = "ITEM_CLAIM";
    public static final String ITEM_START        = "ITEM_START";
    public static final String ITEM_READY        = "ITEM_READY";
    public static final String ISSUE_OPENED      = "ISSUE_OPENED";
    public static final String ISSUE_RESOLVED    = "ISSUE_RESOLVED";

    // Pickup
    public static final String PICKUP_VERIFY_OK     = "PICKUP_VERIFY_OK";     // BR-15
    public static final String PICKUP_VERIFY_FAILED = "PICKUP_VERIFY_FAILED"; // case F mục 15
    public static final String HANDOFF              = "HANDOFF";

    // Admin
    public static final String PRODUCT_CHANGED   = "PRODUCT_CHANGED";
    public static final String CATEGORY_CHANGED  = "CATEGORY_CHANGED";
    public static final String USER_CHANGED      = "USER_CHANGED";

    private AuditAction() {
    }
}
