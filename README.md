# Smart Home Automation Online-Shop Database System
## OLTP/OLAP Solution with Business Intelligence

## Project Overview

Comprehensive database solution for smart home automation e-commerce platform featuring dual OLTP/OLAP architecture with automated ETL pipeline and Power BI dashboard. The system manages 250+ smart home products from 20+ manufacturers with complete order-to-delivery lifecycle tracking.

### Smart Home Product Ecosystem
- **Smart Lighting**: Philips Hue, LIFX color bulbs, LED strips
- **Voice Assistants**: Amazon Echo, Google Nest, Sonos speakers  
- **Climate Control**: Nest, Ecobee, Honeywell thermostats
- **Security Systems**: Ring cameras, smart locks, motion sensors
- **Kitchen Appliances**: Smart coffee makers, air fryers, refrigerators
- **Energy Management**: Tesla Powerwall, smart switches

## System Architecture

### OLTP Database (Port 5434)
- **8 Normalized Tables** in Third Normal Form (3NF)
- **500+ Operational Records** supporting real-time transactions

| Table | Records | Purpose |
|-------|---------|---------|
| `users` | 40+ | Customer accounts across 20+ US states |
| `categories` | 40+ | Hierarchical product categorization |
| `products` | 45+ | Smart home device catalog |
| `orders` | 70+ | Customer orders with full lifecycle |
| `order_items` | 100+ | Order line items and quantities |
| `shopping_cart` | Active | Real-time cart management |
| `payments` | 70+ | Financial transaction processing |
| `order_status_history` | 200+ | Order status change tracking |

### OLAP Database (Port 5433)
- **Snowflake Schema** with 10 dimensional and fact tables
- **3,000+ Analytical Records** supporting business intelligence

| Component | Tables | Purpose |
|-----------|--------|---------|
| **Fact Tables** | `fact_sales`, `fact_inventory` | Transaction and stock metrics |
| **Dimensions** | 7 tables | Customer, Product, Time, Geography |
| **SCD Type 2** | `dim_customer`, `dim_manufacturer` | Historical change tracking |
| **Bridge Table** | `bridge_product_category` | Many-to-many relationships |

## Quick Start

### Automated Setup
```bash
# Windows PowerShell
.\setup.ps1

# Linux/macOS  
./setup.sh
```

### Manual Setup
```bash
# 1. Start containers
docker-compose up -d

# 2. Create OLTP schema
psql -h localhost -p 5434 -U postgres -d smart_home_shop_oltp -f sql/oltp/01_create_tables.sql

# 3. Load operational data
psql -h localhost -p 5434 -U postgres -d smart_home_shop_oltp -f sql/oltp/02_load_data.sql

# 4. Create OLAP schema
psql -h localhost -p 5433 -U postgres -d smart_home_shop_olap -f sql/olap/01_create_tables.sql

# 5. Execute ETL pipeline
psql -h localhost -p 5433 -U postgres -d smart_home_shop_olap -f sql/olap/02_etl_process.sql
```

## Project Structure

```
smart_home_automation_SQL/
├── README.md
├── docker-compose.yml
├── setup.ps1                         # Windows automation script
├── setup.sh                          # Linux/macOS automation script
│
├── data/                              # CSV data files (250+ records)
│   ├── 01_users.csv                   # Customer data (40 records)
│   ├── 02_categories.csv              # Product categories (40 records)
│   ├── 03_products.csv                # Smart home devices (45 records)
│   ├── 04_orders.csv                  # Customer orders (70 records)
│   └── 05_order_items.csv             # Order line items (100+ records)
│
├── sql/                               # Database scripts
│   ├── oltp/                          # Operational database
│   │   ├── 01_create_tables.sql       # OLTP schema (8 tables)
│   │   └── 02_load_data.sql           # Data loading with status history
│   ├── olap/                          # Analytics database
│   │   ├── 01_create_tables.sql       # OLAP schema (10 tables)
│   │   └── 02_etl_process.sql         # ETL pipeline (422 lines)
│   ├── 03_oltp_queries.sql            # Operational analytics (7 queries)
│   └── 04_olap_queries.sql            # Strategic analytics (7 queries)
│
├── schema_diagrams/                   # Schema visualization files
│   ├── oltp_schema_for_diagram.sql    # OLTP schema for diagram tools
│   └── olap_schema_for_diagram.sql    # OLAP schema for diagram tools
│
└── documentation/                     # Reports & documentation
    ├── Smart_Home_Shop_Documentation.docx  # Word format documentation
    └── Smart Home Automation Online-Shop.pbix # Power BI dashboard (436KB)
```

### SQL Analytics
- **14 Advanced Queries** (7 OLTP + 7 OLAP)
- **Multi-dimensional Analysis** across time, geography, products, customers

```bash
# Execute OLTP operational analytics
psql -h localhost -p 5434 -U postgres -d smart_home_shop_oltp -f sql/03_oltp_queries.sql

# Execute OLAP strategic analytics  
psql -h localhost -p 5433 -U postgres -d smart_home_shop_olap -f sql/04_olap_queries.sql
```

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Database Engine** | PostgreSQL 15+ | OLTP & OLAP data storage |
| **Containerization** | Docker & Docker Compose | Database deployment |
| **Business Intelligence** | Microsoft Power BI | Interactive dashboards |
| **ETL Processing** | SQL + postgres_fdw | Data transformation |
| **Automation** | PowerShell + Bash | Setup scripts |

## System Requirements

- **Docker**: Docker Desktop or Docker Engine + Docker Compose
- **Memory**: 4GB RAM minimum, 8GB recommended
- **Storage**: 2GB free disk space
- **Power BI**: Desktop version for dashboard access

## System Management

### Health Monitoring
```bash
# Check system status
docker exec smart_home_shop_oltp psql -U postgres -c "SELECT COUNT(*) FROM users;"
docker exec smart_home_shop_olap psql -U postgres -c "SELECT COUNT(*) FROM fact_sales;"
```

### System Shutdown
```bash
# Graceful shutdown
docker-compose down

# Complete cleanup
docker-compose down -v --remove-orphans
```
mplete technical specification + Schema diagrams
