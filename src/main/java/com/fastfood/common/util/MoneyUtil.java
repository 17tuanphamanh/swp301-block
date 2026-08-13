package com.fastfood.common.util;

import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.Locale;

/** Định dạng tiền Việt: 55000 -> "55.000 đ". */
public final class MoneyUtil {

    private static final DecimalFormat FORMAT;

    static {
        DecimalFormatSymbols symbols = new DecimalFormatSymbols(Locale.forLanguageTag("vi-VN"));
        symbols.setGroupingSeparator('.');
        FORMAT = new DecimalFormat("#,###", symbols);
    }

    private MoneyUtil() {
    }

    public static String format(BigDecimal amount) {
        return amount == null ? "0 đ" : FORMAT.format(amount) + " đ";
    }

    public static BigDecimal multiply(BigDecimal unitPrice, int quantity) {
        return unitPrice == null ? BigDecimal.ZERO : unitPrice.multiply(BigDecimal.valueOf(quantity));
    }
}
