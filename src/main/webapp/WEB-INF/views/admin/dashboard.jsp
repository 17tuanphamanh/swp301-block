<c:set var="pageTitle" value="Tổng quan" /><c:set var="nav" value="dashboard" />
<%@ include file="/WEB-INF/views/layout/page-start.jspf" %>
  <div class="page-head"><h1>Tổng quan</h1></div>

  <%@ include file="/WEB-INF/views/layout/flash.jspf" %>

  <div class="card">
    <form method="get" action="${ctx}/admin/dashboard" class="form-row">
      <div class="field">
        <label for="from">Từ</label>
        <input type="datetime-local" id="from" name="from" value="<c:out value="${from}"/>">
      </div>
      <div class="field">
        <label for="to">Đến</label>
        <input type="datetime-local" id="to" name="to" value="<c:out value="${to}"/>">
      </div>
      <button type="submit" class="btn btn-primary">Xem</button>
    </form>
  </div>

  <div class="grid grid-4 mb">
    <div class="kpi">
      <div class="label">Doanh thu thuần</div>
      <div class="value">${ff:money(kpi.netRevenue)}</div>
      <div class="sub">Thu ${ff:money(kpi.grossRevenue)} · hoàn ${ff:money(kpi.refundedAmount)}</div>
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
        <thead><tr><th scope="col">Món</th><th scope="col">Nhóm</th><th scope="col" class="num">Đã bán</th><th scope="col" class="num">Doanh thu</th></tr></thead>
        <tbody>
          <c:forEach var="row" items="${bestSellers}">
            <tr>
              <td><c:out value="${row.label}"/></td>
              <td class="small muted"><c:out value="${row.subLabel}"/></td>
              <td class="num"><strong>${row.quantity}</strong></td>
              <td class="num">${ff:money(row.amount)}</td>
            </tr>
          </c:forEach>
          <c:if test="${empty bestSellers}">
            <tr><td colspan="4" class="center muted cell-empty">Chưa có đơn hoàn tất trong kỳ.</td></tr>
          </c:if>
        </tbody>
      </table>
    </div>

    <div class="card pad0 table-wrap">
      <div class="card-head"><h2>Thanh toán</h2></div>
      <table>
        <thead><tr><th scope="col">Phương thức</th><th scope="col">Trạng thái</th><th scope="col" class="num">Số lượt</th><th scope="col" class="num">Số tiền</th></tr></thead>
        <tbody>
          <c:forEach var="row" items="${paymentSummary}">
            <tr>
              <td><c:out value="${row.label}"/></td>
              <td><span class="${ff:paymentStatusClass(row.subLabel)}">${ff:paymentStatus(row.subLabel)}</span></td>
              <td class="num">${row.quantity}</td>
              <td class="num">${ff:money(row.amount)}</td>
            </tr>
          </c:forEach>
          <c:if test="${empty paymentSummary}">
            <tr><td colspan="4" class="center muted cell-empty">Chưa có giao dịch trong kỳ.</td></tr>
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
      <%-- role="img" kèm nhãn cho từng cột: không có nó thì trình đọc màn hình chỉ gặp một
           chuỗi ô trống, còn thuộc tính title thì chỉ chuột mới thấy. --%>
      <div class="chart" role="img" aria-label="Biểu đồ doanh thu theo ngày, ${fn:length(revenueByDay)} ngày">
        <c:forEach var="row" items="${revenueByDay}">
          <div class="chart-col"
               title="<c:out value="${row.label}"/>: ${ff:money(row.amount)}"
               aria-label="<c:out value="${row.label}"/>: ${ff:money(row.amount)}">
            <%-- Chỉ chiều cao còn nằm trong style: đó là số liệu, không phải kiểu hiển thị. --%>
            <div class="chart-bar"
                 style="height:${maxRevenue > 0 ? (row.amount * 130 / maxRevenue) : 0}px;"></div>
            <div class="small muted chart-label">
              ${fn:substring(row.label, 5, 10)}
            </div>
          </div>
        </c:forEach>
      </div>
    </div>
  </c:if>
<%@ include file="/WEB-INF/views/layout/page-end.jspf" %>
