<c:set var="pageTitle" value="Tài khoản" /><c:set var="nav" value="users" />
<%@ include file="/WEB-INF/views/layout/page-start.jspf" %>
  <div class="page-head">
    <h1>Tài khoản</h1>
    <p>Nhân viên nghỉ việc thì khoá tài khoản, không xoá — để lịch sử đơn người đó xử lý vẫn tra được.</p>
  </div>

  <%@ include file="/WEB-INF/views/layout/flash.jspf" %>

  <div class="grid grid-side">
    <div>
      <div class="card">
        <form method="get" action="${ctx}/admin/users" class="form-row">
          <div class="field">
            <label for="keyword">Tìm theo tên hoặc email</label>
            <input type="search" id="keyword" name="keyword" value="<c:out value="${keyword}"/>">
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
          <thead><tr><th scope="col">Họ tên</th><th scope="col">Email</th><th scope="col">Vai trò</th><th scope="col">Trạng thái</th><th scope="col"><span class="visually-hidden">Thao tác</span></th></tr></thead>
          <tbody>
            <c:forEach var="u" items="${users}">
              <tr>
                <td><strong><c:out value="${u.fullName}"/></strong>
                  <div class="small muted"><c:out value="${u.phone}"/></div></td>
                <td class="small mono"><c:out value="${u.email}"/></td>
                <td>
                  <form method="post" action="${ctx}/admin/users" class="row-tight">
                    <input type="hidden" name="action" value="changeRole">
                    <input type="hidden" name="userId" value="${u.userId}">
                    <select name="roleId" data-autosubmit class="select-sm">
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
                  <div class="actions center">
                    <form method="post" action="${ctx}/admin/users" class="inline-form">
                      <input type="hidden" name="action" value="${u.active ? 'lock' : 'unlock'}">
                      <input type="hidden" name="userId" value="${u.userId}">
                      <button type="submit" class="btn btn-sm ${u.active ? 'btn-danger' : ''}">
                        ${u.active ? 'Khoá' : 'Mở khoá'}
                      </button>
                    </form>
                    <form method="post" action="${ctx}/admin/users" class="inline-form"
                          <%-- Câu hỏi không nhắc tên người dùng: tên đã hiện ngay trên cùng dòng
                               của bảng, và ghép tên vào đây thì lại phải lo chuyện thoát ký tự. --%>
                          data-confirm="Đặt lại mật khẩu của tài khoản này về 123456?">
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
<%@ include file="/WEB-INF/views/layout/page-end.jspf" %>
