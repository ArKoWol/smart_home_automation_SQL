# Smart Home Automation SQL Database

University coursework project for developing a database system for smart home automation with both OLTP and OLAP components.

## Database Architecture

**OLTP Database**: 8 tables in 3NF
- Users, Rooms, DeviceTypes, Devices, DeviceStatus, Scenes, SceneDevices, Events

**OLAP Database**: Snowflake schema
- Dimensional model with fact tables, dimensions, and SCD Type 2

## Quick Start

### Prerequisites
- Docker
- Docker Compose

### Setup
1. Clone the repository:
```bash
git clone git@github.com:ArKoWol/smart_home_automation_SQL.git
cd smart_home_automation_SQL
```

2. Start containers:
```bash
docker-compose up -d
```

3. Wait for database initialization (~30 seconds)

### Database Access
- **PostgreSQL**: localhost:5433
- **PgAdmin**: http://localhost:8080
  - Email: `admin@example.com`
  - Password: `admin123`

## Project Structure
```
smart_home_automation_SQL/
├── docker-compose.yml                    # Docker configuration
├── sql/                                  # SQL scripts directory
│   ├── oltp/                            # OLTP database scripts
│   │   ├── 01_create_tables.sql         # Create OLTP tables
│   │   └── 02_load_data.sql             # Load data into OLTP
│   └── olap/                            # OLAP database scripts
│       ├── 01_create_olap_schema.sql    # Create OLAP schema
│       ├── 02_populate_reference_data.sql # Load reference data
│       ├── 03_etl_process.sql           # Main ETL process
│       ├── 03_etl_simple.sql            # Simplified ETL
│       └── 05_generate_demo_data.sql    # Generate demo data
├── data/                                # CSV data files
│   ├── users.csv                        # User data
│   ├── rooms.csv                        # Room data
│   ├── device_types.csv                 # Device type data
│   ├── devices.csv                      # Device data
│   ├── scenes.csv                       # Scene data
│   └── scene_devices.csv                # Scene-device relationships
├── analytical_queries.sql               # Business intelligence queries
├── ANALYTICAL_QUERIES_DOCUMENTATION.md  # Query documentation
├── Course work.pbix                     # Power BI report
└── Smart_Home_Course_Work_Documentation.docx # Project documentation
```

## Features Implemented
- ✅ **OLTP 3NF Database** (8 tables)
- ✅ **CSV Data Loading** (rerunnable scripts)
- ✅ **OLAP Snowflake Schema** (fact tables, dimensions, SCD Type 2)
- ✅ **ETL Process** (OLTP → OLAP)
- ✅ **Analytical Queries**
- ✅ **Power BI Report**

## Commands
```bash
# Start system
docker-compose up -d

# Stop system
docker-compose down

# Connect to database
docker exec -it smart_home_db psql -U admin -d smart_home

# Run ETL process
docker exec -i smart_home_db psql -U admin -d smart_home < sql/olap/03_etl_process.sql

# Run simplified ETL
docker exec -i smart_home_db psql -U admin -d smart_home < sql/olap/03_etl_simple.sql
```

## Documentation
- `ANALYTICAL_QUERIES_DOCUMENTATION.md` - Query documentation
- `Smart_Home_Course_Work_Documentation.docx` - Complete project documentation
- See `analytical_queries.sql` for business intelligence queries
- Power BI report available in `Course work.pbix`