<c:set var="pageTitle" value="Tài khoản" /><c:set var="nav" value="users" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head">
    <h1>Tài khoản</h1>
    <p>Nhân viên nghỉ việc thì khoá tài khoản, không xoá — để lịch sử đơn người đó xử lý vẫn tra được.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-side">
    <div>
      <div class="card">
        <form method="get" action="${ctx}/admin/users" class="form-row">
          <div class="field">
            <label for="keyword">Tìm theo tên hoặc email</label>
            <input type="search" id="keyword" name="keyword" value="${keyword}">
          </div>
          <div class="field">
            <label for="roleFilter">Vai trò</label>
            <select id="roleFilter" name="role">
              <option value="">Tất cả</option>
              <c:forEach var="r" items="${roles}">
                <option value="${r.name}" ${role eq r.name ? 'selected' : ''}>${ff:roleName(r.name)}</option>
              </c:forEach>
            </select>
          </div>
          <button type="submit" class="btn btn-primary">Lọc</button>
        </form>
      </div>

      <div class="card pad0 table-wrap">
        <table>
          <thead><tr><th>Họ tên</th><th>Email</th><th>Vai trò</th><th>Trạng thái</th><th></th></tr></thead>
          <tbody>
            <c:forEach var="u" items="${users}">
              <tr>
                <td><strong>${u.fullName}</strong>
                  <div class="small muted">${u.phone}</div></td>
                <td class="small mono">${u.email}</td>
                <td>
                  <form method="post" action="${ctx}/admin/users" style="display:flex; gap:4px;">
                    <input type="hidden" name="action" value="changeRole">
                    <input type="hidden" name="userId" value="${u.userId}">
                    <select name="roleId" onchange="this.form.submit()" style="font-size:12px; padding:3px 6px;">
                      <c:forEach var="r" items="${roles}">
                        <option value="${r.roleId}" ${u.roleId eq r.roleId ? 'selected' : ''}>${ff:roleName(r.name)}</option>
                      </c:forEach>
                    </select>
                  </form>
                </td>
                <td>
                  <span class="tag ${u.active ? 'tag-green' : 'tag-red'}">
                    ${u.active ? 'Hoạt động' : 'Đã khoá'}
                  </span>
                </td>
                <td class="center">
                  <div class="actions" style="justify-content:center;">
                    <form method="post" action="${ctx}/admin/users" class="inline-form">
                      <input type="hidden" name="action" value="${u.active ? 'lock' : 'unlock'}">
                      <input type="hidden" name="userId" value="${u.userId}">
                      <button type="submit" class="btn btn-sm ${u.active ? 'btn-danger' : ''}">
                        ${u.active ? 'Khoá' : 'Mở khoá'}
                      </button>
                    </form>
                    <form method="post" action="${ctx}/admin/users" class="inline-form"
                          onsubmit="return confirm('Đặt lại mật khẩu cho ${u.fullName}?');">
                      <input type="hidden" name="action" value="resetPassword">
                      <input type="hidden" name="userId" value="${u.userId}">
                      <input type="hidden" name="newPassword" value="123456">
                      <button type="submit" class="btn btn-sm">Đặt lại mật khẩu</button>
                    </form>
                  </div>
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </div>
      <p class="small muted">Đặt lại mật khẩu sẽ đưa về <span class="mono">123456</span>.</p>
    </div>

    <div class="card">
      <h2>Tạo tài khoản nhân viên</h2>
      <p class="small muted mb">Khách hàng tự đăng ký. Tài khoản nhân viên do quản trị viên tạo.</p>
      <form method="post" action="${ctx}/admin/users">
        <input type="hidden" name="action" value="create">
        <div class="field">
          <label for="fullName">Họ và tên</label>
          <input type="text" id="fullName" name="fullName" required>
        </div>
        <div class="field">
          <label for="email">Email</label>
          <input type="email" id="email" name="email" required>
        </div>
        <div class="field">
          <label for="phone">Số điện thoại</label>
          <input type="text" id="phone" name="phone">
        </div>
        <div class="field">
          <label for="roleId">Vai trò</label>
          <select id="roleId" name="roleId" required>
            <c:forEach var="r" items="${roles}">
              <c:if test="${r.name ne 'CUSTOMER'}">
                <option value="${r.roleId}">${ff:roleName(r.name)}</option>
              </c:if>
            </c:forEach>
          </select>
        </div>
        <div class="field">
          <label for="password">Mật khẩu ban đầu</label>
          <input type="password" id="password" name="password" value="123456" required>
        </div>
        <button type="submit" class="btn btn-primary btn-block">Tạo tài khoản</button>
      </form>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
