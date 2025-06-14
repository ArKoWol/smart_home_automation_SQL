\echo 'Starting ETL process...'

\echo 'Populating Date Dimension...'

INSERT INTO dim_date (date_key, full_date, day_of_week, day_name, day_of_month, 
                     day_of_year, week_of_year, month_number, month_name, 
                     quarter, quarter_name, year, is_weekend, fiscal_year, fiscal_quarter)
SELECT 
    TO_CHAR(date_series, 'YYYYMMDD')::INTEGER as date_key,
    date_series as full_date,
    EXTRACT(DOW FROM date_series) as day_of_week,
    TO_CHAR(date_series, 'Day') as day_name,
    EXTRACT(DAY FROM date_series) as day_of_month,
    EXTRACT(DOY FROM date_series) as day_of_year,
    EXTRACT(WEEK FROM date_series) as week_of_year,
    EXTRACT(MONTH FROM date_series) as month_number,
    TO_CHAR(date_series, 'Month') as month_name,
    EXTRACT(QUARTER FROM date_series) as quarter,
    'Q' || EXTRACT(QUARTER FROM date_series) as quarter_name,
    EXTRACT(YEAR FROM date_series) as year,
    CASE WHEN EXTRACT(DOW FROM date_series) IN (0, 6) THEN TRUE ELSE FALSE END as is_weekend,
    CASE 
        WHEN EXTRACT(MONTH FROM date_series) >= 4 THEN EXTRACT(YEAR FROM date_series)
        ELSE EXTRACT(YEAR FROM date_series) - 1 
    END as fiscal_year,
    CASE 
        WHEN EXTRACT(MONTH FROM date_series) IN (4, 5, 6) THEN 1
        WHEN EXTRACT(MONTH FROM date_series) IN (7, 8, 9) THEN 2
        WHEN EXTRACT(MONTH FROM date_series) IN (10, 11, 12) THEN 3
        ELSE 4
    END as fiscal_quarter
FROM generate_series('2022-01-01'::date, '2026-12-31'::date, '1 day'::interval) date_series
WHERE NOT EXISTS (
    SELECT 1 FROM dim_date d WHERE d.date_key = TO_CHAR(date_series, 'YYYYMMDD')::INTEGER
);

\echo 'Populating Time Dimension...'

INSERT INTO dim_time (time_key, hour, minute, second, time_of_day, hour_12, am_pm, business_hour)
SELECT 
    hour * 10000 + minute * 100 + second as time_key,
    hour,
    minute,
    second,
    CASE 
        WHEN hour BETWEEN 6 AND 11 THEN 'Morning'
        WHEN hour BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN hour BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END as time_of_day,
    CASE WHEN hour = 0 THEN 12 WHEN hour > 12 THEN hour - 12 ELSE hour END as hour_12,
    CASE WHEN hour < 12 THEN 'AM' ELSE 'PM' END as am_pm,
    CASE WHEN hour BETWEEN 9 AND 17 THEN TRUE ELSE FALSE END as business_hour
FROM generate_series(0, 23) hour
CROSS JOIN generate_series(0, 59, 15) minute
CROSS JOIN generate_series(0, 0) second
WHERE NOT EXISTS (
    SELECT 1 FROM dim_time t WHERE t.time_key = hour * 10000 + minute * 100 + second
);

\echo 'Loading location data from CSV users data...'

-- Create temporary table for CSV import
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

\copy temp_users FROM '/csv-data/01_users.csv' DELIMITER ',' CSV HEADER;

INSERT INTO dim_location (city, state, postal_code, country, region, time_zone, area_type)
SELECT DISTINCT 
    city,
    state,
    postal_code,
    country,
    CASE 
        WHEN state IN ('NY', 'PA', 'NJ', 'CT', 'MA', 'VT', 'NH', 'ME', 'RI') THEN 'Northeast'
        WHEN state IN ('CA', 'WA', 'OR', 'NV', 'AZ', 'UT', 'ID', 'MT', 'WY', 'CO', 'NM', 'HI', 'AK') THEN 'West'
        WHEN state IN ('TX', 'OK', 'AR', 'LA') THEN 'Southwest'
        WHEN state IN ('FL', 'GA', 'SC', 'NC', 'VA', 'WV', 'KY', 'TN', 'MS', 'AL', 'MD', 'DE', 'DC') THEN 'Southeast'
        ELSE 'Midwest'
    END as region,
    CASE 
        WHEN state IN ('NY', 'PA', 'NJ', 'CT', 'MA', 'VT', 'NH', 'ME', 'RI', 'FL', 'GA', 'SC', 'NC', 'VA', 'WV', 'KY', 'TN', 'OH', 'MI', 'IN') THEN 'EST'
        WHEN state IN ('TX', 'OK', 'AR', 'LA', 'MS', 'AL', 'IL', 'WI', 'MN', 'IA', 'MO', 'ND', 'SD', 'NE', 'KS') THEN 'CST'
        WHEN state IN ('AZ', 'UT', 'ID', 'MT', 'WY', 'CO', 'NM') THEN 'MST'
        WHEN state IN ('CA', 'WA', 'OR', 'NV', 'HI', 'AK') THEN 'PST'
        ELSE 'EST'
    END as time_zone,
    'Urban' as area_type
FROM temp_users
WHERE city IS NOT NULL AND state IS NOT NULL AND country IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM dim_location l 
    WHERE l.city = temp_users.city 
    AND l.state = temp_users.state 
    AND l.postal_code = temp_users.postal_code
);

\echo 'Loading categories from CSV...'

CREATE TEMP TABLE temp_categories (
    category_name VARCHAR(100),
    description TEXT,
    parent_category_name VARCHAR(100),
    is_active BOOLEAN,
    created_date DATE
);

\copy temp_categories FROM '/csv-data/02_categories.csv' DELIMITER ',' CSV HEADER;

INSERT INTO dim_category (category_id, category_name, parent_category_name, 
                         category_level, category_path, description, is_active)
SELECT 
    ROW_NUMBER() OVER (ORDER BY category_name) as category_id,
    c.category_name,
    c.parent_category_name,
    CASE WHEN c.parent_category_name IS NULL THEN 1 ELSE 2 END as category_level,
    CASE 
        WHEN c.parent_category_name IS NULL THEN c.category_name
        ELSE COALESCE(c.parent_category_name, 'Unknown') || ' > ' || c.category_name
    END as category_path,
    c.description,
    c.is_active
FROM temp_categories c
WHERE NOT EXISTS (SELECT 1 FROM dim_category WHERE category_name = c.category_name);

\echo 'Loading products from CSV...'

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

\copy temp_products FROM '/csv-data/03_products.csv' DELIMITER ',' CSV HEADER;

-- Load manufacturers from products data
INSERT INTO dim_manufacturer (manufacturer_id, company_name, contact_email, website, 
                             city, state, country, established_year, company_size,
                             valid_from, valid_to, is_current, version)
SELECT 
    ROW_NUMBER() OVER (ORDER BY manufacturer_name) as manufacturer_id,
    manufacturer_name as company_name,
    'contact@' || LOWER(REPLACE(manufacturer_name, ' ', '')) || '.com' as contact_email,
    'https://www.' || LOWER(REPLACE(manufacturer_name, ' ', '')) || '.com' as website,
    'Unknown' as city,
    'Unknown' as state,
    'USA' as country,
    2000 as established_year,
    'Medium' as company_size,
    CURRENT_DATE as valid_from,
    DATE '9999-12-31' as valid_to,
    TRUE as is_current,
    1 as version
FROM (SELECT DISTINCT manufacturer_name FROM temp_products WHERE manufacturer_name IS NOT NULL) m
WHERE NOT EXISTS (SELECT 1 FROM dim_manufacturer WHERE company_name = m.manufacturer_name AND is_current = TRUE);

INSERT INTO dim_product (product_id, product_name, product_description, model_number,
                        price, cost, weight_kg, dimensions_cm, color, warranty_months,
                        energy_rating, connectivity_type, price_range, is_active, created_date)
SELECT 
    ROW_NUMBER() OVER (ORDER BY product_name) as product_id,
    p.product_name,
    p.product_description,
    p.model_number,
    p.price,
    p.cost,
    p.weight_kg,
    p.dimensions_cm,
    p.color,
    p.warranty_months,
    p.energy_rating,
    p.connectivity_type,
    CASE 
        WHEN p.price < 50 THEN 'Budget'
        WHEN p.price < 200 THEN 'Mid-range'
        ELSE 'Premium'
    END as price_range,
    p.is_active,
    p.created_date
FROM temp_products p
WHERE NOT EXISTS (SELECT 1 FROM dim_product WHERE product_name = p.product_name);

\echo 'Loading customers from CSV...'

INSERT INTO dim_customer (customer_id, email, first_name, last_name, phone,
                         address_line1, city, state, postal_code, country,
                         customer_segment, registration_date, valid_from, valid_to, is_current)
SELECT 
    ROW_NUMBER() OVER (ORDER BY email) as customer_id,
    u.email,
    u.first_name,
    u.last_name,
    u.phone,
    u.address_line1,
    u.city,
    u.state,
    u.postal_code,
    u.country,
    'Regular' as customer_segment,
    u.date_registered as registration_date,
    u.date_registered as valid_from,
    DATE '9999-12-31' as valid_to,
    TRUE as is_current
FROM temp_users u
WHERE NOT EXISTS (SELECT 1 FROM dim_customer WHERE email = u.email);

\echo 'Loading bridge_product_category from CSV...'

INSERT INTO bridge_product_category (product_key, category_key, relationship_type, effective_date, is_active)
SELECT DISTINCT
    dp.product_key,
    dc.category_key,
    'primary' as relationship_type,
    CURRENT_DATE as effective_date,
    TRUE as is_active
FROM temp_products tp
INNER JOIN dim_product dp ON dp.product_name = tp.product_name
INNER JOIN dim_category dc ON dc.category_name = tp.category_name
WHERE NOT EXISTS (
    SELECT 1 FROM bridge_product_category bpc 
    WHERE bpc.product_key = dp.product_key 
    AND bpc.category_key = dc.category_key
);

\echo 'Loading orders from CSV...'

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

\copy temp_orders FROM '/csv-data/04_orders.csv' DELIMITER ',' CSV HEADER;

\echo 'Loading order items from CSV...'

CREATE TEMP TABLE temp_order_items (
    order_id INTEGER,
    product_name VARCHAR(255),
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2)
);

\copy temp_order_items FROM '/csv-data/05_order_items.csv' DELIMITER ',' CSV HEADER;

\echo 'Loading fact_sales from CSV data...'

INSERT INTO fact_sales (
    date_key, time_key, customer_key, product_key, manufacturer_key, location_key,
    order_id, order_status, quantity_sold, unit_price, unit_cost, total_sales_amount,
    total_cost_amount, gross_profit, tax_amount, shipping_cost, discount_amount,
    days_to_ship, days_to_deliver, is_returned, is_refunded
)
SELECT 
    TO_CHAR(to_order.order_date::date, 'YYYYMMDD')::INTEGER as date_key,
    100000 as time_key,  -- Используем простое значение 10:00:00
    dc.customer_key,
    dp.product_key,
    dm.manufacturer_key,
    dl.location_key,
    toi.order_id,
    to_order.order_status,
    toi.quantity,
    toi.unit_price,
    dp.cost as unit_cost,
    toi.total_price as total_sales_amount,
    (toi.quantity * dp.cost) as total_cost_amount,
    (toi.total_price - (toi.quantity * dp.cost)) as gross_profit,
    CASE 
        WHEN ROW_NUMBER() OVER (PARTITION BY toi.order_id ORDER BY toi.product_name) = 1 
        THEN to_order.tax_amount 
        ELSE 0 
    END as tax_amount,
    CASE 
        WHEN ROW_NUMBER() OVER (PARTITION BY toi.order_id ORDER BY toi.product_name) = 1 
        THEN to_order.shipping_cost 
        ELSE 0 
    END as shipping_cost,
    0 as discount_amount,
    CASE 
        WHEN to_order.shipped_date IS NOT NULL 
        THEN (to_order.shipped_date::date - to_order.order_date::date)
        ELSE NULL 
    END as days_to_ship,
    CASE 
        WHEN to_order.delivered_date IS NOT NULL AND to_order.shipped_date IS NOT NULL
        THEN (to_order.delivered_date::date - to_order.shipped_date::date)
        ELSE NULL 
    END as days_to_deliver,
    FALSE as is_returned,
    FALSE as is_refunded
FROM temp_order_items toi
INNER JOIN (
    SELECT *, ROW_NUMBER() OVER (ORDER BY order_date) as order_id_seq
    FROM temp_orders
) to_order ON to_order.order_id_seq = toi.order_id
INNER JOIN dim_customer dc ON dc.email = to_order.user_email
INNER JOIN dim_product dp ON dp.product_name = toi.product_name
INNER JOIN dim_manufacturer dm ON dm.company_name = (
    SELECT manufacturer_name FROM temp_products tp WHERE tp.product_name = toi.product_name LIMIT 1
)
INNER JOIN dim_location dl ON dl.city = to_order.shipping_city 
    AND dl.state = to_order.shipping_state 
    AND dl.postal_code = to_order.shipping_postal_code;

\echo 'Loading fact_inventory from product CSV data...'

INSERT INTO fact_inventory (
    date_key, product_key, manufacturer_key, stock_quantity, min_stock_level, 
    reorder_point, stock_value, units_sold, units_received, units_adjusted,
    stock_status, days_of_supply, turnover_rate, is_active, is_discontinued, is_seasonal
)
SELECT 
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD')::INTEGER as date_key,
    dp.product_key,
    dm.manufacturer_key,
    tp.stock_quantity,
    CASE 
        WHEN tp.stock_quantity > 100 THEN 20
        WHEN tp.stock_quantity > 50 THEN 10
        ELSE 5
    END as min_stock_level,
    CASE 
        WHEN tp.stock_quantity > 100 THEN 40
        WHEN tp.stock_quantity > 50 THEN 20
        ELSE 10
    END as reorder_point,
    (tp.stock_quantity * tp.cost) as stock_value,
    0 as units_sold,
    tp.stock_quantity as units_received,
    0 as units_adjusted,
    CASE 
        WHEN tp.stock_quantity <= 10 THEN 'Low Stock'
        WHEN tp.stock_quantity <= 0 THEN 'Out of Stock'
        WHEN tp.stock_quantity >= 200 THEN 'Overstock'
        ELSE 'Normal'
    END as stock_status,
    CASE 
        WHEN tp.stock_quantity > 0 THEN 
            ROUND((tp.stock_quantity::DECIMAL / GREATEST(1, tp.stock_quantity::DECIMAL / 30)), 0)::INTEGER
        ELSE 0
    END as days_of_supply,
    CASE 
        WHEN tp.stock_quantity > 0 THEN 
            ROUND((365.0 / GREATEST(1, tp.stock_quantity::DECIMAL / 12)), 4)
        ELSE 0
    END as turnover_rate,
    tp.is_active,
    FALSE as is_discontinued,
    FALSE as is_seasonal
FROM temp_products tp
INNER JOIN dim_product dp ON dp.product_name = tp.product_name
INNER JOIN dim_manufacturer dm ON dm.company_name = tp.manufacturer_name
WHERE NOT EXISTS (
    SELECT 1 FROM fact_inventory fi 
    WHERE fi.product_key = dp.product_key 
    AND fi.date_key = TO_CHAR(CURRENT_DATE, 'YYYYMMDD')::INTEGER
);

\echo 'ETL process completed successfully with CSV data!'

SELECT 'Dimension Tables' as category, 'dim_date' as table_name, COUNT(*) as records FROM dim_date
UNION ALL
SELECT 'Dimension Tables', 'dim_time', COUNT(*) FROM dim_time
UNION ALL
SELECT 'Dimension Tables', 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL
SELECT 'Dimension Tables', 'dim_location', COUNT(*) FROM dim_location
UNION ALL
SELECT 'Dimension Tables', 'dim_category', COUNT(*) FROM dim_category
UNION ALL
SELECT 'Dimension Tables', 'dim_manufacturer', COUNT(*) FROM dim_manufacturer
UNION ALL
SELECT 'Dimension Tables', 'dim_product', COUNT(*) FROM dim_product
UNION ALL
SELECT 'Bridge Tables', 'bridge_product_category', COUNT(*) FROM bridge_product_category
UNION ALL
SELECT 'Fact Tables', 'fact_sales', COUNT(*) FROM fact_sales
UNION ALL
SELECT 'Fact Tables', 'fact_inventory', COUNT(*) FROM fact_inventory
ORDER BY category, table_name; 