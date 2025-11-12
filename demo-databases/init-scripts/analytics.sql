-- Analytics Demo Database
-- This simulates an analytics/events database

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Events table (for tracking user events)
CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB,
    session_id VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Page views table
CREATE TABLE IF NOT EXISTS page_views (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    page_url TEXT NOT NULL,
    page_title VARCHAR(255),
    referrer TEXT,
    duration_seconds INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User sessions table
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id VARCHAR(255) PRIMARY KEY,
    user_id INTEGER,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    duration_seconds INTEGER,
    page_count INTEGER DEFAULT 0
);

-- Metrics table (for aggregated metrics)
CREATE TABLE IF NOT EXISTS daily_metrics (
    id SERIAL PRIMARY KEY,
    metric_date DATE NOT NULL UNIQUE,
    active_users INTEGER DEFAULT 0,
    page_views INTEGER DEFAULT 0,
    events_count INTEGER DEFAULT 0,
    revenue DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample events
INSERT INTO events (user_id, event_type, event_data, session_id, ip_address, user_agent, created_at) VALUES
    (1, 'page_view', '{"page": "/home", "title": "Homepage"}', 'sess_001', '192.168.1.100', 'Mozilla/5.0...', NOW() - INTERVAL '1 hour'),
    (1, 'click', '{"element": "button", "text": "Buy Now"}', 'sess_001', '192.168.1.100', 'Mozilla/5.0...', NOW() - INTERVAL '55 minutes'),
    (2, 'page_view', '{"page": "/products", "title": "Products"}', 'sess_002', '192.168.1.101', 'Mozilla/5.0...', NOW() - INTERVAL '45 minutes'),
    (2, 'add_to_cart', '{"product_id": 1, "quantity": 2}', 'sess_002', '192.168.1.101', 'Mozilla/5.0...', NOW() - INTERVAL '40 minutes'),
    (3, 'page_view', '{"page": "/checkout", "title": "Checkout"}', 'sess_003', '192.168.1.102', 'Mozilla/5.0...', NOW() - INTERVAL '30 minutes'),
    (3, 'purchase', '{"order_id": 123, "amount": 1299.99}', 'sess_003', '192.168.1.102', 'Mozilla/5.0...', NOW() - INTERVAL '25 minutes'),
    (1, 'page_view', '{"page": "/account", "title": "Account"}', 'sess_004', '192.168.1.100', 'Mozilla/5.0...', NOW() - INTERVAL '15 minutes'),
    (4, 'page_view', '{"page": "/products/5", "title": "Product Details"}', 'sess_005', '192.168.1.103', 'Mozilla/5.0...', NOW() - INTERVAL '10 minutes');

-- Insert sample page views
INSERT INTO page_views (user_id, page_url, page_title, referrer, duration_seconds, created_at) VALUES
    (1, '/home', 'Homepage', NULL, 45, NOW() - INTERVAL '1 hour'),
    (1, '/products', 'Products', '/home', 120, NOW() - INTERVAL '55 minutes'),
    (2, '/products', 'Products', 'https://google.com', 180, NOW() - INTERVAL '45 minutes'),
    (2, '/products/1', 'Laptop Pro 15', '/products', 300, NOW() - INTERVAL '40 minutes'),
    (3, '/checkout', 'Checkout', '/cart', 240, NOW() - INTERVAL '30 minutes'),
    (1, '/account', 'My Account', '/home', 60, NOW() - INTERVAL '15 minutes'),
    (4, '/products/5', 'Monitor 27"', '/products', 150, NOW() - INTERVAL '10 minutes');

-- Insert sample sessions
INSERT INTO user_sessions (session_id, user_id, started_at, ended_at, duration_seconds, page_count) VALUES
    ('sess_001', 1, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '50 minutes', 600, 3),
    ('sess_002', 2, NOW() - INTERVAL '45 minutes', NOW() - INTERVAL '35 minutes', 600, 2),
    ('sess_003', 3, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '20 minutes', 600, 2),
    ('sess_004', 1, NOW() - INTERVAL '15 minutes', NULL, NULL, 1),
    ('sess_005', 4, NOW() - INTERVAL '10 minutes', NULL, NULL, 1);

-- Insert sample daily metrics
INSERT INTO daily_metrics (metric_date, active_users, page_views, events_count, revenue, created_at) VALUES
    (CURRENT_DATE - INTERVAL '2 days', 150, 1250, 3200, 15499.50, NOW() - INTERVAL '2 days'),
    (CURRENT_DATE - INTERVAL '1 day', 180, 1450, 3800, 18250.75, NOW() - INTERVAL '1 day'),
    (CURRENT_DATE, 95, 850, 2100, 12500.25, NOW());

-- Create indexes for better query performance
CREATE INDEX idx_events_user_id ON events(user_id);
CREATE INDEX idx_events_event_type ON events(event_type);
CREATE INDEX idx_events_created_at ON events(created_at);
CREATE INDEX idx_events_session_id ON events(session_id);
CREATE INDEX idx_page_views_user_id ON page_views(user_id);
CREATE INDEX idx_page_views_created_at ON page_views(created_at);
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_started_at ON user_sessions(started_at);

-- Create a materialized view for event summaries (optional, for analytics)
CREATE MATERIALIZED VIEW IF NOT EXISTS event_summary AS
SELECT 
    event_type,
    DATE(created_at) as event_date,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT session_id) as unique_sessions
FROM events
GROUP BY event_type, DATE(created_at);

CREATE INDEX idx_event_summary_date ON event_summary(event_date);
CREATE INDEX idx_event_summary_type ON event_summary(event_type);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

