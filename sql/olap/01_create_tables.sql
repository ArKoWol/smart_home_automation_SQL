DROP TABLE IF EXISTS fact_sales CASCADE;
DROP TABLE IF EXISTS fact_inventory CASCADE;
DROP TABLE IF EXISTS bridge_product_category CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;
DROP TABLE IF EXISTS dim_time CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_category CASCADE;
DROP TABLE IF EXISTS dim_manufacturer CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_location CASCADE;

CREATE TABLE dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    day_of_month INTEGER NOT NULL,
    day_of_year INTEGER NOT NULL,
    week_of_year INTEGER NOT NULL,
    month_number INTEGER NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    quarter INTEGER NOT NULL,
    quarter_name VARCHAR(10) NOT NULL,
    year INTEGER NOT NULL,
    is_weekend BOOLEAN DEFAULT FALSE,
    is_holiday BOOLEAN DEFAULT FALSE,
    fiscal_year INTEGER,
    fiscal_quarter INTEGER
);

CREATE TABLE dim_time (
    time_key INTEGER PRIMARY KEY,
    hour INTEGER NOT NULL,
    minute INTEGER NOT NULL,
    second INTEGER NOT NULL,
    time_of_day VARCHAR(20) NOT NULL,
    hour_12 INTEGER NOT NULL,
    am_pm VARCHAR(2) NOT NULL,
    business_hour BOOLEAN DEFAULT FALSE
);

CREATE TABLE dim_customer (
    customer_key SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    email VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    customer_segment VARCHAR(50),
    registration_date DATE,
    valid_from DATE NOT NULL,
    valid_to DATE,
    is_current BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1
);

CREATE TABLE dim_location (
    location_key SERIAL PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20),
    country VARCHAR(100) NOT NULL,
    region VARCHAR(100),
    time_zone VARCHAR(50),
    population INTEGER,
    area_type VARCHAR(20)
);

CREATE TABLE dim_category (
    category_key SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    parent_category_name VARCHAR(100),
    category_level INTEGER NOT NULL,
    category_path VARCHAR(255),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE dim_manufacturer (
    manufacturer_key SERIAL PRIMARY KEY,
    manufacturer_id INTEGER NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    website VARCHAR(255),
    address_line1 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    established_year INTEGER,
    company_size VARCHAR(20),
    valid_from DATE NOT NULL,
    valid_to DATE,
    is_current BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1
);

CREATE TABLE dim_product (
    product_key SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_description TEXT,
    model_number VARCHAR(100),
    price DECIMAL(10,2),
    cost DECIMAL(10,2),
    weight_kg DECIMAL(8,2),
    dimensions_cm VARCHAR(50),
    color VARCHAR(50),
    warranty_months INTEGER,
    energy_rating VARCHAR(20),
    connectivity_type VARCHAR(100),
    price_range VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    created_date DATE
);

CREATE TABLE bridge_product_category (
    bridge_key SERIAL PRIMARY KEY,
    product_key INTEGER NOT NULL REFERENCES dim_product(product_key),
    category_key INTEGER NOT NULL REFERENCES dim_category(category_key),
    relationship_type VARCHAR(50) DEFAULT 'primary',
    effective_date DATE DEFAULT CURRENT_DATE,
    expiry_date DATE,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE fact_sales (
    sale_key SERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date(date_key),
    time_key INTEGER NOT NULL REFERENCES dim_time(time_key),
    customer_key INTEGER NOT NULL REFERENCES dim_customer(customer_key),
    product_key INTEGER NOT NULL REFERENCES dim_product(product_key),
    manufacturer_key INTEGER NOT NULL REFERENCES dim_manufacturer(manufacturer_key),
    location_key INTEGER NOT NULL REFERENCES dim_location(location_key),
    
    order_id INTEGER NOT NULL,
    order_status VARCHAR(50),
    
    quantity_sold INTEGER NOT NULL CHECK (quantity_sold > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    unit_cost DECIMAL(10,2) CHECK (unit_cost >= 0),
    total_sales_amount DECIMAL(12,2) NOT NULL CHECK (total_sales_amount >= 0),
    total_cost_amount DECIMAL(12,2) CHECK (total_cost_amount >= 0),
    gross_profit DECIMAL(12,2),
    tax_amount DECIMAL(10,2) DEFAULT 0,
    shipping_cost DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    
    days_to_ship INTEGER,
    days_to_deliver INTEGER,
    
    is_returned BOOLEAN DEFAULT FALSE,
    is_refunded BOOLEAN DEFAULT FALSE,
    
    etl_load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system VARCHAR(50) DEFAULT 'OLTP'
);

CREATE TABLE fact_inventory (
    inventory_key SERIAL PRIMARY KEY,
    date_key INTEGER NOT NULL REFERENCES dim_date(date_key),
    product_key INTEGER NOT NULL REFERENCES dim_product(product_key),
    manufacturer_key INTEGER NOT NULL REFERENCES dim_manufacturer(manufacturer_key),
    
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0),
    min_stock_level INTEGER NOT NULL,
    reorder_point INTEGER,
    stock_value DECIMAL(12,2) NOT NULL CHECK (stock_value >= 0),
    units_sold INTEGER DEFAULT 0,
    units_received INTEGER DEFAULT 0,
    units_adjusted INTEGER DEFAULT 0,
    
    stock_status VARCHAR(20),
    days_of_supply INTEGER,
    turnover_rate DECIMAL(8,4),
    
    is_active BOOLEAN DEFAULT TRUE,
    is_discontinued BOOLEAN DEFAULT FALSE,
    is_seasonal BOOLEAN DEFAULT FALSE,
    
    etl_load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_system VARCHAR(50) DEFAULT 'OLTP'
);

CREATE INDEX idx_fact_sales_date ON fact_sales(date_key);
CREATE INDEX idx_fact_sales_customer ON fact_sales(customer_key);
CREATE INDEX idx_fact_sales_product ON fact_sales(product_key);
CREATE INDEX idx_fact_sales_manufacturer ON fact_sales(manufacturer_key);
CREATE INDEX idx_fact_sales_location ON fact_sales(location_key);
CREATE INDEX idx_fact_sales_order ON fact_sales(order_id);

CREATE INDEX idx_fact_inventory_date ON fact_inventory(date_key);
CREATE INDEX idx_fact_inventory_product ON fact_inventory(product_key);
CREATE INDEX idx_fact_inventory_manufacturer ON fact_inventory(manufacturer_key);
CREATE INDEX idx_fact_inventory_status ON fact_inventory(stock_status);

CREATE INDEX idx_dim_customer_id ON dim_customer(customer_id);
CREATE INDEX idx_dim_customer_current ON dim_customer(is_current);
CREATE INDEX idx_dim_customer_valid_from ON dim_customer(valid_from);
CREATE INDEX idx_dim_customer_valid_to ON dim_customer(valid_to);

CREATE INDEX idx_dim_manufacturer_id ON dim_manufacturer(manufacturer_id);
CREATE INDEX idx_dim_manufacturer_current ON dim_manufacturer(is_current);

CREATE INDEX idx_dim_product_id ON dim_product(product_id);
CREATE INDEX idx_dim_category_id ON dim_category(category_id);

CREATE INDEX idx_bridge_product ON bridge_product_category(product_key);
CREATE INDEX idx_bridge_category ON bridge_product_category(category_key);

\dt 