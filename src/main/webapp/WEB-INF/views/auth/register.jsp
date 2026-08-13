<c:set var="pageTitle" value="Đăng ký" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container narrow">
  <div class="page-head">
    <h1>Tạo tài khoản</h1>
    <p>Tài khoản khách hàng để đặt trước món và hẹn giờ đến lấy.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <form method="post" action="${ctx}/register">
      <div class="field">
        <label for="fullName">Họ và tên</label>
        <input type="text" id="fullName" name="fullName" value="${fullName}" required autofocus>
      </div>
      <div class="field">
        <label for="email">Email</label>
        <input type="email" id="email" name="email" value="${email}" required>
      </div>
      <div class="field">
        <label for="phone">Số điện thoại <span class="hint">(không bắt buộc)</span></label>
        <input type="text" id="phone" name="phone" value="${phone}" placeholder="0901234567">
      </div>
      <div class="field">
        <label for="password">Mật khẩu <span class="hint">(tối thiểu 6 ký tự)</span></label>
        <input type="password" id="password" name="password" required>
      </div>
      <div class="field">
        <label for="confirmPassword">Nhập lại mật khẩu</label>
        <input type="password" id="confirmPassword" name="confirmPassword" required>
      </div>
      <button type="submit" class="btn btn-primary btn-block">Đăng ký</button>
    </form>
    <p class="small muted mt">Đã có tài khoản? <a href="${ctx}/login">Đăng nhập</a></p>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
