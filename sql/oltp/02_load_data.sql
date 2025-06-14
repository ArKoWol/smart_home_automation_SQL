
DROP TABLE IF EXISTS temp_users CASCADE;
DROP TABLE IF EXISTS temp_categories CASCADE;
DROP TABLE IF EXISTS temp_products CASCADE;
DROP TABLE IF EXISTS temp_orders CASCADE;
DROP TABLE IF EXISTS temp_order_items CASCADE;

\echo 'Starting data loading process...'

\echo 'Connected to OLTP database.'

CREATE TEMP TABLE temp_users (
    email VARCHAR(255),
    password_hash VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    date_registered DATE,
    is_active BOOLEAN,
    last_login TIMESTAMP
);

CREATE TEMP TABLE temp_categories (
    category_name VARCHAR(100),
    description TEXT,
    parent_category_name VARCHAR(100),
    is_active BOOLEAN,
    created_date DATE
);

CREATE TEMP TABLE temp_products (
    product_name VARCHAR(255),
    product_description TEXT,
    category_name VARCHAR(100),
    manufacturer_name VARCHAR(255),
    model_number VARCHAR(100),
    price DECIMAL(10,2),
    cost DECIMAL(10,2),
    stock_quantity INTEGER,
    weight_kg DECIMAL(8,2),
    dimensions_cm VARCHAR(50),
    color VARCHAR(50),
    warranty_months INTEGER,
    energy_rating VARCHAR(20),
    connectivity_type VARCHAR(100),
    is_active BOOLEAN,
    created_date DATE
);

CREATE TEMP TABLE temp_orders (
    user_email VARCHAR(255),
    order_date TIMESTAMP,
    order_status VARCHAR(50),
    shipping_address_line1 VARCHAR(255),
    shipping_city VARCHAR(100),
    shipping_state VARCHAR(100),
    shipping_postal_code VARCHAR(20),
    shipping_country VARCHAR(100),
    subtotal DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    shipping_cost DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    tracking_number VARCHAR(100),
    shipped_date TIMESTAMP,
    delivered_date TIMESTAMP
);

CREATE TEMP TABLE temp_order_items (
    order_id INTEGER,
    product_name VARCHAR(255),
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2)
);

\echo 'Temporary tables created.'

\echo 'Loading CSV data into temporary tables...'

\copy temp_users FROM '/data/01_users.csv' WITH CSV HEADER;
\copy temp_categories FROM '/data/02_categories.csv' WITH CSV HEADER;
\copy temp_products FROM '/data/03_products.csv' WITH CSV HEADER;
\copy temp_orders FROM '/data/04_orders.csv' WITH CSV HEADER;
\copy temp_order_items FROM '/data/05_order_items.csv' WITH CSV HEADER;

\echo 'CSV data loaded into temporary tables.'

INSERT INTO users (email, password_hash, first_name, last_name, phone,
                  address_line1, address_line2, city, state, postal_code,
                  country, date_registered, is_active, last_login)
SELECT email, password_hash, first_name, last_name, phone,
       address_line1, address_line2, city, state, postal_code,
       country, date_registered, is_active, last_login
FROM temp_users t
WHERE NOT EXISTS (
    SELECT 1 FROM users u WHERE u.email = t.email
)
ON CONFLICT (email) DO NOTHING;

\echo 'Users data inserted.'

INSERT INTO categories (category_name, description, parent_category_id, is_active, created_date)
SELECT category_name, description, NULL, is_active, created_date
FROM temp_categories t
WHERE parent_category_name IS NULL 
   OR parent_category_name = ''
   AND NOT EXISTS (
    SELECT 1 FROM categories c WHERE c.category_name = t.category_name
)
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO categories (category_name, description, parent_category_id, is_active, created_date)
SELECT t.category_name, t.description, p.category_id, t.is_active, t.created_date
FROM temp_categories t
JOIN categories p ON p.category_name = t.parent_category_name
WHERE t.parent_category_name IS NOT NULL 
   AND t.parent_category_name != ''
   AND NOT EXISTS (
    SELECT 1 FROM categories c WHERE c.category_name = t.category_name
)
ON CONFLICT (category_name) DO NOTHING;

\echo 'Categories data inserted.'

INSERT INTO products (product_name, product_description, category_id, manufacturer_name,
                     model_number, price, cost, stock_quantity, weight_kg, dimensions_cm,
                     color, warranty_months, energy_rating, connectivity_type, is_active, created_date)
SELECT t.product_name, t.product_description, c.category_id, t.manufacturer_name,
       t.model_number, t.price, t.cost, t.stock_quantity, t.weight_kg, t.dimensions_cm,
       t.color, t.warranty_months, t.energy_rating, t.connectivity_type, t.is_active, t.created_date
FROM temp_products t
JOIN categories c ON c.category_name = t.category_name
WHERE NOT EXISTS (
    SELECT 1 FROM products p WHERE p.product_name = t.product_name AND p.model_number = t.model_number
);

\echo 'Products data inserted.'

INSERT INTO orders (user_id, order_date, order_status, shipping_address_line1,
                   shipping_city, shipping_state, shipping_postal_code, shipping_country,
                   subtotal, tax_amount, shipping_cost, total_amount, tracking_number, 
                   shipped_date, delivered_date)
SELECT u.user_id, t.order_date, t.order_status, t.shipping_address_line1,
       t.shipping_city, t.shipping_state, t.shipping_postal_code, t.shipping_country,
       t.subtotal, t.tax_amount, t.shipping_cost, t.total_amount, t.tracking_number, 
       t.shipped_date, t.delivered_date
FROM temp_orders t
JOIN users u ON u.email = t.user_email
WHERE NOT EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.user_id = u.user_id 
      AND o.order_date = t.order_date 
      AND o.total_amount = t.total_amount
);

\echo 'Orders data inserted.'

INSERT INTO order_items (order_id, product_id, quantity, unit_price, total_price)
SELECT t.order_id, p.product_id, t.quantity, t.unit_price, t.total_price
FROM temp_order_items t
JOIN products p ON p.product_name = t.product_name
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.order_id = t.order_id)
AND NOT EXISTS (
    SELECT 1 FROM order_items oi 
    WHERE oi.order_id = t.order_id AND oi.product_id = p.product_id
)
ON CONFLICT (order_id, product_id) DO NOTHING;

\echo 'Order items data inserted.'

-- Generate order status history from existing orders
INSERT INTO order_status_history (order_id, old_status, new_status, status_change_reason, 
                                change_timestamp, estimated_completion_date, actual_completion_date)
SELECT 
    o.order_id,
    'new' as old_status,
    'pending' as new_status,
    'Order created' as status_change_reason,
    o.order_date as change_timestamp,
    o.order_date + INTERVAL '3 days' as estimated_completion_date,
    NULL as actual_completion_date
FROM orders o
WHERE NOT EXISTS (
    SELECT 1 FROM order_status_history osh 
    WHERE osh.order_id = o.order_id AND osh.new_status = 'pending'
);

-- Add status changes for shipped orders
INSERT INTO order_status_history (order_id, old_status, new_status, status_change_reason, 
                                change_timestamp, estimated_completion_date, actual_completion_date)
SELECT 
    o.order_id,
    'pending' as old_status,
    'shipped' as new_status,
    'Order shipped to customer' as status_change_reason,
    o.shipped_date as change_timestamp,
    o.shipped_date + INTERVAL '2 days' as estimated_completion_date,
    o.shipped_date as actual_completion_date
FROM orders o
WHERE o.shipped_date IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM order_status_history osh 
    WHERE osh.order_id = o.order_id AND osh.new_status = 'shipped'
);

-- Add status changes for delivered orders
INSERT INTO order_status_history (order_id, old_status, new_status, status_change_reason, 
                                change_timestamp, estimated_completion_date, actual_completion_date)
SELECT 
    o.order_id,
    'shipped' as old_status,
    'delivered' as new_status,
    'Order delivered successfully' as status_change_reason,
    o.delivered_date as change_timestamp,
    o.delivered_date as estimated_completion_date,
    o.delivered_date as actual_completion_date
FROM orders o
WHERE o.delivered_date IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM order_status_history osh 
    WHERE osh.order_id = o.order_id AND osh.new_status = 'delivered'
);

\echo 'Order status history data generated.'

\echo 'Data loading completed. Summary:'
SELECT 'Users' as table_name, COUNT(*) as record_count FROM users
UNION ALL
SELECT 'Categories', COUNT(*) FROM categories
UNION ALL
SELECT 'Products', COUNT(*) FROM products
UNION ALL
SELECT 'Orders', COUNT(*) FROM orders
UNION ALL
SELECT 'Order Items', COUNT(*) FROM order_items
UNION ALL
SELECT 'Shopping Cart', COUNT(*) FROM shopping_cart
UNION ALL
SELECT 'Payments', COUNT(*) FROM payments
UNION ALL
SELECT 'Order Status History', COUNT(*) FROM order_status_history;

\echo 'OLTP data loading process completed successfully!' 