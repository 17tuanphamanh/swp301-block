/**
 * Tầng nghiệp vụ. Đây là nơi đặt toàn bộ quy tắc kinh doanh và ranh giới giao dịch.
 * Lớp đáng đọc trước tiên là OrderService (vòng đời đơn hàng), PaymentService
 * (chống ghi nhận tiền hai lần) và ScheduleService (đưa đơn xuống bếp đúng giờ).
 */
package com.fastfood.service;
