\c smart_home_olap;

CREATE TABLE IF NOT EXISTS etl_control (
    table_name VARCHAR(100) PRIMARY KEY,
    last_etl_date TIMESTAMP NOT NULL,
    last_source_row_count INTEGER DEFAULT 0,
    last_target_row_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'READY',
    error_message TEXT NULL
);

INSERT INTO etl_control (table_name, last_etl_date) VALUES
    ('dim_user', '2023-01-01 00:00:00'),
    ('dim_room', '2023-01-01 00:00:00'),
    ('dim_device', '2023-01-01 00:00:00'),
    ('dim_scene', '2023-01-01 00:00:00'),
    ('bridge_scene_device', '2023-01-01 00:00:00'),
    ('fact_device_usage', '2023-01-01 00:00:00'),
    ('fact_scene_execution', '2023-01-01 00:00:00')
ON CONFLICT (table_name) DO NOTHING;

CREATE OR REPLACE FUNCTION etl_load_dim_user() RETURNS VOID AS $$
BEGIN
    UPDATE etl_control SET status = 'RUNNING' WHERE table_name = 'dim_user';
    
    UPDATE dim_user d
    SET validto = NOW(), iscurrent = FALSE
    FROM smart_home.users s
    WHERE d.userid = s.userid
    AND d.iscurrent = TRUE 
    AND (d.name != s.name OR d.email != s.email);
    
    INSERT INTO dim_user (
        userid, name, email, registrationdate, usertype, 
        city, country, validfrom, validto, iscurrent
    )
    SELECT 
        s.userid,
        s.name,
        s.email,
        CURRENT_DATE - INTERVAL '1 day' * FLOOR(RANDOM() * 365),
        CASE 
            WHEN s.userid <= 1 THEN 'Premium'
            WHEN s.userid <= 2 THEN 'Standard' 
            ELSE 'Trial' 
        END,
        CASE 
            WHEN s.userid = 1 THEN 'New York'
            WHEN s.userid = 2 THEN 'London'
            ELSE 'Berlin'
        END,
        CASE 
            WHEN s.userid = 1 THEN 'United States'
            WHEN s.userid = 2 THEN 'United Kingdom'
            ELSE 'Germany'
        END,
        NOW(),
        NULL,
        TRUE
    FROM smart_home.users s
    LEFT JOIN dim_user d ON s.userid = d.userid AND d.iscurrent = TRUE
    WHERE d.userid IS NULL;
    
    UPDATE etl_control 
    SET status = 'COMPLETED', last_etl_date = NOW(), 
        last_target_row_count = (SELECT COUNT(*) FROM dim_user)
    WHERE table_name = 'dim_user';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION etl_load_dim_room() RETURNS VOID AS $$
BEGIN
    UPDATE etl_control SET status = 'RUNNING' WHERE table_name = 'dim_room';
    
    INSERT INTO dim_room (
        roomid, userkey, roomname, roomtype, area_sqm, floor, haswindows
    )
    SELECT 
        sr.roomid,
        du.userkey,
        sr.roomname,
        CASE 
            WHEN sr.roomname LIKE '%Living%' THEN 'Living Room'
            WHEN sr.roomname LIKE '%Kitchen%' THEN 'Kitchen'
            WHEN sr.roomname LIKE '%Bedroom%' THEN 'Bedroom'
            WHEN sr.roomname LIKE '%Bathroom%' THEN 'Bathroom'
            ELSE 'Other'
        END,
        CASE 
            WHEN sr.roomname LIKE '%Living%' THEN 25.5
            WHEN sr.roomname LIKE '%Kitchen%' THEN 15.2
            WHEN sr.roomname LIKE '%Bedroom%' THEN 18.7
            ELSE 12.0
        END,
        1,
        TRUE
    FROM smart_home.rooms sr
    INNER JOIN dim_user du ON sr.userid = du.userid AND du.iscurrent = TRUE
    LEFT JOIN dim_room dr ON sr.roomid = dr.roomid
    WHERE dr.roomid IS NULL;
    
    UPDATE etl_control 
    SET status = 'COMPLETED', last_etl_date = NOW(),
        last_target_row_count = (SELECT COUNT(*) FROM dim_room)
    WHERE table_name = 'dim_room';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION etl_load_dim_device() RETURNS VOID AS $$
BEGIN
    UPDATE etl_control SET status = 'RUNNING' WHERE table_name = 'dim_device';
    
    INSERT INTO dim_device (
        deviceid, roomkey, devicetypekey, manufacturerkey, 
        devicename, model, installationdate, warrantyexpiry, status
    )
    SELECT 
        sd.deviceid,
        dr.roomkey,
        dt.devicetypekey,
        dm.manufacturerkey,
        sd.devicename,
        sd.manufacturer || ' Model ' || FLOOR(RANDOM() * 1000 + 100)::TEXT,
        CURRENT_DATE - INTERVAL '1 day' * FLOOR(RANDOM() * 730),
        CURRENT_DATE + INTERVAL '1 day' * FLOOR(RANDOM() * 365 + 365),
        'Active'
    FROM smart_home.devices sd
    INNER JOIN dim_room dr ON sd.roomid = dr.roomid
    INNER JOIN smart_home.devicetypes sdt ON sd.devicetypeid = sdt.devicetypeid
    INNER JOIN dim_device_type dt ON sdt.typename = dt.typename
    INNER JOIN dim_manufacturer dm ON sd.manufacturer = dm.manufacturername AND dm.iscurrent = TRUE
    LEFT JOIN dim_device dd ON sd.deviceid = dd.deviceid
    WHERE dd.deviceid IS NULL;
    
    UPDATE etl_control 
    SET status = 'COMPLETED', last_etl_date = NOW(),
        last_target_row_count = (SELECT COUNT(*) FROM dim_device)
    WHERE table_name = 'dim_device';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION etl_load_dim_scene() RETURNS VOID AS $$
BEGIN
    UPDATE etl_control SET status = 'RUNNING' WHERE table_name = 'dim_scene';
    
    INSERT INTO dim_scene (
        sceneid, userkey, scenename, category, description, isactive
    )
    SELECT 
        ss.sceneid,
        du.userkey,
        ss.scenename,
        CASE 
            WHEN ss.scenename LIKE '%Security%' OR ss.scenename LIKE '%Lock%' THEN 'Security'
            WHEN ss.scenename LIKE '%Morning%' OR ss.scenename LIKE '%Night%' THEN 'Comfort'
            WHEN ss.scenename LIKE '%Movie%' OR ss.scenename LIKE '%Entertainment%' THEN 'Entertainment'
            WHEN ss.scenename LIKE '%Cooking%' OR ss.scenename LIKE '%Kitchen%' THEN 'Energy'
            ELSE 'General'
        END,
        ss.description,
        TRUE
    FROM smart_home.scenes ss
    INNER JOIN dim_user du ON ss.userid = du.userid AND du.iscurrent = TRUE
    LEFT JOIN dim_scene ds ON ss.sceneid = ds.sceneid
    WHERE ds.sceneid IS NULL;
    
    UPDATE etl_control 
    SET status = 'COMPLETED', last_etl_date = NOW(),
        last_target_row_count = (SELECT COUNT(*) FROM dim_scene)
    WHERE table_name = 'dim_scene';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION etl_load_bridge_scene_device() RETURNS VOID AS $$
BEGIN
    UPDATE etl_control SET status = 'RUNNING' WHERE table_name = 'bridge_scene_device';
    
    INSERT INTO bridge_scene_device (
        scenekey, devicekey, devicegroupkey, desiredstatus, priority
    )
    SELECT 
        ds.scenekey,
        dd.devicekey,
        ROW_NUMBER() OVER (PARTITION BY ds.scenekey ORDER BY dd.devicekey),
        ssd.desiredstatus,
        ROW_NUMBER() OVER (PARTITION BY ds.scenekey ORDER BY dd.devicekey)
    FROM smart_home.scenedevices ssd
    INNER JOIN dim_scene ds ON ssd.sceneid = ds.sceneid
    INNER JOIN dim_device dd ON ssd.deviceid = dd.deviceid
    LEFT JOIN bridge_scene_device bsd ON ds.scenekey = bsd.scenekey AND dd.devicekey = bsd.devicekey
    WHERE bsd.bridgekey IS NULL;
    
    UPDATE etl_control 
    SET status = 'COMPLETED', last_etl_date = NOW(),
        last_target_row_count = (SELECT COUNT(*) FROM bridge_scene_device)
    WHERE table_name = 'bridge_scene_device';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION etl_generate_fact_data() RETURNS VOID AS $$
DECLARE
    date_rec RECORD;
BEGIN
    FOR date_rec IN SELECT datekey FROM dim_date WHERE date >= '2024-01-01' AND date <= '2024-12-31' LIMIT 100
    LOOP
        INSERT INTO fact_device_usage (
            datekey, devicekey, userkey, roomkey,
            totalactivations, totalusageminutes, energyconsumption_kwh,
            avgresponsetime_ms, errorcount
        )
        SELECT 
            date_rec.datekey,
            d.devicekey,
            d.userkey,
            d.roomkey,
            FLOOR(RANDOM() * 50 + 1)::INTEGER,
            FLOOR(RANDOM() * 480 + 60)::INTEGER,
            ROUND((RANDOM() * 5.0 + 0.1)::NUMERIC, 3),
            FLOOR(RANDOM() * 500 + 100)::INTEGER,
            FLOOR(RANDOM() * 3)::INTEGER
        FROM (
            SELECT DISTINCT 
                dd.devicekey, 
                du.userkey, 
                dr.roomkey
            FROM dim_device dd
            INNER JOIN dim_room dr ON dd.roomkey = dr.roomkey
            INNER JOIN dim_user du ON dr.userkey = du.userkey
            WHERE du.iscurrent = TRUE
            ORDER BY RANDOM()
            LIMIT 5
        ) d;
        
        INSERT INTO fact_scene_execution (
            datekey, timekey, scenekey, userkey,
            executioncount, successfulexecutions, failedexecutions,
            avgexecutiontime_ms, devicesaffected
        )
        SELECT 
            date_rec.datekey,
            (FLOOR(RANDOM() * 24) * 100 + (FLOOR(RANDOM() * 4) * 15))::INTEGER,
            ds.scenekey,
            ds.userkey,
            FLOOR(RANDOM() * 10 + 1)::INTEGER,
            FLOOR(RANDOM() * 8 + 1)::INTEGER,
            FLOOR(RANDOM() * 2)::INTEGER,
            FLOOR(RANDOM() * 2000 + 500)::INTEGER,
            FLOOR(RANDOM() * 5 + 1)::INTEGER
        FROM (
            SELECT DISTINCT scenekey, userkey
            FROM dim_scene
            ORDER BY RANDOM()
            LIMIT 3
        ) ds;
        
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION run_etl_process() RETURNS VOID AS $$
BEGIN
    PERFORM etl_load_dim_user();
    PERFORM etl_load_dim_room();
    PERFORM etl_load_dim_device();
    PERFORM etl_load_dim_scene();
    PERFORM etl_load_bridge_scene_device();
    PERFORM etl_generate_fact_data();
    
    INSERT INTO fact_monthly_summary (
        year, month, userkey,
        totaldeviceactivations, totalenergyconsumption_kwh, totalsceneexecutions,
        avgdevicesperscene, mostuseddevicekey, mostusedscenekey
    )
    SELECT 
        dd.year,
        dd.month,
        fdu.userkey,
        SUM(fdu.totalactivations),
        SUM(fdu.energyconsumption_kwh),
        COUNT(DISTINCT fse.scenekey),
        AVG(fse.devicesaffected),
        (SELECT devicekey FROM fact_device_usage 
         WHERE userkey = fdu.userkey 
         ORDER BY totalactivations DESC LIMIT 1),
        (SELECT scenekey FROM fact_scene_execution 
         WHERE userkey = fse.userkey 
         ORDER BY executioncount DESC LIMIT 1)
    FROM fact_device_usage fdu
    INNER JOIN dim_date dd ON fdu.datekey = dd.datekey
    LEFT JOIN fact_scene_execution fse ON fdu.userkey = fse.userkey AND fdu.datekey = fse.datekey
    LEFT JOIN fact_monthly_summary existing ON dd.year = existing.year 
        AND dd.month = existing.month AND fdu.userkey = existing.userkey
    WHERE existing.summarykey IS NULL
    GROUP BY dd.year, dd.month, fdu.userkey;
END;
$$ LANGUAGE plpgsql; 