<c:set var="pageTitle" value="Tài khoản" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container medium">
  <div class="page-head"><h1>Tài khoản</h1></div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-2">
    <div class="card">
      <h2>Thông tin cá nhân</h2>
      <form method="post" action="${ctx}/profile">
        <div class="field">
          <label>Email <span class="hint">(không đổi được)</span></label>
          <input type="email" value="${profile.email}" disabled>
        </div>
        <div class="field">
          <label>Vai trò</label>
          <input type="text" value="${ff:roleName(profile.roleName)}" disabled>
        </div>
        <div class="field">
          <label for="fullName">Họ và tên</label>
          <input type="text" id="fullName" name="fullName" value="${profile.fullName}" required>
        </div>
        <div class="field">
          <label for="phone">Số điện thoại</label>
          <input type="text" id="phone" name="phone" value="${profile.phone}">
        </div>
        <button type="submit" class="btn btn-primary">Lưu thay đổi</button>
      </form>
    </div>

    <div class="card">
      <h2>Đổi mật khẩu</h2>
      <form method="post" action="${ctx}/profile">
        <input type="hidden" name="action" value="changePassword">
        <div class="field">
          <label for="currentPassword">Mật khẩu hiện tại</label>
          <input type="password" id="currentPassword" name="currentPassword" required>
        </div>
        <div class="field">
          <label for="newPassword">Mật khẩu mới <span class="hint">(tối thiểu 6 ký tự)</span></label>
          <input type="password" id="newPassword" name="newPassword" required>
        </div>
        <div class="field">
          <label for="confirmPassword">Nhập lại mật khẩu mới</label>
          <input type="password" id="confirmPassword" name="confirmPassword" required>
        </div>
        <button type="submit" class="btn btn-primary">Đổi mật khẩu</button>
      </form>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
