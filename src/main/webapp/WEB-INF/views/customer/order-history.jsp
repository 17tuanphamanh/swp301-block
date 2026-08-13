<c:set var="pageTitle" value="Đơn của tôi" /><c:set var="nav" value="orders" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head"><h1>Đơn của tôi</h1></div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <c:if test="${not empty activeOrders}">
    <div class="card">
      <h2>Đang theo dõi</h2>
      <div class="grid grid-3">
        <c:forEach var="o" items="${activeOrders}">
          <a class="kds-card ${o.online ? 'online' : 'pos'}" href="${ctx}/order/track?orderId=${o.orderId}"
             style="color:inherit;">
            <div class="row-between">
              <strong>#${o.orderId}</strong>
              <span class="${ff:orderStatusClass(o.orderStatus)}">${ff:orderStatus(o.orderStatus)}</span>
            </div>
            <div class="meta mt">
              <span>${ff:money(o.totalAmount)}</span>
              <c:if test="${o.online}"><span>${ff:humanize(o.pickupTime)}</span></c:if>
            </div>
            <c:if test="${not empty o.pickupCode}">
              <div class="mono small mt">Mã: ${o.pickupCode}</div>
            </c:if>
          </a>
        </c:forEach>
      </div>
    </div>
  </c:if>

  <div class="card pad0 table-wrap">
    <div class="card-head"><h2>Toàn bộ lịch sử</h2></div>
    <c:choose>
      <c:when test="${empty orders}">
        <div class="empty">
          <div class="icon">📋</div>
          Bạn chưa có đơn hàng nào.
          <div class="mt"><a class="btn btn-primary" href="${ctx}/menu">Đặt món ngay</a></div>
        </div>
      </c:when>
      <c:otherwise>
        <table>
          <thead>
            <tr><th>Mã đơn</th><th>Đặt lúc</th><th>Giờ hẹn</th>
                <th class="num">Tổng tiền</th><th>Trạng thái</th><th></th></tr>
          </thead>
          <tbody>
            <c:forEach var="o" items="${orders}">
              <tr>
                <td><strong>#${o.orderId}</strong></td>
                <td class="small">${ff:dateTime(o.createdAt)}</td>
                <td class="small">
                  <c:choose>
                    <c:when test="${o.online}">${ff:dateTime(o.pickupTime)}</c:when>
                    <c:otherwise><span class="muted">Mua tại quầy</span></c:otherwise>
                  </c:choose>
                </td>
                <td class="num">${ff:money(o.totalAmount)}</td>
                <td><span class="${ff:orderStatusClass(o.orderStatus)}">${ff:orderStatus(o.orderStatus)}</span></td>
                <td class="center">
                  <a class="btn btn-sm" href="${ctx}/order/track?orderId=${o.orderId}">Xem</a>
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </c:otherwise>
    </c:choose>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
