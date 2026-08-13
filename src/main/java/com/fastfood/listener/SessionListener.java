package com.fastfood.listener;

import javax.servlet.annotation.WebListener;
import javax.servlet.http.HttpSessionEvent;
import javax.servlet.http.HttpSessionListener;
import java.util.concurrent.atomic.AtomicInteger;

/** Đếm số phiên đang hoạt động. Dùng để theo dõi tải khi trình bày. */
@WebListener
public class SessionListener implements HttpSessionListener {

    private static final AtomicInteger ACTIVE_SESSIONS = new AtomicInteger();

    public static int getActiveSessions() {
        return ACTIVE_SESSIONS.get();
    }

    @Override
    public void sessionCreated(HttpSessionEvent se) {
        ACTIVE_SESSIONS.incrementAndGet();
    }

    @Override
    public void sessionDestroyed(HttpSessionEvent se) {
        ACTIVE_SESSIONS.decrementAndGet();
    }
}
