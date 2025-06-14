\echo 'Executing OLAP Analytical Queries...'

\echo 'Query 1: Sales Performance Analysis by Time Dimensions'
SELECT 
    dd.year,
    dd.quarter_name,
    dd.month_name,
    COUNT(DISTINCT fs.order_id) as total_orders,
    SUM(fs.quantity_sold) as total_units_sold,
    SUM(fs.total_sales_amount) as total_revenue,
    SUM(fs.gross_profit) as total_gross_profit,
    AVG(fs.unit_price) as avg_unit_price,
    SUM(fs.tax_amount) as total_tax,
    SUM(fs.shipping_cost) as total_shipping_cost,
    ROUND(
        SUM(fs.gross_profit) * 100.0 / NULLIF(SUM(fs.total_sales_amount), 0), 2
    ) as gross_profit_margin_pct,
    AVG(SUM(fs.total_sales_amount)) OVER (
        ORDER BY dd.year, dd.month_number 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as rolling_3month_avg_revenue
FROM fact_sales fs
JOIN dim_date dd ON fs.date_key = dd.date_key
WHERE dd.year >= 2024
GROUP BY dd.year, dd.quarter, dd.quarter_name, dd.month_number, dd.month_name
ORDER BY dd.year, dd.month_number;

\echo 'Query 2: Customer Segmentation Analysis with SCD Type 2'
WITH customer_metrics AS (
    SELECT 
        dc.customer_segment,
        dc.city,
        dc.state,
        dl.region,
        COUNT(DISTINCT fs.customer_key) as unique_customers,
        COUNT(DISTINCT fs.order_id) as total_orders,
        SUM(fs.total_sales_amount) as total_revenue,
        AVG(fs.total_sales_amount) as avg_order_value,
        SUM(fs.quantity_sold) as total_units_purchased,
        AVG(fs.quantity_sold) as avg_units_per_order,
        MIN(dd.full_date) as first_purchase_date,
        MAX(dd.full_date) as last_purchase_date,
        AVG(DATE_PART('day', dd.full_date - dc.valid_from)) as avg_customer_age_days
    FROM fact_sales fs
    JOIN dim_customer dc ON fs.customer_key = dc.customer_key
    JOIN dim_date dd ON fs.date_key = dd.date_key
    JOIN dim_location dl ON fs.location_key = dl.location_key
    WHERE dc.is_current = TRUE
    GROUP BY dc.customer_segment, dc.city, dc.state, dl.region
)
SELECT 
    customer_segment,
    region,
    unique_customers,
    total_orders,
    total_revenue,
    ROUND(total_revenue / unique_customers, 2) as revenue_per_customer,
    ROUND(avg_order_value, 2) as avg_order_value,
    ROUND(total_orders * 1.0 / unique_customers, 2) as avg_orders_per_customer,
    total_units_purchased,
    ROUND(avg_units_per_order, 1) as avg_units_per_order,
    ROUND(avg_customer_age_days, 0) as avg_customer_age_days,
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    ROUND(
        total_revenue * 100.0 / SUM(total_revenue) OVER (), 2
    ) as revenue_share_pct
FROM customer_metrics
ORDER BY total_revenue DESC;

\echo 'Query 3: Product Performance Analysis with Bridge Table'
SELECT 
    dc.category_name,
    dc.category_path,
    dp.product_name,
    dm.company_name as manufacturer,
    dp.price_range,
    COUNT(DISTINCT fs.order_id) as total_orders,
    SUM(fs.quantity_sold) as total_units_sold,
    SUM(fs.total_sales_amount) as total_revenue,
    SUM(fs.gross_profit) as total_gross_profit,
    AVG(fs.unit_price) as avg_selling_price,
    AVG(fi.stock_quantity) as avg_stock_level,
    AVG(fi.stock_value) as avg_stock_value,
    COALESCE(AVG(fi.turnover_rate), 0) as avg_turnover_rate,
    ROUND(
        SUM(fs.gross_profit) * 100.0 / NULLIF(SUM(fs.total_sales_amount), 0), 2
    ) as profit_margin_pct,
    CASE 
        WHEN AVG(fi.stock_quantity) > 0 THEN
            ROUND(SUM(fs.quantity_sold) * 1.0 / AVG(fi.stock_quantity), 2)
        ELSE 0
    END as inventory_turns,
    bpc.relationship_type as category_relationship
FROM bridge_product_category bpc
JOIN dim_product dp ON bpc.product_key = dp.product_key
JOIN dim_category dc ON bpc.category_key = dc.category_key
LEFT JOIN fact_sales fs ON dp.product_key = fs.product_key
LEFT JOIN fact_inventory fi ON dp.product_key = fi.product_key
LEFT JOIN dim_manufacturer dm ON fs.manufacturer_key = dm.manufacturer_key AND dm.is_current = TRUE
WHERE bpc.is_active = TRUE
    AND dp.is_active = TRUE
    AND dc.is_active = TRUE
GROUP BY dc.category_name, dc.category_path, dp.product_name, 
         dm.company_name, dp.price_range, bpc.relationship_type
HAVING SUM(fs.total_sales_amount) > 0
ORDER BY total_revenue DESC;

\echo 'Query 4: Time-based Sales Trend Analysis'
WITH daily_sales AS (
    SELECT 
        dd.full_date,
        dd.day_name,
        dd.is_weekend,
        dt.time_of_day,
        dt.business_hour,
        COUNT(DISTINCT fs.order_id) as daily_orders,
        SUM(fs.total_sales_amount) as daily_revenue,
        AVG(fs.total_sales_amount) as avg_order_value,
        SUM(fs.quantity_sold) as daily_units_sold
    FROM fact_sales fs
    JOIN dim_date dd ON fs.date_key = dd.date_key
    JOIN dim_time dt ON fs.time_key = dt.time_key
    WHERE dd.full_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY dd.full_date, dd.day_name, dd.is_weekend, dt.time_of_day, dt.business_hour
),
time_analysis AS (
    SELECT 
        day_name,
        time_of_day,
        is_weekend,
        business_hour,
        COUNT(*) as occurrence_count,
        AVG(daily_orders) as avg_orders,
        AVG(daily_revenue) as avg_revenue,
        AVG(avg_order_value) as avg_order_value,
        AVG(daily_units_sold) as avg_units_sold,
        STDDEV(daily_revenue) as revenue_stddev
    FROM daily_sales
    GROUP BY day_name, time_of_day, is_weekend, business_hour
)
SELECT 
    day_name,
    time_of_day,
    CASE WHEN is_weekend THEN 'Weekend' ELSE 'Weekday' END as day_type,
    CASE WHEN business_hour THEN 'Business Hours' ELSE 'After Hours' END as hour_type,
    occurrence_count,
    ROUND(avg_orders, 1) as avg_orders_per_period,
    ROUND(avg_revenue, 2) as avg_revenue_per_period,
    ROUND(avg_order_value, 2) as avg_order_value,
    ROUND(avg_units_sold, 1) as avg_units_sold,
    ROUND(revenue_stddev, 2) as revenue_volatility,
    RANK() OVER (ORDER BY avg_revenue DESC) as revenue_rank,
    ROUND(
        avg_revenue * 100.0 / SUM(avg_revenue) OVER (), 2
    ) as revenue_contribution_pct
FROM time_analysis
ORDER BY avg_revenue DESC;

\echo 'Query 5: Geographic Sales Distribution Analysis'
SELECT 
    dl.region,
    dl.state,
    dl.city,
    dl.area_type,
    COUNT(DISTINCT fs.customer_key) as unique_customers,
    COUNT(DISTINCT fs.order_id) as total_orders,
    SUM(fs.total_sales_amount) as total_revenue,
    AVG(fs.total_sales_amount) as avg_order_value,
    SUM(fs.quantity_sold) as total_units_sold,
    SUM(fs.tax_amount) as total_tax_collected,
    SUM(fs.shipping_cost) as total_shipping_costs,
    ROUND(total_revenue / COUNT(DISTINCT fs.customer_key), 2) as revenue_per_customer,
    ROUND(COUNT(DISTINCT fs.order_id) * 1.0 / COUNT(DISTINCT fs.customer_key), 2) as orders_per_customer,
    ROUND(
        SUM(fs.total_sales_amount) * 100.0 / SUM(SUM(fs.total_sales_amount)) OVER (), 2
    ) as market_share_pct,
    RANK() OVER (ORDER BY SUM(fs.total_sales_amount) DESC) as revenue_rank,
    ROUND(
        AVG(fs.days_to_deliver), 1
    ) as avg_delivery_days,
    ROUND(
        SUM(fs.shipping_cost) * 100.0 / SUM(fs.total_sales_amount), 2
    ) as shipping_cost_pct
FROM fact_sales fs
JOIN dim_location dl ON fs.location_key = dl.location_key
GROUP BY dl.region, dl.state, dl.city, dl.area_type
HAVING COUNT(DISTINCT fs.order_id) >= 1
ORDER BY total_revenue DESC;

\echo 'Query 6: Manufacturer Performance with SCD Type 2 History'
SELECT 
    dm.company_name,
    dm.company_size,
    dm.established_year,
    dm.state as manufacturer_state,
    dm.version as data_version,
    dm.valid_from,
    dm.valid_to,
    dm.is_current,
    COUNT(DISTINCT fs.order_id) as total_orders,
    SUM(fs.quantity_sold) as total_units_sold,
    SUM(fs.total_sales_amount) as total_revenue,
    SUM(fs.total_cost_amount) as total_cost,
    SUM(fs.gross_profit) as total_gross_profit,
    AVG(fs.unit_price) as avg_selling_price,
    ROUND(
        SUM(fs.gross_profit) * 100.0 / NULLIF(SUM(fs.total_sales_amount), 0), 2
    ) as gross_profit_margin_pct,
    ROUND(
        SUM(fs.total_sales_amount) / COUNT(DISTINCT fs.order_id), 2
    ) as avg_order_value,
    RANK() OVER (
        PARTITION BY dm.is_current 
        ORDER BY SUM(fs.total_sales_amount) DESC
    ) as revenue_rank_current,
    ROUND(
        SUM(fs.total_sales_amount) * 100.0 / 
        SUM(SUM(fs.total_sales_amount)) OVER (PARTITION BY dm.is_current), 2
    ) as market_share_pct,
    AVG(fi.stock_quantity) as avg_inventory_level,
    AVG(fi.stock_value) as avg_inventory_value,
    COALESCE(AVG(fi.turnover_rate), 0) as avg_inventory_turnover
FROM dim_manufacturer dm
LEFT JOIN fact_sales fs ON dm.manufacturer_key = fs.manufacturer_key
LEFT JOIN fact_inventory fi ON dm.manufacturer_key = fi.manufacturer_key
GROUP BY dm.manufacturer_key, dm.company_name, dm.company_size, dm.established_year,
         dm.state, dm.version, dm.valid_from, dm.valid_to, dm.is_current
HAVING SUM(fs.total_sales_amount) > 0 OR dm.is_current = TRUE
ORDER BY dm.is_current DESC, total_revenue DESC;

\echo 'Query 7: Inventory Management Dashboard Query'
WITH inventory_summary AS (
    SELECT 
        fi.date_key,
        dd.full_date,
        dp.product_name,
        dc.category_name,
        dm.company_name as manufacturer,
        fi.stock_quantity,
        fi.min_stock_level,
        fi.stock_value,
        fi.stock_status,
        fi.units_sold,
        fi.units_received,
        fi.turnover_rate,
        CASE 
            WHEN fi.stock_quantity = 0 THEN 'Out of Stock'
            WHEN fi.stock_quantity < fi.min_stock_level THEN 'Low Stock'
            WHEN fi.stock_quantity > fi.min_stock_level * 3 THEN 'Overstock'
            ELSE 'Normal Stock'
        END as stock_health,
        CASE 
            WHEN fi.min_stock_level > 0 THEN
                ROUND(fi.stock_quantity * 1.0 / fi.min_stock_level, 2)
            ELSE NULL
        END as stock_ratio
    FROM fact_inventory fi
    JOIN dim_product dp ON fi.product_key = dp.product_key
    JOIN dim_category dc ON dp.product_id = dc.category_id
    JOIN dim_manufacturer dm ON fi.manufacturer_key = dm.manufacturer_key AND dm.is_current = TRUE
    JOIN dim_date dd ON fi.date_key = dd.date_key
    WHERE fi.is_active = TRUE
        AND dd.full_date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    category_name,
    manufacturer,
    stock_health,
    COUNT(DISTINCT product_name) as product_count,
    SUM(stock_quantity) as total_stock_units,
    SUM(stock_value) as total_stock_value,
    AVG(stock_ratio) as avg_stock_ratio,
    SUM(units_sold) as total_units_sold,
    SUM(units_received) as total_units_received,
    AVG(turnover_rate) as avg_turnover_rate,
    COUNT(CASE WHEN stock_health = 'Out of Stock' THEN 1 END) as out_of_stock_products,
    COUNT(CASE WHEN stock_health = 'Low Stock' THEN 1 END) as low_stock_products,
    COUNT(CASE WHEN stock_health = 'Overstock' THEN 1 END) as overstock_products,
    ROUND(
        COUNT(CASE WHEN stock_health IN ('Out of Stock', 'Low Stock') THEN 1 END) * 100.0 / 
        COUNT(DISTINCT product_name), 2
    ) as risk_percentage,
    ROUND(
        SUM(CASE WHEN stock_health = 'Overstock' THEN stock_value ELSE 0 END), 2
    ) as overstock_value,
    ROUND(
        AVG(turnover_rate) * SUM(stock_value), 2
    ) as estimated_annual_throughput
FROM inventory_summary
GROUP BY category_name, manufacturer, stock_health
ORDER BY total_stock_value DESC, risk_percentage DESC;

\echo 'OLAP Analytical Queries completed successfully!'

\echo 'OLAP Database Summary:'
SELECT 'Dimension Tables' as table_type, 'dim_date' as table_name, COUNT(*) as record_count FROM dim_date
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
ORDER BY table_type, table_name; 