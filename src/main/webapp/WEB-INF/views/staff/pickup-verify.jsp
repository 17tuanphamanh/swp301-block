<c:set var="pageTitle" value="Tra mã nhận hàng" /><c:set var="nav" value="pickup" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container medium">
  <div class="page-head">
    <h1>Tra mã nhận hàng</h1>
    <p>Nhập hoặc quét mã khách đưa để xem đơn tương ứng.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <form method="get" action="${ctx}/staff/pickup/verify" class="form-row">
      <div class="field">
        <label for="code">Mã nhận hàng</label>
        <input type="text" id="code" name="code" value="${code}" class="mono" autofocus
               placeholder="VD: 260813A1C7" style="text-transform:uppercase; letter-spacing:0.1em;">
      </div>
      <button type="submit" class="btn btn-primary">Tra cứu</button>
    </form>
  </div>

  <c:if test="${not empty order}">
    <div class="card">
      <div class="row-between mb">
        <div>
          <h2>Đơn #${order.orderId}</h2>
          <p class="small muted">${empty order.customerName ? 'Khách tại quầy' : order.customerName}</p>
        </div>
        <span class="${ff:orderStatusClass(order.orderStatus)}">${ff:orderStatus(order.orderStatus)}</span>
      </div>

      <div class="grid grid-2">
        <div>
          <div class="total-line"><span class="muted">Giờ hẹn</span><span>${ff:dateTime(order.pickupTime)}</span></div>
          <div class="total-line"><span class="muted">Sẵn sàng lúc</span>
            <span>${empty order.readyAt ? 'Chưa xong' : ff:dateTime(order.readyAt)}</span></div>
        </div>
        <div>
          <div class="total-line"><span class="muted">Thanh toán</span>
            <span class="${ff:paymentStatusClass(order.latestPayment.paymentStatus)}">
              ${ff:paymentStatus(order.latestPayment.paymentStatus)}</span></div>
          <div class="total-line grand"><span>Tổng tiền</span><span>${ff:money(order.totalAmount)}</span></div>
        </div>
      </div>

      <ul class="mt" style="padding-left:18px;">
        <c:forEach var="item" items="${order.items}">
          <li>${item.productNameSnapshot} × ${item.quantity}
            <span class="${ff:itemStatusClass(item.itemStatus)}">${ff:itemStatus(item.itemStatus)}</span>
          </li>
        </c:forEach>
      </ul>

      <div class="actions mt">
        <a class="btn btn-primary" href="${ctx}/staff/order/detail?orderId=${order.orderId}">
          Mở đơn để giao món
        </a>
      </div>
    </div>
  </c:if>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
