<c:set var="pageTitle" value="Giỏ hàng" /><c:set var="nav" value="cart" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container medium">
  <div class="page-head"><h1>Giỏ hàng</h1></div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <c:if test="${cart.hasUnavailable}">
    <div class="alert alert-warn">
      Có món trong giỏ vừa hết hàng hoặc ngừng bán. Bỏ các món đó ra để tiếp tục đặt hàng.
      <form method="post" action="${ctx}/cart" class="inline-form">
        <input type="hidden" name="action" value="removeUnavailable">
        <button type="submit" class="btn btn-sm">Bỏ các món đó</button>
      </form>
    </div>
  </c:if>

  <c:choose>
    <c:when test="${empty cart.items}">
      <div class="card empty">
        <div class="icon">🛒</div>
        Giỏ hàng đang trống.
        <div class="mt"><a class="btn btn-primary" href="${ctx}/menu">Xem thực đơn</a></div>
      </div>
    </c:when>
    <c:otherwise>
      <div class="card pad0 table-wrap">
        <table>
          <thead>
            <tr>
              <th>Món</th><th class="num">Đơn giá</th>
              <th class="center">Số lượng</th><th class="num">Thành tiền</th><th></th>
            </tr>
          </thead>
          <tbody>
            <c:forEach var="item" items="${cart.items}">
              <tr>
                <td>
                  ${item.productName}
                  <c:if test="${not item.orderable}">
                    <div><span class="tag tag-red">Không còn phục vụ</span></div>
                  </c:if>
                </td>
                <td class="num">${ff:money(item.unitPrice)}</td>
                <td class="center">
                  <form method="post" action="${ctx}/cart" style="display:flex; gap:5px; justify-content:center;">
                    <input type="hidden" name="action" value="update">
                    <input type="hidden" name="cartItemId" value="${item.cartItemId}">
                    <input type="number" name="quantity" value="${item.quantity}" min="0" max="50"
                           style="width:66px; text-align:center;">
                    <button type="submit" class="btn btn-sm">Lưu</button>
                  </form>
                </td>
                <td class="num">${ff:money(item.lineTotal)}</td>
                <td class="center">
                  <form method="post" action="${ctx}/cart" class="inline-form">
                    <input type="hidden" name="action" value="remove">
                    <input type="hidden" name="cartItemId" value="${item.cartItemId}">
                    <button type="submit" class="btn btn-sm btn-danger">Bỏ</button>
                  </form>
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </div>

      <div class="card">
        <div class="total-line grand">
          <span>Tổng cộng</span>
          <span>${ff:money(cart.totalAmount)}</span>
        </div>
        <div class="actions mt">
          <a class="btn" href="${ctx}/menu">Chọn thêm món</a>
          <c:choose>
            <c:when test="${cart.checkoutable}">
              <a class="btn btn-primary" href="${ctx}/checkout">Đặt trước và chọn giờ lấy</a>
            </c:when>
            <c:otherwise>
              <button class="btn btn-primary" disabled>Đặt trước và chọn giờ lấy</button>
            </c:otherwise>
          </c:choose>
        </div>
      </div>
    </c:otherwise>
  </c:choose>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
