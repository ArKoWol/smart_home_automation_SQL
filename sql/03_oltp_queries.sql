
\echo 'Executing OLTP Analytical Queries...'

\echo 'Query 1: Top 5 Best-Selling Products with Revenue Analysis'
SELECT 
    p.product_name,
    p.model_number,
    p.manufacturer_name,
    c.category_name,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(oi.quantity) as total_units_sold,
    SUM(oi.total_price) as total_revenue,
    AVG(oi.unit_price) as avg_unit_price,
    p.stock_quantity as current_stock,
    CASE 
        WHEN p.stock_quantity < p.min_stock_level THEN 'Low Stock'
        WHEN p.stock_quantity = 0 THEN 'Out of Stock'
        ELSE 'In Stock'
    END as stock_status
FROM products p
JOIN categories c ON p.category_id = c.category_id
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.product_name, p.model_number, p.manufacturer_name, c.category_name, p.stock_quantity, p.min_stock_level
ORDER BY total_revenue DESC NULLS LAST
LIMIT 5;

\echo 'Query 2: Customer Purchasing Behavior Analysis'
SELECT 
    u.first_name || ' ' || u.last_name as customer_name,
    u.email,
    u.city,
    u.state,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent,
    AVG(o.total_amount) as avg_order_value,
    MIN(o.order_date) as first_order_date,
    MAX(o.order_date) as last_order_date,
    DATE_PART('day', MAX(o.order_date) - MIN(o.order_date)) as customer_lifetime_days,
    CASE 
        WHEN COUNT(DISTINCT o.order_id) >= 5 THEN 'VIP Customer'
        WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 'Regular Customer'
        WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 'New Customer'
        ELSE 'Inactive'
    END as customer_segment,
    COUNT(sc.cart_id) as items_in_cart
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
LEFT JOIN shopping_cart sc ON u.user_id = sc.user_id
WHERE u.is_active = TRUE
GROUP BY u.user_id, u.first_name, u.last_name, u.email, u.city, u.state
HAVING COUNT(DISTINCT o.order_id) > 0
ORDER BY total_spent DESC;

\echo 'Query 3: Order Fulfillment and Shipping Performance Analysis'
SELECT 
    o.order_status,
    COUNT(*) as order_count,
    AVG(o.total_amount) as avg_order_value,
    SUM(o.total_amount) as total_revenue,
    AVG(DATE_PART('day', o.shipped_date - o.order_date)) as avg_days_to_ship,
    AVG(DATE_PART('day', o.delivered_date - o.shipped_date)) as avg_days_to_deliver,
    AVG(DATE_PART('day', o.delivered_date - o.order_date)) as avg_total_fulfillment_days,
    COUNT(CASE WHEN o.shipped_date IS NOT NULL THEN 1 END) as shipped_orders,
    COUNT(CASE WHEN o.delivered_date IS NOT NULL THEN 1 END) as delivered_orders,
    ROUND(
        COUNT(CASE WHEN o.delivered_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2
    ) as delivery_success_rate
FROM orders o
GROUP BY o.order_status
ORDER BY 
    CASE o.order_status 
        WHEN 'pending' THEN 1
        WHEN 'confirmed' THEN 2
        WHEN 'shipped' THEN 3
        WHEN 'delivered' THEN 4
        WHEN 'cancelled' THEN 5
    END;

\echo 'Query 4: Inventory Management and Stock Analysis'
SELECT 
    c.category_name,
    p.manufacturer_name,
    COUNT(p.product_id) as total_products,
    SUM(p.stock_quantity) as total_stock_units,
    SUM(p.stock_quantity * p.cost) as total_inventory_value,
    AVG(p.price) as avg_product_price,
    COUNT(CASE WHEN p.stock_quantity < p.min_stock_level THEN 1 END) as low_stock_products,
    COUNT(CASE WHEN p.stock_quantity = 0 THEN 1 END) as out_of_stock_products,
    ROUND(
        COUNT(CASE WHEN p.stock_quantity < p.min_stock_level THEN 1 END) * 100.0 / COUNT(p.product_id), 2
    ) as low_stock_percentage,
    COALESCE(SUM(oi_stats.total_sold), 0) as total_units_sold,
    CASE 
        WHEN SUM(p.stock_quantity) > 0 THEN 
            ROUND(COALESCE(SUM(oi_stats.total_sold), 0) * 1.0 / SUM(p.stock_quantity), 2)
        ELSE 0 
    END as inventory_turnover_ratio
FROM categories c
JOIN products p ON c.category_id = p.category_id
LEFT JOIN (
    SELECT 
        product_id,
        SUM(quantity) as total_sold
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status IN ('shipped', 'delivered')
    GROUP BY product_id
) oi_stats ON p.product_id = oi_stats.product_id
WHERE p.is_active = TRUE
GROUP BY c.category_id, c.category_name, p.manufacturer_name
ORDER BY total_inventory_value DESC;

\echo 'Query 5: Payment Methods and Financial Analysis'
SELECT 
    p.payment_method,
    p.payment_status,
    COUNT(*) as transaction_count,
    SUM(p.amount) as total_amount,
    AVG(p.amount) as avg_transaction_amount,
    MIN(p.amount) as min_transaction,
    MAX(p.amount) as max_transaction,
    SUM(p.processing_fee) as total_processing_fees,
    AVG(p.processing_fee) as avg_processing_fee,
    ROUND(
        COUNT(CASE WHEN p.payment_status = 'completed' THEN 1 END) * 100.0 / COUNT(*), 2
    ) as success_rate,
    COUNT(CASE WHEN p.payment_status = 'failed' THEN 1 END) as failed_transactions,
    COUNT(CASE WHEN p.payment_status = 'refunded' THEN 1 END) as refunded_transactions
FROM payments p
GROUP BY p.payment_method, p.payment_status
ORDER BY p.payment_method, total_amount DESC;

\echo 'Query 6: Monthly Sales Trend Analysis'
SELECT 
    DATE_TRUNC('month', o.order_date) as month,
    TO_CHAR(o.order_date, 'YYYY-MM') as month_year,
    COUNT(DISTINCT o.order_id) as total_orders,
    COUNT(DISTINCT o.user_id) as unique_customers,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    SUM(o.subtotal) as total_subtotal,
    SUM(o.tax_amount) as total_tax,
    SUM(o.shipping_cost) as total_shipping,
    LAG(SUM(o.total_amount)) OVER (ORDER BY DATE_TRUNC('month', o.order_date)) as prev_month_revenue,
    CASE 
        WHEN LAG(SUM(o.total_amount)) OVER (ORDER BY DATE_TRUNC('month', o.order_date)) IS NOT NULL THEN
            ROUND(
                ((SUM(o.total_amount) - LAG(SUM(o.total_amount)) OVER (ORDER BY DATE_TRUNC('month', o.order_date))) * 100.0 / 
                LAG(SUM(o.total_amount)) OVER (ORDER BY DATE_TRUNC('month', o.order_date))), 2
            )
        ELSE NULL
    END as month_over_month_growth_pct
FROM orders o
WHERE o.order_date >= '2024-01-01'
GROUP BY DATE_TRUNC('month', o.order_date), TO_CHAR(o.order_date, 'YYYY-MM')
ORDER BY month;

\echo 'Query 7: Product Category Performance Comparison'
WITH category_performance AS (
    SELECT 
        c.category_name,
        c.parent_category_id,
        COUNT(DISTINCT p.product_id) as product_count,
        COUNT(DISTINCT o.order_id) as order_count,
        SUM(oi.quantity) as total_units_sold,
        SUM(oi.total_price) as total_revenue,
        AVG(oi.unit_price) as avg_unit_price,
        SUM(p.stock_quantity) as total_stock,
        SUM(p.stock_quantity * p.cost) as inventory_value
    FROM categories c
    LEFT JOIN products p ON c.category_id = p.category_id
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id
    WHERE p.is_active = TRUE OR p.is_active IS NULL
    GROUP BY c.category_id, c.category_name, c.parent_category_id
)
SELECT 
    cp.category_name,
    CASE WHEN cp.parent_category_id IS NULL THEN 'Parent Category' ELSE 'Sub Category' END as category_type,
    cp.product_count,
    cp.order_count,
    COALESCE(cp.total_units_sold, 0) as total_units_sold,
    COALESCE(cp.total_revenue, 0) as total_revenue,
    COALESCE(cp.avg_unit_price, 0) as avg_unit_price,
    cp.total_stock,
    COALESCE(cp.inventory_value, 0) as inventory_value,
    CASE 
        WHEN cp.total_stock > 0 AND cp.total_units_sold > 0 THEN
            ROUND(cp.total_units_sold * 1.0 / cp.total_stock, 2)
        ELSE 0
    END as stock_turnover_ratio,
    RANK() OVER (ORDER BY COALESCE(cp.total_revenue, 0) DESC) as revenue_rank
FROM category_performance cp
ORDER BY cp.total_revenue DESC NULLS LAST;

\echo 'OLTP Analytical Queries completed successfully!' 