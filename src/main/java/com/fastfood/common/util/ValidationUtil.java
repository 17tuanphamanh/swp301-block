package com.fastfood.common.util;

import com.fastfood.common.exception.ValidationException;

import java.util.regex.Pattern;

/** Kiểm tra dữ liệu người dùng nhập. Ném ValidationException với thông báo tiếng Việt. */
public final class ValidationUtil {

    private static final Pattern EMAIL = Pattern.compile("^[\\w.+-]+@[\\w-]+\\.[\\w.-]+$");
    private static final Pattern PHONE = Pattern.compile("^0\\d{9,10}$");

    private ValidationUtil() {
    }

    public static String requireText(String value, String fieldName) {
        if (value == null || value.trim().isEmpty()) {
            throw new ValidationException("Vui lòng nhập " + fieldName + ".");
        }
        return value.trim();
    }

    public static String requireEmail(String value) {
        String email = requireText(value, "email");
        if (!EMAIL.matcher(email).matches()) {
            throw new ValidationException("Địa chỉ email không hợp lệ.");
        }
        return email.toLowerCase();
    }

    public static String optionalPhone(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        String phone = value.trim();
        if (!PHONE.matcher(phone).matches()) {
            throw new ValidationException("Số điện thoại phải gồm 10 hoặc 11 chữ số và bắt đầu bằng 0.");
        }
        return phone;
    }

    public static void requirePasswordStrength(String password) {
        if (password == null || password.length() < 6) {
            throw new ValidationException("Mật khẩu phải có ít nhất 6 ký tự.");
        }
    }

    public static int requirePositive(int value, String fieldName) {
        if (value <= 0) {
            throw new ValidationException(fieldName + " phải lớn hơn 0.");
        }
        return value;
    }
}
