<%-- Phần <head> dùng chung. Trang gọi phải đặt trước biến pageTitle. --%>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${empty pageTitle ? 'Fast Food' : pageTitle} · Fast Food</title>
<link rel="stylesheet" href="${ctx}/assets/css/main.css">
