<c:set var="pageTitle" value="Nhóm món" /><c:set var="nav" value="categories" />
<%@ include file="/WEB-INF/views/layout/page-start.jspf" %>
  <div class="page-head">
    <h1>Nhóm món</h1>
    <p>Tắt một nhóm sẽ ẩn toàn bộ món trong nhóm khỏi thực đơn — cách nhanh nhất để ngừng bán cả dòng sản phẩm.</p>
  </div>

  <%@ include file="/WEB-INF/views/layout/flash.jspf" %>

  <div class="grid grid-side">
    <div class="card pad0 table-wrap">
      <table>
        <thead><tr><th scope="col" class="center">Thứ tự</th><th scope="col">Tên nhóm</th>
                   <th scope="col" class="center">Số món</th><th scope="col">Trạng thái</th><th scope="col"><span class="visually-hidden">Thao tác</span></th></tr></thead>
        <tbody>
          <c:forEach var="cat" items="${categories}">
            <tr>
              <td class="center">${cat.displayOrder}</td>
              <td><strong><c:out value="${cat.name}"/></strong></td>
              <td class="center">${cat.productCount}</td>
              <td>
                <span class="tag ${cat.active ? 'tag-green' : 'tag-muted'}">
                  ${cat.active ? 'Đang hiện' : 'Đã ẩn'}
                </span>
              </td>
              <td class="center"><a class="btn btn-sm" href="${ctx}/admin/categories?edit=${cat.categoryId}">Sửa</a></td>
            </tr>
          </c:forEach>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>${empty editing ? 'Thêm nhóm món' : 'Sửa nhóm món'}</h2>
      <form method="post" action="${ctx}/admin/categories">
        <input type="hidden" name="categoryId" value="${editing.categoryId}">
        <div class="field">
          <label for="name">Tên nhóm</label>
          <input type="text" id="name" name="name" value="<c:out value="${editing.name}"/>" required>
        </div>
        <div class="field">
          <label for="displayOrder">Thứ tự hiển thị</label>
          <input type="number" id="displayOrder" name="displayOrder" value="${empty editing ? 0 : editing.displayOrder}">
        </div>
        <div class="field check">
          <input type="checkbox" id="active" name="active" value="true"
                 ${empty editing or editing.active ? 'checked' : ''}>
          <label for="active">Hiện trên thực đơn</label>
        </div>
        <button type="submit" class="btn btn-primary btn-block">
          ${empty editing ? 'Thêm nhóm' : 'Lưu thay đổi'}
        </button>
        <c:if test="${not empty editing}">
          <a class="btn btn-block mt" href="${ctx}/admin/categories">Huỷ sửa</a>
        </c:if>
      </form>
    </div>
  </div>
<%@ include file="/WEB-INF/views/layout/page-end.jspf" %>
