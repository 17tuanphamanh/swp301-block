<c:set var="pageTitle" value="Đã hoàn thành" /><c:set var="nav" value="history" />
<%@ include file="/WEB-INF/views/layout/page-start.jspf" %>
  <div class="page-head">
    <h1>Món đã hoàn thành</h1>
    <p>
      Kèm thời gian làm và giờ khách hẹn để đối chiếu.
    </p>
  </div>

  <div class="card pad0 table-wrap">
    <table>
      <thead>
        <tr><th scope="col">Món</th><th scope="col">Đơn</th><th scope="col" class="center">SL</th><th scope="col">Người làm</th>
            <th scope="col">Bắt đầu</th><th scope="col">Xong lúc</th><th scope="col">Giờ hẹn</th><th scope="col">Đúng hẹn</th></tr>
      </thead>
      <tbody>
        <c:forEach var="item" items="${pageData.items}">
          <tr>
            <td><c:out value="${item.productNameSnapshot}"/></td>
            <td>#${item.orderId}</td>
            <td class="center">${item.quantity}</td>
            <td class="small"><c:out value="${item.assignedToName}"/></td>
            <td class="small muted">${ff:time(item.startedAt)}</td>
            <td class="small muted">${ff:time(item.readyAt)}</td>
            <td class="small">
              <c:choose>
                <c:when test="${empty item.pickupTime}"><span class="muted">Tại quầy</span></c:when>
                <c:otherwise>${ff:time(item.pickupTime)}</c:otherwise>
              </c:choose>
            </td>
            <td>
              <c:choose>
                <c:when test="${empty item.pickupTime}"><span class="tag tag-muted">—</span></c:when>
                <c:when test="${item.readyAt le item.pickupTime}"><span class="tag tag-green">Đúng hẹn</span></c:when>
                <c:otherwise><span class="tag tag-red">Trễ</span></c:otherwise>
              </c:choose>
            </td>
          </tr>
        </c:forEach>
        <c:if test="${pageData.emptyPage}">
          <tr><td colspan="8" class="center muted cell-empty">Chưa có món nào hoàn thành.</td></tr>
        </c:if>
      </tbody>
    </table>
    <%@ include file="/WEB-INF/views/layout/pager.jspf" %>
  </div>
<%@ include file="/WEB-INF/views/layout/page-end.jspf" %>
