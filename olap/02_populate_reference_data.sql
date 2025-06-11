\c smart_home_olap;

INSERT INTO DIM_DATE (DateKey, Date, Year, Quarter, Month, MonthName, Week, Day, DayName, DayOfYear, IsWeekend)
SELECT 
    TO_CHAR(date_series, 'YYYYMMDD')::INTEGER,
    date_series,
    EXTRACT(YEAR FROM date_series),
    EXTRACT(QUARTER FROM date_series),
    EXTRACT(MONTH FROM date_series),
    TO_CHAR(date_series, 'Month'),
    EXTRACT(WEEK FROM date_series),
    EXTRACT(DAY FROM date_series),
    TO_CHAR(date_series, 'Day'),
    EXTRACT(DOY FROM date_series),
    CASE WHEN EXTRACT(ISODOW FROM date_series) IN (6, 7) THEN TRUE ELSE FALSE END
FROM generate_series('2023-01-01'::DATE, '2025-12-31'::DATE, '1 day'::INTERVAL) AS date_series;

INSERT INTO DIM_TIME (TimeKey, Hour, Minute, TimeOfDay, IsBusinessHour)
SELECT 
    (h * 100 + m) AS TimeKey,
    h,
    m,
    CASE 
        WHEN h BETWEEN 6 AND 11 THEN 'Morning'
        WHEN h BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN h BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END AS TimeOfDay,
    CASE 
        WHEN h BETWEEN 9 AND 17 THEN TRUE 
        ELSE FALSE 
    END AS IsBusinessHour
FROM 
    generate_series(0, 23) h
CROSS JOIN
    generate_series(0, 45, 15) m;

INSERT INTO DIM_MANUFACTURER (ManufacturerName, Country, Founded_Year, ValidFrom, ValidTo, IsCurrent)
VALUES 
    ('Philips', 'Netherlands', 1891, NOW(), NULL, TRUE),
    ('Amazon', 'United States', 1994, NOW(), NULL, TRUE),
    ('Google', 'United States', 1998, NOW(), NULL, TRUE),
    ('Samsung', 'South Korea', 1938, NOW(), NULL, TRUE),
    ('Apple', 'United States', 1976, NOW(), NULL, TRUE),
    ('IKEA', 'Sweden', 1943, NOW(), NULL, TRUE),
    ('Nest', 'United States', 2010, NOW(), NULL, TRUE),
    ('Ring', 'United States', 2013, NOW(), NULL, TRUE),
    ('August', 'United States', 2012, NOW(), NULL, TRUE),
    ('Leviton', 'United States', 1906, NOW(), NULL, TRUE),
    ('SmartThings', 'United States', 2012, NOW(), NULL, TRUE),
    ('Honeywell', 'United States', 1906, NOW(), NULL, TRUE),
    ('TP-Link', 'China', 1996, NOW(), NULL, TRUE),
    ('Xiaomi', 'China', 2010, NOW(), NULL, TRUE),
    ('Sonos', 'United States', 2002, NOW(), NULL, TRUE);

INSERT INTO DIM_DEVICE_TYPE (TypeName, Category, Description, EnergyEfficiencyRating)
VALUES 
    ('Smart Light', 'Lighting', 'LED lights with dimming and color control', 'A++'),
    ('Smart Thermostat', 'Climate', 'Temperature control system with scheduling', 'A+'),
    ('Smart Switch', 'Lighting', 'Electrical switch with remote control capability', 'A'),
    ('Smart Lock', 'Security', 'Electronic door lock with keypad and remote access', 'A'),
    ('Smart Camera', 'Security', 'Security camera with motion detection', 'B+'),
    ('Smart Speaker', 'Entertainment', 'Voice-controlled speaker with AI assistant', 'A'),
    ('Smart Sensor', 'Monitoring', 'Motion and temperature sensors', 'A++'),
    ('Smart Plug', 'Control', 'Remote controlled electrical outlet', 'A+'),
    ('Smart Doorbell', 'Security', 'Video doorbell with two-way communication', 'A'),
    ('Smart Vacuum', 'Cleaning', 'Robotic vacuum with smart navigation', 'A+'),
    ('Smart TV', 'Entertainment', 'Internet-connected television', 'A+'),
    ('Smart Blinds', 'Climate', 'Automated window blinds', 'A'),
    ('Smart Alarm', 'Security', 'Home security alarm system', 'A'),
    ('Smart Fan', 'Climate', 'Ceiling fan with smart controls', 'A+'),
    ('Smart Garage Door', 'Security', 'Automated garage door opener', 'A'); 