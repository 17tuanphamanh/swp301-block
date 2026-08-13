<c:set var="pageTitle" value="Đăng nhập" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container narrow">
  <div class="page-head">
    <h1>Đăng nhập</h1>
    <p>Đặt trước và hẹn giờ đến lấy cần đăng nhập. Mua trực tiếp tại quầy thì không cần.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <form method="post" action="${ctx}/login">
      <div class="field">
        <label for="email">Email</label>
        <input type="email" id="email" name="email" value="${email}" required autofocus>
      </div>
      <div class="field">
        <label for="password">Mật khẩu</label>
        <input type="password" id="password" name="password" required>
      </div>
      <button type="submit" class="btn btn-primary btn-block">Đăng nhập</button>
    </form>
    <p class="small muted mt">Chưa có tài khoản? <a href="${ctx}/register">Đăng ký</a></p>
  </div>

  <div class="card">
    <h3>Tài khoản dùng thử</h3>
    <p class="small muted mb">Mật khẩu chung: <span class="mono">123456</span></p>
    <table>
      <tr><td>Khách hàng</td><td class="mono small">customer1@gmail.com</td></tr>
      <tr><td>Thu ngân</td><td class="mono small">cashier1@fastfood.vn</td></tr>
      <tr><td>Bếp</td><td class="mono small">kitchen1@fastfood.vn</td></tr>
      <tr><td>Quản trị</td><td class="mono small">admin@fastfood.vn</td></tr>
    </table>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
