<c:set var="pageTitle" value="Đơn hàng #${order.orderId}" /><c:set var="nav" value="orders" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container medium">
  <p class="small mb"><a href="${ctx}/order/history">← Tất cả đơn của tôi</a></p>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <div class="row-between mb">
      <div>
        <h1>Đơn hàng #${order.orderId}</h1>
        <p class="muted small">Đặt lúc ${ff:dateTime(order.createdAt)}</p>
      </div>
      <span class="${ff:orderStatusClass(order.orderStatus)}">${ff:orderStatus(order.orderStatus)}</span>
    </div>

    <%-- Tiến trình đơn. Bước hiện tại tô đậm để khách biết đang ở đâu. --%>
    <c:if test="${order.orderStatus ne 'CANCELLED' and order.orderStatus ne 'EXPIRED'}">
      <div class="steps">
        <c:set var="s" value="${order.orderStatus}" />
        <div class="step ${s ne 'PENDING_PAYMENT' ? 'done' : 'current'}">Thanh toán</div>
        <div class="step ${s eq 'CONFIRMED' ? 'current' : (s eq 'PREPARING' or s eq 'READY' or s eq 'COMPLETED' ? 'done' : '')}">Đã xác nhận</div>
        <div class="step ${s eq 'PREPARING' ? 'current' : (s eq 'READY' or s eq 'COMPLETED' ? 'done' : '')}">Đang chế biến</div>
        <div class="step ${s eq 'READY' ? 'current' : (s eq 'COMPLETED' ? 'done' : '')}">Sẵn sàng</div>
        <div class="step ${s eq 'COMPLETED' ? 'done' : ''}">Đã nhận</div>
      </div>
    </c:if>

    <c:if test="${order.overdue}">
      <div class="alert alert-warn">
        Món đã sẵn sàng và đã quá giờ hẹn. Đơn vẫn được giữ tại quầy, bạn tới lấy bất cứ lúc nào.
      </div>
    </c:if>

    <c:if test="${order.orderStatus eq 'PENDING_PAYMENT'}">
      <div class="alert alert-warn">
        Đơn chưa được thanh toán nên cửa hàng chưa nhận. Thanh toán để giữ suất.
        <div class="mt">
          <a class="btn btn-primary btn-sm" href="${ctx}/payment/start?orderId=${order.orderId}">
            Thanh toán ngay
          </a>
        </div>
      </div>
    </c:if>

    <c:if test="${order.orderStatus eq 'EXPIRED'}">
      <div class="alert alert-error">
        Đơn đã hết hạn thanh toán và không còn hiệu lực. Bạn có thể đặt lại đơn mới.
      </div>
    </c:if>

    <div class="grid grid-2 mt">
      <div>
        <h3>Thông tin nhận hàng</h3>
        <div class="total-line"><span class="muted">Hình thức</span><span>${ff:orderSource(order.orderSource)}</span></div>
        <c:if test="${order.online}">
          <div class="total-line">
            <span class="muted">Giờ hẹn</span>
            <span><strong>${ff:dateTime(order.pickupTime)}</strong></span>
          </div>
          <c:if test="${order.orderStatus eq 'CONFIRMED' or order.orderStatus eq 'PREPARING'}">
            <div class="total-line">
              <span class="muted">Trạng thái bếp</span>
              <span>${ff:releaseState(order.releaseState)}</span>
            </div>
          </c:if>
        </c:if>
        <c:if test="${not empty order.readyAt}">
          <div class="total-line"><span class="muted">Sẵn sàng lúc</span><span>${ff:dateTime(order.readyAt)}</span></div>
        </c:if>
        <c:if test="${not empty order.pickedUpAt}">
          <div class="total-line"><span class="muted">Đã nhận lúc</span><span>${ff:dateTime(order.pickedUpAt)}</span></div>
        </c:if>
        <c:if test="${not empty order.latestPayment}">
          <div class="total-line">
            <span class="muted">Thanh toán</span>
            <span class="${ff:paymentStatusClass(order.latestPayment.paymentStatus)}">
              ${ff:paymentStatus(order.latestPayment.paymentStatus)}
            </span>
          </div>
        </c:if>
      </div>

      <div>
        <c:if test="${not empty order.pickupCode}">
          <h3>Mã nhận hàng</h3>
          <div class="pickup-code">${order.pickupCode}</div>
          <c:if test="${not empty qrDataUri}">
            <div class="qr-box"><img src="${qrDataUri}" alt="Mã QR nhận hàng" width="160" height="160"></div>
          </c:if>
          <p class="small muted">Đưa mã này cho nhân viên tại quầy để nhận món.</p>
        </c:if>
      </div>
    </div>
  </div>

  <div class="card pad0 table-wrap">
    <div class="card-head"><h2>Món đã đặt</h2></div>
    <table>
      <thead><tr><th>Món</th><th class="center">SL</th><th class="num">Đơn giá</th><th class="num">Thành tiền</th><th class="center">Bếp</th></tr></thead>
      <tbody>
        <c:forEach var="item" items="${order.items}">
          <tr>
            <td>${item.productNameSnapshot}</td>
            <td class="center">${item.quantity}</td>
            <td class="num">${ff:money(item.unitPrice)}</td>
            <td class="num">${ff:money(item.lineTotal)}</td>
            <td class="center">
              <c:choose>
                <c:when test="${empty order.releasedToKdsAt}">
                  <span class="tag tag-muted">Chưa vào bếp</span>
                </c:when>
                <c:otherwise>
                  <span class="${ff:itemStatusClass(item.itemStatus)}">${ff:itemStatus(item.itemStatus)}</span>
                </c:otherwise>
              </c:choose>
            </td>
          </tr>
        </c:forEach>
      </tbody>
      <tfoot>
        <tr><td colspan="3"><strong>Tổng cộng</strong></td>
            <td class="num"><strong>${ff:money(order.totalAmount)}</strong></td><td></td></tr>
      </tfoot>
    </table>
  </div>

  <c:if test="${order.cancellable}">
    <div class="card">
      <h3>Huỷ đơn</h3>
      <p class="small muted mb">
        Bếp chưa bắt đầu chuẩn bị nên bạn vẫn huỷ được. Tiền đã thanh toán sẽ được hoàn lại đầy đủ.
        Sau ${ff:dateTime(order.kitchenReleaseAt)} thì không huỷ được nữa.
      </p>
      <form method="post" action="${ctx}/order/track"
            onsubmit="return confirm('Huỷ đơn hàng này?');">
        <input type="hidden" name="orderId" value="${order.orderId}">
        <button type="submit" class="btn btn-danger">Huỷ đơn hàng</button>
      </form>
    </div>
  </c:if>
</main>

<%-- Tự cập nhật trạng thái để khách không phải bấm tải lại khi đang chờ món. --%>
<c:if test="${order.orderStatus eq 'CONFIRMED' or order.orderStatus eq 'PREPARING'}">
  <script>
    var orderId = ${order.orderId};
    var current = '${order.orderStatus}';
    setInterval(function () {
      fetch('${ctx}/api/order/status?orderId=' + orderId)
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (data) {
          if (data && data.status !== current) { location.reload(); }
        })
        .catch(function () { /* mất mạng tạm thời thì thử lại ở lần sau */ });
    }, 10000);
  </script>
</c:if>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
