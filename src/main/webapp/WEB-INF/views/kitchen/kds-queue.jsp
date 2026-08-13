<c:set var="pageTitle" value="Bếp" /><c:set var="nav" value="queue" />
<%@ include file="/WEB-INF/views/layout/page-start.jspf" %>
  <div class="page-head">
    <h1>Bếp</h1>
    <p>
      Việc của bạn ở trên, hàng chờ chung ở dưới.
      Món làm xong phải bàn giao ra quầy thì thu ngân mới giao cho khách được.
    </p>
  </div>

  <%@ include file="/WEB-INF/views/layout/flash.jspf" %>

  <%-- Việc đang làm dở đứng đầu: đó là thứ đầu bếp phải quay lại, không phải việc mới. --%>
  <c:if test="${not empty myTasks}">
    <h2>Đang làm (<span id="kds-mytasks-count">${fn:length(myTasks)}</span>)</h2>
    <div class="kds-grid mb">
      <c:forEach var="v" items="${myTasks}">
        <div class="kds-card ${v.late ? 'late' : (v.urgent ? 'urgent' : (v.online ? 'online' : 'pos'))}">
          <div class="row-between">
            <span class="tag tag-amber">Đang làm</span>
            <span class="qty">×${v.item.quantity}</span>
          </div>
          <div class="title mt"><c:out value="${v.item.productNameSnapshot}"/></div>
          <div class="meta">
            <span>Đơn #${v.item.orderId}</span>
            <span>${v.pickupLabel}</span>
          </div>
          <div class="small muted mt">Bắt đầu lúc ${ff:time(v.item.startedAt)}</div>
          <div class="actions">
            <form method="post" action="${ctx}/kitchen/queue" class="grow">
              <input type="hidden" name="action" value="ready">
              <input type="hidden" name="orderItemId" value="${v.item.orderItemId}">
              <button type="submit" class="btn btn-green btn-block touch">Đã làm xong</button>
            </form>
            <a class="btn touch" href="${ctx}/kitchen/issue?orderItemId=${v.item.orderItemId}">Báo sự cố</a>
          </div>
        </div>
      </c:forEach>
    </div>
  </c:if>

  <%-- Món đã xong mà chưa ra quầy. Đây là khối quan trọng nhất của màn hình này: trước khi
       có nó, món nấu xong không còn nằm trong danh sách nào và chỉ lộ ra khi khách hỏi. --%>
  <c:if test="${not empty awaitingHandover}">
    <h2>Chờ bàn giao ra quầy (<span id="kds-handover-count">${fn:length(awaitingHandover)}</span>)</h2>
    <div class="kds-grid mb">
      <c:forEach var="v" items="${awaitingHandover}">
        <div class="kds-card ${v.late ? 'late' : 'urgent'}">
          <div class="row-between">
            <span class="tag tag-green">Đã xong</span>
            <span class="qty">×${v.item.quantity}</span>
          </div>
          <div class="title mt"><c:out value="${v.item.productNameSnapshot}"/></div>
          <div class="meta">
            <span>Đơn #${v.item.orderId}</span>
            <span>${v.pickupLabel}</span>
          </div>
          <div class="small muted mt">Xong lúc ${ff:time(v.item.readyAt)}</div>
          <div class="actions">
            <form method="post" action="${ctx}/kitchen/queue" class="grow">
              <input type="hidden" name="action" value="handover">
              <input type="hidden" name="orderItemId" value="${v.item.orderItemId}">
              <button type="submit" class="btn btn-primary btn-block touch">Bàn giao ra quầy</button>
            </form>
            <a class="btn touch" href="${ctx}/kitchen/item?id=${v.item.orderItemId}">Chi tiết</a>
          </div>
        </div>
      </c:forEach>
    </div>
  </c:if>

  <h2>Hàng chờ</h2>
  <p class="small muted mb">
    Chỉ hiện món của đơn đã tới lượt làm. Đơn đặt trước chưa tới giờ chưa xuất hiện ở đây.
  </p>

  <%-- Hiện khi máy đã hụt vài lượt hỏi liên tiếp. Màn hình bếp đứng im mà không ai biết
       thì nguy hiểm hơn nhiều so với một dòng cảnh báo thừa. --%>
  <div class="alert alert-warn" id="kds-offline" role="status" hidden>
    Mất kết nối tới máy chủ — danh sách bên dưới có thể đã cũ. Hệ thống vẫn đang thử lại.
  </div>

  <noscript>
    <div class="alert alert-warn">
      Trình duyệt đang tắt JavaScript nên danh sách không tự cập nhật.
      Bấm tải lại trang để xem món mới xuống bếp.
    </div>
  </noscript>

  <%-- Cả hai khối luôn có mặt; app.js bật tắt bằng thuộc tính hidden khi hàng chờ đổi
       từ rỗng sang có món và ngược lại. --%>
  <div class="card empty" id="kds-empty" ${empty queue ? '' : 'hidden'}>
    <div class="icon" aria-hidden="true">👨‍🍳</div>
    Không còn món nào chờ làm.
  </div>

  <div class="kds-grid" id="kds-grid" ${empty queue ? 'hidden' : ''}>
    <c:forEach var="v" items="${queue}">
      <%-- data-sig phải khớp đúng thứ tự và cách nối của hàm kdsSignature trong app.js,
           nếu không thì lượt hỏi đầu tiên sẽ dựng lại toàn bộ thẻ một cách vô ích. --%>
      <div class="kds-card ${v.late ? 'late' : (v.urgent ? 'urgent' : (v.online ? 'online' : 'pos'))}"
           data-item-id="${v.item.orderItemId}"
           data-sig="${v.item.quantity}|${v.online}|${v.urgent}|${v.late}|${fn:escapeXml(v.pickupLabel)}|${v.openIssueCount}">
        <div class="row-between">
          <span class="tag ${v.online ? 'tag-info' : 'tag-muted'}">
            ${v.online ? 'Đặt trước' : 'Tại quầy'}
          </span>
          <span class="qty">×${v.item.quantity}</span>
        </div>
        <div class="title mt"><c:out value="${v.item.productNameSnapshot}"/></div>
        <div class="meta">
          <span>Đơn #${v.item.orderId}</span>
          <span class="${v.late ? 'tag tag-red' : (v.urgent ? 'tag tag-amber' : '')}">
            ${v.pickupLabel}
          </span>
        </div>
        <div class="mt" ${v.openIssueCount > 0 ? '' : 'hidden'}>
          <span class="tag tag-red">${v.openIssueCount} sự cố đang mở</span>
        </div>
        <div class="actions">
          <form method="post" action="${ctx}/kitchen/queue" class="grow">
            <input type="hidden" name="action" value="claim">
            <input type="hidden" name="orderItemId" value="${v.item.orderItemId}">
            <button type="submit" class="btn btn-primary btn-block touch">Nhận món này</button>
          </form>
          <a class="btn touch" href="${ctx}/kitchen/item?id=${v.item.orderItemId}">Chi tiết</a>
        </div>
      </div>
    </c:forEach>
  </div>

  <%--
    Khuôn để app.js dựng thẻ mới. Giữ phần chữ và bố cục ở đây, cùng một chỗ với thẻ do
    máy chủ vẽ bên trên, để hai bên không lệch nhau. app.js chỉ điền dữ liệu vào các ô
    đánh dấu data-field.
  --%>
  <template id="kds-card-template">
    <div class="kds-card">
      <div class="row-between">
        <span class="tag" data-field="source"></span>
        <span class="qty" data-field="qty"></span>
      </div>
      <div class="title mt" data-field="productName"></div>
      <div class="meta">
        <span data-field="orderLabel"></span>
        <span data-field="pickupLabel"></span>
      </div>
      <div class="mt" data-slot="issue" hidden>
        <span class="tag tag-red" data-field="issue"></span>
      </div>
      <div class="actions">
        <form method="post" action="${ctx}/kitchen/queue" class="grow">
          <input type="hidden" name="action" value="claim">
          <input type="hidden" name="orderItemId" data-field="itemId">
          <button type="submit" class="btn btn-primary btn-block touch">Nhận món này</button>
        </form>
        <a class="btn touch" data-field="detailHref">Chi tiết</a>
      </div>
    </div>
  </template>

  <%-- Dấu hiệu để app.js biết trang này cần tự cập nhật, kèm địa chỉ để hỏi. --%>
  <div id="kds-watch" hidden
       data-endpoint="${ctx}/api/kds/queue"
       data-detail-base="${ctx}/kitchen/item?id="></div>
<%@ include file="/WEB-INF/views/layout/page-end.jspf" %>
