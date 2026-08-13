package com.fastfood.common.constant;

/**
 * Role - mục 4 & 8 (ma trận phân quyền). MVP: 1 User = 1 Role.
 * RBAC được enforce ở backend (Filter + Service), không dựa UI hiding (case J mục 15).
 */
public enum RoleName {

    CUSTOMER,
    CASHIER,
    KITCHEN,
    ADMIN;

    public static RoleName from(String value) {
        for (RoleName r : values()) {
            if (r.name().equalsIgnoreCase(value)) {
                return r;
            }
        }
        throw new IllegalArgumentException("Unknown role: " + value);
    }
}
