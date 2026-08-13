<c:set var="pageTitle" value="Đặt trước" /><c:set var="nav" value="cart" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container medium">
  <div class="page-head">
    <h1>Chọn giờ đến lấy</h1>
    <p>Món sẽ được làm sát giờ bạn hẹn để còn nóng khi bạn tới.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-side">
    <div>
      <form method="post" action="${ctx}/checkout" class="card">
        <input type="hidden" name="idempotencyKey" value="${idempotencyKey}">

        <div class="field">
          <label for="pickupTime">Giờ đến lấy</label>
          <input type="datetime-local" id="pickupTime" name="pickupTime"
                 value="${suggestedPickupTime}" min="${minPickupTime}" required>
          <p class="small muted mt">
            Sớm nhất là ${minLeadMinutes} phút kể từ bây giờ, đủ thời gian thanh toán và chế biến.
          </p>
        </div>

        <div class="alert alert-info">
          <strong>Nhận hàng tại cửa hàng.</strong>
          Hệ thống chưa có giao hàng tận nơi. Sau khi thanh toán bạn sẽ nhận được mã nhận hàng,
          đưa mã này tại quầy để lấy món.
        </div>

        <div class="field">
          <label>Phương thức thanh toán</label>
          <div class="card" style="margin:0; background:var(--soft);">
            <div class="row-between">
              <div>
                <strong>Thanh toán online</strong>
                <div class="small muted">Đơn đặt trước bắt buộc thanh toán trước khi cửa hàng nhận đơn.</div>
              </div>
              <span class="tag tag-info">Bắt buộc</span>
            </div>
          </div>
          <p class="small muted mt">
            Muốn trả tiền mặt? Bạn có thể mua trực tiếp tại quầy.
          </p>
        </div>

        <button type="submit" class="btn btn-primary btn-block">
          Đặt đơn và thanh toán ${ff:money(cart.totalAmount)}
        </button>
        <p class="small muted mt">
          Đơn chưa thanh toán trong ${paymentExpiryMinutes} phút sẽ tự hết hiệu lực.
        </p>
      </form>
    </div>

    <div class="card">
      <h2>Đơn của bạn</h2>
      <c:forEach var="item" items="${cart.items}">
        <div class="total-line">
          <span>${item.productName} <span class="muted">× ${item.quantity}</span></span>
          <span>${ff:money(item.lineTotal)}</span>
        </div>
      </c:forEach>
      <div class="total-line grand">
        <span>Tổng cộng</span>
        <span>${ff:money(cart.totalAmount)}</span>
      </div>
      <a class="btn btn-block mt" href="${ctx}/cart">Sửa giỏ hàng</a>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
