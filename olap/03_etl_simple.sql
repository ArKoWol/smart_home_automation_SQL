\c smart_home_olap;

CREATE OR REPLACE FUNCTION load_sample_data() RETURNS VOID AS $$
BEGIN

    INSERT INTO dim_user (userid, name, email, registrationdate, usertype, city, country, validfrom, validto, iscurrent)
    VALUES 
        (1, 'John Doe', 'john.doe@example.com', '2023-01-15', 'Premium', 'New York', 'United States', NOW(), NULL, TRUE),
        (2, 'Jane Smith', 'jane.smith@example.com', '2023-02-20', 'Standard', 'London', 'United Kingdom', NOW(), NULL, TRUE),
        (3, 'Bob Johnson', 'bob.johnson@example.com', '2023-03-10', 'Trial', 'Berlin', 'Germany', NOW(), NULL, TRUE)
    ON CONFLICT (userid, iscurrent) DO NOTHING;

    INSERT INTO dim_room (roomid, userkey, roomname, roomtype, area_sqm, floor, haswindows)
    SELECT 
        r.roomid,
        u.userkey,
        r.roomname,
        CASE 
            WHEN r.roomname LIKE '%Living%' THEN 'Living Room'
            WHEN r.roomname LIKE '%Kitchen%' THEN 'Kitchen'
            WHEN r.roomname LIKE '%Bedroom%' THEN 'Bedroom'
            ELSE 'Other'
        END,
        CASE 
            WHEN r.roomname LIKE '%Living%' THEN 25.5
            WHEN r.roomname LIKE '%Kitchen%' THEN 15.2
            WHEN r.roomname LIKE '%Bedroom%' THEN 18.7
            ELSE 12.0
        END,
        1,
        TRUE
    FROM (VALUES 
        (1, 1, 'Living Room'),
        (2, 1, 'Kitchen'),
        (3, 2, 'Bedroom')
    ) AS r(roomid, userid, roomname)
    JOIN dim_user u ON r.userid = u.userid AND u.iscurrent = TRUE
    ON CONFLICT (roomid) DO NOTHING;

    INSERT INTO dim_device (deviceid, roomkey, devicetypekey, manufacturerkey, devicename, model, installationdate, warrantyexpiry, status)
    SELECT 
        d.deviceid,
        dr.roomkey,
        dt.devicetypekey,
        dm.manufacturerkey,
        d.devicename,
        dm.manufacturername || ' Model ' || (100 + d.deviceid)::TEXT,
        CURRENT_DATE - INTERVAL '1 year',
        CURRENT_DATE + INTERVAL '2 years',
        'Active'
    FROM (VALUES 
        (1, 1, 'Smart Light', 'Philips', 'Living Room Main Light'),
        (2, 1, 'Smart Switch', 'Leviton', 'Living Room Switch'),
        (3, 1, 'Smart Speaker', 'Amazon', 'Living Room Speaker'),
        (4, 2, 'Smart Light', 'IKEA', 'Kitchen Light'),
        (5, 2, 'Smart Thermostat', 'Nest', 'Kitchen Thermostat'),
        (6, 3, 'Smart Light', 'Philips', 'Bedroom Light'),
        (7, 3, 'Smart Lock', 'August', 'Bedroom Door Lock'),
        (8, 1, 'Smart Camera', 'Ring', 'Living Room Camera'),
        (9, 2, 'Smart Sensor', 'SmartThings', 'Kitchen Motion Sensor'),
        (10, 3, 'Smart Sensor', 'SmartThings', 'Bedroom Temperature Sensor')
    ) AS d(deviceid, roomid, typename, manufacturer, devicename)
    JOIN dim_room dr ON d.roomid = dr.roomid
    JOIN dim_device_type dt ON d.typename = dt.typename
    JOIN dim_manufacturer dm ON d.manufacturer = dm.manufacturername AND dm.iscurrent = TRUE
    ON CONFLICT (deviceid) DO NOTHING;

    INSERT INTO dim_scene (sceneid, userkey, scenename, category, description, isactive)
    SELECT 
        s.sceneid,
        u.userkey,
        s.scenename,
        CASE 
            WHEN s.scenename LIKE '%Security%' OR s.scenename LIKE '%Lock%' THEN 'Security'
            WHEN s.scenename LIKE '%Morning%' OR s.scenename LIKE '%Night%' THEN 'Comfort'
            WHEN s.scenename LIKE '%Movie%' OR s.scenename LIKE '%Entertainment%' THEN 'Entertainment'
            WHEN s.scenename LIKE '%Cooking%' OR s.scenename LIKE '%Kitchen%' THEN 'Energy'
            ELSE 'General'
        END,
        s.description,
        TRUE
    FROM (VALUES 
        (1, 1, 'Good Morning', 'Turn on lights and adjust temperature for morning routine'),
        (2, 1, 'Good Night', 'Turn off all lights and lock doors for bedtime'),
        (3, 1, 'Movie Time', 'Dim lights and turn on entertainment system'),
        (4, 2, 'Home Security', 'Turn on cameras and sensors when leaving home'),
        (5, 2, 'Cooking Mode', 'Adjust kitchen lighting and turn on ventilation')
    ) AS s(sceneid, userid, scenename, description)
    JOIN dim_user u ON s.userid = u.userid AND u.iscurrent = TRUE
    ON CONFLICT (sceneid) DO NOTHING;

    INSERT INTO bridge_scene_device (scenekey, devicekey, devicegroupkey, desiredstatus, priority)
    SELECT 
        ds.scenekey,
        dd.devicekey,
        ROW_NUMBER() OVER (PARTITION BY ds.scenekey ORDER BY dd.devicekey),
        ssd.desiredstatus,
        ROW_NUMBER() OVER (PARTITION BY ds.scenekey ORDER BY dd.devicekey)
    FROM (VALUES 
        (1, 1, 'ON'),
        (1, 4, 'ON'),
        (2, 1, 'OFF'),
        (2, 4, 'OFF'),
        (2, 6, 'OFF'),
        (3, 1, 'DIM_50%'),
        (3, 3, 'ON'),
        (4, 8, 'ON'),
        (4, 9, 'ARMED'),
        (5, 4, 'BRIGHT'),
        (5, 9, 'ON')
    ) AS ssd(sceneid, deviceid, desiredstatus)
    JOIN dim_scene ds ON ssd.sceneid = ds.sceneid
    JOIN dim_device dd ON ssd.deviceid = dd.deviceid
    ON CONFLICT DO NOTHING;

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_fact_data() RETURNS VOID AS $$
DECLARE
    date_rec RECORD;
    device_rec RECORD;
    scene_rec RECORD;
BEGIN
    FOR date_rec IN SELECT datekey FROM dim_date WHERE date >= '2024-01-01' AND date <= '2024-12-31' LIMIT 50
    LOOP
        FOR device_rec IN SELECT devicekey, userkey, roomkey FROM dim_device LIMIT 5
        LOOP
            INSERT INTO fact_device_usage (
                datekey, devicekey, userkey, roomkey,
                totalactivations, totalusageminutes, energyconsumption_kwh,
                avgresponsetime_ms, errorcount
            )
            VALUES (
                date_rec.datekey,
                device_rec.devicekey,
                device_rec.userkey,
                device_rec.roomkey,
                FLOOR(RANDOM() * 50 + 1)::INTEGER,
                FLOOR(RANDOM() * 480 + 60)::INTEGER,
                ROUND((RANDOM() * 5.0 + 0.1)::NUMERIC, 3),
                FLOOR(RANDOM() * 500 + 100)::INTEGER,
                FLOOR(RANDOM() * 3)::INTEGER
            )
            ON CONFLICT DO NOTHING;
        END LOOP;
        
        FOR scene_rec IN SELECT scenekey, userkey FROM dim_scene LIMIT 3
        LOOP
            INSERT INTO fact_scene_execution (
                datekey, timekey, scenekey, userkey,
                executioncount, successfulexecutions, failedexecutions,
                avgexecutiontime_ms, devicesaffected
            )
            VALUES (
                date_rec.datekey,
                (FLOOR(RANDOM() * 24) * 100 + (FLOOR(RANDOM() * 4) * 15))::INTEGER,
                scene_rec.scenekey,
                scene_rec.userkey,
                FLOOR(RANDOM() * 10 + 1)::INTEGER,
                FLOOR(RANDOM() * 8 + 1)::INTEGER,
                FLOOR(RANDOM() * 2)::INTEGER,
                FLOOR(RANDOM() * 2000 + 500)::INTEGER,
                FLOOR(RANDOM() * 5 + 1)::INTEGER
            )
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION run_demo_etl() RETURNS VOID AS $$
BEGIN
    PERFORM load_sample_data();
    PERFORM generate_fact_data();
    
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
    
    RAISE NOTICE 'ETL Demo completed successfully!';
END;
$$ LANGUAGE plpgsql; 