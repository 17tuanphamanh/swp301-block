<c:set var="pageTitle" value="Đơn #${order.orderId}" /><c:set var="nav" value="orders" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <p class="small mb"><a href="${ctx}/staff/orders">← Danh sách đơn hàng</a></p>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-side">
    <div>
      <div class="card">
        <div class="row-between mb">
          <div>
            <h1>Đơn #${order.orderId}</h1>
            <p class="small muted">
              ${ff:orderSource(order.orderSource)} · đặt lúc ${ff:dateTime(order.createdAt)}
            </p>
          </div>
          <span class="${ff:orderStatusClass(order.orderStatus)}">${ff:orderStatus(order.orderStatus)}</span>
        </div>

        <div class="grid grid-2">
          <div>
            <div class="total-line"><span class="muted">Khách hàng</span>
              <span>${empty order.customerName ? 'Khách tại quầy' : order.customerName}</span></div>
            <c:if test="${order.online}">
              <div class="total-line"><span class="muted">Giờ hẹn</span>
                <span><strong>${ff:dateTime(order.pickupTime)}</strong></span></div>
              <div class="total-line"><span class="muted">Kế hoạch vào bếp</span>
                <span>${ff:dateTime(order.kitchenReleaseAt)}</span></div>
            </c:if>
            <div class="total-line"><span class="muted">Bếp nhận lúc</span>
              <span>${empty order.releasedToKdsAt ? 'Chưa nhận' : ff:dateTime(order.releasedToKdsAt)}</span></div>
          </div>
          <div>
            <c:if test="${not empty order.readyAt}">
              <div class="total-line"><span class="muted">Sẵn sàng lúc</span><span>${ff:dateTime(order.readyAt)}</span>
              </div>
            </c:if>
            <c:if test="${not empty order.pickedUpAt}">
              <div class="total-line"><span class="muted">Giao lúc</span><span>${ff:dateTime(order.pickedUpAt)}</span></div>
              <div class="total-line"><span class="muted">Người giao</span><span>${order.handoffByName}</span></div>
            </c:if>
            <div class="total-line grand"><span>Tổng tiền</span><span>${ff:money(order.totalAmount)}</span></div>
          </div>
        </div>
      </div>

      <div class="card pad0 table-wrap">
        <div class="card-head"><h2>Món trong đơn</h2></div>
        <table>
          <thead><tr><th>Món</th><th class="center">SL</th><th class="num">Đơn giá</th>
                     <th class="num">Thành tiền</th><th>Bếp</th><th>Người làm</th></tr></thead>
          <tbody>
            <c:forEach var="item" items="${order.items}">
              <tr>
                <td>${item.productNameSnapshot}
                  <c:if test="${item.openIssueCount > 0}">
                    <span class="tag tag-red">${item.openIssueCount} sự cố</span>
                  </c:if>
                </td>
                <td class="center">${item.quantity}</td>
                <td class="num">${ff:money(item.unitPrice)}</td>
                <td class="num">${ff:money(item.lineTotal)}</td>
                <td><span class="${ff:itemStatusClass(item.itemStatus)}">${ff:itemStatus(item.itemStatus)}</span></td>
                <td class="small muted">${empty item.assignedToName ? '—' : item.assignedToName}</td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </div>

      <div class="card pad0 table-wrap">
        <div class="card-head"><h2>Thanh toán</h2></div>
        <table>
          <thead><tr><th class="center">Lần</th><th>Phương thức</th><th class="num">Số tiền</th>
                     <th>Trạng thái</th><th>Thời điểm</th></tr></thead>
          <tbody>
            <c:forEach var="p" items="${payments}">
              <tr>
                <td class="center">${p.attemptNo}</td>
                <td>${ff:paymentMethod(p.method)}</td>
                <td class="num">${ff:money(p.amount)}</td>
                <td><span class="${ff:paymentStatusClass(p.paymentStatus)}">${ff:paymentStatus(p.paymentStatus)}</span></td>
                <td class="small muted">
                  ${empty p.paidAt ? ff:dateTime(p.createdAt) : ff:dateTime(p.paidAt)}
                </td>
              </tr>
            </c:forEach>
            <c:if test="${empty payments}">
              <tr><td colspan="5" class="muted center">Chưa có giao dịch nào.</td></tr>
            </c:if>
          </tbody>
        </table>
      </div>

      <div class="card pad0 table-wrap">
        <div class="card-head"><h2>Nhật ký thao tác</h2></div>
        <table>
          <thead><tr><th>Thời điểm</th><th>Thao tác</th><th>Người thực hiện</th><th>Thay đổi</th></tr></thead>
          <tbody>
            <c:forEach var="log" items="${auditLogs}">
              <tr>
                <td class="small muted">${ff:dateTime(log.createdAt)}</td>
                <td>${ff:auditAction(log.action)}</td>
                <td class="small">${log.actorDisplay}</td>
                <td class="small muted">
                  <c:if test="${not empty log.oldValue}">${log.oldValue} → </c:if>${log.newValue}
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </div>
    </div>

    <div>
      <c:if test="${order.orderStatus eq 'READY'}">
        <div class="card">
          <h2>Giao món cho khách</h2>
          <c:choose>
            <c:when test="${order.online}">
              <p class="small muted mb">
                Nhập mã khách đưa. Mã sai thì hệ thống từ chối giao — tránh đưa nhầm đơn.
              </p>
              <form method="post" action="${ctx}/staff/order/detail">
                <input type="hidden" name="orderId" value="${order.orderId}">
                <input type="hidden" name="action" value="handoff">
                <div class="field">
                  <label for="pickupCode">Mã nhận hàng</label>
                  <input type="text" id="pickupCode" name="pickupCode" class="mono"
                         placeholder="VD: 260813A1C7" required autofocus
                         style="text-transform:uppercase; letter-spacing:0.1em;">
                </div>
                <button type="submit" class="btn btn-green btn-block">Xác minh và giao món</button>
              </form>
            </c:when>
            <c:otherwise>
              <p class="small muted mb">Đơn tại quầy, khách đang đứng đợi — giao trực tiếp.</p>
              <form method="post" action="${ctx}/staff/order/detail">
                <input type="hidden" name="orderId" value="${order.orderId}">
                <input type="hidden" name="action" value="handoff">
                <button type="submit" class="btn btn-green btn-block">Đã giao món</button>
              </form>
            </c:otherwise>
          </c:choose>
        </div>
      </c:if>

      <c:if test="${order.cancellable}">
        <div class="card">
          <h2>Huỷ đơn</h2>
          <p class="small muted mb">Bếp chưa nhận việc nên còn huỷ được. Tiền sẽ được hoàn đầy đủ.</p>
          <form method="post" action="${ctx}/staff/order/detail"
                onsubmit="return confirm('Huỷ đơn #${order.orderId}?');">
            <input type="hidden" name="orderId" value="${order.orderId}">
            <input type="hidden" name="action" value="cancel">
            <button type="submit" class="btn btn-danger btn-block">Huỷ đơn</button>
          </form>
        </div>
      </c:if>

      <c:if test="${order.orderStatus ne 'COMPLETED' and not empty order.latestPayment
                    and order.latestPayment.paymentStatus eq 'PAID'}">
        <div class="card">
          <h2>Hoàn tiền</h2>
          <p class="small muted mb">Hoàn toàn bộ số tiền của đơn. Không có hoàn một phần.</p>
          <form method="post" action="${ctx}/staff/order/detail"
                onsubmit="return confirm('Hoàn tiền cho đơn #${order.orderId}?');">
            <input type="hidden" name="orderId" value="${order.orderId}">
            <input type="hidden" name="action" value="refund">
            <button type="submit" class="btn btn-danger btn-block">
              Hoàn ${ff:money(order.totalAmount)}
            </button>
          </form>
        </div>
      </c:if>

      <c:if test="${not empty order.pickupCode}">
        <div class="card">
          <h3>Mã nhận hàng của đơn</h3>
          <div class="pickup-code">${order.pickupCode}</div>
        </div>
      </c:if>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
