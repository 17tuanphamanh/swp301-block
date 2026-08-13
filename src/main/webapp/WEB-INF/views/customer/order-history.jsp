<c:set var="pageTitle" value="Đơn của tôi" /><c:set var="nav" value="orders" />
<%@ include file="/WEB-INF/views/layout/page-start.jspf" %>
  <div class="page-head"><h1>Đơn của tôi</h1></div>

  <%@ include file="/WEB-INF/views/layout/flash.jspf" %>

  <c:if test="${not empty activeOrders}">
    <div class="card">
      <h2>Đang theo dõi</h2>
      <div class="grid grid-3">
        <c:forEach var="o" items="${activeOrders}">
          <a class="kds-card ${o.online ? 'online' : 'pos'}" href="${ctx}/order/track?orderId=${o.orderId}">
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
      <c:when test="${pageData.emptyPage}">
        <div class="empty">
          <div class="icon" aria-hidden="true">📋</div>
          Bạn chưa có đơn hàng nào.
          <div class="mt"><a class="btn btn-primary" href="${ctx}/menu">Đặt món ngay</a></div>
        </div>
      </c:when>
      <c:otherwise>
        <table class="table-cards">
          <thead>
            <tr><th scope="col">Mã đơn</th><th scope="col">Đặt lúc</th><th scope="col">Giờ hẹn</th>
                <th scope="col" class="num">Tổng tiền</th><th scope="col">Trạng thái</th><th scope="col"><span class="visually-hidden">Thao tác</span></th></tr>
          </thead>
          <tbody>
            <c:forEach var="o" items="${pageData.items}">
              <tr>
                <td data-label="Mã đơn"><strong>#${o.orderId}</strong></td>
                <td class="small" data-label="Đặt lúc">${ff:dateTime(o.createdAt)}</td>
                <td class="small" data-label="Giờ hẹn">
                  <c:choose>
                    <c:when test="${o.online}">${ff:dateTime(o.pickupTime)}</c:when>
                    <c:otherwise><span class="muted">Mua tại quầy</span></c:otherwise>
                  </c:choose>
                </td>
                <td class="num" data-label="Tổng tiền">${ff:money(o.totalAmount)}</td>
                <td data-label="Trạng thái"><span class="${ff:orderStatusClass(o.orderStatus)}">${ff:orderStatus(o.orderStatus)}</span></td>
                <td class="center" data-label="">
                  <a class="btn touch" href="${ctx}/order/track?orderId=${o.orderId}">Xem</a>
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </c:otherwise>
    </c:choose>
    <%@ include file="/WEB-INF/views/layout/pager.jspf" %>
  </div>
<%@ include file="/WEB-INF/views/layout/page-end.jspf" %>
