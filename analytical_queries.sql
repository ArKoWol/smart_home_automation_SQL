SELECT 
    dt.TypeName as DeviceType,
    d.DeviceName,
    d.Manufacturer,
    r.RoomName,
    u.Name as UserName,
    COUNT(ds.StatusID) as TotalStatusChanges,
    COUNT(DISTINCT DATE(ds.StatusTimestamp)) as ActiveDays,
    MAX(ds.StatusTimestamp) as LastActivity
FROM Devices d
    JOIN DeviceTypes dt ON d.DeviceTypeID = dt.DeviceTypeID
    JOIN Rooms r ON d.RoomID = r.RoomID
    JOIN Users u ON r.UserID = u.UserID
    LEFT JOIN DeviceStatus ds ON d.DeviceID = ds.DeviceID
WHERE ds.StatusTimestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY dt.TypeName, d.DeviceName, d.Manufacturer, r.RoomName, u.Name
HAVING COUNT(ds.StatusID) > 0
ORDER BY TotalStatusChanges DESC
LIMIT 20;

SELECT 
    u.Name as UserName,
    u.Email,
    COUNT(DISTINCT s.SceneID) as TotalScenes,
    COUNT(DISTINCT d.DeviceID) as TotalDevices,
    COUNT(DISTINCT r.RoomID) as TotalRooms,
    COUNT(e.EventID) as TotalEvents,
    COUNT(DISTINCT DATE(e.EventTimestamp)) as ActiveDays
FROM Users u
    LEFT JOIN Rooms r ON u.UserID = r.UserID
    LEFT JOIN Devices d ON r.RoomID = d.RoomID
    LEFT JOIN Scenes s ON u.UserID = s.UserID
    LEFT JOIN Events e ON u.UserID = e.UserID
GROUP BY u.UserID, u.Name, u.Email
ORDER BY TotalEvents DESC;

SELECT 
    s.SceneName,
    s.Description,
    u.Name as UserName,
    COUNT(sd.DeviceID) as DevicesInScene,
    COUNT(e.EventID) as TimesExecuted
FROM Scenes s
    JOIN Users u ON s.UserID = u.UserID
    LEFT JOIN SceneDevices sd ON s.SceneID = sd.SceneID
    LEFT JOIN Events e ON s.SceneID = e.SceneID 
GROUP BY s.SceneID, s.SceneName, s.Description, u.Name
ORDER BY TimesExecuted DESC;

SELECT 
    dt.TypeName as DeviceType,
    COUNT(DISTINCT d.DeviceID) as TotalDevices,
    COUNT(DISTINCT CASE WHEN ds.StatusValue ILIKE '%on%' OR ds.StatusValue ILIKE '%active%' 
          THEN d.DeviceID END) as ActiveDevices,
    COUNT(DISTINCT CASE WHEN ds.StatusValue ILIKE '%off%' OR ds.StatusValue ILIKE '%inactive%' 
          THEN d.DeviceID END) as InactiveDevices,
    ROUND(
        COUNT(DISTINCT CASE WHEN ds.StatusValue ILIKE '%on%' OR ds.StatusValue ILIKE '%active%' 
              THEN d.DeviceID END) * 100.0 / COUNT(DISTINCT d.DeviceID), 2
    ) as ActivePercentage
FROM Devices d
    JOIN DeviceTypes dt ON d.DeviceTypeID = dt.DeviceTypeID
    LEFT JOIN DeviceStatus ds ON d.DeviceID = ds.DeviceID
    AND ds.StatusTimestamp = (
        SELECT MAX(StatusTimestamp) 
        FROM DeviceStatus ds2 
        WHERE ds2.DeviceID = d.DeviceID
    )
GROUP BY dt.TypeName
ORDER BY TotalDevices DESC;

SELECT 
    dd.Year,
    dd.Month,
    dd.MonthName,
    ddt.TypeName as DeviceType,
    COUNT(DISTINCT fdu.DeviceKey) as ActiveDevices,
    SUM(fdu.TotalActivations) as TotalActivations,
    SUM(fdu.EnergyConsumption_kWh) as TotalEnergyConsumption,
    ROUND(AVG(fdu.EnergyConsumption_kWh), 3) as AvgEnergyPerDevice
FROM FACT_DEVICE_USAGE fdu
    JOIN DIM_DATE dd ON fdu.DateKey = dd.DateKey
    JOIN DIM_DEVICE dev ON fdu.DeviceKey = dev.DeviceKey
    JOIN DIM_DEVICE_TYPE ddt ON dev.DeviceTypeKey = ddt.DeviceTypeKey
WHERE dd.Date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY dd.Year, dd.Month, dd.MonthName, ddt.TypeName
ORDER BY dd.Year DESC, dd.Month DESC, TotalEnergyConsumption DESC;

SELECT 
    dt.TimeOfDay,
    dt.Hour,
    ds.Category as SceneCategory,
    COUNT(*) as TotalExecutions,
    SUM(fse.ExecutionCount) as ExecutionAttempts,
    SUM(fse.SuccessfulExecutions) as SuccessfulExecutions,
    ROUND(AVG(fse.SuccessRate), 2) as AvgSuccessRate
FROM FACT_SCENE_EXECUTION fse
    JOIN DIM_TIME dt ON fse.TimeKey = dt.TimeKey
    JOIN DIM_SCENE ds ON fse.SceneKey = ds.SceneKey
GROUP BY dt.TimeOfDay, dt.Hour, ds.Category
ORDER BY dt.Hour, ds.Category;

SELECT 
    du.Name,
    du.UserType,
    du.City,
    COUNT(DISTINCT fdu.DeviceKey) as UniqueDevicesUsed,
    SUM(fdu.TotalActivations) as TotalActivations,
    SUM(fdu.EnergyConsumption_kWh) as TotalEnergyConsumption,
    AVG(fdu.UsageScore) as AvgUsageScore
FROM DIM_USER du
    LEFT JOIN FACT_DEVICE_USAGE fdu ON du.UserKey = fdu.UserKey
WHERE du.IsCurrent = TRUE
GROUP BY du.UserKey, du.Name, du.UserType, du.City
ORDER BY TotalActivations DESC;

SELECT 
    dr.RoomType,
    dr.RoomName,
    du.Name as UserName,
    dr.Area_SqM,
    COUNT(DISTINCT dev.DeviceKey) as DeviceCount,
    SUM(fdu.TotalActivations) as TotalActivations,
    SUM(fdu.EnergyConsumption_kWh) as TotalEnergy,
    ROUND(
        SUM(fdu.TotalActivations) / NULLIF(dr.Area_SqM, 0), 2
    ) as ActivationsPerSqM,
    ROUND(
        SUM(fdu.EnergyConsumption_kWh) / NULLIF(dr.Area_SqM, 0), 3
    ) as EnergyPerSqM
FROM DIM_ROOM dr
    JOIN DIM_USER du ON dr.UserKey = du.UserKey
    LEFT JOIN DIM_DEVICE dev ON dr.RoomKey = dev.RoomKey
    LEFT JOIN FACT_DEVICE_USAGE fdu ON dr.RoomKey = fdu.RoomKey
WHERE du.IsCurrent = TRUE
    AND dev.Status = 'Active'
GROUP BY dr.RoomKey, dr.RoomType, dr.RoomName, du.Name, dr.Area_SqM
HAVING COUNT(DISTINCT dev.DeviceKey) > 0
ORDER BY TotalActivations DESC;

SELECT 
    dm.ManufacturerName,
    dm.Country,
    COUNT(DISTINCT dev.DeviceKey) as TotalDevices,
    SUM(fdu.TotalActivations) as TotalActivations,
    SUM(fdu.EnergyConsumption_kWh) as TotalEnergyConsumption,
    AVG(fdu.UsageScore) as AvgUsageScore,
    SUM(fdu.ErrorCount) as TotalErrors,
    ROUND(
        SUM(fdu.ErrorCount) * 100.0 / 
        NULLIF(SUM(fdu.TotalActivations), 0), 4
    ) as ErrorRate,
    ROUND(
        COUNT(DISTINCT dev.DeviceKey) * 100.0 / 
        (SELECT COUNT(*) FROM DIM_DEVICE WHERE Status = 'Active'), 2
    ) as MarketShare
FROM DIM_MANUFACTURER dm
    JOIN DIM_DEVICE dev ON dm.ManufacturerKey = dev.ManufacturerKey
    LEFT JOIN FACT_DEVICE_USAGE fdu ON dev.DeviceKey = fdu.DeviceKey
WHERE dm.IsCurrent = TRUE
    AND dev.Status = 'Active'
GROUP BY dm.ManufacturerKey, dm.ManufacturerName, dm.Country
ORDER BY MarketShare DESC, AvgUsageScore DESC;

SELECT 
    'Total Active Users' as Metric, 
    COUNT(DISTINCT du.UserKey)::text as Value
FROM DIM_USER du WHERE du.IsCurrent = TRUE
UNION ALL
SELECT 
    'Total Active Devices', 
    COUNT(DISTINCT dev.DeviceKey)::text
FROM DIM_DEVICE dev WHERE dev.Status = 'Active'
UNION ALL
SELECT 
    'Total Energy Consumption (Last 30 Days)', 
    ROUND(SUM(fdu.EnergyConsumption_kWh), 2)::text || ' kWh'
FROM FACT_DEVICE_USAGE fdu
    JOIN DIM_DATE dd ON fdu.DateKey = dd.DateKey
WHERE dd.Date >= CURRENT_DATE - INTERVAL '30 days'
UNION ALL
SELECT 
    'Average Scene Success Rate', 
    ROUND(AVG(fse.SuccessRate), 2)::text || '%'
FROM FACT_SCENE_EXECUTION fse
    JOIN DIM_DATE dd ON fse.DateKey = dd.DateKey
WHERE dd.Date >= CURRENT_DATE - INTERVAL '30 days'; 