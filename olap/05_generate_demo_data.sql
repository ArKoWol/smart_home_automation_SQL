-- ======================================================
-- ИСПРАВЛЕННАЯ ГЕНЕРАЦИЯ ДЕМОНСТРАЦИОННЫХ ДАННЫХ ДЛЯ POWER BI
-- ======================================================

-- Подключение к OLAP базе
\c smart_home_olap

-- ======================================================
-- 1. ДОПОЛНИТЕЛЬНЫЕ ПОЛЬЗОВАТЕЛИ (SCD Type 2)
-- ======================================================

-- Добавляем больше пользователей
INSERT INTO dim_user (userid, name, email, registrationdate, usertype, city, country, validfrom, validto, iscurrent) VALUES
(4, 'Alice Johnson', 'alice.johnson@email.com', '2024-01-15', 'Premium', 'San Francisco', 'USA', '2024-01-15 00:00:00', NULL, true),
(5, 'Mike Wilson', 'mike.wilson@email.com', '2024-02-01', 'Standard', 'Los Angeles', 'USA', '2024-02-01 00:00:00', NULL, true),
(6, 'Sarah Davis', 'sarah.davis@email.com', '2024-02-15', 'Premium', 'Seattle', 'USA', '2024-02-15 00:00:00', NULL, true),
(7, 'Tom Brown', 'tom.brown@email.com', '2024-03-01', 'Trial', 'Portland', 'USA', '2024-03-01 00:00:00', NULL, true),
(8, 'Lisa Garcia', 'lisa.garcia@email.com', '2024-03-15', 'Standard', 'Denver', 'USA', '2024-03-15 00:00:00', NULL, true);

-- ======================================================
-- 2. ДОПОЛНИТЕЛЬНЫЕ КОМНАТЫ
-- ======================================================

-- Добавляем комнаты для новых пользователей (правильные имена колонок)
INSERT INTO dim_room (roomid, userkey, roomname, roomtype, area_sqm, floor, haswindows) 
SELECT 
    ROW_NUMBER() OVER () + 100 as roomid,
    u.userkey,
    room_data.roomname,
    room_data.roomtype,
    room_data.area_sqm,
    room_data.floor,
    room_data.haswindows
FROM dim_user u
CROSS JOIN (
    VALUES 
    ('Master Bedroom', 'Bedroom', 25.5, 2, true),
    ('Guest Bedroom', 'Bedroom', 18.0, 2, true),
    ('Home Office', 'Office', 15.0, 1, true),
    ('Garage', 'Utility', 40.0, 1, false),
    ('Bathroom', 'Bathroom', 8.5, 1, false),
    ('Dining Room', 'Dining', 20.0, 1, true),
    ('Basement', 'Utility', 35.0, 0, false)
) AS room_data(roomname, roomtype, area_sqm, floor, haswindows)
WHERE u.userid IN (4, 5, 6, 7, 8) AND u.iscurrent = true;

-- ======================================================
-- 3. ДОПОЛНИТЕЛЬНЫЕ УСТРОЙСТВА
-- ======================================================

-- Добавляем разнообразные устройства
INSERT INTO dim_device (deviceid, roomkey, devicetypekey, manufacturerkey, devicename, model, installationdate, warrantyexpiry, status)
SELECT 
    ROW_NUMBER() OVER () + 1000 as deviceid,
    r.roomkey,
    device_data.devicetypekey,
    device_data.manufacturerkey,
    device_data.devicename,
    device_data.model,
    device_data.installationdate::date,
    device_data.warrantyexpiry::date,
    'Active'
FROM dim_room r
CROSS JOIN (
    VALUES 
    (1, 1, 'Smart LED Bulb', 'Hue Color', '2024-01-10', '2026-01-10'),
    (2, 2, 'Smart Thermostat', 'Nest Gen 3', '2024-01-15', '2026-01-15'),
    (3, 3, 'Security Camera', 'Ring Pro', '2024-01-20', '2026-01-20'),
    (4, 4, 'Smart Speaker', 'Echo Dot 5', '2024-01-25', '2026-01-25'),
    (5, 5, 'Smart Switch', 'Kasa HS200', '2024-02-01', '2026-02-01'),
    (1, 6, 'Motion Sensor', 'Hue Motion', '2024-02-05', '2026-02-05'),
    (2, 7, 'Smart Door Lock', 'August Pro', '2024-02-10', '2026-02-10'),
    (3, 8, 'Smoke Detector', 'Nest Protect', '2024-02-15', '2026-02-15'),
    (4, 9, 'Smart Plug', 'Alexa Smart Plug', '2024-02-20', '2026-02-20'),
    (5, 10, 'Smart TV', 'Samsung QLED', '2024-02-25', '2026-02-25')
) AS device_data(devicetypekey, manufacturerkey, devicename, model, installationdate, warrantyexpiry)
WHERE r.roomkey <= 20; -- Ограничиваем количество

-- ======================================================
-- 4. ДОПОЛНИТЕЛЬНЫЕ СЦЕНАРИИ
-- ======================================================

-- Добавляем разнообразные сценарии (правильные имена колонок)
INSERT INTO dim_scene (sceneid, userkey, scenename, category, description, isactive)
SELECT 
    ROW_NUMBER() OVER () + 100 as sceneid,
    u.userkey,
    scene_data.scenename,
    scene_data.category,
    scene_data.description,
    true
FROM dim_user u
CROSS JOIN (
    VALUES 
    ('Good Night', 'Sleep', 'Turn off all lights, lock doors, set thermostat to 68°F'),
    ('Movie Time', 'Entertainment', 'Dim lights, turn on TV, close blinds'),
    ('Away Mode', 'Security', 'Turn off all devices, arm security system'),
    ('Dinner Time', 'Daily', 'Turn on dining room lights, play soft music'),
    ('Work Mode', 'Productivity', 'Turn on office lights, start white noise'),
    ('Party Mode', 'Entertainment', 'Turn on all lights, play party music'),
    ('Energy Saver', 'Utility', 'Reduce thermostat, turn off unused devices')
) AS scene_data(scenename, category, description)
WHERE u.iscurrent = true;

-- ======================================================
-- 5. BRIDGE TABLE - СВЯЗИ СЦЕНАРИЙ-УСТРОЙСТВО
-- ======================================================

-- Удаляем старые связи и создаем новые (правильные имена колонок)
DELETE FROM bridge_scene_device;

-- Создаем реалистичные связи между сценариями и устройствами
INSERT INTO bridge_scene_device (scenekey, devicekey, devicegroupkey, desiredstatus, priority)
SELECT 
    s.scenekey,
    d.devicekey,
    1 as devicegroupkey, -- Используем группу по умолчанию
    CASE 
        WHEN s.scenename = 'Good Night' THEN 'OFF'
        WHEN s.scenename = 'Good Morning' THEN 'ON'
        WHEN s.scenename = 'Movie Time' THEN 'DIM'
        WHEN s.scenename = 'Away Mode' THEN 'ARMED'
        ELSE 'AUTO'
    END as desiredstatus,
    ROW_NUMBER() OVER (PARTITION BY s.scenekey ORDER BY d.devicekey) as priority
FROM dim_scene s
JOIN dim_device d ON true  -- Cartesian join для создания связей
WHERE 
    -- Good Morning: освещение + термостат
    (s.scenename = 'Good Morning' AND (d.devicename LIKE '%Light%' OR d.devicename LIKE '%Thermostat%'))
    -- Good Night: все устройства кроме безопасности
    OR (s.scenename = 'Good Night' AND d.devicename NOT LIKE '%Camera%' AND d.devicename NOT LIKE '%Smoke%')
    -- Movie Time: освещение + TV + звук
    OR (s.scenename = 'Movie Time' AND (d.devicename LIKE '%Light%' OR d.devicename LIKE '%TV%' OR d.devicename LIKE '%Speaker%'))
    -- Away Mode: безопасность + замки
    OR (s.scenename = 'Away Mode' AND (d.devicename LIKE '%Camera%' OR d.devicename LIKE '%Lock%' OR d.devicename LIKE '%Sensor%'))
    -- Dinner Time: освещение + музыка
    OR (s.scenename = 'Dinner Time' AND (d.devicename LIKE '%Light%' OR d.devicename LIKE '%Speaker%'))
    -- Work Mode: офисные устройства
    OR (s.scenename = 'Work Mode' AND d.devicename LIKE '%Light%')
    -- Party Mode: все развлекательные устройства
    OR (s.scenename = 'Party Mode' AND (d.devicename LIKE '%Light%' OR d.devicename LIKE '%Speaker%' OR d.devicename LIKE '%TV%'))
    -- Energy Saver: термостат + выключатели
    OR (s.scenename = 'Energy Saver' AND (d.devicename LIKE '%Thermostat%' OR d.devicename LIKE '%Switch%' OR d.devicename LIKE '%Plug%'));

-- ======================================================
-- 6. ГЕНЕРАЦИЯ ФАКТОВЫХ ДАННЫХ - ИСПОЛЬЗОВАНИЕ УСТРОЙСТВ
-- ======================================================

-- Удаляем старые данные
DELETE FROM fact_device_usage;

-- Генерируем реалистичные данные использования устройств за последние 3 месяца
INSERT INTO fact_device_usage (
    datekey, devicekey, userkey, roomkey, 
    totalactivations, totalusageminutes, energyconsumption_kwh, 
    avgresponsetime_ms, errorcount
)
SELECT 
    dd.datekey,
    d.devicekey,
    u.userkey,
    r.roomkey,
    -- Случайные, но реалистичные значения активаций
    CASE 
        WHEN dt.typename = 'Lighting' THEN (RANDOM() * 20 + 5)::INTEGER
        WHEN dt.typename = 'Climate Control' THEN (RANDOM() * 10 + 2)::INTEGER
        WHEN dt.typename = 'Security' THEN (RANDOM() * 15 + 3)::INTEGER
        WHEN dt.typename = 'Entertainment' THEN (RANDOM() * 8 + 1)::INTEGER
        ELSE (RANDOM() * 12 + 2)::INTEGER
    END as totalactivations,
    
    -- Время использования
    CASE 
        WHEN dt.typename = 'Lighting' THEN (RANDOM() * 300 + 60)::INTEGER
        WHEN dt.typename = 'Climate Control' THEN (RANDOM() * 1200 + 600)::INTEGER
        WHEN dt.typename = 'Security' THEN (RANDOM() * 180 + 30)::INTEGER
        WHEN dt.typename = 'Entertainment' THEN (RANDOM() * 240 + 45)::INTEGER
        ELSE (RANDOM() * 120 + 30)::INTEGER
    END as totalusageminutes,
    
    -- Потребление энергии
    CASE 
        WHEN dt.typename = 'Lighting' THEN ROUND((RANDOM() * 2 + 0.5)::NUMERIC, 3)
        WHEN dt.typename = 'Climate Control' THEN ROUND((RANDOM() * 15 + 5)::NUMERIC, 3)
        WHEN dt.typename = 'Security' THEN ROUND((RANDOM() * 1 + 0.1)::NUMERIC, 3)
        WHEN dt.typename = 'Entertainment' THEN ROUND((RANDOM() * 8 + 2)::NUMERIC, 3)
        ELSE ROUND((RANDOM() * 3 + 0.5)::NUMERIC, 3)
    END as energyconsumption_kwh,
    
    (RANDOM() * 500 + 50)::INTEGER as avgresponsetime_ms,
    (RANDOM() * 3)::INTEGER as errorcount

FROM dim_date dd
CROSS JOIN dim_device d
JOIN dim_room r ON d.roomkey = r.roomkey
JOIN dim_user u ON r.userkey = u.userkey
JOIN dim_device_type dt ON d.devicetypekey = dt.devicetypekey
WHERE 
    dd.date >= '2024-01-01' 
    AND dd.date <= '2024-11-30'
    AND u.iscurrent = true
    AND (RANDOM() > 0.3) -- 70% вероятность использования в день
    AND dd.dayofyear % 7 BETWEEN 1 AND 5; -- Больше активности в будние дни

-- ======================================================
-- 7. ГЕНЕРАЦИЯ ФАКТОВЫХ ДАННЫХ - ВЫПОЛНЕНИЕ СЦЕНАРИЕВ
-- ======================================================

-- Удаляем старые данные
DELETE FROM fact_scene_execution;

-- Генерируем данные выполнения сценариев
INSERT INTO fact_scene_execution (
    datekey, timekey, scenekey, userkey,
    executioncount, successfulexecutions, failedexecutions,
    avgexecutiontime_ms, devicesaffected
)
SELECT 
    dd.datekey,
    dt.timekey,
    s.scenekey,
    s.userkey,
    -- Количество выполнений
    CASE 
        WHEN s.scenename = 'Good Morning' THEN 1
        WHEN s.scenename = 'Good Night' THEN 1
        WHEN s.scenename = 'Movie Time' THEN (RANDOM() * 2)::INTEGER + 1
        WHEN s.scenename = 'Away Mode' THEN (RANDOM() * 1)::INTEGER + 1
        ELSE (RANDOM() * 2 + 1)::INTEGER
    END as executioncount,
    
    -- Успешные выполнения (80-95% от общего)
    CASE 
        WHEN s.scenename = 'Good Morning' THEN 1
        WHEN s.scenename = 'Good Night' THEN 1
        WHEN s.scenename = 'Movie Time' THEN (RANDOM() * 2)::INTEGER + 1
        WHEN s.scenename = 'Away Mode' THEN (RANDOM() * 1)::INTEGER + 1
        ELSE (RANDOM() * 2)::INTEGER + 1
    END as successfulexecutions,
    
    -- Неудачные выполнения (редко)
    (RANDOM() * 0.3)::INTEGER as failedexecutions,
    
    -- Время выполнения
    (RANDOM() * 3000 + 500)::INTEGER as avgexecutiontime_ms,
    
    -- Количество задействованных устройств
    CASE 
        WHEN s.scenename = 'Good Morning' THEN 3 + (RANDOM() * 2)::INTEGER
        WHEN s.scenename = 'Good Night' THEN 5 + (RANDOM() * 3)::INTEGER
        WHEN s.scenename = 'Movie Time' THEN 2 + (RANDOM() * 2)::INTEGER
        WHEN s.scenename = 'Away Mode' THEN 4 + (RANDOM() * 2)::INTEGER
        ELSE 2 + (RANDOM() * 3)::INTEGER
    END as devicesaffected

FROM dim_date dd
CROSS JOIN dim_time dt
CROSS JOIN dim_scene s
JOIN dim_user u ON s.userkey = u.userkey
WHERE 
    dd.date >= '2024-01-01' 
    AND dd.date <= '2024-11-30'
    AND u.iscurrent = true
    -- Время выполнения сценариев зависит от типа
    AND (
        (s.scenename = 'Good Morning' AND dt.hour BETWEEN 6 AND 9)
        OR (s.scenename = 'Good Night' AND dt.hour BETWEEN 21 AND 23)
        OR (s.scenename = 'Movie Time' AND dt.hour BETWEEN 18 AND 22)
        OR (s.scenename = 'Away Mode' AND dt.hour BETWEEN 8 AND 18)
        OR (s.scenename IN ('Dinner Time', 'Work Mode', 'Party Mode', 'Energy Saver') AND dt.hour BETWEEN 9 AND 21)
    )
    AND (RANDOM() > 0.8); -- 20% вероятность выполнения сценария

-- ======================================================
-- 8. ПРОВЕРКА РЕЗУЛЬТАТОВ
-- ======================================================

-- Показываем статистику по созданным данным
SELECT 'СТАТИСТИКА СОЗДАННЫХ ДАННЫХ' as info;

SELECT 
    'dim_user' as table_name, 
    COUNT(*) as total_records,
    COUNT(CASE WHEN iscurrent = true THEN 1 END) as current_records
FROM dim_user
UNION ALL
SELECT 'dim_room', COUNT(*), COUNT(*) FROM dim_room
UNION ALL
SELECT 'dim_device', COUNT(*), COUNT(*) FROM dim_device
UNION ALL
SELECT 'dim_scene', COUNT(*), COUNT(*) FROM dim_scene
UNION ALL
SELECT 'bridge_scene_device', COUNT(*), COUNT(*) FROM bridge_scene_device
UNION ALL
SELECT 'fact_device_usage', COUNT(*), COUNT(*) FROM fact_device_usage
UNION ALL
SELECT 'fact_scene_execution', COUNT(*), COUNT(*) FROM fact_scene_execution
ORDER BY table_name;

-- Показываем примеры данных для проверки
SELECT 'ПРИМЕРЫ ДАННЫХ ДЛЯ POWER BI' as info;

-- Топ устройств по потреблению энергии
SELECT 
    d.devicename,
    dt.typename,
    ROUND(SUM(f.energyconsumption_kwh), 2) as total_energy,
    COUNT(*) as usage_days
FROM fact_device_usage f
JOIN dim_device d ON f.devicekey = d.devicekey
JOIN dim_device_type dt ON d.devicetypekey = dt.devicetypekey
GROUP BY d.devicename, dt.typename
ORDER BY total_energy DESC
LIMIT 10;

-- Успешность сценариев
SELECT 
    s.scenename,
    ROUND(AVG(f.successrate), 2) as avg_success_rate,
    SUM(f.executioncount) as total_executions
FROM fact_scene_execution f
JOIN dim_scene s ON f.scenekey = s.scenekey
GROUP BY s.scenename
ORDER BY avg_success_rate DESC; 