<c:set var="pageTitle" value="Thanh toán" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container narrow">
  <div class="card">
    <div class="alert alert-warn">
      <strong>Cổng thanh toán giả lập.</strong>
      Bản chạy thử không kết nối ngân hàng thật. Bạn chọn kết quả để diễn lại các tình huống
      như khi dùng cổng thật.
    </div>

    <h1>Xác nhận thanh toán</h1>
    <div class="mt mb">
      <div class="total-line"><span class="muted">Mã đơn</span><span>#${orderId}</span></div>
      <div class="total-line"><span class="muted">Mã giao dịch</span><span class="mono small">${txnId}</span></div>
      <div class="total-line grand"><span>Số tiền</span><span>${amount} đ</span></div>
    </div>

    <div class="stack">
      <a class="btn btn-green btn-block"
         href="${ctx}/payment/callback?paymentId=${paymentId}&txnId=${txnId}&orderId=${orderId}&success=true&sig=${successSig}">
        Thanh toán thành công
      </a>
      <a class="btn btn-danger btn-block"
         href="${ctx}/payment/callback?paymentId=${paymentId}&txnId=${txnId}&orderId=${orderId}&success=false&sig=${failureSig}">
        Thanh toán thất bại
      </a>
      <a class="btn btn-block" href="${ctx}/order/track?orderId=${orderId}">
        Để sau — quay lại đơn hàng
      </a>
    </div>

    <p class="small muted mt">
      Thử bấm "thành công" hai lần: lần thứ hai hệ thống nhận ra giao dịch trùng và bỏ qua,
      không ghi nhận tiền thêm lần nữa.
    </p>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
