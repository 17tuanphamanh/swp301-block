<c:set var="pageTitle" value="Tổng quan" /><c:set var="nav" value="dashboard" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head"><h1>Tổng quan</h1></div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <form method="get" action="${ctx}/admin/dashboard" class="form-row">
      <div class="field">
        <label for="from">Từ</label>
        <input type="datetime-local" id="from" name="from" value="${from}">
      </div>
      <div class="field">
        <label for="to">Đến</label>
        <input type="datetime-local" id="to" name="to" value="${to}">
      </div>
      <button type="submit" class="btn btn-primary">Xem</button>
    </form>
  </div>

  <div class="grid grid-4 mb">
    <div class="kpi">
      <div class="label">Doanh thu thuần</div>
      <div class="value">${ff:money(kpi.netRevenue)}</div>
      <div class="sub">Đã trừ ${ff:money(kpi.refundedAmount)} hoàn tiền</div>
    </div>
    <div class="kpi">
      <div class="label">Số đơn</div>
      <div class="value">${kpi.totalOrderCount}</div>
      <div class="sub">${kpi.onlineOrderCount} đặt trước · ${kpi.posOrderCount} tại quầy</div>
    </div>
    <div class="kpi ${kpi.onTimeReadyRate >= 90 ? 'good' : (kpi.onTimeReadyRate >= 70 ? 'warn' : 'bad')}">
      <div class="label">Món xong đúng hẹn</div>
      <div class="value"><fmt:formatNumber value="${kpi.onTimeReadyRate}" maxFractionDigits="1"/>%</div>
      <div class="sub">${kpi.onTimeReadyCount}/${kpi.totalReadyMeasured} đơn đặt trước</div>
    </div>
    <div class="kpi ${kpi.overduePickupCount > 0 ? 'warn' : ''}">
      <div class="label">Khách đến muộn</div>
      <div class="value">${kpi.overduePickupCount}</div>
      <div class="sub">${kpi.readyOrderCount} đơn đang chờ khách lấy</div>
    </div>
  </div>

  <div class="grid grid-4 mb">
    <div class="kpi">
      <div class="label">Đã giao</div>
      <div class="value">${kpi.completedOrderCount}</div>
    </div>
    <div class="kpi">
      <div class="label">Đã huỷ</div>
      <div class="value">${kpi.cancelledOrderCount}</div>
    </div>
    <div class="kpi">
      <div class="label">Hết hạn thanh toán</div>
      <div class="value">${kpi.expiredOrderCount}</div>
    </div>
    <div class="kpi">
      <div class="label">Thời gian làm trung bình</div>
      <div class="value">
        <c:choose>
          <c:when test="${empty kpi.avgPrepLeadMinutes}">—</c:when>
          <c:otherwise><fmt:formatNumber value="${kpi.avgPrepLeadMinutes}" maxFractionDigits="0"/> phút</c:otherwise>
        </c:choose>
      </div>
      <div class="sub">Từ lúc bếp nhận tới lúc xong</div>
    </div>
  </div>

  <div class="grid grid-2">
    <div class="card pad0 table-wrap">
      <div class="card-head"><h2>Món bán chạy</h2></div>
      <table>
        <thead><tr><th>Món</th><th>Nhóm</th><th class="num">Đã bán</th><th class="num">Doanh thu</th></tr></thead>
        <tbody>
          <c:forEach var="row" items="${bestSellers}">
            <tr>
              <td>${row.label}</td>
              <td class="small muted">${row.subLabel}</td>
              <td class="num"><strong>${row.quantity}</strong></td>
              <td class="num">${ff:money(row.amount)}</td>
            </tr>
          </c:forEach>
          <c:if test="${empty bestSellers}">
            <tr><td colspan="4" class="center muted" style="padding:26px;">Chưa có đơn hoàn tất trong kỳ.</td></tr>
          </c:if>
        </tbody>
      </table>
    </div>

    <div class="card pad0 table-wrap">
      <div class="card-head"><h2>Thanh toán</h2></div>
      <table>
        <thead><tr><th>Phương thức</th><th>Trạng thái</th><th class="num">Số lượt</th><th class="num">Số tiền</th></tr></thead>
        <tbody>
          <c:forEach var="row" items="${paymentSummary}">
            <tr>
              <td>${row.label}</td>
              <td><span class="${ff:paymentStatusClass(row.subLabel)}">${ff:paymentStatus(row.subLabel)}</span></td>
              <td class="num">${row.quantity}</td>
              <td class="num">${ff:money(row.amount)}</td>
            </tr>
          </c:forEach>
          <c:if test="${empty paymentSummary}">
            <tr><td colspan="4" class="center muted" style="padding:26px;">Chưa có giao dịch trong kỳ.</td></tr>
          </c:if>
        </tbody>
      </table>
    </div>
  </div>

  <c:if test="${not empty revenueByDay}">
    <div class="card">
      <h2>Doanh thu theo ngày</h2>
      <c:set var="maxRevenue" value="0" />
      <c:forEach var="row" items="${revenueByDay}">
        <c:if test="${row.amount > maxRevenue}"><c:set var="maxRevenue" value="${row.amount}" /></c:if>
      </c:forEach>
      <div style="display:flex; align-items:flex-end; gap:6px; height:150px; padding-top:10px;">
        <c:forEach var="row" items="${revenueByDay}">
          <div style="flex:1; text-align:center;" title="${row.label}: ${ff:money(row.amount)}">
            <div style="background:var(--brand); border-radius:4px 4px 0 0;
                        height:${maxRevenue > 0 ? (row.amount * 130 / maxRevenue) : 0}px;"></div>
            <div class="small muted" style="font-size:10px; margin-top:4px;">
              ${fn:substring(row.label, 5, 10)}
            </div>
          </div>
        </c:forEach>
      </div>
    </div>
  </c:if>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
